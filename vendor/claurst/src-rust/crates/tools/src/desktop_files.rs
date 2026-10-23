//! Recoverable desktop file organization. Paths stay bound to open directories.
use super::{save_record, ChangeReceipt, WriteResult};
use crate::{PermissionLevel, Tool, ToolContext, ToolResult};
use async_trait::async_trait;
use base64::Engine;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::ffi::CString;
use std::fs::{File, Metadata, OpenOptions};
use std::io::{self, Read};
use std::os::unix::ffi::OsStrExt;
use std::os::unix::fs::{MetadataExt, OpenOptionsExt};
use std::os::unix::io::{AsRawFd, FromRawFd};
use std::path::{Path, PathBuf};

const MAX_FILE_BYTES: u64 = 32 * 1024 * 1024;

pub struct DesktopMove;
pub struct DesktopDelete;

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct DeleteInput {
    file_path: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct MoveInput {
    file_path: String,
    destination: String,
}

#[derive(Serialize)]
struct MoveRecord<'a> {
    id: &'a str,
    path: &'a Path,
    original_path: &'a Path,
    operation: &'static str,
    before: Option<&'a str>,
    after: &'a str,
    diff: String,
    bytes_base64: String,
    mode: u32,
    parent_identity: (u64, u64),
    original_parent_identity: (u64, u64),
}

#[async_trait]
impl Tool for DesktopMove {
    fn name(&self) -> &str {
        "Move"
    }
    fn description(&self) -> &str {
        "Move or rename one regular file (text or binary, at most 32 MiB) into an existing directory on the same volume. Never overwrites an existing destination. Saves recovery material before moving. Directories and symlinks are not supported."
    }
    fn permission_level(&self) -> PermissionLevel {
        PermissionLevel::Write
    }
    fn self_gates(&self) -> bool {
        true
    }
    fn input_schema(&self) -> Value {
        json!({"type":"object","properties":{"file_path":{"type":"string"},"destination":{"type":"string"}},"required":["file_path","destination"],"additionalProperties":false})
    }
    async fn execute(&self, input: Value, ctx: &ToolContext) -> ToolResult {
        let input: MoveInput = match serde_json::from_value(input) {
            Ok(input) => input,
            Err(error) => return ToolResult::error(format!("移动参数无效：{error}")),
        };
        let source = ctx.resolve_path(&input.file_path);
        let destination = ctx.resolve_path(&input.destination);
        let locks = crate::lock_files([source.as_path(), destination.as_path()]).await;
        let ctx = ctx.clone();
        match tokio::task::spawn_blocking(move || {
            let _locks = locks;
            move_file(&source, &destination, &ctx)
        })
        .await
        {
            Ok(Ok(result)) => ToolResult::success(result),
            Ok(Err(error)) => ToolResult::error(error.to_string()),
            Err(error) => {
                ToolResult::error(format!("文件移动异常结束，请核对文件与恢复材料：{error}"))
            }
        }
    }
}

