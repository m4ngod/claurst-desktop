# 任务 12：模型视觉读取验收

日期：2026-10-22。前两阶段见 [本地 OCR](verification-12-local.md) 和 [图像能力检查](verification-12-capability.md)。本阶段在真实文件入口接入 `ReadImage`，补齐用户图片和扫描 PDF 的模型视觉理解。

## 交付行为

- 印刷文字优先 `RecognizeText` 本地 OCR；只有当前模型配置已通过随机图像检查才允许 `ReadImage`，能力未验证时不读、不发送图片，并提示检查配置或使用本地 OCR。
- 每次读取一张 PNG/JPEG 或 PDF 指定一页。文件通过原有 Read 授权与实际打开句柄校验；独立受限解析器只接收字节，无法访问用户文件或网络。输入最多 32 MiB，图片最多 2000 万像素；低于 200×200 或缩放后过窄的图片拒绝。
- 归一化副本最长边 1600，校正方向、去除原文件元数据；优先 PNG，超过 4 MiB 时尝试 JPEG，仍超限则失败。PDF 处理裁切及旋转。OCR 与视觉模式共用 PDF 绘制函数，按 2400/1600 的上限显式缩放。
- OpenAI 兼容适配层保留工具图像。先完成本批全部工具回复，再发送包含工具调用标识的图片消息；图片内容明确视为来源素材。来源窗口只保存路径、页码和生成记录，区分 OCR、文字提取与视觉读取，不把生成副本当作模型已接收或理解的证明。
- 原文件保持不变；历史保留方法、页码和未验证说明。模型拒绝图像时任务失败，已生成的副本记录仍不声称成功识别。

## 红例与修复

完整入口为 TaskService → ACP → 实际工具/文件/隔离解析器 → 模型 HTTP。只替换模型网络边界。

1. `image-read-red.log`：无 ReadImage 工具。
2. `image-read-wired.log`：来源生成，但适配层丢弃图像，仅回传文字。修复后由实际像素读出全部颜色。
3. `image-read-pdf-red.log`：PDF 未支持。接入后发现系统 drawing transform 不放大小页面，按原始大小居中；显式缩放修复指定页像素测试，并共享到 OCR。
4. `image-read-source-red.log`：视觉来源标记缺失，已补入 Codable 历史和来源预览。
5. 审查发现 ImageIO 对截断 PNG 仍报告 complete，`image-read-truncated-red.log` 复现。增加 PNG chunk 边界、CRC 和 IEND 校验；JPEG 检查起止标记并保留系统解码状态检查。
6. `image-read-white-pdf-red.log`：损坏内嵌压缩流静默绘制为白页。视觉模式现在将纯白结果作为“未得到可核对图像，可能为空白、内容损坏或绘制失败”返回，保留总页数和续读位置，不返回成功来源、不发送像素。真实空白页同样保守处理。

JPEG 方向回归第一次因样本未实际写入方向元数据失败，已修正样本生成器，独立读取确认 TIFF Orientation=3，再通过完整入口验证倒序像素。PDF Rotate=180 独立通过。

## 自动化证据

- `scripts/test-desktop.sh`：十一套桌面集成及独立 90 秒超时用例全部通过；日志 `.build-tools/desktop-12-image-final.log`。
- 新图像套件覆盖 PNG、JPEG、PDF 指定页及旋转、批量工具顺序、能力未验证、模型 HTTP 拒绝、损坏、截断、低清、页码/范围、目录外符号链接拒绝、原件字节和历史。网络替身只能从实际收到的像素读取颜色。
- `cargo check --workspace` 与 `cargo clippy --workspace --all-targets -- -D warnings` 通过；日志 `rust-12-image-check.log`、`rust-12-image-clippy.log`。
- `cargo test --workspace`：2284 passed，0 failed，1 ignored；日志 `rust-12-image-test.log`。链接阶段仍有原有 BoringSSL 搜索目录警告，check/clippy 无新增警告。
- 已执行 `cargo fmt --all`，保留本次变更格式；恢复 277 个不相关上游文件的纯格式变化，OpenAI 文件保留原 CRLF。使用 `git -c core.whitespace=cr-at-eol diff --check` 核对实际空白错误。

## 真实模型与窗口

Computer Use 操作 `qwen3.8-flash`，使用已保存的用户配置。自有工作目录 `/private/tmp/claurst-image-live-b9qwbovk/workspace`。

- 构建 `build-XsmXBO`：只用 ReadImage 查看 PNG、PDF 第 1/2 页，三组八色顺序均与样本独立预期一致；三个来源、三次工具、无文件修改。
- PDF 来源预览显示第 2–2 页/共 2 页、视觉副本说明；打开原文件在 Preview 目视核对两页色块；Finder 精确选中原始 colors.pdf。
- 最终构建 `build-q91hTc`：退出旧构建后恢复旧任务，以可见历史续聊，不重放旧工具。新读 printed.png、scanned.pdf 第 1 页，真实 Qwen 均返回“银杏 SCAN-731、73 元、华东 13.25、华西 7.50”，明确 PDF 第 2 页未读且数字/行列关系须核对原图。侧栏恰为原有三个来源加两个新来源；新 PDF 记录包含 offset=2 与完整性限制。
- 最终构建真实 Qwen 异常验收：truncated.png 与 damaged.pdf 第 2 页各一次 ReadImage，均明确失败；模型说明没有得到像素、不推测原始内容，不能区分真空白与绘制失败。侧栏零来源、两条失败工具、无文件修改。
- 四个成功验收原件（colors.png/pdf、printed.png、scanned.pdf）逐字节与仓库样本一致；异常副本单独保留。
- 两个构建沿用固定 Apple Development 证书、应用标识及兼容身份要求；此次新请求与升级续聊均未出现新的钥匙串授权。

## 审查与限制

规范审查的一个判断性发现（重复 PDF 绘制）已修复；需求审查的两个具体复现（截断 PNG、损坏 PDF 白页）已修复并复审通过。

这是有界的图像读取与辅助识别，不是完整 PDF 校验。部分 PDF 元素仍可能静默缺失，不能仅凭非空渲染证明原稿完整；来源和模型提示明确要求对照原稿。JPEG 起止/系统状态检查也不保证发现所有内部损坏。手写、公式、复杂表格和数字不承诺可靠识别；随机图像能力检查不保证任意材料的理解准确率。
