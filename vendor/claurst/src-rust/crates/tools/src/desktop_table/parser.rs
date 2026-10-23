use super::{Action, ParsedTable, Request, TableLocation};
use calamine::{Data, DataRef, Reader, Xlsx, XlsxFormulaMetadata};
use rust_decimal::Decimal;
use sha2::{Digest, Sha256};
use std::{
    collections::BTreeMap,
    io::{Cursor, Read},
};

pub fn main() -> anyhow::Result<()> {
    let result = (|| {
        let argument = std::env::args()
            .nth(1)
            .ok_or_else(|| anyhow::anyhow!("缺少表格请求"))?;
        let request: Request = serde_json::from_str(&argument)?;
        let mut bytes = Vec::new();
        std::io::stdin()
            .take(16 * 1024 * 1024 + 1)
            .read_to_end(&mut bytes)?;
        anyhow::ensure!(bytes.len() <= 16 * 1024 * 1024, "表格超过 16 MiB");
        parse(&request, &bytes)
    })()
    .map_err(|error: anyhow::Error| error.to_string());
    serde_json::to_writer(std::io::stdout(), &result)?;
    Ok(())
}

#[derive(Clone, Default)]
struct Cell {
    value: String,
    kind: Kind,
    formula: Option<String>,
}
#[derive(Clone, Default, PartialEq, Eq, PartialOrd, Ord)]
enum Kind {
    #[default]
    Empty,
    Text,
    Number,
    Boolean,
    Date,
    Error,
}
struct Row {
    cells: Vec<Cell>,
    physical_line: Option<u64>,
}
struct Table {
    sheet: String,
    description: String,
    rows: Vec<Row>,
}

