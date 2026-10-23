# 第三方材料核对进度

日期：2026-10-22。仍在核对，尚不是完整的分发许可材料，也不据此声明许可证兼容或公开发布就绪。

## 可重复收集

此证据收集工具需要 Python 3.11 或更高版本（使用标准库 `tomllib` 校验 Cargo.lock），与应用运行无关。先用 `python3 --version` 确认解释器；macOS CLT 自带的 Python 3.9 不满足该工具要求，会收到明确提示。然后从项目根目录加载 `scripts/env.sh`，运行：

```sh
python3 scripts/collect-third-party-notices.py \
  --app '/absolute/path/Claurst Desktop.app' \
  --font-archives .build-tools/third-party-inputs/fonts \
  --output .build/third-party/new-inspection
```

`--font-archives` 指向保存 `fandol.zip` 与 `lm.zip` 的目录。来源地址及固定摘要在 `third_party/font-notices/sources.json`；镜像后续更新时不能用新字节冒充已匹配版本。指定此参数后，缺少归档、归档摘要不符或清单中的成员摘要不符均拒绝；不指定时继续收集其他材料，但报告明确记为 `not_collected`，不会声称保存过完整字体分发归档。

固定 TeX 包采集全部成功后，可同时增加 `--tex-sources .build-tools/third-party-inputs/tex-package-sources-with-exclusions` 与 `--tex-package-database .build-tools/third-party-inputs/bundle-v33-research/texlive.tlpdb`。两个参数必须一起提供。收集器从固定摘要的数据库和当前来源清单重新生成计划，核对包记录、下载完成状态、无遗漏或重复的文件集合、固定版本 URL、归属、每个文件的长度与摘要，以及已匹配应用资源的摘要。复制后再次校验，保存数据库、原始计划、收据、全部所选文件和逐文件清单。未完成的下载不能进入成功报告；不提供参数则明确记为未收集。

该目录覆盖所选包的文档、源码和运行文件，并非全部 TeX Live；字体分发归档及 bundler 补丁另行保存。它不自动解决字体的首选修改形式、全部组件来源或整体许可兼容问题。

脚本先核对包内构建记录与当前完整 Rust 输入集合及哈希、上游 LICENSE，再用 locked/offline、arm64 macOS 的 Cargo metadata 收集运行时和表格工具的 normal/build 依赖闭包。工作区特性合并可能包含未实际链接的依赖，清单是保守范围；不是精确的二进制链接清单。原有通知文件按原字节复制并记录摘要，缺失单列，不用 SPDX 声明代替原件或兼容性判断。

对源码 `711b3c1` 的 `build-0AC5Jr` 实际收集得到 369 项 Rust 包记录、5 项无通知原件，以及 368 个 LaTeX 缓存文件的路径和 SHA-256。本地输出在 `.build/third-party/inspection-711b3c1-verified`。原脚本仅比对锁文件的证据关联缺口已按两路审查修复；保持 Cargo.lock 不变、只改变临时候选记录中的 Cargo.toml 哈希，脚本实际拒绝且未创建输出目录。

## 明确缺口

当前 Rust 缓存中未找到通知文件的包为：`alloc-stdlib 0.2.2`、`dasp_sample 0.11.0`、`rmcp 1.7.0`、`selectors 0.41.0`、`sse-stream 0.2.3`。应按各包发布版本和 VCS 记录补原件，并核对对应源码材料。Claurst 本地子包引用保留的 `vendor/claurst/LICENSE.md`；最终产品的许可和分发方案尚未确认。

已从前三项的 `.cargo_vcs_info.json` 精确提交取得原件，保存在 `third_party/rust-notices`；来源 URL、提交和 SHA-256 见其中 `sources.json`。收集器再次比对 crate 名称、版本、实际 VCS 提交及原件摘要后复制，不改写原件中的许可说明。`rmcp` 原件包含许可过渡说明，未将它简化成 Cargo 声明的单一结论。补齐后实际输出仍为 369 个包，未找到独立原件的减为 `selectors` 和 `sse-stream` 两项；这两个精确提交的根目录也没有独立 LICENSE 文件，仍需核对源码内通知及适用材料。

字体修复构建 `build-Kxg7bW` 对应 `002b577`，实际 LaTeX 缓存增加为 397 个文件；补充后的收集结果在 `.build/third-party/inspection-002b577-final`。两路审查复核来源关联，无新增实质问题；这不构成法律兼容性结论。

