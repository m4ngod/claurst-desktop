# 当前候选的本地交付材料

2026-10-23，已将候选 `candidate-mpGA4v` 的匹配源码、Claurst 运行时及排版资源材料、Tectonic 默认 arm64 材料、两种 Rust 标准库材料与 PSNFSS 原件合并为可检查的本地归档。归档本身不证明安装或发布通过；后续第 18 项的实际验收见 [干净 Mac 记录](clean-mac-acceptance.md)，第 19 项公开发布仍未完成。

## 精确关联

| 对象 | 大小（字节） | SHA-256 |
| --- | ---: | --- |
| 应用 `Claurst-Desktop-local-arm64.zip` | 96,715,370 | `744c7febefd374148a7c03dddc72a2367552b565c231994cb2ddb0fa8c922877` |
| 匹配 `source.zip` | 8,250,927 | `523eb9dda886fe330a6c54b78f807e8bb3c09671638c2a8ee6a0a8d8241113ff` |
| `candidate-mpGA4v-materials-v1.tar.gz` | 361,884,700 | `e7ea6336879183189808b9a543e154e85fb268183c7579bc5d9c7b8a1e1eec8c` |

源码提交为 `278fd7fdd942215c5d84ac06930375a5e4e9e6fb`。归档与解包目录均在 `.build/third-party/`；应用 ZIP 留在 `.build/packages/candidate-mpGA4v/`，没有重复放进材料归档。根目录的 `candidate-association.json` 保存当前候选与三个 Rust 可执行文件的摘要、编译器路径提交及输入目录；这些是关联证据，不是可重复构建证明。

## 输入和检查

| 输入目录 | 文件数 | 内容 |
| --- | ---: | --- |
| `build-8s7Nlm-sources` | 5,196 | 当前 collector 输出：369 项 Rust 记录、362 份注册表源码、字体和所选 TeX 包、生成配置输入与配方 |
| `tectonic-default-arm64-materials-v5` | 986 | 默认 arm64 主源码、子模块、原生依赖、303 份注册表源码及 Rust 1.97.1 材料，含重建说明 |
| `rust-toolchain-1.99.1` | 11 | Claurst 运行时和表格组件所关联的标准库源码、通知及历史关联记录 |
| `psnfss-9.3` | 8 | 完整上游作品、LPPL 原文和当前 TFM 的关联收据 |

输入逐文件复制并核对原字节，加入候选构建/检查记录、11 份调查文档、说明与当前关联记录。归档固定路径排序、时间戳及属主元数据，内含 **6,220 个唯一常规文件**，未压缩总计 **457,280,853 字节**；其中 6,219 个文件列入 `SHA256SUMS`，另一个文件即摘要清单本身。重新打开归档后逐成员核对大小与 SHA-256，全部通过。

输入中的原始清单保持不变。Tectonic collector 的 `rebuild_verified=false` 表示收集动作本身未执行构建；之后已经完成的原版构建、修改实际 TECkit 实现后的重新链接及 PDF 运行证据见 [重建记录](tectonic-rebuild.md)。Rust 1.99.1 原始清单对旧候选的关联也保留，由新的候选关联文件补充当前二进制证据。

没有收录 Git 历史或原件目录外的文件；对文件名和内容摘要检查已记录的 `pzdr.afm` 排除项，并检查匹配源码 ZIP 无该文件。保留 TFM 与完整 PSNFSS 作品。具体范围见 [AFM 分发记录](adobe-afm-distribution.md)。汇总脚本位于忽略的 `.build-tools/assemble-candidate-materials.py`，采用上述固定输入并拒绝覆盖现有输出。

## 使用与剩余条件

解包后先运行 `shasum -a 256 -c SHA256SUMS`，再从根 `README.md` 和 `components/tectonic/BUILD.md` 阅读组件范围与重建入口。各原件保留自己的条款，未统一改成某个项目许可证。

仍须完成产品级通知呈现及最终许可证决定、正式分发身份与公证、浏览器下载 Gatekeeper 验证，以及没有受限旧历史的公开仓库与 Release；最终分发包如改变，须复验对应变化。当前候选已按原规格通过 Qwen 视觉扫描与安装功能验收，本地 OCR 在当前虚拟机失败的限制保留，见 [干净 Mac 记录](clean-mac-acceptance.md)。材料归档明确保留生成当时的 `redistribution_review_complete=false`、`clean_mac_accepted=false` 和 `public_release_complete=false`。归档内文档为历史快照，此后验收进展在仓库继续记录，未原地改写归档或摘要。