fn parse(request: &Request, bytes: &[u8]) -> anyhow::Result<ParsedTable> {
    let extension = std::path::Path::new(&request.file_path)
        .extension()
        .and_then(|ext| ext.to_str())
        .unwrap_or_default()
        .to_ascii_lowercase();
    let table = match extension.as_str() {
        "csv" => read_csv(request, bytes)?,
        "xlsx" => read_xlsx(request, bytes)?,
        _ => {
            anyhow::bail!("仅支持 UTF-8 CSV 与未加密 .xlsx；旧 .xls、.xlsb、宏工作簿需另存为 .xlsx")
        }
    };
    anyhow::ensure!(!table.rows.is_empty(), "表格无记录");
    if matches!(request.action, Action::GroupSum) {
        return group_sum(request, table, bytes);
    }
    anyhow::ensure!(
        request.group_column.is_none()
            && request.value_column.is_none()
            && request.header_row.is_none(),
        "read 不接受统计参数；请使用 group_sum"
    );
    let first = request.offset.unwrap_or(1);
    let limit = request.limit.unwrap_or(50);
    anyhow::ensure!(
        first > 0 && first <= table.rows.len() && (1..=200).contains(&limit),
        "offset 超过记录范围或 limit 不在 1–200"
    );
    let last = first.saturating_add(limit - 1).min(table.rows.len());
    let mut content = format!(
        "{}\n工作表：{}；共 {} 行。空值标为缺失；公式仅显示文件内的缓存值，未重新计算。\n",
        table.description,
        table.sheet,
        table.rows.len()
    );
    for (index, row) in table.rows.iter().enumerate().take(last).skip(first - 1) {
        if let Some(line) = row.physical_line {
            content.push_str(&format!("记录 {}（物理行 {} 起）：", index + 1, line));
        } else {
            content.push_str(&format!("第 {} 行：", index + 1));
        }
        for (column, cell) in row.cells.iter().enumerate() {
            let value = display_cell(cell)?;
            content.push_str(&format!(
                "{}{}={} | ",
                column_name(column + 1),
                index + 1,
                value
            ));
        }
        content.push('\n');
    }
    if last < table.rows.len() {
        content.push_str(&format!("部分读取；继续请使用 offset={}。", last + 1));
    }
    anyhow::ensure!(
        content.len() <= 50 * 1024,
        "提取内容超过 50 KiB，请减小 limit"
    );
    Ok(ParsedTable {
        table: TableLocation {
            sheet: table.sheet,
            first_row: first,
            last_row: last,
            first_column: 1,
            last_column: table.rows[0].cells.len(),
            total_rows: table.rows.len(),
        },
        content,
    })
}
fn read_csv(request: &Request, bytes: &[u8]) -> anyhow::Result<Table> {
    anyhow::ensure!(request.sheet.is_none(), "CSV 没有工作表，请省略 sheet");
    validate_csv_quotes(bytes)?;
    let mut reader = csv::ReaderBuilder::new()
        .has_headers(false)
        .from_reader(bytes);
    let mut rows = Vec::new();
    let mut count = 0;
    for record in reader.records() {
        let record = record.map_err(|error| anyhow::anyhow!("CSV 解析失败：{error}"))?;
        count += record.len();
        anyhow::ensure!(
            rows.len() < 50_000 && record.len() <= 256 && count <= 500_000,
            "表格超过 50000 行、256 列或 500000 单元格限制"
        );
        rows.push(Row {
            physical_line: record.position().map(|position| position.line()),
            cells: record
                .iter()
                .map(|value| Cell {
                    value: value.into(),
                    kind: if value.is_empty() {
                        Kind::Empty
                    } else {
                        Kind::Text
                    },
                    formula: None,
                })
                .collect(),
        });
    }
    Ok(Table {
        sheet: "CSV".into(),
        description:
            "CSV（UTF-8，逗号分隔）；单元格行号是逻辑记录号，含首行。带引号的字段可跨多个物理行；真正的空白物理行会被跳过。不能仅凭相邻记录的起始行号差断定存在空白行，请核对字段中的换行。"
                .into(),
        rows,
    })
}
fn read_xlsx(request: &Request, bytes: &[u8]) -> anyhow::Result<Table> {
    anyhow::ensure!(
        !bytes.starts_with(&[0xd0, 0xcf, 0x11, 0xe0]),
        "加密或旧式 Excel 容器不支持，请提供未加密 .xlsx"
    );
    let mut archive = zip::ZipArchive::new(Cursor::new(bytes))
        .map_err(|error| anyhow::anyhow!("XLSX 损坏或格式无效：{error}"))?;
    anyhow::ensure!(archive.len() <= 4096, "XLSX 内部项目过多");
    let mut expanded = 0;
    for index in 0..archive.len() {
        let entry = archive.by_index(index)?;
        anyhow::ensure!(!entry.encrypted(), "加密 XLSX 不支持");
        anyhow::ensure!(entry.size() <= 16 * 1024 * 1024, "XLSX 内部单项超过 16 MiB");
        let entry_name = entry.name().to_owned();
        let mut expanded_bytes = Vec::new();
        entry
            .take(16 * 1024 * 1024 + 1)
            .read_to_end(&mut expanded_bytes)?;
        let actual = expanded_bytes.len() as u64;
        expanded += actual;
        anyhow::ensure!(
            actual <= 16 * 1024 * 1024 && expanded <= 64 * 1024 * 1024,
            "XLSX 展开超过限制（单项 16 MiB、总计 64 MiB）"
        );
        // Validate XML parts before calamine converts numeric cells to f64.
        // The check also covers worksheet targets with unconventional filenames.
        match std::str::from_utf8(&expanded_bytes) {
            Ok(xml)
                if xml
                    .trim_start_matches('\u{feff}')
                    .trim_start()
                    .starts_with('<') =>
            {
                validate_worksheet(xml)?
            }
            Err(_)
                if entry_name.ends_with(".xml")
                    || expanded_bytes.starts_with(&[0xff, 0xfe])
                    || expanded_bytes.starts_with(&[0xfe, 0xff]) =>
            {
                anyhow::bail!("XLSX XML 不是受支持的 UTF-8 编码")
            }
            _ => (),
        }
    }
    let mut workbook =
        Xlsx::new(Cursor::new(bytes)).map_err(|error| anyhow::anyhow!("XLSX 解析失败：{error}"))?;
    let names = workbook.sheet_names();
    let sheet = request
        .sheet
        .as_ref()
        .or_else(|| names.first())
        .ok_or_else(|| anyhow::anyhow!("XLSX 无工作表"))?;
    anyhow::ensure!(
        names.contains(sheet),
        "找不到工作表 {sheet}；可用工作表：{}",
        names.join("、")
    );
    let mut reader = workbook.worksheet_cells_reader(sheet)?;
    // Stream cells rather than allocating a rectangle from untrusted dimensions.
    let mut cells = BTreeMap::new();
    let (mut max_row, mut max_column) = (0, 0);
    let mut text_bytes = 0usize;
    while let Some(record) = reader.next_cell_with_formula_metadata()? {
        let (row, column) = (record.pos.0 as usize + 1, record.pos.1 as usize + 1);
        max_row = max_row.max(row);
        max_column = max_column.max(column);
        anyhow::ensure!(
            max_row <= 50_000 && max_column <= 256 && max_row * max_column <= 500_000,
            "工作表范围超过 50000 行、256 列或 500000 单元格限制"
        );
        let formula = record.formula.map(|formula| match formula {
            XlsxFormulaMetadata::Normal { formula } => formula,
            XlsxFormulaMetadata::Shared {
                formula,
                shared_index,
                ..
            } => format!("共享公式 {shared_index} 模板：{formula}"),
            XlsxFormulaMetadata::SharedDerived { shared_index } => {
                format!("共享公式 {shared_index}；未展开")
            }
            _ => "未知公式类型；未计算".into(),
        });
        let kind = match &record.value {
            DataRef::Empty => Kind::Empty,
            DataRef::Int(_) | DataRef::Float(_) => Kind::Number,
            DataRef::Bool(_) => Kind::Boolean,
            DataRef::DateTime(_) | DataRef::DateTimeIso(_) | DataRef::DurationIso(_) => Kind::Date,
            DataRef::Error(_) => Kind::Error,
            DataRef::String(_) | DataRef::SharedString(_) => Kind::Text,
        };
        // Count shared strings before cloning: tiny ZIPs can reference the same
        // large string in many cells, exceeding the archive's expansion budget.
        let borrowed_bytes = match &record.value {
            DataRef::String(value) | DataRef::DateTimeIso(value) | DataRef::DurationIso(value) => {
                value.len()
            }
            DataRef::SharedString(value) => value.len(),
            _ => 0,
        };
        let formula_bytes = formula.as_ref().map_or(0, String::len);
        anyhow::ensure!(
            text_bytes + borrowed_bytes + formula_bytes <= 16 * 1024 * 1024,
            "工作表文字数据超过 16 MiB"
        );
        let value = Data::from(record.value).to_string();
        text_bytes += value.len() + formula_bytes;
        anyhow::ensure!(text_bytes <= 16 * 1024 * 1024, "工作表文字数据超过 16 MiB");
        anyhow::ensure!(
            cells
                .insert(
                    (row, column),
                    Cell {
                        value,
                        kind,
                        formula
                    }
                )
                .is_none(),
            "XLSX 含重复单元格坐标，未确认数据"
        );
    }
    let mut rows = Vec::new();
    for row in 1..=max_row {
        rows.push(Row {
            physical_line: None,
            cells: (1..=max_column)
                .map(|column| cells.remove(&(row, column)).unwrap_or_default())
                .collect(),
        });
    }
    Ok(Table {
        sheet: sheet.clone(),
        description: format!(
            "XLSX；可用工作表：{}。仅处理选中表的单元格值，不含图表/图片/批注；不执行宏或外部链接。日期/时间保留解析值及类型，不套用 Excel 显示格式。",
            names.join("、")
        ),
        rows,
    })
}
fn display_cell(cell: &Cell) -> anyhow::Result<String> {
    let mut value = match cell.kind {
        Kind::Empty => "缺失".into(),
        Kind::Text => serde_json::to_string(&cell.value)?,
        Kind::Date => format!("日期/时间({})", cell.value),
        Kind::Error => format!("错误({})", cell.value),
        Kind::Number | Kind::Boolean => cell.value.clone(),
    };
    if let Some(formula) = &cell.formula {
        value = format!(
            "公式 {}；缓存={value}；未重新计算",
            serde_json::to_string(formula)?
        );
    }
    Ok(value)
}
fn column_name(mut column: usize) -> String {
    let mut letters = Vec::new();
    while column > 0 {
        column -= 1;
        letters.push((b'A' + (column % 26) as u8) as char);
        column /= 26;
    }
    letters.into_iter().rev().collect()
}