#[async_trait]
impl Tool for DesktopDelete {
    fn name(&self) -> &str {
        "Delete"
    }
    fn description(&self) -> &str {
        "Delete one regular file (text or binary, at most 32 MiB) after saving recovery material. Does not delete directories or symlinks."
    }
    fn permission_level(&self) -> PermissionLevel {
        PermissionLevel::Write
    }
    fn self_gates(&self) -> bool {
        true
    }
    fn input_schema(&self) -> Value {
        json!({"type":"object","properties":{"file_path":{"type":"string"}},"required":["file_path"],"additionalProperties":false})
    }
    async fn execute(&self, input: Value, ctx: &ToolContext) -> ToolResult {
        let input: DeleteInput = match serde_json::from_value(input) {
            Ok(input) => input,
            Err(error) => return ToolResult::error(format!("删除参数无效：{error}")),
        };
        let path = ctx.resolve_path(&input.file_path);
        let locks = crate::lock_files([path.as_path()]).await;
        let ctx = ctx.clone();
        match tokio::task::spawn_blocking(move || {
            let _locks = locks;
            let target = Target::open(&path, &ctx, "删除文件")?;
            let snapshot = Snapshot::read(&target)?;
            let id = uuid::Uuid::new_v4().to_string();
            let text = std::str::from_utf8(&snapshot.bytes).ok();
            let record = MoveRecord {
                id: &id,
                path: &target.path,
                original_path: &target.path,
                operation: "delete",
                before: text,
                after: "",
                diff: text
                    .map(|text| {
                        similar::TextDiff::configure()
                            .timeout(std::time::Duration::from_millis(200))
                            .diff_lines(text, "")
                            .unified_diff()
                            .header("删除前", "删除后")
                            .to_string()
                    })
                    .unwrap_or_else(|| {
                        format!(
                            "删除二进制文件（{} 字节），原始内容已保留。",
                            snapshot.bytes.len()
                        )
                    }),
                bytes_base64: base64::engine::general_purpose::STANDARD.encode(&snapshot.bytes),
                mode: snapshot.metadata.mode(),
                parent_identity: directory_identity(&target.directory)?,
                original_parent_identity: directory_identity(&target.directory)?,
            };
            let record_path = save_record(&record, &id)?;
            let result = (|| {
                if ctx.cancel_token.is_cancelled() {
                    return Err(io::Error::other("任务已停止，未删除文件"));
                }
                snapshot.verify(&target)?;
                // SAFETY: the verified name is relative to the open directory;
                // no asynchronous work occurs after the final version check.
                if unsafe { libc::unlinkat(target.directory.as_raw_fd(), target.name.as_ptr(), 0) }
                    != 0
                {
                    return Err(io::Error::last_os_error());
                }
                target.directory.sync_all()
            })();
            if let Err(error) = result {
                return Err(io::Error::other(format!(
                    "删除未完成或持久化未确认：{error}。恢复材料保留于 {}",
                    record_path.display()
                )));
            }
            serde_json::to_string(&WriteResult {
                change: ChangeReceipt {
                    id: &id,
                    path: &target.path,
                    record_path,
                },
                content: format!(
                    "已删除 {}，原始内容已保存，可从文件修改记录恢复。",
                    target.path.display()
                ),
            })
            .map_err(io::Error::other)
        })
        .await
        {
            Ok(Ok(result)) => ToolResult::success(result),
            Ok(Err(error)) => ToolResult::error(error.to_string()),
            Err(error) => {
                ToolResult::error(format!("文件删除异常结束，请核对文件与恢复材料：{error}"))
            }
        }
    }
}

struct Target {
    directory: File,
    name: CString,
    path: PathBuf,
}

impl Target {
    fn open(path: &Path, ctx: &ToolContext, verb: &str) -> io::Result<Self> {
        let (Some(parent), Some(name)) = (path.parent(), path.file_name()) else {
            return Err(io::Error::other("无法确定文件和父目录"));
        };
        let parent = parent.canonicalize()?;
        let requested = parent.join(name);
        // These desktop-only operations use the existing file-write policy:
        // AcceptEdits inside the workspace, individual path approval outside.
        let grant = ctx
            .check_permission_for_path(
                "Write",
                &format!("{verb} {}", requested.display()),
                requested.clone(),
                false,
            )
            .map_err(io::Error::other)?;
        let directory = OpenOptions::new()
            .read(true)
            .custom_flags(libc::O_DIRECTORY | libc::O_NOFOLLOW | libc::O_CLOEXEC)
            .open(&parent)?;
        let actual = crate::opened_file_location(&directory, &parent)?.join(name);
        if actual != requested || grant == crate::PermissionGrant::Policy {
            ctx.check_permission_for_path(
                "Write",
                &format!("{verb} {}", actual.display()),
                actual.clone(),
                false,
            )
            .map_err(io::Error::other)?;
        }
        Ok(Self {
            directory,
            name: CString::new(name.as_bytes())?,
            path: actual,
        })
    }

