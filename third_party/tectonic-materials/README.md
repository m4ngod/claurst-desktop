# Tectonic 源码材料收集

`inputs.json` 固定 Tectonic 0.17.0 的主源码提交、Cargo.lock、默认 macOS arm64
依赖选择及六份输入清单的长度和摘要。`BUILD.md` 随材料交付，说明解包、构建及替换
实际 TECkit 源文件的方法。原生构建、修改后重新链接及映射文档回归已在隔离目录
验证，实际环境、摘要和限制见重建记录；不代表上游二进制逐字节可复现。

使用 Python 3.11 或更新版本，在项目根目录运行：

```sh
python3 scripts/collect-tectonic-materials.py \
  --research .build-tools/third-party-inputs/tectonic-source-research \
  --crates .build/third-party/tectonic-locked-crates \
  --freetype .build/third-party/tectonic-freetype-2.13.3 \
  --output .build/third-party/tectonic-materials-new
```

输入是此前按固定来源取得的材料，下载记录见
[来源记录](../../docs/build/tectonic-source-provenance.md)和
[重建调查](../../docs/build/tectonic-rebuild.md)。脚本不下载文件、不执行上游代码，
也不修改应用。输出必须是新目录。它先校验输入清单及所选内容，再复制并逐项复核；
最终 `SHA256SUMS` 覆盖材料、说明和生成清单，可在输出目录执行
`shasum -a 256 -c SHA256SUMS`。

范围包括 303 个注册表源码归档、24 个本地包身份记录、13 个主项目/原生源码归档、
Rust 1.97.1 标准库源码和原始通知。默认依赖选择不是最终二进制链接映射；303 个
crate 归档也不是可直接用于离线解析整个工作区的 Cargo vendor 目录。

清单仅将 `source_collection_complete_for_catalog` 标为 true。
收集器自身不执行构建，因此其 `rebuild_verified` 与 `redistribution_review_complete`
保持 false；本次独立构建结果记录在随附 `tectonic-rebuild.md`，不由收集动作自动推定。
这是 Tectonic 组件材料；Claurst、其它工具链版本、字体及 TeX 材料仍需与最终
候选包一并核对和组装。此目录的收集完成不表示整个产品已经具备发布条件。
