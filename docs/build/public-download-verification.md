# 公开下载与启动验收

2026-10-24，用户明确选择发布未公证预览版，并验证实际下载与启动。目标为 `m4ngod/claurst-desktop` 的 `v0.1.0-preview.1` prerelease。

## 当前实测结果

- GitHub CLI 浏览器登录由用户完成，已确认登录账号为 `m4ngod`，目标为其公开仓库。
- 清洁源码初始提交 `a73e6a50d6c739d14a5a8885e155990dbc34375e` 已推送，GitHub API 返回 main 的同一提交。未上传原工作仓库历史。
- 首次 Git 分块传输返回 HTTP 400，远端核对仍无 main；单次 HTTP/1.1 和请求缓冲调整后推送成功。未改变全局 Git 配置。
- `v0.1.0-preview.1` 已于北京时间 2026-10-24 01:27:47 公开，GitHub 返回 `isDraft=false`、`isPrerelease=true`。8 个上传文件的大小、SHA-256 与本地交付逐一一致。406 个源码构建输入与应用清单匹配。
- [公开 Release](https://github.com/m4ngod/claurst-desktop/releases/tag/v0.1.0-preview.1) 包含应用、项目源码、第三方材料、许可、发布说明、构建清单、候选关联和 SHA256SUMS。
- 实际浏览器下载与启动验收继续；验收虚拟机已唤醒到本地账户登录页，待用户输入其密码。当前不能记为启动通过。

## 候选及验收边界

应用为已验收 `candidate-lxG7UT`，构建源码 `d2f8f76f75519b9a9b898e46d79845a512c5d709`。ZIP 共 101,649,018 字节，SHA-256 为 `6629a64642fa7986eb33bfb31c34de0794692dd33ea3c2db9145e53b1738c21c`。公开初始源码快照的构建输入与实际应用一致；Release 同时提供完整项目源码、第三方对应源码和重建材料。

使用原 Apple Development 签名和应用标识，没有 Developer ID 公证。虚拟机为 macOS 27.0.1，没有 Xcode、Rust 或 TeX；已有模型首次配置和完整功能验收记录见 [干净 Mac 验收](clean-mac-acceptance.md)。本次必须从 GitHub 浏览器下载，保留隔离属性并记录系统实际提示；不以旧共享卷启动证据替代。

应用内离线说明包含构建时“尚未发布下载包”的状态文字，当前入口以 Release 为准。历史材料归档中的上传/公证 false 字段保留其生成时含义，新的实测结果单独记录。