    fn read(&self) -> io::Result<File> {
        // SAFETY: the directory and NUL-terminated single-component name remain
        // alive; a successful open returns a newly owned file descriptor.
        let fd = unsafe {
            libc::openat(
                self.directory.as_raw_fd(),
                self.name.as_ptr(),
                libc::O_RDONLY | libc::O_NOFOLLOW | libc::O_NONBLOCK | libc::O_CLOEXEC,
            )
        };
        if fd < 0 {
            return Err(io::Error::last_os_error());
        }
        // SAFETY: fd is a new descriptor returned above, with no other owner.
        let file = unsafe { File::from_raw_fd(fd) };
        if !file.metadata()?.is_file() {
            return Err(io::Error::other(
                "仅支持普通文件，不处理文件夹、符号链接或设备",
            ));
        }
        Ok(file)
    }

    fn check_location(&self) -> io::Result<()> {
        let current = crate::opened_file_location(&self.directory, &self.path)?;
        if Some(current.as_path()) != self.path.parent() {
            return Err(io::Error::other(
                "父目录在准备期间被移动，已取消操作；请重新核对路径",
            ));
        }
        Ok(())
    }
}

struct Snapshot {
    file: File,
    metadata: Metadata,
    bytes: Vec<u8>,
}

impl Snapshot {
    fn read(target: &Target) -> io::Result<Self> {
        let mut file = target.read()?;
        // SAFETY: file owns a valid descriptor throughout this operation.
        if unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } != 0 {
            return Err(io::Error::other("文件正被另一项操作使用，请稍后重试"));
        }
        let metadata = file.metadata()?;
        if metadata.len() > MAX_FILE_BYTES {
            return Err(io::Error::other(
                "文件超过 32 MiB，未修改；当前恢复功能不支持更大的文件",
            ));
        }
        let mut bytes = Vec::new();
        Read::by_ref(&mut file)
            .take(MAX_FILE_BYTES + 1)
            .read_to_end(&mut bytes)?;
        if bytes.len() as u64 > MAX_FILE_BYTES || version(&metadata) != version(&file.metadata()?) {
            return Err(io::Error::other("文件在读取期间被修改，已取消操作"));
        }
        Ok(Self {
            file,
            metadata,
            bytes,
        })
    }

    fn verify(&self, target: &Target) -> io::Result<()> {
        target.check_location()?;
        let mut current = target.read()?;
        let before = current.metadata()?;
        let mut bytes = Vec::new();
        Read::by_ref(&mut current)
            .take(MAX_FILE_BYTES + 1)
            .read_to_end(&mut bytes)?;
        if version(&before) != version(&self.metadata)
            || version(&before) != version(&current.metadata()?)
            || version(&self.file.metadata()?) != version(&self.metadata)
            || bytes != self.bytes
        {
            return Err(io::Error::other(
                "文件在操作准备期间被修改或替换，已保留当前文件并取消操作",
            ));
        }
        target.check_location()
    }
}

fn version(metadata: &Metadata) -> (u64, u64, u64, i64, i64, i64, i64) {
    (
        metadata.dev(),
        metadata.ino(),
        metadata.len(),
        metadata.mtime(),
        metadata.mtime_nsec(),
        metadata.ctime(),
        metadata.ctime_nsec(),
    )
}

fn directory_identity(directory: &File) -> io::Result<(u64, u64)> {
    let metadata = directory.metadata()?;
    Ok((metadata.dev(), metadata.ino()))
}

