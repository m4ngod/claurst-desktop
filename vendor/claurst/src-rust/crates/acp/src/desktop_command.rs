//! Desktop commands always enter a restricted-read Seatbelt sandbox.
use async_trait::async_trait;
use claurst_core::permissions::{PermissionDecision, PermissionRequest};
use claurst_tools::{PendingPermissionRequest, PermissionLevel, Tool, ToolContext, ToolResult};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::{
    io,
    os::unix::{fs::MetadataExt, process::ExitStatusExt},
    path::{Path, PathBuf},
    process::Stdio,
    time::Duration,
};
use tokio::{io::AsyncReadExt, process::Command};

pub(crate) struct DesktopCommand;

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Input {
    command: String,
    #[serde(default)]
    timeout: Option<u64>,
    #[serde(default)]
    read_paths: Vec<PathBuf>,
    check_name: Option<String>,
    skip_reason: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "snake_case")]
enum CheckState {
    Passed,
    Failed,
    Skipped,
    NotRun,
}

#[derive(Serialize)]
struct CheckReceipt {
    name: String,
    state: CheckState,
}

#[derive(Serialize)]
struct CheckResult {
    content: String,
    command_check: CheckReceipt,
}

impl CheckResult {
    fn into_tool_result(self, success: bool) -> ToolResult {
        match serde_json::to_string(&self) {
            Ok(content) if success => ToolResult::success(content),
            Ok(content) => ToolResult::error(content),
            Err(error) => ToolResult::error(format!("检查结果未能返回：{error}")),
        }
    }
}

// Reuse the upstream process/sysctl defaults, but NOT its unrestricted disk
// reads or preferences IPC. Paths are parameters, never interpolated into SBPL.
const BASE: &str = include_str!("../../tools/src/sandbox/seatbelt_base_policy.sbpl");
const FILES: &str = r#"
(allow file-read* file-map-executable
  (subpath "/bin") (subpath "/sbin") (subpath "/usr/bin")
  (subpath "/usr/sbin") (subpath "/usr/lib") (subpath "/usr/libexec")
  (subpath "/usr/share") (subpath "/System/Library")
  (subpath "/Library/Apple/System/Library")
  (subpath "/Library/Developer/CommandLineTools")
  (subpath (param "WORKSPACE")) (subpath (param "SCRATCH")))
(allow file-read-metadata (literal "/") (literal "/private")
  (literal "/tmp") (literal "/var") (literal "/etc")
  (path-ancestors "/Library/Developer/CommandLineTools")
  (path-ancestors (param "WORKSPACE")) (path-ancestors (param "SCRATCH")))
(allow file-read* (literal "/") (literal "/dev/null") (literal "/dev/zero")
  (literal "/dev/random") (literal "/dev/urandom")
  (literal "/private/etc/localtime") (subpath "/private/var/db/timezone"))
(allow file-read-data file-write-data (subpath "/dev/fd"))
(allow file-write* (subpath (param "WORKSPACE")) (subpath (param "SCRATCH")))
(deny file-write-unlink (literal (param "WORKSPACE")) (literal (param "SCRATCH")))
(deny mach-lookup (xpc-service-name-prefix ""))
(deny system-fcntl (fcntl-command 80 110))
"#;

