# 公开下载与启动验收

2026-10-24，用户明确选择发布未公证预览版，并验证实际下载与启动。目标为 `m4ngod/claurst-desktop` 的 `v0.1.0-preview.1` prerelease。

## 当前实测结果

- GitHub CLI 浏览器登录由用户完成，已确认登录账号为 `m4ngod`，目标为其公开仓库。
- 清洁源码初始提交 `a73e6a50d6c739d14a5a8885e155990dbc34375e` 已推送，GitHub API 返回 main 的同一提交。未上传原工作仓库历史。
- 首次 Git 分块传输返回 HTTP 400，远端核对仍无 main；单次 HTTP/1.1 和请求缓冲调整后推送成功。未改变全局 Git 配置。
- `v0.1.0-preview.1` 已于北京时间 2026-10-24 01:27:47 公开，GitHub 返回 `isDraft=false`、`isPrerelease=true`。8 个上传文件的大小、SHA-256 与本地交付逐一一致。406 个源码构建输入与应用清单匹配。
- [公开 Release](https://github.com/m4ngod/claurst-desktop/releases/tag/v0.1.0-preview.1) 包含应用、项目源码、第三方材料、许可、发布说明、构建清单、候选关联和 SHA256SUMS。
- 宿主与干净虚拟机均已通过实际 Safari 下载、1,800 个文件匹配和签名验证；两者首次打开均被 Gatekeeper 阻止。用户在干净虚拟机完成系统允许后，下载版主窗口、真实 Qwen 读写、来源预览、Finder 定位及许可证窗口均通过。宿主下载版未补测允许后启动，不将其记为通过。

## 候选及验收边界

应用为已验收 `candidate-lxG7UT`，构建源码 `d2f8f76f75519b9a9b898e46d79845a512c5d709`。ZIP 共 101,649,018 字节，SHA-256 为 `6629a64642fa7986eb33bfb31c34de0794692dd33ea3c2db9145e53b1738c21c`。公开初始源码快照的构建输入与实际应用一致；Release 同时提供完整项目源码、第三方对应源码和重建材料。

使用原 Apple Development 签名和应用标识，没有 Developer ID 公证。虚拟机为 macOS 27.0.1，没有 Xcode、Rust 或 TeX；已有模型首次配置和完整功能验收记录见 [干净 Mac 验收](clean-mac-acceptance.md)。本次必须从 GitHub 浏览器下载，保留隔离属性并记录系统实际提示；不以旧共享卷启动证据替代。

应用内离线说明包含构建时“尚未发布下载包”的状态文字，当前入口以 Release 为准。历史材料归档中的上传/公证 false 字段保留其生成时含义，新的实测结果单独记录。

## 宿主 Safari 实际下载

Safari 从 Release 的公开应用 ZIP 链接下载并自动解压，下载列表显示 101.6 MB。解压后的 1,800 个普通文件逐一 SHA-256 对照原候选全部一致；`com.apple.quarantine` 存在，来源为 Safari（0083）。严格深层签名检查在允许系统信任服务访问的环境通过，应用 CDHash 为 `11bfdcaf2f5ba972cbd69cc5f84a6226e21a9a71`，应用标识和签名团队与候选相同。沙箱内最初的 CSSMERR_TP_NOT_TRUSTED 不是最终签名结果。

通过 Finder 正常打开后，进程进入 AppTranslocation，窗口访问超时。只读采样显示进程尚在 `_dyld_start`，系统安全日志明确记录 Gatekeeper 已显示提示并等待响应，随后以 Gatekeeper rejection 终止进程。因此本轮结果为未公证应用被系统阻止，不记为成功启动，也不归因于应用初始化冻结。未修改应用、关闭 Gatekeeper 或移除隔离属性。干净虚拟机的用户允许后启动结果见下文。

## 干净虚拟机 Safari 实际下载

用户登录后，虚拟机 Safari 从同一公开附件链接下载，实际许可提示的服务器为 `release-assets.githubusercontent.com`。下载列表显示 101.6 MB，Safari 自动解压为 `~/Downloads/Claurst Desktop-2.app`；不同于此前共享卷安装的 `Claurst Desktop 2.app`。旧应用已正常退出。

使用系统自带 shasum 对照原候选的清单，1,800 个文件全部匹配；严格深层签名验证通过，标识仍为 `local.claurst.desktop.dev`，团队仍为 `7LL9SV2THD`。隔离属性为 `0083;6adb9e09;Safari;EE7E2D30-378E-4BA9-A87C-ACD5036B0759`，没有手动更改。通过 Finder 双击后实际显示“未打开 Claurst Desktop-2 / Apple 无法验证……”及“完成 / 移到废纸篓”；选择完成保留文件。当时用户允许后的启动检查尚未完成。

定位系统设置期间 Computer Use 曾报告宿主 Mac 锁定，因此暂停界面操作。当时未点击“仍要打开”或处理系统凭据；后续解锁与用户允许结果如下。

## 用户允许后的实际启动与复验

2026-10-24（北京时间），重新通过 Finder 触发同一下载应用的首次打开提示，在系统设置「隐私与安全」实际定位到“已阻止 Claurst Desktop-2”及「仍要打开」。用户亲自处理并回复“已放行”；随后 Computer Use 直接观察到应用主窗口。系统允许步骤由用户完成，可能出现的凭据授权也交由用户处理；没有关闭 Gatekeeper 或手工清除隔离属性。

客体 Terminal 的只读 `ps -axo pid=,comm=` 检查确认：主进程 5623 与运行时 5665 都来自系统 AppTranslocation 中的 `Claurst Desktop-2.app`，排除了误用此前共享卷副本。主窗口恢复了原任务、工作范围和已保存的 Qwen 配置。

新任务使用阿里云 Token Plan 的真实 `qwen3.8-flash`，要求读取 notes.md、给出项目代号和预算及行号，并新建 download-check.txt；实际执行完成，无新增钥匙串提示：

- 来源预览显示 notes.md 第 1–4 行，项目为第 2 行“银杏”。这份混合研究素材没有预算；模型如实回答缺少预算，没有套用早期另一个样例中的 73 元。
- 来源中的「在 Finder 中显示」定位到实际工作区。随后从 Finder 打开 download-check.txt，系统 TextEdit 显示“公开下载版验收成功”，独立确认文件已落盘。
- 客体系统 `shasum -a 256 -c` 对照只读原件清单，notes.md、scanned.pdf、report.docx、sales.xlsx、report.pdf、sales.csv、printed.png 七份原件全部 OK。
- 应用菜单打开「许可证与第三方说明」，实际加载 1,364 份原文；搜索 claurst desktop 得到唯一项目 GPLv3 条目，点击后正常显示许可正文，关闭后返回主窗口。

## 发布候选的证据整合

最终公开应用未在此次复验中重建或替换。编程与研究的真实模型结果分别见 [第 16 项](verification-16-live-coding.md)、[第 17 项](verification-17-live-research.md)；[第 18 项](clean-mac-acceptance.md)覆盖无开发工具环境的配置、文档/表格/视觉读取、离线中文 PDF、停止与重开恢复。后续候选改变了产品许可及说明窗口，四个执行组件的 CDHash 与已验收候选一致；最终候选的包内回归、完整源码匹配、许可证搜索及导出已按[窗口复验记录](verification-19-notices.md)核对。本次再对实际公开下载包补齐启动与真实服务复验。

公开仓库、8 个附件及其摘要、406 个构建输入对应关系均已有实际回执。第 19 项于 2026-10-24 完成，19 项按用户已确认的首版范围全部完成。交付仍为 Apple 芯片 Mac 的未公证预览版；仅实际验收 macOS 27.0.1，虚拟机本地 Vision OCR 限制、单一供应商及研究输出需人工核对的边界继续保留。