fn move_file(source: &Path, destination: &Path, ctx: &ToolContext) -> io::Result<String> {
    let source = Target::open(source, ctx, "移动来源")?;
    let destination = Target::open(destination, ctx, "移动目标")?;
    let snapshot = Snapshot::read(&source)?;
    let id = uuid::Uuid::new_v4().to_string();
    let record = MoveRecord {
        id: &id,
        path: &destination.path,
        original_path: &source.path,
        operation: "move",
        before: std::str::from_utf8(&snapshot.bytes).ok(),
        after: std::str::from_utf8(&snapshot.bytes).unwrap_or(""),
        diff: format!(
            "移动文件\n{}\n→ {}\n内容保持不变（{} 字节）",
            source.path.display(),
            destination.path.display(),
            snapshot.bytes.len()
        ),
        bytes_base64: base64::engine::general_purpose::STANDARD.encode(&snapshot.bytes),
        mode: snapshot.metadata.mode(),
        parent_identity: directory_identity(&destination.directory)?,
        original_parent_identity: directory_identity(&source.directory)?,
    };
    let record_path = save_record(&record, &id)?;
    let result = (|| {
        if ctx.cancel_token.is_cancelled() {
            return Err(io::Error::other("任务已停止，未移动文件"));
        }
        snapshot.verify(&source)?;
        destination.check_location()?;
        rename_exclusive(&source, &destination)?;
        source.directory.sync_all()?;
        destination.directory.sync_all()
    })();
    if let Err(error) = result {
        return Err(io::Error::other(format!(
            "移动未完成或持久化未确认：{error}。恢复材料保留于 {}",
            record_path.display()
        )));
    }
    serde_json::to_string(&WriteResult {
        change: ChangeReceipt {
            id: &id,
            path: &destination.path,
            record_path,
        },
        content: format!(
            "已移动 {} → {}，恢复材料已保存。",
            source.path.display(),
            destination.path.display()
        ),
    })
    .map_err(io::Error::other)
}

