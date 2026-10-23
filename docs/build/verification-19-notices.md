# 第 19 项：应用内第三方说明

2026-10-23 初始记录；2026-10-24 追加 GPLv3 与窗口实测。第 18 项原候选的干净环境证据继续保留；本页按版本记录增加说明窗口后的变化与复验。以下原始候选记录不覆盖后续结果。

## 行为

菜单「Claurst Desktop → 许可证与第三方说明」打开独立窗口，支持按组件、版本、许可声明过滤，查看和复制原文、返回总览、在 Finder 定位实际原件。HTML 作为纯文本显示，不执行。关于窗口使用已确认名称 Claurst Desktop。

从已经核对的 `candidate-mpGA4v-materials-v1` 汇总材料中生成 1,363 份原文，合计 8,899,588 字节。Claurst/Rust、Tectonic 及其依赖、两种 Rust 标准库、TeX/字体与 PSNFSS 分别保留。sse-stream 后续版本通知明确标记；不把其变成旧版原件，也不将所有组件重标为项目许可证。项目新增代码许可仍待用户确认。

原文压缩包和索引进入源码；构建逐一核对长度与 SHA-256，再解包到签名应用。收集工具比对锁文件、Cargo 清单、排版输入与旧材料的构建记录；构建工具拒绝依赖输入变化而仍沿用旧索引的情况。源码输入指纹包含新窗口、资源和解包工具。

## 已执行

- Swift 5.8.1 / arm64 macOS 13 编译成功。明确限定为现有工具链，没有引入 Swift 6 专属 API。
- 重复生成原文 ZIP 字节完全一致；全部 1,363 份文件独立核对通过。
- 临时副本改动文件内容或以符号链接代替原文均被校验器拒绝。
- 新原文包无已排除的 `pzdr.afm` 路径及原字节摘要。
- 正式开发构建脚本生成 `build-zGnJIt/Claurst Desktop.app`，使用原证书 `CC8130A1B3C342937779101FCD1FED515FCCA409`、bundle ID `local.claurst.desktop.dev` 及同一证书绑定身份要求。包检查通过，构建输入无未提交项。最初沙盒内无法枚举身份，沙盒外核对证书存在后完成构建，没有换证书或临时签名。
- 新旧 runtime、table parser、document parser、Tectonic 的 CDHash 分别一致。签名包装字节因重新签名而变化；不把完整文件 SHA-256 不同误称为代码变化。
- 新包解压到 `/private/tmp`，通过当前 DesktopCore → 包内 runtime 的混合研究回归，实际执行提取、OCR、表格计算、网页解析、LaTeX、PDF 像素和历史检查。模型及外网边界使用确定性替身；这是宿主回归，不是新版本的真实模型或干净 VM 窗口验收。

构建保留既有 linker 搜索目录警告、字体样例的 0.8598pt overfull 警告，以及禁止访问 `/dev/null` 的说明；相关构建与 PDF 检查仍成功，没有宣称无警告构建。

## 当前候选

目录 `.build/packages/candidate-BC2EGF`，对应上述已提交源码：

| 文件 | 字节 | SHA-256 |
| --- | ---: | --- |
| `Claurst-Desktop-local-arm64.zip` | 101,632,074 | `e60683e12780aeb401d7d6b38eae70f985410cc90c4b5cead5c941a6cfc409c8` |
| `source.zip` | 9,715,105 | `2a77e352b269c4db769a0110e5b4457bd1410b38c3b5f9c6248463e90036a2b6` |

同目录有 `inspection.json`、`build-info.json`、`functional-check.log` 与 `SHA256SUMS`。源码 ZIP 逐文件匹配构建输入；两个 ZIP 的路径检查未见 Git 历史、配置/历史目录、私钥扩展名、构建工具缓存或排除的 AFM 文件。这是明确的路径检查，不能扩大成任意秘密内容检测证明。

## 尚未执行

Computer Use 当前返回本机锁定，已请求用户解锁。说明窗口的菜单、搜索、长文滚动、Finder 定位和关闭返回仍待实际窗口验收，不以编译成功替代。

最终项目许可和开发者会员情况已向用户询问，尚未取得回复。GitHub connector 确认登录为 `m4ngod`，仓库搜索未找到 `claurst-desktop`；没有创建仓库、上传代码或下载资产。正式分发身份、公证和浏览器下载路径继续由第 19 项跟进，当前本地候选不算公开版本。

## 2026-10-24 许可确认、Finder 修复与实测

用户确认 GPLv3 方案、暂无付费开发者会员并解锁本机。实现提交 `d2f8f76`，构建 `build-Kdvn1l/Claurst Desktop.app`，候选 `candidate-lxG7UT`。根 LICENSE 与上游 GPLv3 原文逐字节一致；应用目录新增项目许可，合计 1,364 份原文、8,935,409 字节。

旧版 Finder 按钮实际点击后卡住。鼠标和无障碍点击均复现，进程采样显示主线程阻塞于 `NSWorkspace` → pasteboard → `CreateSecurityScopeData` → `sandbox_extension_issue`。以最小程序对照，包内路径会阻塞，普通临时目录的相同原文可立即定位。修复将按钮改为「导出原文到 Finder」，在私有临时目录复制原字节后选中，不修改签名包。

Computer Use 在新构建实际通过：从主任务菜单打开窗口、按 Rust 版本搜索得到四条记录、将 1.5 MB HTML 作为纯文本显示并滚动、返回总览、搜索项目 GPLv3、导出 HTML 和 LICENSE 后继续响应、关闭窗口返回主任务及输入框。第一次启动恢复为仅说明窗口，关闭后没有窗口；采样证实主线程处于正常事件等待。重启后从主窗口执行完整开关流程通过，未将自动化的 noWindowsAvailable 误记为应用冻结。

Finder 实际选中的两个临时副本已与原件逐字节比对：

| 原文 | 字节 | SHA-256 |
| --- | ---: | --- |
| COPYRIGHT-library.html | 1,499,465 | `5647be074c8edf7339fd863055923a8fc80bc5610a8d4661ec3b767b9d392c27` |
| LICENSE | 35,821 | `81cbae84a29ce7e770bf2bc7b178e50bda0ce8de6067aba661b0bc7b05b562f8` |

继续复用固定开发证书、应用标识与身份要求。包检查、1,364 份原文校验、源码输入匹配及解压后混合研究回归均通过；混合回归的模型及外网边界仍为替身。最新文件：

| 文件 | SHA-256 |
| --- | --- |
| Claurst-Desktop-local-arm64.zip | `6629a64642fa7986eb33bfb31c34de0794692dd33ea3c2db9145e53b1738c21c` |
| source.zip | `6e7a4ef7faa2f2b6868eaec4e04315405265b9bba7ca514ece3e40fc3230f31e` |

已创建公开仓库 `m4ngod/claurst-desktop`，GitHub 页面与连接工具均确认位置、公开可见性及所有者；本段记录时尚未上传源码和下载文件。源码将从当前树建立独立历史，不推送含已排除 AFM 的旧开发历史。公开下载与 Gatekeeper 路径仍待验证，Developer ID 公证路线缺少会员条件。