#[async_trait]
impl Tool for DesktopCommand {
    fn name(&self) -> &str {
        "Bash"
    }
    fn description(&self) -> &str {
        "Run a project check in a macOS sandbox. Reads/writes only the selected workspace and a private temporary directory, plus read-only system runtimes. Network and other user files are denied. Returns real stdout, stderr and exit status. Commands cannot be automatically undone."
    }
    fn permission_level(&self) -> PermissionLevel {
        PermissionLevel::Execute
    }
    fn self_gates(&self) -> bool {
        true
    }
    fn input_schema(&self) -> Value {
        json!({"type":"object","properties":{"command":{"type":"string"},"skip_reason":{"type":"string","description":"Explain why this named check is deliberately skipped. When present, the command is NEVER executed; requires check_name and a nonempty reason."},"check_name":{"type":"string","description":"Name of the project check being run. Omit for exploratory commands; only actual exit status determines its result."},"timeout":{"type":"integer","description":"Timeout in milliseconds; default 120000, maximum 600000"},"read_paths":{"type":"array","items":{"type":"string"},"description":"Existing absolute files or directories to additionally read for this command. Requires one-time user approval; omit when unnecessary."}},"required":["command"],"additionalProperties":false})
    }
    async fn execute(&self, value: Value, ctx: &ToolContext) -> ToolResult {
        let input = match Input::deserialize(&value) {
            Ok(input) => input,
            Err(error) => {
                let content = format!("命令参数无效，未运行：{error}");
                if let Some(name) = value
                    .get("check_name")
                    .and_then(Value::as_str)
                    .filter(|name| !name.trim().is_empty())
                {
                    return CheckResult {
                        content,
                        command_check: CheckReceipt {
                            name: name.to_owned(),
                            state: CheckState::NotRun,
                        },
                    }
                    .into_tool_result(false);
                }
                return ToolResult::error(content);
            }
        };
        let mut input = input;
        let check_name = input
            .check_name
            .take()
            .filter(|name| !name.trim().is_empty());
        let (content, success, state) = if let Some(reason) = input.skip_reason.take() {
            if check_name.is_some() && !reason.trim().is_empty() {
                (
                    format!(
                        "已跳过检查（助手说明）：{reason}\n未执行命令：{}",
                        input.command
                    ),
                    true,
                    CheckState::Skipped,
                )
            } else {
                (
                    "跳过检查须填写 check_name 和非空 skip_reason，未运行命令".into(),
                    false,
                    CheckState::NotRun,
                )
            }
        } else {
            match run(input, ctx).await {
                Ok((output, true)) => (output, true, CheckState::Passed),
                Ok((output, false)) => (output, false, CheckState::Failed),
                Err(error) => (format!("命令未运行：{error}"), false, CheckState::NotRun),
            }
        };
        if let Some(name) = check_name {
            CheckResult {
                content,
                command_check: CheckReceipt { name, state },
            }
            .into_tool_result(success)
        } else if success {
            ToolResult::success(content)
        } else {
            ToolResult::error(content)
        }
    }
}

pub(super) struct ProcessGroup(pub(super) i32);
impl Drop for ProcessGroup {
    fn drop(&mut self) {
        let mut info = std::mem::MaybeUninit::<libc::siginfo_t>::zeroed();
        // SAFETY: info points to valid storage. WNOWAIT never reaps the owned
        // child: retaining its PID prevents it being reused for an unrelated
        // group. No Child::wait is polled until after this guard is dropped.
        unsafe {
            if libc::waitid(
                libc::P_PID,
                self.0 as libc::id_t,
                info.as_mut_ptr(),
                libc::WEXITED | libc::WNOWAIT | libc::WNOHANG,
            ) == 0
            {
                libc::kill(-self.0, libc::SIGKILL);
                // A direct child can join another group. Kill only its owned
                // PID as well; never signal the other group's members.
                libc::kill(self.0, libc::SIGKILL);
            }
        }
    }
}

pub(super) async fn observe_exit(pid: u32) -> io::Result<()> {
    loop {
        let exited = {
            let mut info = std::mem::MaybeUninit::<libc::siginfo_t>::zeroed();
            // SAFETY: info is writable and zero-initialized, PID came from our
            // unreaped Child. WNOWAIT observes exit without releasing PID ownership.
            let result = unsafe {
                libc::waitid(
                    libc::P_PID,
                    pid,
                    info.as_mut_ptr(),
                    libc::WEXITED | libc::WNOWAIT | libc::WNOHANG,
                )
            };
            if result != 0 {
                return Err(io::Error::last_os_error());
            }
            // SAFETY: storage started fully initialized and waitid succeeded.
            unsafe { info.assume_init() }.si_pid == pid as i32
        };
        if exited {
            return Ok(());
        }
        tokio::time::sleep(Duration::from_millis(20)).await;
    }
}

struct Scope {
    path: PathBuf,
    identity: (u64, u64),
}
impl Scope {
    fn new(path: &Path) -> io::Result<Self> {
        if !path.is_absolute() {
            return Err(io::Error::other("额外授权路径必须是已存在的绝对路径"));
        }
        let path = path.canonicalize()?;
        if path.to_str().is_none() {
            return Err(io::Error::other("命令隔离暂不支持非 UTF-8 路径"));
        }
        let metadata = path.metadata()?;
        if !metadata.is_file() && !metadata.is_dir() {
            return Err(io::Error::other("只能授权普通文件或目录"));
        }
        Ok(Self {
            path,
            identity: (metadata.dev(), metadata.ino()),
        })
    }
    fn verify(&self) -> io::Result<()> {
        let metadata = self.path.metadata()?;
        if self.path.canonicalize()? != self.path
            || (metadata.dev(), metadata.ino()) != self.identity
        {
            return Err(io::Error::other("授权路径已更换，未运行命令；请核对后重试"));
        }
        Ok(())
    }
}

