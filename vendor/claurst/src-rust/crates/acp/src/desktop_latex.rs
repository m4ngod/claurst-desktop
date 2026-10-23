//! LaTeX executes locally with read-only inputs and an isolated output folder.
use crate::desktop_command::{observe_exit, read_output, CapturedOutput, ProcessGroup};
use anyhow::{anyhow, ensure, Context};
use async_trait::async_trait;
use claurst_tools::{PermissionLevel, Tool, ToolContext, ToolResult};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::{path::PathBuf, process::Stdio, time::Duration};
use tokio::{io::AsyncReadExt, process::Command};

pub(crate) struct CompileLaTeX;

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Input {
    file_path: String,
}

#[derive(Serialize)]
struct Artifact {
    id: String,
    main_path: PathBuf,
    pdf_path: PathBuf,
    log_path: PathBuf,
    compiled_at: String,
    page_count: usize,
    pdf_sha256: String,
    warnings: Vec<String>,
}

#[derive(Serialize)]
struct Compilation {
    latex_artifact: Artifact,
    content: String,
}

const POLICY: &str = r#"
(version 1)
(deny default)
(allow process-exec (literal (param "COMPILER")))
(allow signal (target same-sandbox))
(allow sysctl-read)
(allow file-read* file-map-executable
  (literal "/") (subpath "/System/Library") (subpath "/usr/lib")
  (subpath "/usr/share") (literal "/dev/null") (literal "/dev/urandom")
  (subpath (param "WORKSPACE")) (subpath (param "SUPPORT"))
  (subpath (param "OUTPUT")))
(allow file-read-metadata (path-ancestors (param "WORKSPACE"))
  (path-ancestors (param "SUPPORT")) (path-ancestors (param "OUTPUT")))
(allow file-write* (subpath (param "OUTPUT")))
(deny file-write-unlink (literal (param "OUTPUT")))
(allow file-write-data (literal "/dev/null"))
; The CLI probes a user configuration before processing its explicit options.
; Hide it even when the chosen workspace contains the user's home folder.
(deny file-read* (with errno 2) (literal (param "USER_CONFIG")))
"#;

#[async_trait]
impl Tool for CompileLaTeX {
    fn name(&self) -> &str {
        "CompileLaTeX"
    }
    fn description(&self) -> &str {
        "实际编译工作文件夹内的 LaTeX 主文件及其支持文件。中文使用 ctexart 与 fontset=claurst（思源宋体、黑体，无楷体或仿宋）。编译器离线运行，禁用 shell-escape，原始文件只读；PDF 和日志写到独立成果目录，不覆盖上次成果。成功只代表本次编译产生 PDF，仍须用 Read 和 ReadImage 核对内容、引用和页面布局；失败、缺少排版组件或警告须如实说明。"
    }
    fn permission_level(&self) -> PermissionLevel {
        PermissionLevel::Execute
    }
    fn self_gates(&self) -> bool {
        true
    }
    fn input_schema(&self) -> Value {
        json!({"type":"object","properties":{"file_path":{"type":"string","description":"工作文件夹内的 .tex 主文件，包含图片、章节和参考文献等支持文件。"}},"required":["file_path"],"additionalProperties":false})
    }
    async fn execute(&self, value: Value, ctx: &ToolContext) -> ToolResult {
        match compile(value, ctx).await {
            Ok(result) => match serde_json::to_string(&result) {
                Ok(content) => ToolResult::success(content),
                Err(_) => ToolResult::error("编译记录编码失败，未确认成果。"),
            },
            Err(error) => ToolResult::error(format!("LaTeX 编译未完成：{error}")),
        }
    }
}

