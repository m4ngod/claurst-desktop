# 首版许可与发布方案

2026-10-23。名称与仓库已确定为 Claurst Desktop / m4ngod/claurst-desktop；用户已确认采用以下 GPLv3 方案，并说明暂时没有 Apple Developer Program 付费会员；许可选择已确定；2026-10-24 已按用户后续选择公开未公证预览版，见文末记录。

## 已确认的项目许可

项目新增代码采用 **GNU GPL 第 3 版（GPL-3.0-only）**，上游 Claurst 及所有第三方代码、字体、排版资源保留各自原始版权和许可。上游的实际原文见 [Claurst LICENSE.md](../../vendor/claurst/LICENSE.md)，Cargo 元数据声明 GPL-3.0。本项目不把所有第三方作品重新标为同一种许可证。

根 README 已采用的声明：

> Claurst Desktop 的项目新增代码按 GNU General Public License 第 3 版发布。你可以按该许可证使用、修改和再分发；软件不提供担保。上游 Claurst 和第三方组件保留各自版权及适用条款，详见 LICENSE、THIRD_PARTY_NOTICES 和同一 Release 的对应源码材料。

根 LICENSE 使用未修改的 GPLv3 原文。GitHub Release 将同时提供应用 ZIP、匹配源码、第三方源码与通知材料及 SHA-256 清单。对外源码采用清洁快照创建新仓库历史，排除旧历史中的受限 AFM、开发资料、模型配置、凭据和构建缓存。现有仓库与本地工作记录保留。

独立 Tectonic 引擎的已确认交付选择按[组件原文核对](tectonic-distribution-path.md)：GPLv3 组合，TECkit 选 LGPL 2.1-or-later，Graphite 选 GPLv3，FreeType 选 FTL 并附归属。完整原件和重链接材料已在[候选材料](candidate-materials.md)中；该选择不覆盖其它组件的原条款。

## 发布与更新方式

首版使用已确定仓库的 GitHub Release，手动下载 ZIP 更新；当前不加入自动更新服务。应用保留固定 bundle identifier。开发构建继续使用已固定的 Apple Development 证书；正式分发证书单独配置，实际身份迁移与钥匙串连续性必须验证，不能承诺换证书绝无一次性提示。

正式下载路径计划使用 **Developer ID Application 签名、公证及附加票据**，随后在干净虚拟机通过浏览器下载并正常启动验证。现有 Apple Development 签名仅有本地候选与共享卷启动证据。Apple 说明 Developer ID 证书用于 App Store 以外的分发，创建者需具备 Developer Program 对应账户权限；公证检查由 Apple 服务执行。[Apple 分发说明](https://developer.apple.com/developer-id/)、[证书创建说明](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)

用户已确认采用上述 GPLv3 项目许可与组件分支，暂时没有付费会员。继续完成公开源码与本地发布材料；Developer ID 公证下载路线尚不具备账户条件，不将 Apple Development 候选宣称为公证版。是否公开未公证的测试下载包属于分发方式的实际取舍，必须明确说明 Gatekeeper 限制并验证实际下载路径，不自动等同于首版安装验收。不会代用户购买会员、接受条款或处理账号凭据。

2026-10-24：用户明确选择先发布未公证预览版，并验证实际下载与启动。首个预览版使用 `v0.1.0-preview.1` 标签，标记为 GitHub prerelease；保留现有 Apple Development 签名，随包提供匹配源码、第三方材料与摘要。发布说明明确首次打开可能需要用户在「隐私与安全性」中手动允许。继续执行真实浏览器下载和干净虚拟机启动验证，不关闭 Gatekeeper、不移除隔离属性。用户同时选择使用 GitHub 官方 CLI 的浏览器登录补齐写入权限；已进入实际授权页，最终账号授权由用户核对后完成。

2026-10-24 发布回执：用户完成实际授权后，CLI 登录账号核对为 m4ngod；清洁源码已推送，v0.1.0-preview.1 已公开为 prerelease。8 个交付文件的远端大小与 SHA-256 全部一致。公开入口与后续 Gatekeeper 实测记录见[公开下载与启动验收](public-download-verification.md)。未取得 Developer ID 或公证，不将用户对预览版的选择解释为这些条件已经满足。

2026-10-24 启动验收完成：用户在干净 macOS 27.0.1 虚拟机亲自允许已校验的 Safari 下载版，随后主窗口、真实 Qwen 读写和许可证资源检查通过。此次完成符合用户选择的未公证预览版交付范围，不改变 Developer ID 与公证尚未取得的事实，详见[公开下载与启动验收](public-download-verification.md)。