async fn approve_extra(input: &Input, scopes: &[Scope], ctx: &ToolContext) -> io::Result<()> {
    if scopes.is_empty() {
        return Ok(());
    }
    let queue = ctx
        .pending_permissions
        .as_ref()
        .ok_or_else(|| io::Error::other("无法取得额外范围授权，未运行命令"))?;
    let paths = scopes
        .iter()
        .map(|scope| scope.path.display().to_string())
        .collect::<Vec<_>>()
        .join("\n");
    let reason = format!(
        "仅本次命令扩大访问范围：\n只读：\n{paths}\n命令：{}\n其他文件与网络仍受隔离。",
        input.command
    );
    let (tx, rx) = tokio::sync::oneshot::channel();
    queue.lock().queue.push_back(PendingPermissionRequest {
        tool_use_id: format!("command-scope-{}", uuid::Uuid::new_v4()),
        request: PermissionRequest {
            tool_name: "DesktopCommandScope".into(),
            description: reason.clone(),
            details: None,
            is_read_only: false,
            path: None,
            working_dir: Some(ctx.working_dir.clone()),
            allowed_roots: Vec::new(),
            context_description: None,
        },
        reason,
        decision_tx: Some(tx),
    });
    tokio::select! {
        biased;
        _ = ctx.cancel_token.cancelled() => Err(io::Error::other("命令已停止")),
        answer = rx => match answer {
            Ok(PermissionDecision::Allow | PermissionDecision::AllowPermanently) => Ok(()),
            _ => Err(io::Error::other("用户未授权额外范围，未执行命令")),
        }
    }
}

#[derive(Default)]
pub(super) struct CapturedOutput {
    bytes: Vec<u8>,
    omitted: usize,
}
impl CapturedOutput {
    pub(super) fn text(&self) -> String {
        let mut text = String::from_utf8_lossy(&self.bytes).into_owned();
        if self.omitted > 0 {
            text.push_str(&format!("\n[后续 {} 字节输出已截断]", self.omitted));
        }
        text
    }
}

pub(super) async fn read_output(
    stream: &mut (impl tokio::io::AsyncRead + Unpin),
    output: &mut CapturedOutput,
) -> io::Result<()> {
    let mut buffer = [0; 8192];
    loop {
        let count = stream.read(&mut buffer).await?;
        if count == 0 {
            break;
        }
        let retained = count.min((64 * 1024usize).saturating_sub(output.bytes.len()));
        output.bytes.extend_from_slice(&buffer[..retained]);
        output.omitted += count - retained;
    }
    Ok(())
}

// Seatbelt restricts paths, not every alias of an inode. Refuse workspaces
// containing pre-existing hard links rather than silently modifying an alias
// outside the selected tree. New links to outside files are denied by Seatbelt.
async fn check_workspace(
    path: PathBuf,
    cancel: tokio_util::sync::CancellationToken,
) -> io::Result<()> {
    tokio::task::spawn_blocking(move || {
        let mut directories = vec![path];
        let mut count = 0;
        while let Some(directory) = directories.pop() {
            for entry in std::fs::read_dir(directory)? {
                if cancel.is_cancelled() { return Err(io::Error::other("命令已停止")); }
                count += 1;
                if count > 300_000 { return Err(io::Error::other("工作区条目超过命令隔离检查上限，请选择更小的项目文件夹")); }
                let entry = entry?;
                let metadata = entry.path().symlink_metadata()?;
                if metadata.is_dir() { directories.push(entry.path()); }
                if metadata.is_file() && metadata.nlink() > 1 {
                    return Err(io::Error::other(format!("工作区含硬链接文件，可能同时改动范围外的别名，未执行命令：{}。请使用独立副本的工作区。", entry.path().display())));
                }
            }
        }
        Ok(())
    }).await.map_err(io::Error::other)?
}