struct Group {
    sum: Decimal,
    valid: usize,
    missing: usize,
    rows: Vec<usize>,
    missing_rows: Vec<usize>,
}
fn group_sum(request: &Request, table: Table, bytes: &[u8]) -> anyhow::Result<ParsedTable> {
    anyhow::ensure!(
        request.offset.is_none() && request.limit.is_none(),
        "group_sum 不接受 offset/limit；统计表头之后的全部行"
    );
    let header = request.header_row.unwrap_or(1);
    anyhow::ensure!(
        header > 0 && header < table.rows.len(),
        "表头行越界或其后没有数据"
    );
    let group_col = column_index(request.group_column.as_deref())?;
    let value_col = column_index(request.value_column.as_deref())?;
    let columns = table.rows[0].cells.len();
    anyhow::ensure!(
        group_col <= columns && value_col <= columns && group_col != value_col,
        "统计列越界或两列相同"
    );
    let group_name = column_name(group_col);
    let value_name = column_name(value_col);
    for col in [group_col, value_col] {
        let cell = &table.rows[header - 1].cells[col - 1];
        anyhow::ensure!(
            cell.kind != Kind::Empty && cell.formula.is_none() && cell.kind != Kind::Error,
            "{}{} 表头缺失、含公式或错误；请核对 header_row",
            column_name(col),
            header
        );
    }
    let mut groups: BTreeMap<(Kind, String), Group> = BTreeMap::new();
    for (index, row) in table.rows.iter().enumerate().skip(header) {
        let group = &row.cells[group_col - 1];
        let value = &row.cells[value_col - 1];
        let row_number = index + 1;
        for (column, cell) in [(group_col, group), (value_col, value)] {
            anyhow::ensure!(
                cell.formula.is_none(),
                "{}{} 含公式；未重新计算，不使用缓存值统计。请提供已核对的纯数值副本",
                column_name(column),
                row_number
            );
            anyhow::ensure!(
                cell.kind != Kind::Error,
                "{}{} 含错误值；未完成统计",
                column_name(column),
                row_number
            );
        }
        anyhow::ensure!(
            group.kind != Kind::Empty && !group.value.is_empty(),
            "{group_name}{row_number} 分组缺失；未完成统计"
        );
        let key = (group.kind.clone(), group.value.clone());
        let entry = groups.entry(key).or_insert(Group {
            sum: Decimal::ZERO,
            valid: 0,
            missing: 0,
            rows: Vec::new(),
            missing_rows: Vec::new(),
        });
        if value.kind == Kind::Empty || value.value.is_empty() {
            entry.missing += 1;
            if entry.missing_rows.len() < 20 {
                entry.missing_rows.push(row_number);
            }
        } else {
            anyhow::ensure!(
                matches!(value.kind, Kind::Number | Kind::Text),
                "{value_name}{row_number} 不是数值；未完成统计"
            );
            // Deliberately strict: no locale guessing, thousands separators or silent precision loss.
            anyhow::ensure!(
                value
                    .value
                    .bytes()
                    .all(|byte| byte.is_ascii_digit() || matches!(byte, b'+' | b'-' | b'.')),
                "{value_name}{row_number} 不是受支持的十进制数值（不接受单位、千分位或科学计数文本）；未完成统计"
            );
            let number = Decimal::from_str_exact(&value.value).map_err(|_| {
                anyhow::anyhow!("{value_name}{row_number} 不是数值或超过十进制精度；未完成统计")
            })?;
            let sum = entry
                .sum
                .checked_add(number)
                .ok_or_else(|| anyhow::anyhow!("统计合计超出十进制范围"))?;
            anyhow::ensure!(
                sum.checked_sub(entry.sum) == Some(number)
                    && sum.checked_sub(number) == Some(entry.sum),
                "统计需要超出支持范围的十进制精度；未返回近似结果"
            );
            entry.sum = sum;
            entry.valid += 1;
        }
        if entry.rows.len() < 20 {
            entry.rows.push(row_number);
        }
        anyhow::ensure!(groups.len() <= 200, "分组超过 200，未返回局部统计");
    }
    let total = table.rows.len();
    let mut content = format!(
        "本地分组求和（真实计算）\n工作表：{}\n输入 SHA-256：{:x}\n方法：按 {}{}={} 分组，对 {}{}={} 列以十进制精确相加；数值缺失跳过并计数，不填零；不执行公式、不使用公式缓存。文本分组保持原样，类型不同不合并。\n范围：{}{}:{}{} 与 {}{}:{}{}，共 {} 行；表头 {} 行，其他工作表不参与。\n",
        table.sheet,
        Sha256::digest(bytes),
        group_name,
        header,
        display_cell(&table.rows[header - 1].cells[group_col - 1])?,
        value_name,
        header,
        display_cell(&table.rows[header - 1].cells[value_col - 1])?,
        group_name,
        header + 1,
        group_name,
        total,
        value_name,
        header + 1,
        value_name,
        total,
        total - header,
        header
    );
    for ((kind, name), group) in groups {
        let label = if kind == Kind::Text {
            serde_json::to_string(&name)?
        } else {
            format!("非文本({name})")
        };
        let sum = if group.valid == 0 {
            "无有效数值".into()
        } else {
            group.sum.normalize().to_string()
        };
        content.push_str(&format!(
            "组 {label}：合计={sum}；有效数={}；缺失数={}\n",
            group.valid, group.missing
        ));
        let references: Vec<_> = group
            .rows
            .iter()
            .map(|row| format!("{group_name}{row}/{value_name}{row}"))
            .collect();
        let missing: Vec<_> = group
            .missing_rows
            .iter()
            .map(|row| format!("{value_name}{row}"))
            .collect();
        content.push_str(&format!(
            "来源单元格（最多前 20 对）：{}；缺失位置（最多前 20 个）：{}\n",
            references.join("、"),
            missing.join("、")
        ));
    }
    content.push_str("统计完成；原文件未修改。原件可能之后改变，复核请比较输入摘要并重新运行。\n");
    anyhow::ensure!(
        content.len() <= 50 * 1024,
        "统计输出超过 50 KiB，未返回截断结果"
    );
    Ok(ParsedTable {
        table: TableLocation {
            sheet: table.sheet,
            first_row: header,
            last_row: total,
            first_column: group_col.min(value_col),
            last_column: group_col.max(value_col),
            total_rows: total,
        },
        content,
    })
}
fn column_index(column: Option<&str>) -> anyhow::Result<usize> {
    let column = column
        .ok_or_else(|| anyhow::anyhow!("group_sum 必须指定 group_column 和 value_column 字母列"))?;
    anyhow::ensure!(
        !column.is_empty()
            && column.len() <= 3
            && column.bytes().all(|byte| byte.is_ascii_uppercase()),
        "请使用大写字母列，如 A、B、AA"
    );
    Ok(column
        .bytes()
        .fold(0, |value, byte| value * 26 + (byte - b'A' + 1) as usize))
}

