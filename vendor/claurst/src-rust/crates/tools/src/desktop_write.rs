//! Desktop writes bind authorization and creation to the same directory handle.
use crate::{PermissionGrant, PermissionLevel, Tool, ToolContext, ToolResult};
use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;
use std::ffi::{CString, OsStr};
use std::fs::{DirBuilder, File, OpenOptions};
use std::io::{self, Read, Write};
use std::os::unix::ffi::OsStrExt;
use std::os::unix::fs::{DirBuilderExt, MetadataExt, OpenOptionsExt};
use std::os::unix::io::{AsRawFd, FromRawFd};
use std::path::{Path, PathBuf};
use std::sync::{Arc, OnceLock};

// Temporary desktop processes never persist recovery payloads. The UI receives
// these via ACP metadata, separate from the compact tool result sent to models.
static EPHEMERAL_RECORDS: OnceLock<parking_lot::Mutex<HashMap<String, Vec<u8>>>> = OnceLock::new();

pub fn is_ephemeral() -> bool {
    std::env::var_os("CLAURST_DESKTOP_EPHEMERAL").as_deref() == Some(OsStr::new("1"))
}

pub fn ephemeral_record(id: &str) -> Option<Value> {
    let records = EPHEMERAL_RECORDS.get()?.lock();
    serde_json::from_slice(records.get(id)?).ok()
}

pub fn remember_ephemeral_record(id: &str, record: &Value) -> io::Result<()> {
    if !is_ephemeral()
        || uuid::Uuid::parse_str(id).is_err()
        || record.get("id").and_then(Value::as_str) != Some(id)
    {
        return Err(io::Error::other("临时恢复记录无效"));
    }
    let bytes = serde_json::to_vec(record)?;
    let mut records = EPHEMERAL_RECORDS.get_or_init(Default::default).lock();
    let total: usize = records
        .iter()
        .filter(|(key, _)| key.as_str() != id)
        .map(|(_, value)| value.len())
        .sum();
    if total.saturating_add(bytes.len()) > 128 * 1024 * 1024 {
        return Err(io::Error::other(
            "临时恢复材料达到内存上限；未执行新修改，请新建临时会话",
        ));
    }
    records.insert(id.to_owned(), bytes);
    Ok(())
}

#[path = "desktop_files.rs"]
pub mod files;

#[derive(Default)]
pub struct ReadVersions {
    versions: parking_lot::Mutex<HashMap<(String, PathBuf), String>>,
}

impl ReadVersions {
    pub fn remember(&self, session: &str, path: &Path, revision: &str) {
        self.versions.lock().insert(
            (session.to_owned(), path.to_path_buf()),
            revision.to_owned(),
        );
    }
}

pub struct DesktopWrite {
    pub versions: Arc<ReadVersions>,
}

#[derive(Deserialize)]
struct WriteInput {
    file_path: String,
    content: String,
    reason: Option<String>,
}

#[derive(Serialize)]
struct ChangeRecord<'a> {
    id: &'a str,
    path: &'a Path,
    before: Option<&'a str>,
    after: &'a str,
    diff: String,
    reason: Option<&'a str>,
    parent_identity: (u64, u64),
}

#[derive(Serialize)]
struct ChangeReceipt<'a> {
    id: &'a str,
    path: &'a Path,
    record_path: PathBuf,
}

#[derive(Serialize)]
struct WriteResult<'a> {
    change: ChangeReceipt<'a>,
    content: String,
}

#[async_trait]
impl Tool for DesktopWrite {
    fn name(&self) -> &str {
        "Write"
    }
    fn description(&self) -> &str {
        "Create or replace a UTF-8 text file in an existing directory. Read existing files first. If the file changed since Read, the write is refused; explain the conflict to the user."
    }
    fn permission_level(&self) -> PermissionLevel {
        PermissionLevel::Write
    }
    fn self_gates(&self) -> bool {
        true
    }
    fn input_schema(&self) -> Value {
        let mut schema = crate::file_write::FileWriteTool.input_schema();
        schema["properties"]["reason"] = serde_json::json!({"type": "string", "description": "Briefly explain why this change addresses the user's request; this is an explanation, not verification."});
        schema
    }

