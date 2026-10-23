//! Preserve verified read locations across ACP's textual tool-result boundary.
use async_trait::async_trait;
use claurst_tools::{
    file_read::{FileReadTool, ReadLocation},
    PermissionLevel, Tool, ToolContext, ToolResult,
};
use serde::Serialize;
use serde_json::Value;

pub(crate) struct DesktopRead {
    #[cfg(unix)]
    pub(crate) versions: std::sync::Arc<claurst_tools::desktop_write::ReadVersions>,
}

#[derive(Serialize)]
struct ReadResult {
    source: ReadLocation,
    content: String,
}

#[async_trait]
impl Tool for DesktopRead {
    fn name(&self) -> &str {
        "Read"
    }
    fn description(&self) -> &str {
        "读取本地文本、文字型 PDF 或 DOCX。文本返回真实行号，默认 2000 行；PDF 返回真实页码，DOCX 按正文（含表格与空段落）的 XML 顺序计段，不提供固定页码。PDF/DOCX 每次默认 10 页/段，limit 1–20，offset 从 1 开始，最多 32 MiB 输入与 50 KiB 提取文字；DOCX 正文展开最多 16 MiB。按继续读取提示补读剩余内容，不得将局部读取称为全文。DOCX 不含页眉页脚、批注、脚注、文本框、图片；删除修订忽略，插入修订保留。不支持旧 .doc、宏文档、加密文件或 OCR；无法提取时明确失败，不能声称已读。"
    }
    fn permission_level(&self) -> PermissionLevel {
        PermissionLevel::ReadOnly
    }
    fn self_gates(&self) -> bool {
        true
    }
    fn input_schema(&self) -> Value {
        let mut schema = FileReadTool.input_schema();
        schema["properties"]["offset"]["description"] =
            Value::String("从 1 开始的行号、PDF 页码或 DOCX 段落号；按续读提示继续。".into());
        schema["properties"]["limit"]["description"] = Value::String(
            "文本默认 2000 行；PDF/DOCX 默认 10 页/段，最大 20，至少 1。返回文字最多 50 KiB。"
                .into(),
        );
        schema
    }

    async fn execute(&self, mut input: Value, ctx: &ToolContext) -> ToolResult {
        // Ask about the real target, including macOS /var → /private/var aliases.
        // FileRead still checks the opened handle after this resolution, so a
        // later symlink swap cannot use this canonicalization as authorization.
        if let Some(path) = input.get("file_path").and_then(Value::as_str) {
            if let Ok(real) = ctx.resolve_path(path).canonicalize() {
                input["file_path"] = Value::String(real.to_string_lossy().into_owned());
            }
        }
        if input
            .get("file_path")
            .and_then(Value::as_str)
            .and_then(|path| std::path::Path::new(path).extension())
            .is_some_and(|ext| ext.eq_ignore_ascii_case("doc") || ext.eq_ignore_ascii_case("docm"))
        {
            return ToolResult::error(
                "不支持旧式 .doc 或宏文档 .docm；请另存为未加密 .docx，当前未读取内容",
            );
        }
        #[cfg(target_os = "macos")]
        if input
            .get("file_path")
            .and_then(Value::as_str)
            .and_then(|path| std::path::Path::new(path).extension())
            .is_some_and(|extension| {
                extension.eq_ignore_ascii_case("pdf") || extension.eq_ignore_ascii_case("docx")
            })
        {
            return claurst_tools::desktop_document::read_document(input, ctx).await;
        }
        let result = FileReadTool.execute(input, ctx).await;
        if result.is_error {
            return result;
        }
        let Some(metadata) = result.metadata else {
            return result;
        };
        let source: ReadLocation = match serde_json::from_value(metadata) {
            Ok(source) => source,
            Err(e) => return ToolResult::error(format!("读取来源无法验证：{e}")),
        };
        #[cfg(unix)]
        self.versions
            .remember(&ctx.session_id, &source.path, &source.revision);
        match serde_json::to_string(&ReadResult {
            source,
            content: result.content,
        }) {
            Ok(content) => ToolResult::success(content),
            Err(e) => ToolResult::error(format!("读取结果无法编码：{e}")),
        }
    }
}