// The csv crate intentionally accepts malformed quoting; don't silently repair user data.
fn validate_csv_quotes(bytes: &[u8]) -> anyhow::Result<()> {
    enum State {
        Start,
        Unquoted,
        Quoted,
        Closed,
    }
    let bytes = bytes.strip_prefix(&[0xef, 0xbb, 0xbf]).unwrap_or(bytes);
    let mut state = State::Start;
    for (index, byte) in bytes.iter().enumerate() {
        state = match (&state, byte) {
            (State::Quoted, b'"') => State::Closed,
            (State::Quoted, _) => State::Quoted,
            (State::Closed, b'"') => State::Quoted,
            (State::Start, b'"') => State::Quoted,
            (_, b',' | b'\r' | b'\n') => State::Start,
            (State::Start | State::Unquoted, value) if *value != b'"' => State::Unquoted,
            _ => anyhow::bail!("CSV 解析失败：字节 {} 的引号或闭引号后内容无效", index + 1),
        };
    }
    anyhow::ensure!(
        !matches!(state, State::Quoted),
        "CSV 解析失败：字段引号未闭合"
    );
    Ok(())
}

fn validate_worksheet(xml: &str) -> anyhow::Result<()> {
    use quick_xml::{XmlVersion, events::Event};
    let mut reader = quick_xml::Reader::from_str(xml.trim_start_matches('\u{feff}'));
    let mut worksheet = false;
    let mut root_seen = false;
    let mut numeric = false;
    let mut position = String::new();
    loop {
        let event = reader.read_event()?;
        let empty = matches!(&event, Event::Empty(_));
        match event {
            Event::Start(element) | Event::Empty(element) => {
                let name = element.local_name();
                if !root_seen {
                    worksheet = name.as_ref() == "worksheet";
                    root_seen = true;
                }
                if !worksheet {
                    continue;
                }
                match name.as_ref() {
                    "c" => {
                        numeric = true;
                        position.clear();
                        for attribute in element.attributes() {
                            let attribute = attribute?;
                            let value = attribute.normalized_value(XmlVersion::Implicit1_0)?;
                            match attribute.key.as_ref() {
                                "t" => numeric = value == "n",
                                "r" => position = value.into_owned(),
                                "cm" | "vm" => anyhow::bail!(
                                    "XLSX 扩展单元格元数据暂不支持；未确认公式覆盖范围"
                                ),
                                _ => (),
                            }
                        }
                    }
                    "f" => {
                        for attribute in element.attributes() {
                            let attribute = attribute?;
                            let value = attribute.normalized_value(XmlVersion::Implicit1_0)?;
                            anyhow::ensure!(
                                (attribute.key.as_ref() != "t" || value == "normal")
                                    && attribute.key.as_ref() != "ref",
                                "XLSX 数组公式、共享公式或数据表公式暂不支持；未将覆盖范围的缓存当作普通数值"
                            );
                        }
                    }
                    "v" if numeric && !empty => {
                        let text = reader.read_text(element.name())?;
                        let text = text.xml10_content();
                        if !text.is_empty() {
                            let number: f64 = text
                                .parse()
                                .map_err(|_| anyhow::anyhow!("{position} 数值无效"))?;
                            let original = exact_decimal(&text)
                                .map_err(|_| anyhow::anyhow!("{position} 数值精度超出支持范围"))?;
                            let converted = exact_decimal(&number.to_string())
                                .map_err(|_| anyhow::anyhow!("{position} 数值精度超出支持范围"))?;
                            anyhow::ensure!(
                                original == converted,
                                "{position} 数值精度无法无损保留；请将该值另存为文本，未返回舍入值"
                            );
                        }
                    }
                    _ => (),
                }
            }
            Event::DocType(_) => anyhow::bail!("XLSX XML 含不支持的文档类型声明"),
            Event::Eof => break,
            _ => (),
        }
    }
    Ok(())
}
fn exact_decimal(value: &str) -> Result<Decimal, rust_decimal::Error> {
    if let Some((base, _)) = value.split_once(['e', 'E']) {
        // from_scientific uses a rounding base parser; require an exact base first.
        Decimal::from_str_exact(base)?;
        Decimal::from_scientific(value)
    } else {
        Decimal::from_str_exact(value)
    }
}
