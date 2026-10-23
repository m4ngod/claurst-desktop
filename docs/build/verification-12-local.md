# 12 扫描识别：本地 OCR 阶段

日期：2026-10-22。本记录只覆盖本地 OCR 实现与自动化验证；任务 12 尚未完成。已配置非 Claude 模型的视觉能力检查及实际视觉理解仍待实现，真实 Qwen 与来源窗口验收等待 Mac 解锁。

## 实现

`RecognizeText` 通过已有 Read 授权与打开文件句柄核验取得输入，在独立 Swift 解析进程中使用系统 Vision 识别中文、英文印刷文字。支持单张 PNG/JPEG 和未加密扫描 PDF；默认一页、最多五页。输入上限 32 MiB，图片解码前检查尺寸不超过 2000 万像素；渲染最长边不超过 2400 像素，结果最多 50 KiB。小于 200×200 像素的图片明确拒绝，原文件不修改。

来源保留实际页码或图片位置、经方向校正的像素区域、识别分数和原始识别文本。分数明确不是准确率；数字与名称必须对照原图，手写、公式、复杂表格结构、阅读顺序和原稿完整性均不作可靠保证。无可靠文字的范围不创建成功来源，但保留总页数和续读位置；含有文字的范围保留其中空白页的说明。历史保存识别标记、定位与摘录，来源预览可以打开原件或在 Finder 中显示。

## 隔离与诊断

原有 PDF/Word 解析隔离策略下，真实图片 OCR 返回组件执行失败。诊断逐步确认 Vision 的模型编译需要独立缓存，以及 IOSurface、图形和神经计算设备。旧的 `usesCPUOnly` 和新计算设备 API 在本机系统上都不能完全消除这些依赖；移除图形设备会返回空识别结果，不能以“调用没有抛错”视作成功。

最终识别策略只开放已验证的三个设备类别、`com.apple.appleneuralengine`、系统框架/ICU、解析器目录枚举，以及每次调用新建的缓存。没有通用 Mach 服务许可、通用文件元数据许可、用户文件内容许可或网络许可。缓存通过 CoreFoundation 的进程环境定向到独立目录；如系统忽略此设置，隔离策略仍拒绝访问用户 Library。仅该缓存可签发只读扩展给系统计算服务。普通文字 PDF/Word 继续使用原有较小策略。

取消或超时会终止解析器；正常完成和取消都清理缓存。独立受限探针实际尝试读取、写入缓存外的自有测试文件，并连接自有本机监听器，三项均被拒绝。隔离诊断保留在忽略目录 `.build-tools/recognition-diagnostic/`，生产源码无调试日志。

## 验证证据

固定自有像素样本见 `tests/fixtures/scans/README.md`，独立预期包括“银杏”“SCAN-731”“73 元”、13.25、7.50 以及第二页 SECOND-418。测试只替换模型 HTTP 边界，实际经过 TaskService → ACP → 工具 → 系统 OCR、文件和进程。

- `.build-tools/recognition-image-red.log`：尚未接入工具时的 Unknown tool 红例。
- `.build-tools/recognition-image-wired.log`：接入后的真实隔离识别失败。
- `.build-tools/recognition-image-green.log`：正式策略与缓存接入后，从真实图片像素得到全部预期字段。
- `.build-tools/recognition-blank-{red,green}.log`：空白首页遗漏续读提示的红→绿回归。
- `.build-tools/recognition-local-suite.log`：图片、两页扫描 PDF、续读、低清/损坏/越界输入、外部符号链接拒绝、停止、原件字节保持与历史恢复通过。
- `.build-tools/recognition-active-cancel-focused.log`：等待测试自身的真实解析器子进程及模型缓存文件出现后停止，验证子进程退出、缓存删除、没有迟到来源。
- `.build-tools/recognition-local-final.log`：加入实际初始化阶段取消验证后，完整识别套件再次通过。
- `.build-tools/desktop-12-local.log`：九套桌面集成测试通过。`.build-tools/rust-12-local.log`：完整 Rust 测试 2,284 passed、0 failed、1 ignored；`check-12-local.log` 与 `clippy-12-local.log` 通过。
- `.build-tools/recognition-app-build.log`：`build-arBg2e` 构建并使用已固定的 Apple Development 身份签名成功。既有 BoringSSL 链接目录警告保留，未将其描述为新增 OCR 问题。

## 审查与待办

Spec 审查未发现本地 OCR 阶段的确定缺陷或范围扩张；明确保留模型视觉能力与真实窗口验收缺口。Standards 审查未发现规范违反，提出取消测试启动时机的验证缺口；已补充真实子进程与模型缓存阶段的停止检查，复审确认该缺口关闭，无新增实质问题。

此记录不证明任意扫描件、手写、公式或复杂表格均能正确识别，也不把本地文字识别等同于模型视觉理解。任务 12 的验收框仍保持未完成。
