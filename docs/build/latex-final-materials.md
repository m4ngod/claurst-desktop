# 排版材料最后一组来源核对

2026-10-22。接续[固定 bundle 来源](latex-bundle-provenance.md)和[剩余字体与转换资源](latex-remaining-resource-provenance.md)。本轮针对候选 `build-mHHoqi` 的三个生成配置、`pzdr.tfm`、`tex-text.tec`，并有限检查 Latin Modern 2.005 与 Fandol 0.3 的可修改源码入口。没有运行下载的代码、重建 TeX Live、修改应用或第三方 catalog，也没有重启既有宏包采集。

三个生成配置现均有**固定上游原件、精确变换和全文件字节相等证明**。这与“直接从上游取得相同文件”是不同分类：此前材料已有 418/421 个缓存数据文件的原字节匹配；本轮为其余 3 项补充变换关联。不能据此将结果写成“421 个未修改上游文件”，也不能将来源关联数量当成许可审查完成数量。`tex-text.tec` 新取得同字节的官方源码树副本、映射源码、上游编译比较测试和完整项目通知；`pzdr.tfm` 的独立许可原件、两组字体的准确首选可修改形式仍有明确缺口。

## 固定对象与机器清单

研究根目录为 `.build-tools/third-party-inputs/tex-final-provenance/`，下文称 `R`。候选来源是 `.build/desktop-builds/build-mHHoqi/Claurst Desktop.app/Contents/Resources/latex/cache/bundles/data/6ffe055852f8faf66c0acbe1a7fb27f87b869a90bad1204f3bf4d9683f597c7c/`。每个候选的完整原路径、字节数及 SHA-256 见 `R/candidate-files.json`，实际比较副本在 `R/candidate/`。

