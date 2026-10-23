# 第三方说明

Claurst Desktop 的新增代码按 [GNU GPL 第 3 版](LICENSE)（GPL-3.0-only）发布。应用使用 Claurst 0.2.0、Tectonic 0.17.0、Rust 依赖和标准库、TeX 资源及字体。原作者的版权、许可与通知均保留，不能将所有组件视为同一种许可证。已确认的交付选择见[发布方案](docs/build/release-decisions.md)。

应用菜单「Claurst Desktop → 许可证与第三方说明」提供离线搜索与原文查看。原文以字节不变的方式保存在 [originals.zip](desktop/Resources/notices/originals.zip)，[索引](desktop/Resources/notices/index.json) 记录每份文件的路径、大小与 SHA-256。构建时解包到应用资源，逐文件检查后签名；HTML 按纯文本查看，不执行脚本。可用「导出原文到 Finder」取得临时目录中的原字节副本，保存时请移到自己的文件夹。部分构建依赖也保留在清单中，不声称它们全部链接进了可执行文件。

Portions of this software are copyright © 2024 The FreeType Project (www.freetype.org). All rights reserved.

Claurst 的许可原文见 [LICENSE.md](vendor/claurst/LICENSE.md)。Source Han Sans / Serif 保留 SIL OFL，Latin Modern 保留 GUST Font License 及作品清单。Tectonic 派生部分及依赖分别保留自身条款，不能仅用主项目的 MIT 声明代替。

Tectonic 引擎组合按 GPLv3 路径交付；其中 TECkit 选择 LGPL 2.1-or-later，Graphite 选择 GPLv3，FreeType 选择 FTL。Tectonic 使用 TECkit 完成文字映射，TECkit 的完整原文、源码、构建和修改后重新链接步骤随材料提供，见 [Tectonic 重建说明](third_party/tectonic-materials/BUILD.md)。这些选择不改写任何第三方的许可原件或其它组件的适用条款。

`selectors 0.41.0` 的 MPL 声明保留在发布源码内，另附官方 MPL 2.0 原文。`sse-stream 0.2.3` 的发布元数据声明 MIT/Apache-2.0；后续 0.2.4 提交的通知明确标为后续材料，没有冒充旧版原件。依据与范围见 [Rust 材料记录](third_party/rust-evidence/README.md)。

离线通知不替代完整对应源码。当前本地材料已经包含 Claurst/TeX、Tectonic 默认 arm64、两种 Rust 标准库及 PSNFSS 原件，详见[当前候选材料](docs/build/candidate-materials.md)和[实际重建与重新链接](docs/build/tectonic-rebuild.md)。公开仓库与 Release 尚未创建，不提供无效下载链接。

## 更新通知

已有汇总材料的 `SHA256SUMS` 用于核对输入原文；工具同时比较依赖锁文件、Cargo 清单及排版输入与该材料对应的构建记录。版本不匹配会停止，不为新依赖复用旧材料。

```sh
python3 scripts/collect-app-notices.py --materials /path/to/verified-materials --output /path/to/new-notices
```

输出目录必须不存在。检查新索引和原件后将 `index.json`、`originals.zip` 放入 `desktop/Resources/notices`，保留并按实际发布状态更新 `README.txt`。`prepare-notices.py` 在每次构建中校验依赖输入和所有解包字节；生成资源属于源码构建清单。完整发布仍须满足第 19 项，而不只通过通知校验。