    async fn execute(&self, input: Value, ctx: &ToolContext) -> ToolResult {
        let input: WriteInput = match serde_json::from_value(input) {
            Ok(input) => input,
            Err(error) => return ToolResult::error(format!("写入参数无效：{error}")),
        };
        if input.content.len() > 32 * 1024 * 1024 {
            return ToolResult::error(
                "写入内容超过 32 MiB，未修改文件；当前恢复功能不支持更大的文件",
            );
        }
        let path = ctx.resolve_path(&input.file_path);
        let path = path.canonicalize().unwrap_or(path);
        let (Some(parent), Some(name)) = (path.parent(), path.file_name()) else {
            return ToolResult::error("无法确定目标文件和父目录");
        };
        let parent = match parent.canonicalize() {
            Ok(parent) => parent,
            Err(error) => return ToolResult::error(format!("无法打开父目录：{error}")),
        };
        let target = parent.join(name);
        let mut grant = match ctx.check_permission_for_path(
            self.name(),
            &format!("写入文件 {}", target.display()),
            target.clone(),
            false,
        ) {
            Ok(grant) => grant,
            Err(error) => return ToolResult::error(error.to_string()),
        };
        let _lock = crate::lock_files([target.as_path()]).await;
        // File snapshots and durable backups can be large. Keep ACP event
        // delivery and cancellation responsive while the blocking work runs.
        let versions = self.versions.clone();
        let ctx = ctx.clone();
        let name = name.to_os_string();
        let tool_name = self.name().to_owned();
        match tokio::task::spawn_blocking(move || {
            let _lock = _lock;
            let directory = match OpenOptions::new()
                .read(true)
                .custom_flags(libc::O_DIRECTORY | libc::O_NOFOLLOW | libc::O_CLOEXEC)
                .open(&parent)
            {
                Ok(directory) => directory,
                Err(error) => return ToolResult::error(format!("无法打开父目录：{error}")),
            };
            let real_parent = match crate::opened_file_location(&directory, &parent) {
                Ok(real) => real,
                Err(error) => return ToolResult::error(format!("无法校验目标目录：{error}")),
            };
            let mut real = real_parent.join(&name);
            if grant == PermissionGrant::Policy || real != target {
                grant = match ctx.check_permission_for_path(
                    &tool_name,
                    &format!("写入文件 {}", real.display()),
                    real.clone(),
                    false,
                ) {
                    Ok(grant) => grant,
                    Err(error) => return ToolResult::error(error.to_string()),
                };
            }
            if ctx.cancel_token.is_cancelled() {
                return ToolResult::error("任务已停止，未写入文件");
            }
            let mut before = Vec::new();
            let existing = match crate::open_regular_file(&real) {
                Ok(mut file) => {
                    real = match ctx.confirm_opened_path(
                        &tool_name,
                        "写入文件",
                        &real,
                        &file,
                        grant,
                        false,
                    ) {
                        Ok(real) => real,
                        Err(error) => return ToolResult::error(error),
                    };
                    // SAFETY: file owns a valid descriptor for this entire scope.
                    // Nonblocking flock coordinates separate desktop processes;
                    // editors that do not use flock are checked before publishing.
                    if unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } != 0 {
                        return ToolResult::error("文件正被另一项操作使用，未覆盖；请稍后重试");
                    }
                    if let Err(error) = Read::by_ref(&mut file).take(32 * 1024 * 1024 + 1).read_to_end(&mut before) {
                        return ToolResult::error(format!("无法保存修改前的内容：{error}"));
                    }
                    if before.len() > 32 * 1024 * 1024 {
                        return ToolResult::error("原文件超过 32 MiB，未覆盖；当前恢复功能不支持更大的文件");
                    }
                    let revision = claurst_core::crypto_utils::sha256_hex(&before);
                    let known = versions
                        .versions
                        .lock()
                        .get(&(ctx.session_id.clone(), real.clone()))
                        .cloned();
                    match known {
                        None => return ToolResult::error("覆盖已有文件前，必须先用 Read 读取其当前内容"),
                        Some(known) if known != revision => return ToolResult::error("文件在任务读取后已被外部修改；已拒绝覆盖。请向用户说明冲突，再根据最新内容重新处理。"),
                        Some(_) => {}
                    }
                    Some(file)
                }
                Err(error) if error.kind() == io::ErrorKind::NotFound => {
                    if versions
                        .versions
                        .lock()
                        .contains_key(&(ctx.session_id.clone(), real.clone()))
                    {
                        return ToolResult::error(
                            "文件在任务读取或写入后已被外部删除，已拒绝重新创建；请向用户说明冲突",
                        );
                    }
                    None
                }
                Err(error) => return ToolResult::error(format!("无法打开目标文件：{error}")),
            };
            let before_text = match std::str::from_utf8(&before) {
                Ok(text) => text,
                Err(_) => return ToolResult::error("目标不是 UTF-8 文本，未覆盖文件"),
            };
            if ctx.cancel_token.is_cancelled() {
                return ToolResult::error("任务已停止，未写入文件");
            }
            let id = uuid::Uuid::new_v4().to_string();
            let parent_metadata = match directory.metadata() {
                Ok(metadata) => metadata,
                Err(error) => return ToolResult::error(format!("无法记录原目录身份，未写入：{error}")),
            };
            let record = ChangeRecord {
                id: &id,
                path: &real,
                before: existing.as_ref().map(|_| before_text),
                after: &input.content,
                reason: input.reason.as_deref(),
                parent_identity: (parent_metadata.dev(), parent_metadata.ino()),
                diff: similar::TextDiff::configure()
                    .timeout(std::time::Duration::from_millis(200))
                    .diff_lines(before_text, &input.content)
                    .unified_diff()
                    .header("修改前", "修改后")
                    .to_string(),
            };
            let record_path = match save_record(&record, &id) {
                Ok(path) => path,
                Err(error) => {
                    return ToolResult::error(format!("无法保存修改前版本，未写入文件：{error}"))
                }
            };
            let written = publish_file(
                &directory,
                &name,
                input.content.as_bytes(),
                existing.as_ref().map(|file| (file, before.as_slice())),
                None,
                Some(&ctx.cancel_token),
                Some(&real_parent),
            );
            match written {
                Ok(()) => {
                    ctx.record_file_change(
                        real.clone(),
                        &before,
                        input.content.as_bytes(),
                        &tool_name,
                    );
                    versions.remember(
                        &ctx.session_id,
                        &real,
                        &claurst_core::crypto_utils::sha256_hex(input.content.as_bytes()),
                    );
                    let result = WriteResult {
                        change: ChangeReceipt {
                            id: &id,
                            path: &real,
                            record_path,
                        },
                        content: format!(
                            "已{} {}（{} 字节），修改前版本与真实差异已保存。",
                            if existing.is_some() {
                                "修改"
                            } else {
                                "创建"
                            },
                            real.display(),
                            input.content.len()
                        ),
                    };
                    match serde_json::to_string(&result) {
                        Ok(content) => ToolResult::success(content),
                        Err(error) => {
                            ToolResult::error(format!("文件已写入，但修改记录未能返回：{error}"))
                        }
                    }
                }
                Err(error) => ToolResult::error(format!("未写入 {}：{error}", real.display())),
            }
        })
        .await
        {
            Ok(result) => result,
            Err(error) => ToolResult::error(format!("文件操作异常结束，写入结果尚未确认；请检查文件：{error}")),
        }
    }
}

