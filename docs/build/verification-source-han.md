# 思源字体及离线资源目录验收

日期：2026-10-22。开发机 macOS 27.0.1 / arm64。本记录不代表干净 Mac 安装通过或公开发行准备完成。

## 变更

中文模板采用 `ctexart` 与 `fontset=claurst`，固定 Adobe 思源宋体 2.003R / 黑体 2.005R 简体中文 Regular/Bold OTF。原字体字节与原始 OFL 许可保留。TeX/西文字体仍来自已登记的 v33 资源；6 个 Fandol OTF 不进入新版应用。已存在的 Fandol 主文件不被静默改写，需明确迁移并检查版面。

资源目录包含 420 项：415 个原有非 Fandol 资源、4 个思源字体、1 个项目配置。目录标识为 `3f4896e94e9ba74cbff68ff5f7072df7a5682c92e0078720d74ee088f3d84131`，与上游 v33 标识分列。运行时使用本地 bundle，仍为 `--untrusted`、`--only-cached` 和原 OS 沙盒，网络禁止、源文件只读。

## 证据

- 四份官方字体的下载大小、SHA-256、Git blob 与固定来源一致；两份 LICENSE 摘要通过。数据在 `.build-tools/source-han/verified.json`，公开来源记录在 `third_party/source-han/sources.json`。
- 原型在与产品相同的 Seatbelt 策略下编译 minimal、完整报告、10/11/12pt 字号矩阵、中文样式六组项目，全部成功；日志和 PDF 在 `.build-tools/source-han/probe/sandbox-output/`。完整报告和中文样式没有最终文档警告。字号矩阵仍报告 Latin Modern 等宽粗斜体替代与约 0.86pt 溢出，已保留限制。
- 实际渲染并查看完整报告与中文样式 PDF；中文正文、粗体、黑体、强调、数学符号可见，无缺字或裁切。样例图在 `.build-tools/source-han/probe/page-1.png`、`chinese-styles-page.png`。这不替代真实用户成果的视觉核对。
- 正式准备脚本完成新目录构建和对已有 debug 支持目录的整体替换；新资源完整成员与摘要校验通过。修改、缺失、额外文件及错误资源标识四种情况均被拒绝。
- 实际 `TaskService → ACP → Tectonic → PDFKit` 回归通过：中文 PDF、图片/文献/公式/表格、字号矩阵、再次编译、历史恢复、可见警告、编译失败、范围外读取拒绝、shell-escape 拒绝、停止与退出清理、PDF 替换检查和缺少组件提示。只替换模型 HTTP；工具、文件、编译器和系统隔离真实。日志 `.build-tools/source-han/task-latex.log`。
- 来源收集结果 `.build/third-party/source-han-evidence-92oazlv8/inventory.json`：416 个直接匹配、3 个派生配置、1 个项目配置、0 个未匹配。只收集仍在应用中的 Latin Modern 完整字体 ZIP，不再要求或复制 Fandol ZIP；思源 OTF 和原始许可单列。
- Standards / Spec 两路只读审查均无实质发现；审查者独立核对字体与实际 debug bundle。

后续仍需：从提交后源码构建签名候选、真实模型 PDF 复验、干净虚拟机首次安装与功能验收、完整第三方交付材料和公开下载检查。
