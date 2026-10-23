# 10 · PDF、Word 与真实来源定位

日期：2026-10-21 至 2026-10-22。基点：5b4a3a1。

## 实现与范围

桌面 Read 通过原有路径授权与已打开句柄身份检查读取 PDF/DOCX 字节。PDFKit 与 Foundation XMLParser 在独立的 macOS Seatbelt 进程中解析；该进程只接收标准输入，不能访问用户文件或网络，20 秒超时、取消时结束。DOCX 先有界读取 ZIP 的 word/document.xml，完全不解包到文件系统，不跟随关系加载外部内容。XML 禁用外部实体并拒绝实体声明、不支持的正文导入与兼容性替代结构。

PDF 返回实际页码；DOCX 以正文 XML 顺序计段，包含表格单元格与空段落，不编造页码。页眉页脚、批注、脚注、文本框和图片不提取；删除修订忽略、插入修订保留，范围显示在来源预览。输入最多 32 MiB，DOCX 正文展开最多 16 MiB，每次默认 10 页/段、最多 20 与 50 KiB 文字。超过时拒绝或提示缩小范围；部分读取有续读位置。空白选区保留本次范围、总数及下一位置，不伪造来源。

来源侧栏、读取快照与历史持久化使用类型化 page/paragraph 定位，文本行号保持原有行为。来源预览可打开原件及在 Finder 定位；开发界面和 README 明确支持范围。解析器随应用构建、签名和封装；不依赖用户另装 PDF/Word 转换工具。

## 固定样本与完整任务测试

样本与生成脚本位于 tests/fixtures/documents。模型 HTTP 是唯一替身；TaskService、ACP、Read、真实 PDF/ZIP/XML 解析、文件授权与历史均实际运行。

- documents-pdf-red.log：旧实现只提示未提取内容；中间回归发现框架启动须读取根目录，以及标准输入未及时关闭导致等待 EOF。仅允许根目录本身读取、显式关闭输入后修复。
- documents-word-red.log → documents-word-green.log：两页中文 PDF 与四段 DOCX 均实际提取；分离的 Word runs 拼接，空段和表格段号正确。
- documents-errors-red.log → documents-errors-green.log：旧 .doc、加密 PDF、损坏、空白和扫描文件明确拒绝，失败没有已读取来源。
- documents-structure-red.log → documents-structure-green.log：合法 XML 但非 Word 根结构不再误报成功。
- documents-lifecycle-green.log：分页续读、越界页码、经符号链接访问外部 PDF 的授权拒绝、重开历史后的类型化定位通过。
- documents-import-red.log → documents-import-green.log：嵌入正文不再被静默省略。
- documents-empty-range-red.log → documents-empty-range-green.log：前 10 页/段为空时提示 offset=11，随后真实读取第 11 页/段的 LATE-731。

日志在本地 .build-tools，未提交运行缓存。

## Standards

首轮发现 1 项 P2：Word altChunk 导入正文被静默省略。用真实 DOCX 关系和完整任务入口复现，改为明确拒绝；复核无新实质问题，无未解决发现。

## Spec

首轮发现 2 项 P2：altChunk 静默省略，以及空白选区丢失续读定位。两项均有真实 TaskService 红绿回归；复核确认解决，无未解决发现。

## 原生窗口与真实 Qwen

build-wEd3Y2 在 /private/tmp/claurst-documents-check-rc_jk5di/workspace 使用已保存的 Qwen 完成两份 Read，未使用 Bash、未修改文件。侧栏显示 PDF 第 1–2 页、DOCX 第 1–4 段；预览可见实际文本与不支持部分。打开原文件成功进入系统预览，原 PDF 确认第 1 页银杏/73 元、第 2 页 P2-418。重开 build-ilTiSL 后对话与读取记录保留。

模型首次将 DOCX 项目名称错引为第 2 段，来源快照始终正确为第 1 段。要求重新 Read 核对后，模型明确承认并更正，原错误和更正均保留。真实证据证明提取和来源定位正确，不能据此保证模型总结及引用无误；README 明确须用来源核对。

最终 build-ilTiSL 在用户完成钥匙串授权后执行异常与续读验收：scanned.pdf、encrypted.pdf、imported.docx 分别明确报告无文字层、加密和 altChunk 不支持，均没有成功来源。blank-prefix.pdf/.docx 首批 1–10 页/段无文字，模型按工具提示继续 Read offset=11，两份实际来源都显示第 11 项 LATE-731。七次 Read，无 Bash、无文件改动；任务保留失败状态与两份成功来源，回复说明未读取范围。

Computer Use 打开第 11 段来源，核对文字及范围；“在 Finder 中显示”选中测试工作区中的 blank-prefix.docx。窗口从宽屏缩到 900×508 点时，来源面板可滚动并打开 Word 预览，输入与发送区域仍可见。

## 完整检查

check-10.log 与 clippy-10.log 通过。tests-10.log：31 组，2284 通过、0 失败、1 忽略。desktop-tests-10.log 与审查后的 desktop-tests-10-final.log 均为七组完整任务测试通过。最终文档测试使用 warnings-as-errors 编译并通过（documents-final-green.log）。build-desktop-10-final.log 成功构建 build-ilTiSL，签名校验通过。

新增/修改 Rust 实现已 rustfmt。全工作区 fmt-10-baseline.log 仍有未触及的上游既有格式差异，未批量改写。保留原有 CRLF 文件，git -c core.whitespace=cr-at-eol diff --check 通过。构建保留此前 btls-sys 两个缺失链接搜索目录警告，实际链接成功；check 与 Clippy 无警告。