async fn compile(value: Value, ctx: &ToolContext) -> anyhow::Result<Compilation> {
    let input: Input = serde_json::from_value(value).context("主文件参数无效")?;
    let workspace = ctx.working_dir.canonicalize().context("工作文件夹不存在")?;
    let main = ctx
        .resolve_path(&input.file_path)
        .canonicalize()
        .context("找不到 LaTeX 主文件")?;
    ensure!(
        main.starts_with(&workspace),
        "主文件不在已选工作文件夹内，请选择包含整个 LaTeX 项目的文件夹"
    );
    ensure!(
        main.is_file() && main.extension().is_some_and(|ext| ext == "tex"),
        "主文件须为普通 .tex 文件"
    );
    let project = main.parent().context("无法确定 LaTeX 项目目录")?;
    let stem = main
        .file_stem()
        .and_then(|stem| stem.to_str())
        .context("主文件名须为 UTF-8")?;
    ensure!(!stem.is_empty(), "主文件名为空");
    let executable = std::env::current_exe()?;
    let support = executable
        .parent()
        .context("无法定位排版组件")?
        .join("latex")
        .canonicalize()
        .context("缺少内置 LaTeX 排版组件，请在应用的排版组件说明中查看处理方法")?;
    let compiler = support.join("tectonic");
    let cache = support.join("cache");
    let bundle = support.join("bundle");
    let compiler_home = dirs::home_dir().context("无法确定系统用户目录")?;
    let user_config = compiler_home.join("Library/Application Support/Tectonic/config.toml");
    ensure!(
        compiler.is_file() && cache.is_dir() && bundle.join("SHA256SUM").is_file(),
        "内置 LaTeX 排版组件不完整，请查看排版组件说明"
    );
    ensure!(!ctx.cancel_token.is_cancelled(), "编译已停止");
    let output = tempfile::Builder::new()
        .prefix("claurst-latex-")
        .tempdir_in(&workspace)?;
    let output_path = output.path().canonicalize()?;
    let mut command = Command::new(claurst_core::sandbox::SEATBELT_EXECUTABLE);
    command
        .args(["-p", POLICY])
        .arg(format!("-DCOMPILER={}", compiler.display()))
        .arg(format!("-DWORKSPACE={}", workspace.display()))
        .arg(format!("-DSUPPORT={}", support.display()))
        .arg(format!("-DOUTPUT={}", output_path.display()))
        .arg(format!("-DUSER_CONFIG={}", user_config.display()))
        .arg("--")
        .arg(&compiler)
        .args(["-X", "compile", "--untrusted", "--only-cached", "--bundle"])
        .arg(&bundle)
        .args(["--keep-logs", "--keep-intermediates", "--outdir"])
        .arg(&output_path)
        .arg(&main)
        .current_dir(project)
        .env_clear()
        .env("LANG", "en_US.UTF-8")
        .env("TECTONIC_CACHE_DIR", cache)
        .env("TECTONIC_UNTRUSTED_MODE", "1")
        // Preserve the actual OS home solely for platform-directory discovery;
        // do not redirect it to a scratch directory or read the global config.
        .env("HOME", compiler_home)
        .env("TMPDIR", &output_path)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .kill_on_drop(true)
        .process_group(0);
    let mut child = command.spawn().context("无法启动本地排版组件")?;
    let pid = child.id().context("无法取得编译进程编号")?;
    let group = ProcessGroup(pid as i32);
    let mut stdout = child.stdout.take().context("无法读取编译输出")?;
    let mut stderr = child.stderr.take().context("无法读取编译错误")?;
    let mut out = CapturedOutput::default();
    let mut err = CapturedOutput::default();
    let outcome: anyhow::Result<()> = tokio::select! {
        biased;
        _ = ctx.cancel_token.cancelled() => Err(anyhow!("编译已停止，未交付本次 PDF")),
        result = tokio::time::timeout(Duration::from_secs(120), async {
            tokio::try_join!(observe_exit(pid), read_output(&mut stdout, &mut out), read_output(&mut stderr, &mut err))?;
            Ok(())
        }) => result.unwrap_or_else(|_| Err(anyhow!("编译超过 120 秒，未交付本次 PDF"))),
    };
    drop(group);
    let status = tokio::time::timeout(Duration::from_secs(2), child.wait()).await;
    let transcript = format!(
        "编译器：Tectonic\n主文件：{}\n标准输出：\n{}\n标准错误：\n{}",
        main.display(),
        out.text(),
        err.text()
    );
    outcome.map_err(|error| anyhow!("{error}\n{transcript}"))?;
    ensure!(
        matches!(status, Ok(Ok(status)) if status.success()),
        "编译器未成功退出。{transcript}"
    );
    ensure!(
        !ctx.cancel_token.is_cancelled(),
        "编译已停止，未交付本次 PDF"
    );
    let pdf_path = output_path.join(format!("{stem}.pdf"));
    let mut bytes = Vec::new();
    tokio::fs::File::open(&pdf_path)
        .await
        .context("编译器没有生成 PDF")?
        .take(32 * 1024 * 1024 + 1)
        .read_to_end(&mut bytes)
        .await?;
    ensure!(
        bytes.starts_with(b"%PDF-") && bytes.len() <= 32 * 1024 * 1024,
        "输出不是有效 PDF 文件头或超过 32 MiB；未交付本次 PDF"
    );
    let page_count = claurst_tools::desktop_document::validate_pdf(&pdf_path, ctx)
        .await
        .context("生成的 PDF 未通过本地解析检查")?;
    let mut log_bytes = Vec::new();
    tokio::fs::File::open(output_path.join(format!("{stem}.log")))
        .await
        .context("编译日志缺失，无法核对编译警告")?
        .take(1024 * 1024 + 1)
        .read_to_end(&mut log_bytes)
        .await?;
    let tex_log = String::from_utf8_lossy(&log_bytes[..log_bytes.len().min(1024 * 1024)]);
    let mut warnings = Vec::new();
    for line in tex_log.lines() {
        let lower = line.to_ascii_lowercase();
        if [
            " warning:",
            "overfull ",
            "underfull ",
            "missing character:",
            "not loadable",
        ]
        .iter()
        .any(|word| lower.contains(word))
            && !warnings.iter().any(|warning| warning == line)
        {
            warnings.push(line.to_owned());
            if warnings.len() > 100 {
                break;
            }
        }
    }
    if log_bytes.len() > 1024 * 1024 {
        warnings.push("编译日志超过 1 MiB，警告核对可能不完整，请检查原始 .log 文件。".into());
    }
    if warnings.len() > 100 {
        warnings.truncate(99);
        warnings.push("警告过多，仅列出前 99 条，请检查原始 .log 文件。".into());
    }
    let log_path = output_path.join("compilation.txt");
    tokio::fs::write(
        &log_path,
        format!("{transcript}\n最终 TeX 日志：\n{tex_log}"),
    )
    .await?;
    ensure!(
        !ctx.cancel_token.is_cancelled(),
        "编译已停止，未交付本次 PDF"
    );
    let artifact = Artifact {
        id: uuid::Uuid::new_v4().to_string(),
        main_path: main.clone(),
        pdf_path,
        log_path,
        compiled_at: chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Secs, true),
        page_count,
        pdf_sha256: format!("{:x}", Sha256::digest(&bytes)),
        warnings,
    };
    let warning_note = if artifact.warnings.is_empty() {
        "最终日志未发现常见编译警告；这不代表内容或页面布局已验证。".into()
    } else {
        format!(
            "以下编译警告尚未解决，必须核对并如实报告：\n{}",
            artifact.warnings.join("\n")
        )
    };
    let content = format!("已实际编译生成 PDF：{}\n本地 PDF 解析确认 {} 页。\n主文件与支持文件仍在：{}\n编译日志：{}\n{warning_note}\n尚未核对页面布局与引用，须使用 Read 和 ReadImage 检查并报告未解决问题。\n{transcript}",
        artifact.pdf_path.display(), artifact.page_count, project.display(), artifact.log_path.display());
    let _ = output.keep();
    Ok(Compilation {
        latex_artifact: artifact,
        content,
    })
}
