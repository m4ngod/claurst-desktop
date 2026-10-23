# LaTeX 开发验收

日期：2026-10-22。第 14 项原验收条款已通过，不代表公开安装包就绪。

## 可重复验证

测试沿用 TaskService → ACP → 真实工具、文件与 OS 边界，仅替换模型 HTTP。`TaskLatexTests` 覆盖中文、真实 PDF 页数和文字、章节改动后的再次编译、历史恢复、引用及溢出警告、语法错误、越界读取隔离、shell-escape 禁用、停止编译、组件缺失和成果被替换。

固定完整项目还包含图片、BibTeX、表格、公式和标准中文摘要；离线编译后实际 PDF 包含银杏、80 和合成参考文献，引用已解析。

真实 Qwen 最初使用标准摘要时暴露了 `lmroman9-regular` 未打包的问题。新增独立摘要回归先得到相同字体缺失错误（`latex-14-abstract-red.log`）；将标准摘要加入固定资源准备样本后，从同一固定官方 bundle 补齐 regular/bold 字体，整组离线回归通过（`latex-14-abstract-green.log`）。任务期间仍禁止下载。新构建 `build-r6gxLj` 沿用固定签名身份。

退出期间的两项回归均先复现失败再通过：

- 已启动真实编译器后调用 shutdown：编译进程消失，未交付目录删除，没有迟到 PDF。
- 越界读取正在等待权限时调用 shutdown：实际运行时进程退出，未批准读取，未生成来源。

运行时在桌面连接 EOF 时关闭反向请求并取消、等待处理任务；客户端不再直接 SIGTERM 跳过资源析构。关闭令牌同时覆盖请求登记前后与阻塞写入，权限请求以拒绝结束。

修复日志：`.build-tools/latex-14-shutdown-{red,green}.log`、`.build-tools/latex-14-permission-shutdown-{red,green}.log`、`.build-tools/latex-14-final-controls.log`。最终 clippy 已通过；ACP 39 项、tools 199 项测试通过。最终 14 组桌面回归及图像超时检查全部通过，日志为 `.build-tools/latex-14-final-desktop.log`。Rust PTY 用例首次受执行沙盒限制，切换到允许本机 PTY 的测试环境后通过。

## 真实 Qwen 与界面

使用保存的 Qwen `qwen3.8-flash` 配置，经开发应用操作。各构建沿用固定 Apple Development 证书、应用标识与身份要求，本轮没有新增钥匙串授权提示。

- `build-pTfwPG`：CompileLaTeX 在 07:33:17Z 生成 `warning.pdf`，本地解析确认 1 页、3 条警告。实际 PDF 中保留未定义引用 `??`，界面与模型均明确未解决警告，未把编译成功视为页面检查通过。
- 该构建真实复现窄窗预览被压缩的问题。`build-ZKA1Dr` 修复为固定返回/关闭、内容整体滚动和有最小高度的 PDF/源码/日志。
- 在约 651 点宽、最小内容高度的窗口展开警告，预览可滚动，输入与停止仍可见。已通过保存面板导出 `warning-export-check.pdf`，字节与原 PDF 相同；SHA-256 为 `5b433a8b6012c353dc07a5d11f27d8d1961f06e54c44d0f8be0f55c71e3fbb44`。
- 真实模型创建 `generated-report/main.tex`、`sections/summary.tex` 和 `references.bib`，包含预算表、公式及明确标记的合成资料引用。最初禁止 Bash 的测试要求导致缺少父目录，模型实际报告 Write 失败并提问；允许仅建所需目录后继续。模型移除触发字体缺失的摘要后，编译获得 `claurst-latex-0FZsSa/main.pdf`，实际 1 页且无编译警告。Read 已核对 73、7、80 和引用，ReadImage 已实际读取页面像素并核对布局。
- `build-T22JMe` 的 PDF、LaTeX、日志切换已操作；日志显示实际离线编译与 BibTeX 过程。「在 Finder 中显示」准确选择产出的 `main.pdf`，「打开项目」打开含主文件、参考文献和章节的文件夹。Finder 快速查看整页截图中，中文、预算表、公式及两条引用可读，未见裁切或重叠。

解锁后在 build-T22JMe 实际打开「排版组件说明」，完整说明正常显示并可关闭。字体修复后的构建没有再次发送 Qwen 请求；外部源文件打开未做点击验收。既有真实 Qwen、实际标签/项目/导出操作与页面截图，加上资源修复后的真实离线编译回归，已经覆盖原条款。规格复核确认上述额外复测不是硬门槛，不把未点击的控件写作已操作。随后 15 组完整桌面回归和图像超时检查全部通过（`research-15-final-desktop.log`）。

## 审查

规范审查发现并推动修复两种退出清理问题，复核未发现新增实质问题。规格审查发现窄窗预览高度问题，布局修复已通过静态复核与上述实际滚动/导出验证。公开分发的依赖许可材料留在第 18、19 项完成，参见 [编译组件说明](latex.md)。
