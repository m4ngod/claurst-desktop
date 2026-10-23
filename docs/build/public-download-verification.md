# 公开下载与启动验收

2026-10-24，用户明确选择发布未公证预览版，并验证实际下载与启动。目标为 `m4ngod/claurst-desktop` 的 `v0.1.0-preview.1` prerelease。

## 当前实测结果

- GitHub CLI 浏览器登录由用户完成，已确认登录账号为 `m4ngod`，目标为其公开仓库。
- 清洁源码初始提交 `a73e6a50d6c739d14a5a8885e155990dbc34375e` 已推送，GitHub API 返回 main 的同一提交。未上传原工作仓库历史。
- 首次 Git 分块传输返回 HTTP 400，远端核对仍无 main；单次 HTTP/1.1 和请求缓冲调整后推送成功。未改变全局 Git 配置。
- `v0.1.0-preview.1` 已于北京时间 2026-10-24 01:27:47 公开，GitHub 返回 `isDraft=false`、`isPrerelease=true`。8 个上传文件的大小、SHA-256 与本地交付逐一一致。406 个源码构建输入与应用清单匹配。
- [公开 Release](https://github.com/m4ngod/claurst-desktop/releases/tag/v0.1.0-preview.1) 包含应用、项目源码、第三方材料、许可、发布说明、构建清单、候选关联和 SHA256SUMS。
- 宿主与干净虚拟机均已通过实际 Safari 下载、1,800 个文件匹配和签名验证；两者首次打开均被 Gatekeeper 阻止。虚拟机已打开系统设置准备定位该应用的允许入口，但 Computer Use 随后报告本机锁定，用户允许后的启动验收尚未完成。

## 候选及验收边界

应用为已验收 `candidate-lxG7UT`，构建源码 `d2f8f76f75519b9a9b898e46d79845a512c5d709`。ZIP 共 101,649,018 字节，SHA-256 为 `6629a64642fa7986eb33bfb31c34de0794692dd33ea3c2db9145e53b1738c21c`。公开初始源码快照的构建输入与实际应用一致；Release 同时提供完整项目源码、第三方对应源码和重建材料。

使用原 Apple Development 签名和应用标识，没有 Developer ID 公证。虚拟机为 macOS 27.0.1，没有 Xcode、Rust 或 TeX；已有模型首次配置和完整功能验收记录见 [干净 Mac 验收](clean-mac-acceptance.md)。本次必须从 GitHub 浏览器下载，保留隔离属性并记录系统实际提示；不以旧共享卷启动证据替代。

应用内离线说明包含构建时“尚未发布下载包”的状态文字，当前入口以 Release 为准。历史材料归档中的上传/公证 false 字段保留其生成时含义，新的实测结果单独记录。

## 宿主 Safari 实际下载

Safari 从 Release 的公开应用 ZIP 链接下载并自动解压，下载列表显示 101.6 MB。解压后的 1,800 个普通文件逐一 SHA-256 对照原候选全部一致；`com.apple.quarantine` 存在，来源为 Safari（0083）。严格深层签名检查在允许系统信任服务访问的环境通过，应用 CDHash 为 `11bfdcaf2f5ba972cbd69cc5f84a6226e21a9a71`，应用标识和签名团队与候选相同。沙箱内最初的 CSSMERR_TP_NOT_TRUSTED 不是最终签名结果。

通过 Finder 正常打开后，进程进入 AppTranslocation，窗口访问超时。只读采样显示进程尚在 `_dyld_start`，系统安全日志明确记录 Gatekeeper 已显示提示并等待响应，随后以 Gatekeeper rejection 终止进程。因此本轮结果为未公证应用被系统阻止，不记为成功启动，也不归因于应用初始化冻结。未修改应用、关闭 Gatekeeper 或移除隔离属性。下一步在干净虚拟机记录实际提示及用户允许后的启动结果。

## 干净虚拟机 Safari 实际下载

用户登录后，虚拟机 Safari 从同一公开附件链接下载，实际许可提示的服务器为 `release-assets.githubusercontent.com`。下载列表显示 101.6 MB，Safari 自动解压为 `~/Downloads/Claurst Desktop-2.app`；不同于此前共享卷安装的 `Claurst Desktop 2.app`。旧应用已正常退出。

使用系统自带 shasum 对照原候选的清单，1,800 个文件全部匹配；严格深层签名验证通过，标识仍为 `local.claurst.desktop.dev`，团队仍为 `7LL9SV2THD`。隔离属性为 `0083;6adb9e09;Safari;EE7E2D30-378E-4BA9-A87C-ACD5036B0759`，没有手动更改。通过 Finder 双击后实际显示“未打开 Claurst Desktop-2 / Apple 无法验证……”及“完成 / 移到废纸篓”；选择完成保留文件。用户允许后的启动检查继续。

定位系统设置期间 Computer Use 明确报告宿主 Mac 锁定，已请求用户解锁。没有点击“仍要打开”、处理系统凭据或放宽全局安全设置；启动仍未通过。