数学字体补齐的 `12ebfce` / `build-yNvutk` 再次实际收集，仍为 369 项 Rust 包与 2 项缺独立通知文件；LaTeX 缓存为 426 个文件，输出在 `.build/third-party/inspection-12ebfce`。本地 `selectors 0.41.0/lib.rs` 保留 MPL 2.0 的文件头通知和官方原文链接；`sse-stream 0.2.3` 的 Cargo 元数据声明 MIT/Apache-2.0，检查其 README 与源目录未找到额外版权/许可通知。未凭声明补写作者版权或将这两项标为材料完整。

本轮补充依据保存在 [`third_party/rust-evidence`](../../third_party/rust-evidence/README.md)。`selectors 0.41.0` 发布归档中的 15 个 Rust 文件均有 MPL 文件头，另保存 [Mozilla 官方 MPL 2.0 原文](https://www.mozilla.org/en-US/MPL/2.0/)。`sse-stream` 上游在[提交 9b95874](https://github.com/4t145/sse-stream/commit/9b95874ca02cc337b9f86b54915ba6c6b27821d0)加入独立 MIT 和 Apache 文件时，Cargo.toml 已为 0.2.4；这两份按原字节保存为后续版本材料，不冒充当前 0.2.3 原件，对旧版本的适用性仍待确认。

收集器将这些关联独立记为 `license_evidence`，在输出中保留两个完整 `.crate` 源码归档。核对实际 VCS/声明、Cargo.lock 校验和、归档字节，以及列出的归档成员、缓存源文件和外部文档摘要；后续版本的许可文件另记其提交。`ad3ef2c` / `build-mHHoqi` 实际收集结果位于 `.build/third-party/inspection-ad3ef2c-license-evidence-verified`，仍为 369 项、2 项缺独立原件、426 个排版缓存；`redistribution_review_complete` 仍为 false。这两个归档不代表已备齐整个产品的对应源码。

负向检查在临时副本中分别改变 VCS、许可声明、锁文件校验和、归档字节、缓存源文件、归档成员预期摘要、文档预期摘要，七种情形均被拒绝；正确副本保留的源码归档和三份文档与来源字节一致。Python 3.9 启动提示与 Python 3.11 实际收集另行核对。未修改实际依赖缓存或产品运行逻辑。

本轮 Standards 审查发现 Python 3.11 前置条件未说明，已在 README、此处和脚本启动提示中修复，并在两个解释器实测。Standards 与 Spec 复核均无剩余实质问题；该结论仅针对证据收集改动，不是整个产品的许可审查结论。

Tectonic 0.17.0 主项目使用 MIT，其许可说明明确指出派生部分适用多种许可；还需核对实际二进制的原生和传递依赖，不能把它们统一标为 MIT。见 [该版本 LICENSE](https://github.com/tectonic-typesetting/tectonic/blob/tectonic%400.17.0/LICENSE)。

已核实 0.17.0 标签对应提交 `8c0126a9653239a2e6e0a5274af9b8510f643030`。[该提交构建流程](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/.github/workflows/build_and_test.yml) 的 macOS arm64 发布采用 vcpkg；[Cargo.toml](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/Cargo.toml) 固定 vcpkg 为 `a62ce77d56ee07513b4b67de1ec2daeaebfae51a`，列出 fontconfig、freetype、harfbuzz/graphite2、icu。源码还含 HarfBuzz 子模块，官方下载归档仅包含 tectonic 可执行文件。这些记录确定后续材料核对入口，尚未证明实际二进制每项静态依赖的完整版本和许可。

排版缓存包含 Fandol、Latin Modern 和 TeX 宏包、断词及格式文件。CTAN 将 [Fandol](https://ctan.org/pkg/fandol) 标为 GPL，将 [Latin Modern](https://ctan.org/pkg/lm) 标为 GUST Font License；这些页面只提供核对入口，尚不能证明缓存中的每个文件已匹配版本与完整分发材料。仍需逐一关联固定 bundle 中的文件、许可原件和相应源码要求，新增字体资源后也须重新收集。

收集输出与候选包分别保存，尚未作为完整通知包嵌入应用；公开发布前需要完成上述核对。

固定 bundle URL 的实际重定向为 `https://data1b.fullyjustified.net/tlextras-2022.0r0.tar`。按已缓存索引的字节范围取得 SVNREV=`62885`、GITHASH=`082081a375be008c2e049cd7cf1137314f888b18`，大小、范围与摘要保存在 `.build-tools/third-party-inputs/bundle-v33/provenance.json`，未下载整个 2.88 GB 归档。该初次收据中的“仓库关联未解决”状态已由后续调查推进：GITHASH 属于 TeX Live 镜像的 `tags/texlive-2022.0@62885`，不是 Tectonic 引擎或 bundler 本身的提交。固定来源和证据摘要见[排版资源来源记录](latex-bundle-provenance.md)。

从 CTAN 官方镜像获取 Fandol 0.3 与 Latin Modern 2.005 分发归档后，实际按 SHA-256 比对固定缓存：分别有 6 个与 47 个同名文件字节完全一致，没有同名异内容项。许可原文、README、Latin Modern manifest 及逐文件关联保存在 `third_party/font-notices`；Fandol 原件包含 GPL v3 与字体嵌入例外，未将其简化为网页上的 GPL 标签。Latin Modern 上游 README 写 2.005，manifest 仍写 2.004，按原字节保留。这补足两组匹配文件的原件关联，但尚未完成源文件要求与其余排版资源核对，未据此宣布可公开分发。

后续实际比对确认 296 个缓存文件与固定 TeX Live 提交一致，另 3 个与官方历史 bundler 的补丁/extra 一致。根线程再次逐字节复核全部 299 项。与上述 53 项字体记录去重后为 351 个缓存数据文件，不能直接相加为 352；另取得 10 份固定版本的非字体通知/材料入口。研究文件仍在 `.build-tools/third-party-inputs/bundle-v33-research`，完整来源 URL、摘要、重复项及缺口见来源记录。两份大文本、三个生成配置、其余字体/度量文件以及各包完整源码与通知收集尚未完成，也尚未嵌入应用；文件来源匹配不等于分发要求已满足。

继续核对剩余 65 项字体/度量/转换资源后，全部与固定 TeX Live 提交匹配；两份先前超时的 `UnicodeData.txt`、`expl3-code.tex` 改用压缩传输后也取得完整内容并逐字节匹配。当前合计 **418/421 个缓存数据文件有来源匹配**，仍有 `language.dat`、`kanjix.map`、`pdftex.map` 三个生成配置待关联输入与生成过程；另外 5 项索引/记录/格式缓存单列。详见[剩余资源来源记录](latex-remaining-resource-provenance.md)。

已将 366 项来源关联和 22 份固定 TeX Live 原件/源码入口保存至 [`third_party/tex-notices`](../../third_party/tex-notices/README.md)。收集器合并既有字体材料，核对指定应用实际 bundle 标识、缓存路径和字节摘要，按实际路径去重，缺失清单项与未匹配文件分别保留；有来源记录的文件内容不符或材料原件摘要不符即拒绝。输出复制 366 项已匹配运行资源和 27 份原件/材料，保留原始通知。运行资源包括文本和二进制，不称为各包完整作品或全部首选修改形式；`pzdr.tfm`、`tex-text.tec` 的具体许可关联及完整源码材料仍待补齐。

`ad3ef2c` / `build-mHHoqi` 的完整收集结果位于 `.build/third-party/inspection-ad3ef2c-tex-materials-418`：369 项 Rust 包、2 项缺独立原件；排版数据为 418 匹配、3 未匹配、5 其他缓存、0 清单项在包中缺失、27 份原件/材料。全部复制资源和原件再次校验摘要一致。临时副本验证了部分缓存正确收集、已知资源内容改变拒绝、bundle 标识改变拒绝、新增未知文件保留缺口、索引与数据文件分开计数、许可原件被改动拒绝。`redistribution_review_complete` 和 `source_requirements_complete` 均保持 false；应用与已有候选包没有因此被改写。

Rust 源码收集随后扩展到当前 normal/build 依赖闭包的 **全部 362 个 crates.io 注册表归档**，总计 47,764,155 字节；每个归档与 Cargo.lock 的名称、版本、注册表及校验和对应，输出后再次核对全部摘要。其余 7 个本地 Claurst 子包记录仓库相对路径，与报告中的 `app_source_revision` 及既有匹配项目源码 ZIP 配套，不伪造独立注册表来源。未知注册表/其他依赖来源明确拒绝，须补充采集规则后再运行。

最新完整输出为 `.build/third-party/inspection-ad3ef2c-all-crate-sources`，报告还记录收集器脚本摘要。临时副本中的锁文件校验和、归档字节、未知注册表、专项证据归档摘要、VCS、来源文件被修改的六种情形均拒绝，正确归档通过且被专项许可证据复用。该输出补齐了此依赖闭包的注册表源码，仍不包括整个产品所有 Tectonic/原生依赖、工具链运行库、字体/TeX 首选源码，也不自动解决整体许可兼容；已有两项无独立原件的事实记录及 false 状态保留。

排版材料采集与 Rust 全闭包源码采集两批改动均完成 Standards、Spec 双轴审查，无剩余实质发现；审查另行核对了来源记录、材料摘要、计数和完成边界，Spec 复核了全部 362 份归档摘要。这不改变尚未完成安装与公开分发验收的结论。

已扩展收集器保存完整的 Fandol 0.3 和 Latin Modern 2.005 上游分发 ZIP，并逐项核对归档内已匹配的字体、运行文件及原始说明/许可成员。实际输出 `.build/third-party/inspection-ad3ef2c-font-distributions` 中两份 ZIP 分别为 26,688,406 与 18,709,543 字节，均与固定清单摘要一致；原有 369 个 Rust 包、418 个已匹配排版数据及其他缺口计数不变。临时副本检查了省略输入、正确归档，以及归档摘要、字体成员摘要、通知成员摘要、成员路径和缺失归档五类错误关联。

这里的“完整”只指已获取的上游 ZIP 未裁剪。Fandol ZIP 含 8 个 OTF、README、COPYING，没有独立的字形编辑源文件；README 提到 AFDKO、FontForge 与 Inkscape。Latin Modern ZIP 未含 README 所提的独立 METATYPE1 字体源码归档。因此报告仍保留首选修改形式的待核对范围，不把这两份字体分发 ZIP 直接改称完整对应源码。

2026-10-22 后续[分发路径复核](font-distribution-path.md)纠正了上段对 LM 的过宽前提：LM 使用 GUST/LPPL，完整 ZIP 覆盖 manifest 的全部 1,070 项，按未修改完整作品组织交付时，不能额外把独立 METATYPE1 工程设为门槛。`pzdr.tfm` 也已在官方 PSNFSS 完整作品中找到相同字节及明确 LPPL 声明；根线程核对完整 ZIP、内嵌度量和三份固定 TL 原件一致。PSNFSS 不包含实际 Adobe AFM/PFB，不能将其许可套用到额外材料。Fandol 的 GPL 源形式问题保留具体边界，正在验证使用 OFL 思源字体的替代方案。两路文档审查均无实质发现；替换尚未完成，候选包未改动。

## 固定 TeX 包文件收集

`scripts/fetch-tex-package-sources.py` 从上述固定 TeX Live 提交的 `Master/tlpkg/texlive.tlpdb` 生成收集计划，先校验数据库 SHA-256，再选择当前来源清单涉及的包，以及补丁/语言配置相关的 `latex`、`l3backend`、`hyph-utf8`；Fandol、Latin Modern 的分发 ZIP 另行收集。初版计划是 114 个包、3,754 个不同路径（2026-10-23 精确排除一份补充 AFM 后为 3,753），覆盖所选包的 `docfiles`、`srcfiles`、`runfiles`，保留原始包记录。计划包括文档和二进制运行文件，不代表每项都是源码，也不是整个 TeX Live 或产品的完整对应源码。

```sh
python3 scripts/fetch-tex-package-sources.py \
  --tlpdb .build-tools/third-party-inputs/bundle-v33-research/texlive.tlpdb \
  --output .build-tools/third-party-inputs/tex-package-sources
```

数据库固定 URL 为 `https://git.texlive.info/texlive/plain/Master/tlpkg/texlive.tlpdb?id=082081a375be008c2e049cd7cf1137314f888b18`，摘要为 `c518358e4c5f1f512bc67af18c8f0f60c264b1722f75551fda37462ffbf88822`。`--plan-only` 只生成计划，无网络请求。下载使用固定提交 URL，最多四个并发请求，单文件请求限制 180 秒及 64 MB；非零下载结果不进入成功文件。`results.json` 保存 URL、成功字节摘要、失败原因和整体完成状态；重复运行时只复用摘要仍一致的既有文件。新脚本通过输出目录锁拒绝自身的并行冲突，旧的一次性采集进程没有此锁，不可与它同时写入同一目录。

实际采集仍在进行，不能把已生成的计划当成 3,754 份材料全部到齐。脚本已重现正在执行的原计划与 114 份原始记录；数据库/路径错误、缓存摘要复用、缓存改变后重新取得、失败下载不覆盖旧成功文件，以及不同计划拒绝均已检查。网络传输之外的文件与校验使用真实临时文件，下载成功/失败边界以替身检查，真实批量下载的成败单列在本地收据中。后续只有全部文件成功并重新核对摘要，才能据此组装材料归档。

两路审查指出中断时仍会执行排队任务、重新验证未及时清除旧完成标记，均已修复：启动重验前原子保存 `complete=false`，最多保留四个在途任务，退出时取消未开始的请求并终止正在运行的 curl，最终保存回执。OSError、KeyboardInterrupt、实际子进程取消和正常全量结束分别验证；真实取得一份固定源文件 `texmf-dist/doc/bibtex/base/README`，1,424 字节及摘要与原收据相同。

2026-10-22，全部 114 个包的 3,754 个文件实际取得，共 148,024,916 字节。首轮 7 个失败项保留了超时回执，普通重试补齐 4 项，最后 3 份较大 PDF 以相同固定提交 URL 延长时限后成功；全部文件再次按收据独立复核长度和摘要。随后运行新版收集器，实际输出 `.build/third-party/inspection-ad3ef2c-tex-packages`，保存所选文件以及数据库、计划、包记录、收据共 3,758 项；复制后的清单和全部字节再次核对通过，清单 SHA-256 为 `1b93c30ff6ba454d0f2f9ebce8fe265d2c4177762b926e6839de20bcf6ab46d5`。原有 Rust 与应用资源匹配计数不变。

临时输入分别测试计划改变、原始包记录改变、未完成、错误计划摘要、重复/缺少回执、错误 URL、归属、长度和摘要，十种情形均明确拒绝；省略材料和两个参数缺配也单独核对。Standards 与 Spec 静态复核均无实质发现，全量正向结果由上述实际收集补足。这只是所选包文件收集完成，不改变安装与整体许可审查仍未完成的状态。

## Tectonic 引擎材料

[Tectonic 来源记录](tectonic-source-provenance.md) 已区分发布流程声明与实际二进制证据，保存固定主源码、两个 gitlink、vcpkg 及选定原生依赖的 13 份完整归档，共 92,471,911 字节，另有 30 份归档通知原件和一份独立 AWS-LC 复合 LICENSE。根线程重新核对全部归档的 SHA-256/SHA-512，并核对通知与归档成员的字节一致性。完整清单、失败下载与 437 项独立 Rust 锁定来源分别保留；这些材料尚未纳入主收集器或最终候选包。

后续已取得全部 437 份锁定注册表归档，共 82,289,482 字节，另从中保存 783 份原始通知；完整输出为 `.build/third-party/tectonic-locked-crates`。归档逐项匹配主源码内 Cargo.lock，通知再次与归档成员核对一致；官方 CDN 超时后使用的镜像地址单列，不能替代官方摘要依据。清单保留 16 项无独立通知文件的事实及声明，未将这个含其它平台和开发依赖的全集称为实际二进制链接清单。详细来源及限制见上述记录。

FreeType 2.13.3 的 2,482,495 字节完整归档也已取得，SHA-512 匹配固定 vcpkg 端口；三份许可原件和完整归档保存在 `.build/third-party/tectonic-freetype-2.13.3`。另完成[最后一组排版来源研究](latex-final-materials.md)：三个生成配置现有精确变换及全文件字节匹配，根线程在独立副本重执行配方并对照实际应用；XeTeX 的映射源码、同字节转换文件、上游生成测试与通知原件均复核 Git blob 和 SHA-256。它们尚待接入正式收集输出；原有直接匹配计数仍为 418，新增三项应按变换关联单列。Adobe 度量的通知、字体编辑源码的具体问题保留在该记录中。

## 生成配置接入收集器（2026-10-22）

新增 `--latex-extra-sources` 参数读取固定清单列出的 19 份输入原件，并用仓库自身的纯文本变换重建三个配置，不读取候选内容来决定变换，也不执行下载的上游代码。候选观察所得的替换头与五个移除块在清单中明示；这项关联不是历史构建重演证明。XeTeX 的同字节转换文件、映射源码、生成测试和项目通知另存，不增加既有直接匹配计数。

完整实际输出 `.build/third-party/inspection-ad3ef2c-derived-configs` 保留原有 Rust、字体和 114 个 TeX 包材料；排版结果为 **418 项直接匹配、3 项变换关联、0 项未关联数据、5 项缓存元数据**。新增材料共 24 份（19 输入、3 结果、清单、变换脚本），复制后的长度和摘要逐项核对通过。临时文件验证了省略材料、应用无对应文件，以及错误原始行、输出摘要、未知操作、块摘要、缺块、块位置、应用资源、来源字节和来源缺失九类拒绝。完整许可审查和真实安装状态不因此改变。

Standards 与 Spec 两路复核均无实质发现，分别复验固定输入、派生结果与实际输出计数；直接来源、文本变换及许可完成状态继续分开记录。

## Claurst 标准库材料

当前本地工具链报告 `rustc 1.99.1`、提交 `58cf8f9c35b355199727627d07ae34a4e2846d67`、host `aarch64-apple-darwin`、LLVM 23.1.1。实际候选中的 `claurst-desktop-runtime` 与 `claurst-table-parser` 都包含该提交的 `/rustc/` 源码路径；它们的二进制摘要与 `ad3ef2c` 来源记录一起保存。这是工具链关联证据，不是逐字节可重建证明，也不能套用到预构建 Tectonic 所包含的另一编译器提交。

已取得 [Rust 官方 rust-src 1.99.1 归档](https://static.rust-lang.org/dist/2026-10-15/rust-src-1.99.1.tar.xz)，5,863,216 字节，SHA-256 `e485a88c45db546b73571df7bebfcb4454ba4fb552c492e25fc5b00eeb5bf22d`，与已安装工具链的发行清单相符。清单本身的 SHA-256 为 `48419307eb32e389a25ac360b6bccd4d196f3c4f35ce9d67a223319eff017c6c`。归档包含 `library` 源码、30 个 vendor 依赖目录及将 crates.io 替换到该目录的 Cargo 配置；完整归档按原字节保留，没有执行安装器或构建脚本。

本地自包含材料目录为 `.build/third-party/rust-toolchain-1.99.1`：保存完整源码归档、其根目录的 LICENSE-APACHE/LICENSE-MIT/COPYRIGHT 原件、本机该版本的 `COPYRIGHT-library.html`、README 和标准库安装文件清单、发行清单，以及文件摘要和候选二进制关联。`COPYRIGHT-library.html` 为 1,499,465 字节，SHA-256 `5647be074c8edf7339fd863055923a8fc80bc5610a8d4661ec3b767b9d392c27`。这份 HTML 是所观察到的安装材料，未声称它来自 rust-src 归档；材料目录仍与候选包分开，不代表整个产品的对应源码已经齐全。

## 当前 Source Han 候选与补充 AFM 排除（2026-10-23）

候选 `candidate-a3vT0N` 对应源码 `9f1f01c`。完整 collector 输出 `.build/third-party/candidate-a3vT0N-sources`，含 369 项 Rust 包记录、362 个注册表源码归档、Latin Modern 完整作品、4 个未修改 Source Han 字体及 OFL 原件、114 个所选 TeX 包的 3,753 个文件，以及生成配置输入与配方。应用排版数据为 416 项直接匹配、3 项变换关联和 1 项项目配置，0 项未关联。

精确排除独立授权关联未核实、运行时不使用的 `pzdr.afm`；`pzdr.tfm` 和 PSNFSS 完整作品未变。新输入目录为 `.build-tools/third-party-inputs/tex-package-sources-with-exclusions`，旧未排除目录继续保留为内部调查材料，不得选作公开资产。原始数据库记录未变，严格计划/收据校验仍在，旧计划与额外、缺失、重复收据全部拒绝。源码快照排除与旧 Git 历史问题见 [AFM 材料范围](adobe-afm-distribution.md)。Standards 与 Spec 两路复核均无实质发现。

Tectonic 主源码、原生依赖、工具链标准库、PSNFSS 等已有材料仍待合并到最终下载资产；当前 collector 的整体未完成标志继续保留。干净虚拟机已成功解压启动该应用，模型配置及素材任务正在验收，未将共享卷启动等同于浏览器下载分发验收。

## Tectonic 组件材料组装（2026-10-23）

新增独立的 [Tectonic 收集器及固定输入目录](../../third_party/tectonic-materials/README.md)。
它按六份固定输入清单核对原始字节，从主源码归档取出 Cargo.lock，再核对默认 arm64
选择中的 303 个注册表归档；24 个本地包以主源码中的身份记录关联。另保留 13 个
主项目/原生源码归档、Rust 1.97.1 标准库源码及通知，不执行下载的上游代码。

实际输出 `.build/third-party/tectonic-default-arm64-materials-v2` 有 **976 条唯一
源码与通知记录**；连同构建说明、输入依据和清单，共 **985 个被校验文件**，
138,003,789 字节，另附 `SHA256SUMS`。该摘要清单的 SHA-256 为
`3992edad1bd1705685de83124feb3c47e6adfb1e6530e1582915802f8b7719ba`。
全部输出的长度、摘要、路径唯一性再次核对；改变固定输入清单、改变主源码归档
以及试图覆盖既有输出三种情形均被拒绝。Standards 审查发现的两份顶层许可证
重复登记已修正，Spec 审查未发现实质问题。

本地归档 `.build/third-party/Claurst-Tectonic-Sources-0.17.0-arm64-v2.tar.gz`
为 131,774,052 字节，SHA-256
`097b3da6c94cd50d7baf320a80485bf17bba9c6d534e5a6b750ff6e4c8f58bba`。
包含摘要清单在内的 986 个归档成员全部与上述输出逐文件匹配。归档固定成员顺序、
时间戳和属主元数据；这不表示上游二进制已经可重复构建。

输出附有独立 `BUILD.md`，包含子模块解包、默认 vcpkg/Cargo 构建及修改实际
TECkit 实现后重新链接的步骤。**原生构建、修改后的重新链接和文档运行测试仍待执行**；
清单的 `rebuild_verified` 与 `redistribution_review_complete` 均为 false。
这份组件归档尚未公开，也尚未与其它组件合并为最终下载资产。

### 源码构建与重新链接的实际验证

随后在隔离目录完成七种默认原生依赖及 Tectonic 默认 arm64 构建，再修改实际
`TECkit_CreateConverter` 后重新链接。两个版本均以真实本地 bundle 生成一页
中文、数学和文字映射 PDF；仅修改版本的排版运行出现 14 次测试标记，页面已
渲染并核对。日志、二进制摘要、工具版本、先前失败及构建警告见
[实际重建记录](tectonic-rebuild.md)。
测试版本没有替换产品引擎，也未改变产品签名身份。收集器本身不执行构建，
其 `rebuild_verified=false` 表示收集动作没有执行该验证，独立验证证据另列；
不再用旧的“尚未执行”说明覆盖新的实际结果。整个产品的安装与发布条件仍待完成。

更新构建说明后的组件材料为 `.build/third-party/tectonic-default-arm64-materials-v5`，
仍有 976 条唯一原件记录、985 个校验文件，共 138,008,581 字节；
`SHA256SUMS` 摘要为 `a8d1293119b4f90b4339ef815c93c167e949ac1b5029f335032faabd77837987`。
对应本地归档 `Claurst-Tectonic-Sources-0.17.0-arm64-v5.tar.gz` 为 131,766,696 字节，
SHA-256 `4d4f67169743e4b4bff4f819a4469985de1d402b07cd6d73a281687585a1d097`。
全部 986 个归档成员与材料逐字节一致，路径无重复；尚未上传。

## 当前候选材料合并（2026-10-23）

已将 `candidate-mpGA4v` 的匹配源码、当前 Claurst/TeX collector 输出、上述 Tectonic v5、Rust 1.99.1 与 PSNFSS 完整作品合并为本地材料归档。6,220 个唯一归档成员逐文件大小与摘要核对通过；输入原件和历史未完成标记保持不变，另加当前源码及二进制关联。文件大小、SHA-256、组成和尚未满足的发布条件见 [当前候选材料](candidate-materials.md)。未上传，整体许可审查和第 18、19 项仍未完成。