async fn run(input: Input, ctx: &ToolContext) -> io::Result<(String, bool)> {
    if input.command.trim().is_empty() || input.command.len() > 64 * 1024 {
        return Err(io::Error::other("命令为空或超过 64 KiB"));
    }
    let executable = Path::new(claurst_core::sandbox::SEATBELT_EXECUTABLE);
    if !executable.is_file() {
        return Err(io::Error::other("系统隔离不可用，未执行命令"));
    }
    let workspace_scope = Scope::new(&ctx.working_dir)?;
    let workspace = &workspace_scope.path;
    if input.read_paths.len() > 16 {
        return Err(io::Error::other("单次命令最多请求 16 个额外路径"));
    }
    let scopes: Vec<_> = input
        .read_paths
        .iter()
        .map(|path| Scope::new(path))
        .collect::<io::Result<_>>()?;
    let scopes: Vec<_> = scopes
        .into_iter()
        .filter(|scope| !scope.path.starts_with(workspace))
        .collect();
    approve_extra(&input, &scopes, ctx).await?;
    check_workspace(workspace.clone(), ctx.cancel_token.clone()).await?;
    let scratch = tempfile::Builder::new()
        .prefix("claurst-command-")
        .tempdir()?;
    let scratch_path = scratch.path().canonicalize()?;
    let mut policy = format!("{BASE}\n{FILES}");
    for index in 0..scopes.len() {
        policy.push_str(&format!("\n(allow file-read* file-map-executable (literal (param \"READ_{index}\")) (subpath (param \"READ_{index}\")))\n(allow file-read-metadata (path-ancestors (param \"READ_{index}\")))"));
    }
    let mut command = Command::new(executable);
    command.args(["-p", &policy]);
    for (index, scope) in scopes.iter().enumerate() {
        command.arg(format!("-DREAD_{index}={}", scope.path.display()));
        scope.verify()?;
    }
    workspace_scope.verify()?;
    command
        .arg(format!("-DWORKSPACE={}", workspace.display()))
        .arg(format!("-DSCRATCH={}", scratch_path.display()))
        .args([
            "--",
            "/bin/bash",
            "--noprofile",
            "--norc",
            "-c",
            &input.command,
        ])
        .current_dir(workspace)
        .env_clear()
        .env("PATH", "/usr/bin:/bin:/usr/sbin:/sbin")
        .env("LANG", "en_US.UTF-8")
        .env("TMPDIR", &scratch_path)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .kill_on_drop(true)
        .process_group(0);
    if ctx.cancel_token.is_cancelled() {
        return Err(io::Error::other("命令已停止"));
    }
    let mut child = command.spawn()?;
    let pid = child
        .id()
        .ok_or_else(|| io::Error::other("无法取得命令进程标识"))?;
    let group = ProcessGroup(pid as i32);
    let mut stdout = child
        .stdout
        .take()
        .ok_or_else(|| io::Error::other("无法读取标准输出"))?;
    let mut stderr = child
        .stderr
        .take()
        .ok_or_else(|| io::Error::other("无法读取错误输出"))?;
    let limit = Duration::from_millis(input.timeout.unwrap_or(120_000).clamp(1, 600_000));
    let mut out = CapturedOutput::default();
    let mut err = CapturedOutput::default();
    let outcome: io::Result<()> = tokio::select! {
        biased;
        _ = ctx.cancel_token.cancelled() => Err(io::Error::other("命令已停止；已尝试结束进程组，已写入内容不会自动撤销")),
        result = tokio::time::timeout(limit, async {
            tokio::try_join!(observe_exit(pid), read_output(&mut stdout, &mut out), read_output(&mut stderr, &mut err))?;
            Ok(())
        }) => result.unwrap_or_else(|_| Err(io::Error::other("命令超时；已尝试结束进程组，检查未通过"))),
    };
    // Keep PID ownership until both group and direct-child cleanup have run.
    drop(group);
    let status = tokio::time::timeout(Duration::from_secs(2), child.wait()).await;
    // Pick up bytes already in the pipes without waiting on detached children.
    let _ = tokio::time::timeout(Duration::from_millis(100), async {
        tokio::try_join!(
            read_output(&mut stdout, &mut out),
            read_output(&mut stderr, &mut err)
        )
    })
    .await;
    let (code, success) = match status {
        Ok(Ok(status)) => (
            status
                .code()
                .map(|code| code.to_string())
                .unwrap_or_else(|| format!("信号 {}", status.signal().unwrap_or(0))),
            status.success(),
        ),
        _ => ("未确认；进程回收未完成".into(), false),
    };
    let reason = outcome
        .as_ref()
        .err()
        .map(|error| format!("\n{error}"))
        .unwrap_or_default();
    Ok((
        format!(
            "命令：{}\n退出码：{code}{reason}\n标准输出：\n{}\n标准错误：\n{}",
            input.command,
            out.text(),
            err.text()
        ),
        outcome.is_ok() && success,
    ))
}
