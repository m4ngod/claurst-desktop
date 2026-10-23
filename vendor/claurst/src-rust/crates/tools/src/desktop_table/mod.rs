//! Authorized table snapshots and local calculations, isolated from user files.
use crate::{PermissionLevel, Tool, ToolContext, ToolResult};
use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::{io, process::Stdio, time::Duration};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
pub mod parser;

#[derive(Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Request {
    file_path: String,
    action: Action,
    sheet: Option<String>,
    group_column: Option<String>,
    value_column: Option<String>,
    header_row: Option<usize>,
    offset: Option<usize>,
    limit: Option<usize>,
}
#[derive(Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
enum Action {
    Read,
    GroupSum,
}
#[derive(Deserialize, Serialize)]
pub struct TableLocation {
    sheet: String,
    first_row: usize,
    last_row: usize,
    first_column: usize,
    last_column: usize,
    total_rows: usize,
}
#[derive(Deserialize, Serialize)]
pub struct ParsedTable {
    table: TableLocation,
    content: String,
}
#[derive(Serialize)]
struct Source {
    path: std::path::PathBuf,
    table: TableLocation,
}
#[derive(Serialize)]
struct ResultContent {
    source: Source,
    content: String,
}

pub struct DesktopTable;
#[async_trait]
impl Tool for DesktopTable {
    fn name(&self) -> &str {
        "AnalyzeTable"
    }
    fn description(&self) -> &str {
        "本地读取未加密 XLSX 或 UTF-8 逗号 CSV，并可执行真实分组求和。read 返回工作表、单元格值、缺失值、未重新计算的公式及 CSV 记录/物理行；offset 默认 1，limit 默认 50、最多 200。group_sum 先核对表头再指定 group_column/value_column 字母列，统计 header_row（默认 1）之后全部行，不接受 offset/limit。缺失数值跳过并计数，不填零；非数值、分组缺失、选中列含公式/错误则拒绝统计，不使用公式缓存。采用有界十进制精确相加，超出精度明确失败。原件只读；每次输入最多 16 MiB，最多 50000 行、256 列、500000 单元格、200 组与 50 KiB 输出。"
    }
    fn permission_level(&self) -> PermissionLevel {
        PermissionLevel::ReadOnly
    }
    fn self_gates(&self) -> bool {
        true
    }
    fn input_schema(&self) -> Value {
        json!({"type":"object","required":["file_path","action"],"additionalProperties":false,"properties":{
            "file_path":{"type":"string"}, "action":{"type":"string","enum":["read","group_sum"]},
            "sheet":{"type":"string","description":"XLSX 工作表名；省略则读第一张并列出所有表名。CSV 不填。"},
            "group_column":{"type":"string","description":"group_sum 的分组列字母，如 A；先 read 核对表头。"},
            "value_column":{"type":"string","description":"group_sum 的数值列字母，如 B。"},
            "header_row":{"type":"integer","minimum":1,"description":"group_sum 表头行，默认 1；统计其后全部行。"},
            "offset":{"type":"integer","minimum":1}, "limit":{"type":"integer","minimum":1,"maximum":200}
        }})
    }
    async fn execute(&self, input: Value, ctx: &ToolContext) -> ToolResult {
        match run(input, ctx).await {
            Ok(result) => match serde_json::to_string(&result) {
                Ok(content) => ToolResult::success(content),
                Err(error) => ToolResult::error(format!("表格结果无法编码：{error}")),
            },
            Err(error) => ToolResult::error(format!("表格操作未完成：{error}")),
        }
    }
}

async fn run(input: Value, ctx: &ToolContext) -> anyhow::Result<ResultContent> {
    let mut request: Request = serde_json::from_value(input)?;
    let path = ctx.resolve_path(&request.file_path).canonicalize()?;
    // This operation only consumes an authorized snapshot; use the existing Read policy.
    let grant = ctx.check_permission_for_path(
        "Read",
        &format!("读取并分析表格 {}", path.display()),
        path.clone(),
        true,
    )?;
    let file = crate::open_regular_file(&path)?;
    let path = ctx
        .confirm_opened_path("Read", "读取并分析表格", &path, &file, grant, true)
        .map_err(anyhow::Error::msg)?;
    request.file_path = path.to_string_lossy().into_owned();
    let mut bytes = Vec::new();
    tokio::fs::File::from_std(file)
        .take(16 * 1024 * 1024 + 1)
        .read_to_end(&mut bytes)
        .await?;
    anyhow::ensure!(bytes.len() <= 16 * 1024 * 1024, "输入超过 16 MiB，未解析");
    anyhow::ensure!(!ctx.cancel_token.is_cancelled(), "已停止");
    let executable = std::env::current_exe()?;
    let parser = executable
        .parent()
        .ok_or_else(|| io::Error::other("无法定位内置表格解析器"))?
        .join("claurst-table-parser");
    anyhow::ensure!(
        parser.is_file(),
        "内置表格解析和计算组件缺失，请重新安装或构建应用；未执行统计"
    );
    let parser = parser.canonicalize()?;
    let mut child = tokio::process::Command::new(claurst_core::sandbox::SEATBELT_EXECUTABLE)
        .args(["-p", POLICY])
        .arg(format!("-DPARSER={}", parser.display()))
        .arg("--")
        .arg(parser)
        .arg(serde_json::to_string(&request)?)
        .env_clear()
        .current_dir("/")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .kill_on_drop(true)
        .spawn()?;
    let mut input_pipe = child
        .stdin
        .take()
        .ok_or_else(|| io::Error::other("无法发送表格内容"))?;
    let output_pipe = child
        .stdout
        .take()
        .ok_or_else(|| io::Error::other("无法读取表格结果"))?;
    let mut output = Vec::new();
    let operation = async {
        let writer = async move {
            input_pipe.write_all(&bytes).await?;
            input_pipe.shutdown().await?;
            drop(input_pipe);
            Ok::<(), io::Error>(())
        };
        let reader = async {
            output_pipe
                .take(1024 * 1024 + 1)
                .read_to_end(&mut output)
                .await
        };
        let (_, _, status) = tokio::try_join!(writer, reader, child.wait())?;
        anyhow::ensure!(
            status.success() && output.len() <= 1024 * 1024,
            "表格组件异常结束或输出过大，未确认结果"
        );
        Ok::<(), anyhow::Error>(())
    };
    tokio::select! {
        biased;
        _ = ctx.cancel_token.cancelled() => anyhow::bail!("表格操作已停止"),
        result = tokio::time::timeout(Duration::from_secs(20), operation) => result.map_err(|_| io::Error::other("表格操作超时，未确认结果"))??,
    }
    let parsed: Result<ParsedTable, String> = serde_json::from_slice(&output)?;
    let parsed = parsed.map_err(anyhow::Error::msg)?;
    Ok(ResultContent {
        source: Source {
            path,
            table: parsed.table,
        },
        content: parsed.content,
    })
}

const POLICY: &str = r#"
(version 1)
(deny default)
(allow process-exec)
(allow sysctl-read)
(allow file-read* file-map-executable
  (literal "/") (subpath "/System") (subpath "/usr/lib")
  (literal (param "PARSER")) (literal "/dev/null") (literal "/dev/urandom"))
(allow file-read-metadata (literal "/") (path-ancestors (param "PARSER")))
(allow file-write-data (literal "/dev/null"))
"#;