/// Persist before touching the workspace. A failed workspace write leaves an
/// unused backup; only a successful write publishes its receipt to the client.
fn save_record(record: &impl Serialize, id: &str) -> io::Result<PathBuf> {
    let root = claurst_core::paths::claurst_home().join("changes");
    if is_ephemeral() {
        remember_ephemeral_record(id, &serde_json::to_value(record)?)?;
        return Ok(root.join(format!("{id}.json")));
    }
    DirBuilder::new()
        .recursive(true)
        .mode(0o700)
        .create(&root)?;
    let directory = OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_DIRECTORY | libc::O_NOFOLLOW | libc::O_CLOEXEC)
        .open(&root)?;
    let name = format!("{id}.json");
    let bytes = serde_json::to_vec(record)?;
    publish_file(
        &directory,
        OsStr::new(&name),
        &bytes,
        None,
        None,
        None,
        None,
    )?;
    directory.sync_all()?;
    Ok(root.join(name))
}

/// Prepare and flush the replacement first, then validate the current file
/// immediately before committing. Creation is always exclusive. Every path
/// operation stays relative to the already-authorized directory handle.
fn publish_file(
    directory: &File,
    name: &OsStr,
    content: &[u8],
    existing: Option<(&File, &[u8])>,
    create_mode: Option<u32>,
    cancel: Option<&tokio_util::sync::CancellationToken>,
    expected_parent: Option<&Path>,
) -> io::Result<()> {
    let dir_fd = directory.as_raw_fd();
    let name = CString::new(name.as_bytes())?;
    let temporary = CString::new(format!(".claurst-tmp-{}", uuid::Uuid::new_v4().simple()))?;
    // SAFETY: the directory and C string outlive the call. O_CREAT receives a
    // mode_t-compatible argument. A successful open returns a new owned fd.
    let fd = unsafe {
        libc::openat(
            dir_fd,
            temporary.as_ptr(),
            libc::O_WRONLY | libc::O_CREAT | libc::O_EXCL | libc::O_NOFOLLOW | libc::O_CLOEXEC,
            0o600 as libc::c_uint,
        )
    };
    if fd < 0 {
        return Err(io::Error::last_os_error());
    }
    // SAFETY: fd was returned by openat and is owned only by this File.
    let mut file = unsafe { File::from_raw_fd(fd) };
    let result = file
        .write_all(content)
        .and_then(|()| match existing {
            Some((opened, _)) => file.set_permissions(opened.metadata()?.permissions()),
            None => match create_mode {
                Some(mode) => {
                    use std::os::unix::fs::PermissionsExt;
                    file.set_permissions(std::fs::Permissions::from_mode(mode & 0o777))
                }
                None => Ok(()),
            },
        })
        .and_then(|()| file.sync_all())
        .and_then(|()| {
            if let Some(parent) = expected_parent {
                if crate::opened_file_location(directory, parent)? != parent {
                    return Err(io::Error::other("父目录在写入准备期间被移动，已取消操作"));
                }
            }
            if cancel.is_some_and(|token| token.is_cancelled()) {
                return Err(io::Error::new(
                    io::ErrorKind::Interrupted,
                    "任务已停止，未发布文件修改",
                ));
            }
            let rc = if let Some((opened, expected)) = existing {
                // SAFETY: directory and name outlive this call. A successful
                // openat returns a fresh descriptor transferred to File below.
                let fd = unsafe {
                    libc::openat(
                        dir_fd,
                        name.as_ptr(),
                        libc::O_RDONLY | libc::O_NOFOLLOW | libc::O_NONBLOCK | libc::O_CLOEXEC,
                    )
                };
                if fd < 0 {
                    return Err(io::Error::last_os_error());
                }
                // SAFETY: fd was returned by openat and has no other owner.
                let mut current = unsafe { File::from_raw_fd(fd) };
                let original = opened.metadata()?;
                let named = current.metadata()?;
                if !named.is_file()
                    || (named.dev(), named.ino()) != (original.dev(), original.ino())
                    || named.len() != expected.len() as u64
                {
                    return Err(io::Error::other(
                        "目标文件在写入准备期间被修改或替换，已拒绝覆盖",
                    ));
                }
                let mut bytes = Vec::new();
                Read::by_ref(&mut current)
                    .take(expected.len().saturating_add(1) as u64)
                    .read_to_end(&mut bytes)?;
                let checked = current.metadata()?;
                if bytes != expected
                    || (
                        named.mtime(),
                        named.mtime_nsec(),
                        named.ctime(),
                        named.ctime_nsec(),
                        named.len(),
                    ) != (
                        checked.mtime(),
                        checked.mtime_nsec(),
                        checked.ctime(),
                        checked.ctime_nsec(),
                        checked.len(),
                    )
                {
                    return Err(io::Error::other("目标文件在写入准备期间被修改，已拒绝覆盖"));
                }
                if let Some(parent) = expected_parent {
                    if crate::opened_file_location(directory, parent)? != parent {
                        return Err(io::Error::other("父目录在内容复核期间被移动，已取消操作"));
                    }
                }
                // SAFETY: both single-component names and the directory remain
                // valid. No asynchronous work or temporary-file writing occurs
                // between the final version check above and this rename.
                unsafe { libc::renameat(dir_fd, temporary.as_ptr(), dir_fd, name.as_ptr()) }
            } else {
                // SAFETY: both names and the open directory outlive the call.
                // linkat fails atomically if another writer created the target.
                unsafe { libc::linkat(dir_fd, temporary.as_ptr(), dir_fd, name.as_ptr(), 0) }
            };
            if rc == 0 {
                Ok(())
            } else {
                Err(io::Error::last_os_error())
            }
        });
    // SAFETY: temporary is a NUL-terminated name relative to the open directory.
    // Removing the temporary link never removes the published target link.
    unsafe { libc::unlinkat(dir_fd, temporary.as_ptr(), 0) };
    result
}