#[cfg(target_os = "macos")]
fn rename_exclusive(source: &Target, destination: &Target) -> io::Result<()> {
    // SAFETY: both descriptors and single-component C strings outlive the call.
    // RENAME_EXCL atomically refuses any occupied destination, including links.
    let rc = unsafe {
        libc::renameatx_np(
            source.directory.as_raw_fd(),
            source.name.as_ptr(),
            destination.directory.as_raw_fd(),
            destination.name.as_ptr(),
            libc::RENAME_EXCL,
        )
    };
    if rc != 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

#[cfg(not(target_os = "macos"))]
fn rename_exclusive(_source: &Target, _destination: &Target) -> io::Result<()> {
    Err(io::Error::other("当前系统不支持安全移动"))
}

#[derive(Deserialize)]
struct RecoveryRecord {
    id: String,
    path: PathBuf,
    operation: Option<String>,
    bytes_base64: Option<String>,
    mode: Option<u32>,
    original_path: Option<PathBuf>,
    before: Option<String>,
    after: String,
    parent_identity: Option<(u64, u64)>,
    original_parent_identity: Option<(u64, u64)>,
}

fn recovery_target(
    path: &Path,
    identity: Option<(u64, u64)>,
    ctx: &ToolContext,
    verb: &str,
) -> io::Result<Target> {
    let identity = identity.ok_or_else(|| {
        io::Error::other("旧记录没有目录身份，无法安全自动恢复；原始内容仍保留在恢复材料中")
    })?;
    let parent = path
        .parent()
        .ok_or_else(|| io::Error::other("记录中没有父目录"))?;
    if parent.canonicalize()? != parent {
        return Err(io::Error::other(
            "原路径被符号链接重定向，已拒绝恢复；请恢复原目录位置后重试",
        ));
    }
    let target = Target::open(path, ctx, verb)?;
    if target.path != path || directory_identity(&target.directory)? != identity {
        return Err(io::Error::other(
            "原目录已被替换，已拒绝恢复；当前文件保持不变",
        ));
    }
    Ok(target)
}

pub async fn restore(id: &str, ctx: &ToolContext) -> io::Result<()> {
    let id = uuid::Uuid::parse_str(id)
        .map_err(io::Error::other)?
        .to_string();
    let record_path = claurst_core::paths::claurst_home()
        .join("changes")
        .join(format!("{id}.json"));
    let mut file = OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW | libc::O_NONBLOCK | libc::O_CLOEXEC)
        .open(&record_path)?;
    if !file.metadata()?.is_file() || file.metadata()?.len() > 256 * 1024 * 1024 {
        return Err(io::Error::other("恢复记录格式或大小不受支持"));
    }
    // SAFETY: file owns the descriptor until recovery and its marker finish.
    if unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } != 0 {
        return Err(io::Error::other("此记录正在恢复，请等待完成"));
    }
    let mut bytes = Vec::new();
    Read::by_ref(&mut file)
        .take(256 * 1024 * 1024 + 1)
        .read_to_end(&mut bytes)?;
    let record: RecoveryRecord = serde_json::from_slice(&bytes)?;
    if record.id != id || !record.path.is_absolute() {
        return Err(io::Error::other("恢复记录标识或路径无效"));
    }
    if record
        .original_path
        .as_ref()
        .is_some_and(|path| !path.is_absolute())
    {
        return Err(io::Error::other("原文件路径无效"));
    }
    let locks = crate::lock_files(
        std::iter::once(record.path.as_path()).chain(record.original_path.as_deref()),
    )
    .await;
    let ctx = ctx.clone();
    tokio::task::spawn_blocking(move || {
        let _locks = locks;
        let _record_lock = file;
        let target = recovery_target(&record.path, record.parent_identity, &ctx, "恢复文件")?;
        let content = match &record.bytes_base64 {
            Some(bytes) => base64::engine::general_purpose::STANDARD
                .decode(bytes)
                .map_err(io::Error::other)?,
            None => record.before.as_deref().unwrap_or("").as_bytes().to_vec(),
        };
        if content.len() as u64 > MAX_FILE_BYTES {
            return Err(io::Error::other("恢复内容超过 32 MiB"));
        }
        match record.operation.as_deref() {
            Some("delete") => {
                target.check_location()?;
                super::publish_file(
                    &target.directory,
                    std::ffi::OsStr::from_bytes(target.name.as_bytes()),
                    &content,
                    None,
                    record.mode,
                    Some(&ctx.cancel_token),
                    target.path.parent(),
                )?;
                target.directory.sync_all()?;
            }
            Some("move") => {
                let original = recovery_target(
                    record
                        .original_path
                        .as_deref()
                        .ok_or_else(|| io::Error::other("缺少原始路径"))?,
                    record.original_parent_identity,
                    &ctx,
                    "恢复移动到",
                )?;
                let snapshot = Snapshot::read(&target)?;
                if snapshot.bytes != content {
                    return Err(io::Error::other(
                        "文件在移动后已被修改，不能恢复移动；当前内容已保留",
                    ));
                }
                if ctx.cancel_token.is_cancelled() {
                    return Err(io::Error::other("恢复已停止"));
                }
                snapshot.verify(&target)?;
                original.check_location()?;
                rename_exclusive(&target, &original)?;
                target.directory.sync_all()?;
                original.directory.sync_all()?;
            }
            None => {
                let snapshot = Snapshot::read(&target)?;
                if snapshot.bytes != record.after.as_bytes() {
                    return Err(io::Error::other(
                        "文件在写入后已被修改，已拒绝覆盖；当前内容已保留",
                    ));
                }
                target.check_location()?;
                if record.before.is_some() {
                    super::publish_file(
                        &target.directory,
                        std::ffi::OsStr::from_bytes(target.name.as_bytes()),
                        &content,
                        Some((&snapshot.file, &snapshot.bytes)),
                        None,
                        Some(&ctx.cancel_token),
                        target.path.parent(),
                    )?;
                } else {
                    if ctx.cancel_token.is_cancelled() {
                        return Err(io::Error::other("恢复已停止"));
                    }
                    snapshot.verify(&target)?;
                    // SAFETY: name and descriptor remain valid; the current
                    // file was checked immediately above, without awaiting.
                    if unsafe {
                        libc::unlinkat(target.directory.as_raw_fd(), target.name.as_ptr(), 0)
                    } != 0
                    {
                        return Err(io::Error::last_os_error());
                    }
                }
                target.directory.sync_all()?;
            }
            _ => return Err(io::Error::other("此类型的记录尚不支持恢复")),
        }
        Ok(())
    })
    .await
    .map_err(io::Error::other)?
}
