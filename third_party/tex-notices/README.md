# 固定排版资源的部分原件与来源清单

`sources.json` 保留已逐字节核对的 366 项缓存资源来源，以及 21 份固定 TeX Live 提交的许可原文、说明、文件清单或源码入口。原件放在 `texlive-2022/` 的上游相对路径中，按原字节保存；每项包含来源 URL、提交和 SHA-256。来源调查与计数口径见 [排版资源来源记录](../../docs/build/latex-bundle-provenance.md)及[剩余资源记录](../../docs/build/latex-remaining-resource-provenance.md)。旧 Fandol 候选与已有字体目录的 53 项去重后为 418 个缓存数据文件；当前 Source Han 候选的计数见[验证记录](../../docs/build/verification-source-han.md)。

2026-10-23 排除独立授权关联未核实的补充 `pzdr.afm` 原件；它不在运行时资源匹配中。固定包收集计划同时按精确路径排除该文件，并在 `plan.json` 保留摘要和原因。所选 114 包现包含 3,753 个文件，不能称 `zapfding` 包完整无删减；原始 tlpdb 记录保持原样。`pzdr.tfm` 与 PSNFSS 完整作品保持不变，依据与公开历史注意事项见[AFM 材料范围](../../docs/build/adobe-afm-distribution.md)。

这些原件的范围不同：有完整许可证、包组成说明、生成工具说明和文件清单，不能全部视为适用于所有缓存文件的同一份许可。运行文件自身的通知也应保留。`latex.ltx`、`l3backend-xetex.def` 和 `tectonic-format-latex.tex` 匹配官方 bundler 历史源码，不能用 bundler 根目录的许可覆盖宏包内原有通知。

`scripts/collect-third-party-notices.py` 将本清单和已有字体清单与**指定应用包中的实际缓存文件**对应：固定 bundle 标识须一致，已知文件内容改变即拒绝；候选包没有的清单项单列，有但未匹配的文件继续列为缺口。来源匹配按实际缓存路径去重，`ts1lmr.fd` 的两个独立来源记录同时保留。

收集输出中的 `latex-notices` 保存本目录和字体目录的原件；`latex-resource-files` 保存与清单摘要一致的应用包内运行文件，包括文件头通知。后者包含文本和二进制，不是各包所指的完整作品或全部首选修改形式；相关 `.dtx`、字体分发与生成器另行收集。下文补充 `tex-text.tec` 的项目证据；`pzdr.tfm` 的作品分发材料继续核对。输出中的 `source_requirements_complete` 保持 false，本目录尚不构成完整分发材料，也不声明许可兼容或公开发布就绪。

`generated-sources.json` 另保存三个生成配置的固定输入、逐步文本变换和 XeTeX 项目证据。使用 `--latex-extra-sources .build-tools/third-party-inputs/tex-final-provenance` 时，收集器核对 19 份输入原件，运行仓库自身的 `scripts/latex-source-transforms.py`，重建 `language.dat`、`kanjix.map`、`pdftex.map`，并与实际应用资源比较。输出 `latex-extra-sources` 保留输入、三个生成结果、清单和变换脚本共 24 份材料；不执行下载的上游程序。

旧 Fandol 候选的结果为 418 项未修改来源匹配、3 项明确变换关联、0 项未关联数据，另列 5 项缓存元数据。XeTeX 的 `tex-text.tec` 与映射源码、生成比较测试、项目通知关联，作为既有直接匹配的补充证据，不重复计数。配置头和移除的映射块来自候选观察，这不是独立重演历史构建；映射中的字体各自保留原许可范围。详细依据见[最后一组排版来源](../../docs/build/latex-final-materials.md)。完整所选 TeX 包文件、字体分发归档与其它组件的分发条件仍独立处理。
