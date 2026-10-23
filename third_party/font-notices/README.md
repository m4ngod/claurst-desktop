# 已匹配字体的原始材料

这里保留 2026-10-22 从 CTAN 官方镜像取得的 Fandol 0.3 与 Latin Modern 2.005 分发归档中的许可、说明和清单原字节。`sources.json` 记录下载地址、归档 SHA-256、原件在归档中的路径、许可材料摘要，以及与固定 Tectonic v33 缓存逐字节一致的 53 个文件；不凭文件名或网页版本标签认定匹配。

Fandol 原 `COPYING` 包含 GPL v3 全文与字体嵌入例外，README 也保留。Latin Modern 的 GUST Font License、README 与 manifest 均保留；上游归档 README 写 2.005，而 manifest 仍写 2.004，原文未修改。

本目录是已核实的部分材料，不是整个排版组件的完整许可包；尚未核定全部源文件要求、其余宏包/字体材料或整体分发兼容性，也尚未嵌入开发应用。完整进度见 `docs/build/third-party-audit.md`。

向 `scripts/collect-third-party-notices.py` 传入 `--font-archives <目录>` 可将该目录中的 `fandol.zip`、`lm.zip` 完整复制到输出的 `font-distributions/`。脚本校验固定归档摘要及清单列出的所有字体/运行文件和原始通知成员；不提供目录则报告 `not_collected`。这些 ZIP 是上游分发材料：Fandol 仅含 OTF 与说明，Latin Modern 的 README 另外列出了 METATYPE1 源码归档，不能仅凭保存这两个 ZIP 宣称已取得全部首选修改形式。