TeX Live 固定为提交 [`082081a375be008c2e049cd7cf1137314f888b18`](https://git.texlive.info/texlive/commit/?id=082081a375be008c2e049cd7cf1137314f888b18)，对应 `tags/texlive-2022.0@62885`。既有 `bundle-v33-research/texlive.tlpdb` 为 15,844,622 字节，SHA-256 `c518358e4c5f1f512bc67af18c8f0f60c264b1722f75551fda37462ffbf88822`。本轮固定原件 URL 格式均为 `https://git.texlive.info/texlive/plain/Master/<path>?id=082081a375be008c2e049cd7cf1137314f888b18`，实际 URL 逐项保存在收据。

| 清单/产物 | 内容与使用方式 |
| --- | --- |
| `R/generated-configs.json` | 三份原件、额外输入、候选及结果摘要，逐行旧值/新值、映射块起始行/长度/摘要、删除及替换配方、已验证的 `byte_equal` 和局限 |
| `R/reconstruct-configs.py` | 本项目编写的纯本地文本变换校验脚本；不执行上游代码，不联网；当前运行对三份完整结果均断言字节相等 |
| `R/reconstructed/` | 三份实测完整结果；不能伪装成上游原件 |
| `R/download-results*.json` | 固定 URL、有效 URL、状态、字节数、SHA-256；失败保留具体 HTTP 状态 |
| `R/xetex-files.json` | 固定 XeTeX 文件的 URL、Git blob SHA-1、文件 SHA-256，以及根 `COPYING` 的符号链接关系 |
| `R/pzdr-metric-comparison.json` | TFM 与 AFM 的 188 个编码字符宽度比较，含每项数值与限制 |
| `R/fandol-maintainer-statement.json` | 作者说明旧 Git 项目被删除的原始公开评论和永久链接 |

`generated-configs.json` 是可交给收集器的事实输入，尚未由本轮改动接入正式输出。原件与生成结果分开保存，全部留在 `R`；既有 `tex-package-sources` 目录未被修改。

关键机器清单的 SHA-256：`generated-configs.json` 为 `8f857edc34c1fa98988f225b04923e135dfd237f2f71d3b63294ab1f54ca22fc`，`xetex-files.json` 为 `0158c13ce8e5b09645af2b5ac047599e7eb3887c1e32e93cb69dc93fcf0370ff`，`pzdr-metric-comparison.json` 为 `89035a5b244a6e20e7adec9797e2f252df34fc86c578287a010159ad1ad00240`。`R/research-inventory.json` 提供研究文件逐项摘要。成功 curl 下载合计 5,312,001 字节，另有小型 GitHub 源文件/元数据；本轮远低于 80 MB 上限，没有整体 bundle 下载，失败入口未无限重试。

## 三个配置的精确关联

| 文件 | 固定原件字节数 / SHA-256 | 候选与重建结果字节数 / SHA-256 |
| --- | --- | --- |
| [`language.dat`](https://git.texlive.info/texlive/plain/Master/texmf-dist/tex/generic/config/language.dat?id=082081a375be008c2e049cd7cf1137314f888b18) | 6,663 / `8fd7610b40feddf2e0ac3eb4e97a881f747a5e6806aa8c1b781f41348dbe4d5f` | 6,593 / `a8a8e36e120beb9a19ffc2ca7c83445a1308ac9602a50cab1128deac14f5bee9` |
| [`kanjix.map`](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/map/dvipdfmx/updmap/kanjix.map?id=082081a375be008c2e049cd7cf1137314f888b18) | 11,907 / `0b43cf0f60bf9fdcda08451747a437b12c1dd0b5d613cef172fdd30677f37afb` | 11,946 / `a71059fc7213517c40d9d9ee353b107dc5b8dc20e5b4c10fb0c7414879c8a1ed` |
| [`pdftex.map`](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/map/pdftex/updmap/pdftex.map?id=082081a375be008c2e049cd7cf1137314f888b18) | 4,385,071 / `cf58c723b655853bad23dc2a202b3a030fdd1e3c6dce2f0e6530e3c7a53d122d` | 4,408,061 / `16bbb011215db3c7b919e0274bf1a95dc478e6b3712b9cb478149551e0820a6d` |

### `language.dat`

固定文件共 218 行，仅前两行不同。第 1 行的生成程序路径/时间从 `/home/texlive/karl/Master/bin/x86_64-linux/tlmgr`、2022-03-17，变为 `./bin/x86_64-linux/tlmgr`、2022-09-19；第 2 行从展开的 `language.us` SVN `$Id` 变为未展开的 `$Id$`。其余所有字节相同。旧值、新值和 LF 均完整记在机器清单，替换后全文件 SHA 与候选一致。

固定 [`TLUtils.pm`](https://git.texlive.info/texlive/plain/Master/tlpkg/TeXLive/TLUtils.pm?id=082081a375be008c2e049cd7cf1137314f888b18) 的 `create_language_dat`（约 3351 行）读取 `language.us` 头部与 `tlpdb->language_dat_lines`，`_create_config_files` 写入程序名和本地时间。[`TLPDB.pm`](https://git.texlive.info/texlive/plain/Master/tlpkg/TeXLive/TLPDB.pm?id=082081a375be008c2e049cd7cf1137314f888b18) 和 [`TLPOBJ.pm`](https://git.texlive.info/texlive/plain/Master/tlpkg/TeXLive/TLPOBJ.pm?id=082081a375be008c2e049cd7cf1137314f888b18) 将包的 AddHyphen 数据转换为语言/模式文件名及别名。固定 [`language.us`](https://git.texlive.info/texlive/plain/Master/texmf-dist/tex/generic/config/language.us?id=082081a375be008c2e049cd7cf1137314f888b18) 也实际带未展开的 `$Id$`。这些原件支持生成过程说明；本轮只验证两行差异，没有声称重放当年的安装数据库与时钟。

这些生成器原件的 SHA-256 分别为：`TLUtils.pm` `c9d0badb66ae81d306cdffb2a3fe5f9ad91beed2605dcefb7f681ad72de6ec4a`；`TLPDB.pm` `aa1060c7e82650c43e846506322a916c78b5364c1f9a17fc0473ff40b8841c96`；`TLPOBJ.pm` `34696ec8d75b63402e52dd956adc4914eda5816ea8d4a4cc2664b3b290a6ec1c`；`language.us` `96d9365138593e917350f2baddfabc94a2249cd984e5da881e410efd58a97b63`。本轮所有生成器都按原字节保存在 `R/upstream/Master/` 后接其原始路径。

### `kanjix.map`

固定文件共 235 行，仅第 1、6 行的输出文件/日志路径不同。候选路径均以 `/state/installs/tlextras-2022.0r0/texmf-dist/` 开头，分别指向 `fonts/map/dvipdfmx/updmap/kanjix.map` 和 `web2c/updmap.log`；正文没有变化。

固定 [`updmap.pl`](https://git.texlive.info/texlive/plain/Master/texmf-dist/scripts/texlive/updmap.pl?id=082081a375be008c2e049cd7cf1137314f888b18) 在约 1145–1154 行写该六行头部，再以活动 KanjiMap 输入生成内容。Tectonic bundler 快照 [`8710e253efcde4e84c3d2ba8a54db2d85bc27fb0`](https://github.com/tectonic-typesetting/tectonic-texlive-bundles/tree/8710e253efcde4e84c3d2ba8a54db2d85bc27fb0) 的 [`make-installation.py`](https://github.com/tectonic-typesetting/tectonic-texlive-bundles/blob/8710e253efcde4e84c3d2ba8a54db2d85bc27fb0/scripts/make-installation.py)、[`ttb_utils.py`](https://github.com/tectonic-typesetting/tectonic-texlive-bundles/blob/8710e253efcde4e84c3d2ba8a54db2d85bc27fb0/scripts/ttb_utils.py) 和 [`tl-profile.txt`](https://github.com/tectonic-typesetting/tectonic-texlive-bundles/blob/8710e253efcde4e84c3d2ba8a54db2d85bc27fb0/bundles/tlextras/tl-profile.txt) 定义该安装根以及 `TEXMFSYSCONFIG/TEXMFSYSVAR=@dest@/texmf-dist`，路径与实测一致。此对应支持来源链，但没有新发现能独立证明线上归档恰好由该 builder Git HEAD 生成的签名构建记录。

`updmap.pl` 为 87,501 字节，SHA-256 `d5f9f8d110babe10c37b4edb4c885da98d3466b33e546d4bb8ed24f9136a60a8`。`R/bundler-inputs.json` 保存本轮取得的 builder 文件 GitHub 回执；`ttb_utils.py` 复用此前 `bundle-v33-research/bundler-8710e253/scripts/ttb_utils.py` 的原件。

### `pdftex.map`

本轮重新取得**完整 4,385,071 字节**的固定原件；先前研究目录中的 1,114,112 字节截断下载不能作为此项基线。新的成功收据为 `R/download-results.json` 中同路径条目。

按行首 `% <name>.map` 分块，固定文件有 368 块，候选有 363 块。候选中 **362 块与固定文件相同**；另一个 `XCharter.map` 块可由同一固定提交的实际映射输入生成。精确全文件配方为：

1. 与 `kanjix.map` 类似替换第 1、6 行；第 1 行保留 `pdftex_dl14.map` 名称。
2. 删除固定文件中候选没有的五块：`SkakNew.map`（6 行，289 字节）、`mxedruli.map`（6 行，196 字节）、`omega.map`（38 行，1,627 字节）、`original-context-symbol.map`（4 行，134 字节）、`troff-updmap.map`（2 行，51 字节）。机器清单保存每块原始起始行和 SHA-256。
3. 将固定文件旧 `XCharter.map` 块（42,121 字节，SHA-256 `45af64c942d2c62418645bab6c64572343d09bf362b390196c0cbd7b9fbee70d`）替换成由 [`fonts/map/dvips/xcharter/XCharter.map`](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/map/dvips/xcharter/XCharter.map?id=082081a375be008c2e049cd7cf1137314f888b18) 得出的新块。原始输入为 66,515 字节，SHA-256 `f883b33251b324eab91780b2695a806eb49cea0d53d80b930c930f01b1f61610`。去掉空行及注释行，按 TeX 字体名排序，用 `updmap.pl` 的 `getFonts/normalizeLines` 规则处理空白与引号并稳定去重，加入块标题。结果为 67,369 字节，SHA-256 `39a71e87d5adea2290f9d15d221705d4e96811b8658803b13c80505e240dfb18`，与候选该块完全一致。机器清单逐步保存了这些规则，另存 `R/normalized-XCharter.map`。

最终结果和候选 **4,408,061 字节逐字节相等**。固定生成脚本的 `to_pdftex` 因 `pdftexStripEnc=0` 不再改写此输入；`setupSymlinks` 则解释 `pdftex.map` 使用 `pdftex_dl14.map` 的输出。以上是明确的字节关联，不是对未知历史过程的猜测性“重建成功”。五个删块的集合和头部时间来自候选观察；当年的已安装包数据库、全部本地 updmap 配置及 `updmap.log` 尚未取得，因此仍不能断言包为什么被省略。生成 map 中每个字体/映射片段的通知也不能统一套用 `updmap.pl` 的许可。

## `tex-text.tec`：官方源码树、编译测试与通知

官方 [TeX-Live/xetex](https://github.com/TeX-Live/xetex) 固定提交 `bc89c789954895be24c4ca0a042a5d5a184db566`（2020-01-20，版本 0.999992）包含以下已取得原件。GitHub 连接器 base64 内容按原字节保存，并核对 Git blob SHA-1；文件 SHA-256 和精确 URL 保存于 `R/xetex-files.json`。

| 原件 | 实际验证 |
| --- | --- |
| [`source/libs/teckit/tex-text.tec`](https://github.com/TeX-Live/xetex/blob/bc89c789954895be24c4ca0a042a5d5a184db566/source/libs/teckit/tex-text.tec) | 398 字节，`511836c4d363daffa1c789956bdb44b89ac526ef3e4215a846c313b717447d40`；与候选及固定 TeX Live 副本相同 |
| [`source/libs/teckit/tex-text.map`](https://github.com/TeX-Live/xetex/blob/bc89c789954895be24c4ca0a042a5d5a184db566/source/libs/teckit/tex-text.map) | 802 字节，`65a1cf61ec924a1a8b8494760586a098bbf68046f004339108556c6465f75ada`；与此前固定 TeX Live 映射源码相同 |
| [`source/libs/teckit/teckit.test`](https://github.com/TeX-Live/xetex/blob/bc89c789954895be24c4ca0a042a5d5a184db566/source/libs/teckit/teckit.test) | 128 字节，`0a7c8b82904d011d2347720daa754d470a712402d78370d9bba8fa422003ed37`；上游测试明确运行 `teckit_compile` 将该 `.map` 编成临时 `.tec`，再与仓库中的 `.tec` 比较 |
| [`source/libs/teckit/Makefile.am`](https://github.com/TeX-Live/xetex/blob/bc89c789954895be24c4ca0a042a5d5a184db566/source/libs/teckit/Makefile.am) | 1,678 字节，`7864a8ea36192e2a11b9e473aeec9f23490a9a9af56be3cc11e767b101b19dac`；将映射、编译结果和测试列为发行文件 |
| [`source/texk/web2c/xetexdir/COPYING`](https://github.com/TeX-Live/xetex/blob/bc89c789954895be24c4ca0a042a5d5a184db566/source/texk/web2c/xetexdir/COPYING) | 1,648 字节，`5bf166af469a06c013cb1c5613cdb54007eecb37c145b3ea71bb08bf34b474ff`；保留 SIL、Jonathan Kew 等原始版权与完整许可、免责及名称宣传限制 |

根 [`COPYING`](https://github.com/TeX-Live/xetex/blob/bc89c789954895be24c4ca0a042a5d5a184db566/COPYING) 实际是指向上述 `xetexdir/COPYING` 的符号链接；Git blob `8f26367d4d8851d1dce79744c2c02cf6cbe3d296` 对应 34 字节链接目标文本，**不是**跟随后 1,648 字节通知的 blob。机器清单保留此区别。

这把此前仅有 tlpdb `x11` 标签、README 和相邻 `.map` 的证据推进为“官方源码树中相同二进制 + 相同可编辑映射 + 显式生成比较测试 + 项目通知原件”。本轮没有执行该测试，映射文件仍没有独立许可文件头，`COPYING` 也要求查阅各文件通知；因此应保留项目级通知与其作用范围，不应改写成该单文件自带完整许可或以普通 MIT 模板代替原文。

## `pzdr.tfm`：度量关联已核对，授权原件仍缺

候选为 1,528 字节，SHA-256 `6b4254217851e285d1d5c6dfe677284396eeffc59f709ad775404b76dc99d513`，此前已与固定 [`fonts/tfm/adobe/zapfding/pzdr.tfm`](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/adobe/zapfding/pzdr.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) 相同。其 TFM 头明确记录 `FontSpecific`、`ZapfDingbats`。本轮读取同提交 [`pzdr.afm`](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/afm/adobe/zapfding/pzdr.afm?id=082081a375be008c2e049cd7cf1137314f888b18)，SHA-256 `3328cb027cca61175005fa1fd56de4fe17f7d0cbea3a4a8bfff1b6da6439c70c`；原件带 Adobe 1985/1987/1988/1989 版权、ITC 名称、1989-12-01 创建时间和版本 001.004。

自写读取器比较全部 188 个非负编码字符，TFM 与 AFM 的字符集合相同；全部宽度在 TFM 定点数精度内相符，最大误差为每 1000 em 单位的 `0.00046539306640625`。这支持明确的度量内容对应，**不等于**完整 AFM→TFM 生成命令重现，也不是适用许可证明。

Adobe 历史 Core14 AFM 的三个官方归档入口本轮均返回 HTTP 404：`https://www.adobe.com/devnet/font/pdfs/Core14_AFMs.zip`、`https://partners.adobe.com/asn/tech/type/fontinfo/Core14_AFMs.zip`、`https://www.adobe.com/content/dam/acom/en/devnet/font/pdfs/Core14_AFMs.zip`。没有从它们取得 `MustRead` 原件；没有用第三方转载文字或 URW 的 GPL 标签覆盖 Adobe 度量。TeX Live [`LICENSE.TL`](https://git.texlive.info/texlive/plain/Master/LICENSE.TL?id=082081a375be008c2e049cd7cf1137314f888b18) 本身也明确其包不受单一许可覆盖，包内法律声明才是最终原件。

下一步需要找到与此历史 Adobe AFM/TFM 对应的原始分发通知，或取得维护方对该具体文件的适用说明。另一个产品实现路径是评估移除/替换这一实际资源并重做字体测试；本研究没有实施该变更。

## 两组字体的首选可修改形式

**Latin Modern 2.005：仍未取得对应 METATYPE1 归档。** 已存的 [`README-Latin-Modern.TXT`](../../third_party/font-notices/lm-2.005/README-Latin-Modern.TXT) 标题写 2.005，但分发说明仍引用 `lm2.003mt1.zip` 和 METATYPE1 0.48y；不能据此推断这个旧文件名就是 2.005 的源码。2026-10-22 实取 [GUST 下载页](https://www.gust.org.pl/projects/e-foundry/latin-modern/download) 已列 2.007 的 TDS/OTF/Type 1 ZIP，未列 2.005 METATYPE1 归档；[旧项目页](https://www.gust.org.pl/projects/e-foundry/obsolete) 也没有给出此入口。对官方下载路径中 `lm2.003mt1.zip` 及版本替换假设 `lm2.005mt1.zip` 的一次请求均为 404。后者仅是待验证地址假设，绝不能写成已发现的官方文件。两次结果均保存，未扩大下载至新版字体来冒充固定版源码。下一步是从 GUST 的历史存档或维护者取得准确 2.005 源码及生成工具版本关联。

**Fandol 0.3：完整 OTF 发行包不等同于首选编辑工程已确认。** 当前 [CTAN 目录](https://mirrors.ctan.org/fonts/fandol/) 实际只有 8 个 OTF、README 和 COPYING；目录快照保存在 `R/upstream/indexes/fandol.html`。原始 [README](https://mirrors.ctan.org/fonts/fandol/README) 说明使用 FontForge/Inkscape 编辑轮廓并用 AFDKO 编译 OpenType，但没有提供对应工程目录或声明发行 OTF 就是作者首选可修改形式。作者 Clerk Ma 在 [2017-09-25 的官方项目评论](https://github.com/clerkma/ptex-ng-dist/issues/5#issuecomment-331943498) 说明旧 Git 项目因更新大量内容不便而删除；该评论证实历史项目的去向，不能证明任意第三方镜像与 0.3 完全对应。本轮没有把第三方镜像导出物列为已核实官方源码。下一步需取得作者保留的 0.3 工程及构建说明，或关于首选可修改形式的明确声明。

## 可直接移交的材料与剩余边界

收集器可以先将 `generated-configs.json`、校验脚本、三份固定原件、同提交 `XCharter.map`、生成器相关原件和候选摘要一起封装，并把三项状态写成“精确变换关联”。XeTeX 的 `tex-text.map`、`tex-text.tec`、`teckit.test`、`Makefile.am` 和完整 `COPYING` 均在 `R/xetex-bc89c789/`，可按 `xetex-files.json` 原样移入正式来源材料。`pzdr.afm`、比较清单、失败收据可作为未闭合项证据保存，不能使许可状态自动通过。

本轮没有取得历史实际安装的 tlpdb/updmap 日志，没有为整个映射文件逐字体作许可判断，没有取得准确 LM 2.005 METATYPE1 工程或 Fandol 0.3 编辑工程，也没有得到 Adobe 该度量的独立授权原件。以上缺口各自具体；来源对应、可修改形式、通知原件和整体分发兼容性应分别记录。
