# 剩余字体、度量和转换资源的来源核对

2026-10-22。接续[固定 bundle 来源记录](latex-bundle-provenance.md)，本轮从已匹配的 351 个缓存数据文件以外选取剩余 65 个字体、度量和转换资源。它们是 36 个 TFM、28 个 PFB、1 个 TEC，没有剩余 OTF。本轮 **65/65 均与固定 TeX Live 提交逐字节相同**，累计来源匹配为 **416/421**。本记录不声称对应包全部许可材料或源码要求已完成，也不作分发兼容结论。

## 范围与核验方法

使用已有固定 `texlive.tlpdb`，其 SHA-256 为 `c518358e4c5f1f512bc67af18c8f0f60c264b1722f75551fda37462ffbf88822`。所有新下载使用 [TeX Live 提交 `082081a375be008c2e049cd7cf1137314f888b18`](https://git.texlive.info/texlive/commit/?id=082081a375be008c2e049cd7cf1137314f888b18)，即上轮确认的 `tags/texlive-2022.0@62885`；没有以当前 CTAN 文件替代固定版本。

先用既有 `verified-matches.json` 与字体 `sources.json` 去重，得到 70 个未匹配缓存名；其中 65 个扩展名为 TFM/PFB/TEC。本轮每项只有一条 tlpdb 候选路径。读取上限为每请求 512 KiB、45 秒、3 个并发，65 项均一次成功，合计 985,560 字节。下载后重新读取本地缓存，逐字节比较，并核对下载摘要等于缓存既有 SHA-256。没有下载完整 bundle 或字体发行包，没有编译或执行下载内容。

| 上游 tlpdb 包名 | 本轮匹配数 | 范围 |
| --- | ---: | --- |
| `amsfonts` | 37 | 28 个 Type 1 PFB、9 个 TFM |
| `cm` | 22 | Computer Modern TFM |
| `latex-fonts` | 4 | `lcircle10`、`lcirclew10`、`line10`、`linew10` 的 TFM |
| `zapfding` | 1 | `pzdr.tfm` |
| `xetex` | 1 | `tex-text.tec` |

上述包名和路径来自 tlpdb；内容匹配另由实际下载与缓存比较证明，二者不是同一种证据。完整逐项 URL 与摘要见本文最后的表格。

## 已取得的通知与源码入口

研究原件统一保存于 `.build-tools/third-party-inputs/bundle-v33-additional/texlive-fixed/`，其后保留原始 `texmf-dist/...` 路径。以下 12 份小文件全部按原字节保存，未替换其中作者、日期、许可版本或保留字体名；它们是可供根线程进一步核对、移入版本控制目录的原件。README、manifest、源码示例和许可全文的作用不同，不能把它们统一标成“完整许可证”。精确 URL 与 SHA-256 在下表。

| 包/用途入口 | 固定原件完整路径 | SHA-256 |
| --- | --- | --- |
| `amsfonts` | [texmf-dist/doc/fonts/amsfonts/OFL-FAQ.txt](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/fonts/amsfonts/OFL-FAQ.txt?id=082081a375be008c2e049cd7cf1137314f888b18) | `f1c022008dc7e763b1625c121ac50f4bf635179c809ca987af65e984659ce492` |
| `amsfonts` | [texmf-dist/doc/fonts/amsfonts/OFL.txt](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/fonts/amsfonts/OFL.txt?id=082081a375be008c2e049cd7cf1137314f888b18) | `aa783fdd47e92743bafe79277ac4067d20339344dc5b64a09c2d0f869b2999dc` |
| `amsfonts` | [texmf-dist/doc/fonts/amsfonts/README](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/fonts/amsfonts/README?id=082081a375be008c2e049cd7cf1137314f888b18) | `2e2ced3494d3e5f04345804b85c1acb67c23bdd742f3e71f8772f768a59ed451` |
| `amsfonts` | [texmf-dist/source/latex/amsfonts/manifest.txt](https://git.texlive.info/texlive/plain/Master/texmf-dist/source/latex/amsfonts/manifest.txt?id=082081a375be008c2e049cd7cf1137314f888b18) | `7fc17d6a09c16fe6e5b534c100687a99a4553ccaa4d1671cb4fe05d5d00d599d` |
| `cm` | [texmf-dist/doc/fonts/cm/README](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/fonts/cm/README?id=082081a375be008c2e049cd7cf1137314f888b18) | `df37bc99ee2ed981004fc36690f9dbd44045348ae1b63b7ef2894e5b02d0f1a5` |
| `cm` | [texmf-dist/doc/fonts/cm/README-cmps.txt](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/fonts/cm/README-cmps.txt?id=082081a375be008c2e049cd7cf1137314f888b18) | `8486ab502a86e9cfa29c87b4047f592a9e3e3ebb24a54acbdb34069d9da8c061` |
| `cm` | [texmf-dist/fonts/source/public/cm/cmr10.mf](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/source/public/cm/cmr10.mf?id=082081a375be008c2e049cd7cf1137314f888b18) | `32efefa5813c6d5a256ab3824a90f0a7a79688e872926db87e4510ef0f3ee382` |
| `latex-fonts` | [texmf-dist/doc/fonts/latex-fonts/README](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/fonts/latex-fonts/README?id=082081a375be008c2e049cd7cf1137314f888b18) | `22a3f6b41ae95c63ca9e4c535dd9b36894a7924759792ff80d1f15034875c46c` |
| `latex-fonts` | [texmf-dist/doc/fonts/latex-fonts/legal.txt](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/fonts/latex-fonts/legal.txt?id=082081a375be008c2e049cd7cf1137314f888b18) | `46e28d4efe2ca60abf46188adb7d536df5a59fa5d0d54879fe1968569698d70c` |
| `xetex` | [texmf-dist/doc/xetex/base/README](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/xetex/base/README?id=082081a375be008c2e049cd7cf1137314f888b18) | `28e4059f4a062cd8a71bfb7b136d2222086851c55cfa0332a87ed7594fe847ac` |
| `xetex` | [texmf-dist/fonts/misc/xetex/fontmapping/base/tex-text.map](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/misc/xetex/fontmapping/base/tex-text.map?id=082081a375be008c2e049cd7cf1137314f888b18) | `65a1cf61ec924a1a8b8494760586a098bbf68046f004339108556c6465f75ada` |
| `zapfding` | [texmf-dist/fonts/afm/adobe/zapfding/pzdr.afm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/afm/adobe/zapfding/pzdr.afm?id=082081a375be008c2e049cd7cf1137314f888b18) | `3328cb027cca61175005fa1fd56de4fe17f7d0cbea3a4a8bfff1b6da6439c70c` |

### 需要保留的材料差别

- **AMSFonts 不能只保留一个网页标签。** 固定 README 顶部写 LPPL 1.3c 或后续版本；其版本说明又明确区分 Type 1 字体及 AMS 原创 `.mf` 文件使用 OFL。取得的 `OFL.txt` 含 AMS 版权和保留字体名清单，不能以不带这些内容的通用 OFL 模板替代。固定 `manifest.txt` 提供分发文件范围；本轮没有取得完整 manifest 所列全部文件。[固定 README](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/fonts/amsfonts/README?id=082081a375be008c2e049cd7cf1137314f888b18)、[OFL 原件](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/fonts/amsfonts/OFL.txt?id=082081a375be008c2e049cd7cf1137314f888b18)。
- **Computer Modern 的 22 个 TFM 已定位，未据此归入 OFL。** tlpdb 将这些 TFM 分在 `cm`，其元数据写 `knuth`；读取的 `cmr10.mf` 源文件头保留原名修改限制，两个 README 主要是参数及映射说明。相应 METAFONT 路径见 `texmf-dist/fonts/source/public/cm/`，本轮只取 `cmr10.mf` 作为已确认源码入口，没有取得或重建这 22 项的完整输入集合。[固定 cmr10.mf](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/source/public/cm/cmr10.mf?id=082081a375be008c2e049cd7cf1137314f888b18)。
- **LaTeX 线条/圆圈字体有专用说明。** `legal.txt` 列出涉及的 METAFONT 文件、LPPL 1.2 或后续版本，并另有对 TFM 等忠实格式呈现的文字。应保留整份原件；对应源码位于 `fonts/source/public/latex-fonts/`，例如 `lcircle10.mf`、`lcirclew10.mf`、`line10.mf`、`linew10.mf` 及 `circle.mf`、`line.mf`。这些路径已在固定 tlpdb 出现，本轮没有逐项获取或重建它们。[固定 legal.txt](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/fonts/latex-fonts/legal.txt?id=082081a375be008c2e049cd7cf1137314f888b18)。
- **`pzdr.tfm` 的许可关联仍不足。** 它与固定 `fonts/tfm/adobe/zapfding/pzdr.tfm` 完全一致，属于 tlpdb 的 `zapfding`；该包元数据有 URW Base35/GPL 标签，但同时包含 Adobe 和 URW 两组文件。另取的 `fonts/afm/adobe/zapfding/pzdr.afm` 明确含 Adobe 版权、ITC 名称。仅凭包标签不能将该 Adobe TFM 宣称为已核实 GPL；本轮没有取得能充分说明此 TFM 分发条件的独立原件，也未重建 AFM→TFM 的转换。[固定 Adobe AFM](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/afm/adobe/zapfding/pzdr.afm?id=082081a375be008c2e049cd7cf1137314f888b18)。
- **`tex-text.tec` 的来源匹配与许可范围仍须分开。** 已匹配固定二进制，并取得同目录 `tex-text.map`；map 是明确的 TECkit 映射源码，但未发现它自身的版权/许可文件头，也未重新编译证明 `.tec` 由它生成。XeTeX README 仅把 README 自身声明为公有领域；不能据此扩展到映射资源，tlpdb 的 `x11` 标签也不能代替适用原件。[固定 map](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/misc/xetex/fontmapping/base/tex-text.map?id=082081a375be008c2e049cd7cf1137314f888b18)、[固定 XeTeX README](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/xetex/base/README?id=082081a375be008c2e049cd7cf1137314f888b18)。

这些记录涉及已匹配资源的事实和后续材料入口，不是对原件条款作适用性或兼容性裁定。

## 仍未完成的内容

字体比对结束时，五个未匹配数据文件是 `UnicodeData.txt`、`expl3-code.tex`、`language.dat`、`kanjix.map`、`pdftex.map`。前两份大文本先前完整读取超时；本轮随后改用压缩传输及 180 秒上限，从相同固定提交完整取回，实际分别耗时约 20 秒和 15 秒，逐字节与候选缓存一致：

| 文件 | 固定来源 | 字节数 | SHA-256 |
| --- | --- | ---: | --- |
| `UnicodeData.txt` | [固定提交原件](https://git.texlive.info/texlive/plain/Master/texmf-dist/tex/generic/unicode-data/UnicodeData.txt?id=082081a375be008c2e049cd7cf1137314f888b18) | 1897793 | `36018e68657fdcb3485f636630ffe8c8532e01c977703d2803f5b89d6c5feafb` |
| `expl3-code.tex` | [固定提交原件](https://git.texlive.info/texlive/plain/Master/texmf-dist/tex/latex/l3kernel/expl3-code.tex?id=082081a375be008c2e049cd7cf1137314f888b18) | 1204757 | `496aa058ffd3c379d77df9d842ae931575f1ea12db5f806cbeea1634d505b6a1` |

两份新增结果保存于 `.build-tools/third-party-inputs/bundle-v33-large-text/results.json`，且其来源与摘要已进入版本控制的 `third_party/tex-notices/sources.json`。因此当前累计为 **418/421**，仍缺 `language.dat`、`kanjix.map`、`pdftex.map` 三个生成配置的完整输入和生成关联；这些缺口没有因文件同名或字体匹配而自动计为完成。

418/421 只是缓存数据文件有可复核的逐字节上游对应；另外 5 个索引/记录/格式缓存不在这 421 项中。独立源码包、通知的完整性，`pzdr.tfm`/`tex-text.tec` 的具体许可原件，生成配置、`.fmt` 的输入关联，以及将材料正式纳入应用和公开包，仍须继续完成。已核对的 22 份固定 TeX Live 原件/源码入口现已保存于 [`third_party/tex-notices`](../../third_party/tex-notices/README.md)，收集器会核对实际候选内容并复制；这推进了材料保存，但不消除其余缺口。

## 本地研究记录摘要

- `verified-matches.json`：`b7bb4fddc7f557eb8f9a56c0d47d97322ad0a50b3280fb1eaa0698b3bef1fc92`。
- `download-results.json`：`43e4b560bc68769635e13a4e9ca92f935f8944e23a06d9db9dd9dad00dfe6e08`。
- `notice-results.json`：`9dc42b921167c455865088522f94a0ccd27b22072ee3fb9ecb27f5ed675da733`。
- `package-records.json`：`a8200e1b1a82281f1b33004d633de450189d7a98e0c01f7f83f0310c1f666ea4`。

路径均相对于 `.build-tools/third-party-inputs/bundle-v33-additional/`。根线程可从 `texlive-fixed/` 复制需要保留的原件，并使用这份记录中的 URL/摘要复核；研究目录尚不是公开发行材料目录。

## 65 项逐字节匹配清单

每条链接指向固定提交中的完整原始路径；SHA-256 同时适用于实际下载原件与本地缓存。所有项本轮均下载成功并完成完整内容比较。

| 缓存文件 | 上游包 | 固定原件完整路径 | SHA-256 |
| --- | --- | --- | --- |
| `cmex10.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmex10.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmex10.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `791b31aa1db8608d0144b3a40fc0fe53383a60f6b00d0e8fd9f06ac4a11df8cb` |
| `cmex10.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmex10.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmex10.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `0890bccea1dd4d27f001ac30e86c63af35bc803e0557c35aafb1903c8d208e92` |
| `cmex7.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cmextra/cmex7.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cmextra/cmex7.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `df327fc28dc3ce615dc91399f335ec2e1e646e34929936be16836875d5ffaf54` |
| `cmex7.tfm` | `amsfonts` | [texmf-dist/fonts/tfm/public/amsfonts/cmextra/cmex7.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/amsfonts/cmextra/cmex7.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `373172fe340e4aede5129b89d65f576bfb1fe6932bd55c38f60bcaa84f3d1188` |
| `cmex8.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cmextra/cmex8.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cmextra/cmex8.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `778a2aaea4bf9d19ce2a7342864fa2696c07770c86d36a62e2ef799ad0724b05` |
| `cmex8.tfm` | `amsfonts` | [texmf-dist/fonts/tfm/public/amsfonts/cmextra/cmex8.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/amsfonts/cmextra/cmex8.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `3f56ab22f7fc6a015813976c6c6cc2fd55736bbaec4958a4562e10719fa18062` |
| `cmex9.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cmextra/cmex9.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cmextra/cmex9.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `b7aacad3b24221cf6ccfedb08708444a00ded5d3f24c5cff79dcc4450d65ab16` |
| `cmex9.tfm` | `amsfonts` | [texmf-dist/fonts/tfm/public/amsfonts/cmextra/cmex9.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/amsfonts/cmextra/cmex9.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `70ca3442c95cd6cf3437ab7c2d0e4b9797531eacfe400dccc61d04bda288bae0` |
| `cmmi10.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmmi10.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmmi10.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `e3661061e8aa474d6de5ffa916edceb0e3d8b998862018c147f0357fce00bcd7` |
| `cmmi10.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmmi10.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmmi10.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `e442c5487f84df70218ff37f775c87060856f5b6e04c011b6cadbbadfcf46645` |
| `cmmi12.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmmi12.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmmi12.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `80fa6aa5f49d52e1f7e5120d053b32d463cd0392a68588ef17c0d1523fba7786` |
| `cmmi12.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmmi12.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmmi12.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `79563547084d85388e6909888f9fa7f5cad33bdda44ca6b25b362e1d301db539` |
| `cmmi5.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmmi5.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmmi5.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `35048e58e53f4aa53025069c1d0de33a16d8d4c111bfa329669e6456ec0a967b` |
| `cmmi5.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmmi5.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmmi5.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `8839e40838381a0a3c976bdd5becf72afd60bde5a965c3d9b985c3479c6cf75e` |
| `cmmi6.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmmi6.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmmi6.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `c31dbaffb861162eadf3a7210bdf271b0dda577841aed4c0572069b0d52662b6` |
| `cmmi6.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmmi6.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmmi6.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `ab6ecb4aaba9ca1b4259b1d1f64309a785bbaeb09183fd79a066b7764a448a28` |
| `cmmi7.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmmi7.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmmi7.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `5b293a581ddb937b02559c3ce1a60184cc434295533204a2cd3864a6ad8a1f53` |
| `cmmi7.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmmi7.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmmi7.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `ce55681703aae565f17286d800ea9780223132589bdbaeda1751b869aba26a38` |
| `cmmi8.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmmi8.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmmi8.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `f396f52d9ed3498c15aa7e694baef74c0a11119624fcd6db66dad4ac76972cb0` |
| `cmmi8.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmmi8.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmmi8.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `65af8c1e162a952cab8e93c834fcf43ce09b508e6c16e512ebb673cd850b0d41` |
| `cmmi9.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmmi9.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmmi9.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `c7d9ebe6b8313e0eeee8f9ed4d4e7069c74cfa9d9b64295f0f487e4662281a62` |
| `cmmi9.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmmi9.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmmi9.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `20672649a2f07eef8fe07ccb42eeb731023e48f2e0797ecef57c0887da46c032` |
| `cmr10.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmr10.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmr10.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `fdcede8794018df5f2b58f0905fb20a2b418ed8f67b73ee12445855dfbe5b1be` |
| `cmr10.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmr10.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmr10.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `87f2d8981927644cbecaf3d639e96e348ea4e7be49d8804468bd8ba9ff3f5244` |
| `cmr12.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmr12.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmr12.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `9b58bfa828b9553b7c8331cf26c45443b836f8aab62e820b40a5b65c8531dd42` |
| `cmr12.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmr12.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmr12.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `1ce8af37ed38e93940829d3540e494eaaddc5201758d036b9074467e70a738dc` |
| `cmr17.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmr17.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmr17.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `465827b4702e12f7deea159c8084753ffc27998963de516e490bd7bd5bed41dd` |
| `cmr17.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmr17.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmr17.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `86b6e8a52aae6ad1655e32099e12bd2904b158aba4c8afb74143266d2d9cd18f` |
| `cmr5.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmr5.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmr5.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `84d38aac226b5274baca7a292e2039f5284a35d8a2ae31074a475fad87da310b` |
| `cmr5.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmr5.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmr5.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `581be818f67bd11a1792d05e129abe3ea30c5cbdfce3bed8da7c5fb50f5ba95b` |
| `cmr6.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmr6.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmr6.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `9fe20cb9ef24a0f4c74d38a65d4eee5cff3165f3b8600407ceba396aeb2b7617` |
| `cmr6.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmr6.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmr6.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `106afa9172f0c00e58b9f5cbc72b302a18aaeeaddf50caca145af9cc0b81afd2` |
| `cmr7.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmr7.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmr7.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `b37e8671820b0753c6e233eaa3230c6ab9cff04e6c4baee312d60ae261e5aba1` |
| `cmr7.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmr7.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmr7.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `28f9f4d237bdae4babef4a59d90f17686a09d6f9df0b2c3c23b2ba15f20eee82` |
| `cmr8.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmr8.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmr8.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `8150cbfac5cfe53040327df171c3059f10730b32cabf2504b01713d639a11feb` |
| `cmr8.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmr8.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmr8.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `4c5ae243ac0aa254e7ec7f0602cc2a4351e5011ff0cb6dc150a5f6de19585de6` |
| `cmr9.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmr9.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmr9.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `ba5207eea69eaa9b598de2bd3d9aef27c4ff9831524400f70ff6a0dd3e36059b` |
| `cmr9.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmr9.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmr9.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `2ffa73e8446c1d46c3509a0f65ff97d4d09de46f48e1ce578a1004498b67dba9` |
| `cmsy10.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmsy10.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmsy10.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `62ee8cef552017551cd3e026a483e700730103eceaad959c87b7730017f59cff` |
| `cmsy10.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmsy10.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmsy10.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `0ca13d421ac7133271aed7c935099ecf3d1d08ac9e15f81acb34a16564ab8a46` |
| `cmsy5.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmsy5.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmsy5.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `46da57e5a06866efa9a20f3dd350811b5d3279a5ae789af63e530f1f570e3c7f` |
| `cmsy5.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmsy5.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmsy5.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `6b7dc18cba9ca8996d7b146f1ed78d9227577b26248083310fec227692198ca5` |
| `cmsy6.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmsy6.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmsy6.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `73eed8a83a07d8ef04d240da22bce1fd3646074f46179e3677f4f42a542f20b6` |
| `cmsy6.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmsy6.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmsy6.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `137eb9f38f661c66309614066a7b5d63d8969d33aba0c9efee9f844a4ce65b50` |
| `cmsy7.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmsy7.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmsy7.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `583b65bd1857bffc2ab184fcb4aad4e70e12eb05c9ca9f1c58c9a00a86c8bccf` |
| `cmsy7.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmsy7.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmsy7.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `4f59bbf683e947c807158641621982dc83f55fec042fea7963d8ce9f9da98256` |
| `cmsy8.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmsy8.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmsy8.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `2313392f0f4cd974d9da5fb54a52feae126059759edc04a4e47e33ea6027418b` |
| `cmsy8.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmsy8.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmsy8.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `84c37f07ca360c41ad0a0fba7387d279d72457c69bdae03653208c683d8de6bc` |
| `cmsy9.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/cm/cmsy9.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/cm/cmsy9.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `8049871d56d74fe3f8f2375afbb1e59b149bf6835027b4a101051cfca1c1a779` |
| `cmsy9.tfm` | `cm` | [texmf-dist/fonts/tfm/public/cm/cmsy9.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/cm/cmsy9.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `b57c5c42a7991a004ee1b40b340d7bd12cc75ab0a6f7daf7a207827504f91712` |
| `lcircle10.tfm` | `latex-fonts` | [texmf-dist/fonts/tfm/public/latex-fonts/lcircle10.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/latex-fonts/lcircle10.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `f5aaff47e226ff644ae94765b8d6012e0ffb6d62956993acac2f2dd4ad589929` |
| `lcirclew10.tfm` | `latex-fonts` | [texmf-dist/fonts/tfm/public/latex-fonts/lcirclew10.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/latex-fonts/lcirclew10.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `7906e4c5d770db4002740cba4d8194281b06d6fe7edd9d9949b60a291b753646` |
| `line10.tfm` | `latex-fonts` | [texmf-dist/fonts/tfm/public/latex-fonts/line10.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/latex-fonts/line10.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `250200d9efa885fecff118d72e5239adacd0783ccb00c4fb96fa677708ce5217` |
| `linew10.tfm` | `latex-fonts` | [texmf-dist/fonts/tfm/public/latex-fonts/linew10.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/latex-fonts/linew10.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `925de632e8afb641692c58bf6c464fb1aa79782212523532590dd6b91b78c40f` |
| `msam10.tfm` | `amsfonts` | [texmf-dist/fonts/tfm/public/amsfonts/symbols/msam10.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/amsfonts/symbols/msam10.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `3b54bde5cb0e0bd071eea7bc702ed3a1a284f786779ef8e75b06eba4104bb9f2` |
| `msam5.tfm` | `amsfonts` | [texmf-dist/fonts/tfm/public/amsfonts/symbols/msam5.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/amsfonts/symbols/msam5.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `c800d1dfd533040219fcc06d52e0e00c2a20fb9b0039fe9f58ccec53fd003a9f` |
| `msam7.tfm` | `amsfonts` | [texmf-dist/fonts/tfm/public/amsfonts/symbols/msam7.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/amsfonts/symbols/msam7.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `719d100c110fa1cfae9ad0b63e6c21753f4980f925fa516c1a04961e206f69d5` |
| `msbm10.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/symbols/msbm10.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/symbols/msbm10.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `d2121de7e7c14490a2d352e3b62e62882d6c300235464bfa577e6055696e6e62` |
| `msbm10.tfm` | `amsfonts` | [texmf-dist/fonts/tfm/public/amsfonts/symbols/msbm10.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/amsfonts/symbols/msbm10.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `d9f5f519ec718e9dbccb8527c1f5d3b4a008dfb946377f97f71611b385d3d010` |
| `msbm5.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/symbols/msbm5.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/symbols/msbm5.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `4504066336bdfacd4a5ef1abfe80b8447ed712057ec6f66962eab31eb43a93de` |
| `msbm5.tfm` | `amsfonts` | [texmf-dist/fonts/tfm/public/amsfonts/symbols/msbm5.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/amsfonts/symbols/msbm5.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `9e0909a297a3097e50960158d324006ddd5302db665400fa1fdf966df14e1a17` |
| `msbm7.pfb` | `amsfonts` | [texmf-dist/fonts/type1/public/amsfonts/symbols/msbm7.pfb](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/type1/public/amsfonts/symbols/msbm7.pfb?id=082081a375be008c2e049cd7cf1137314f888b18) | `bd86d36def0f2d226cf773a195a88f88e424759f3ddaaf654de2ae670906734e` |
| `msbm7.tfm` | `amsfonts` | [texmf-dist/fonts/tfm/public/amsfonts/symbols/msbm7.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/public/amsfonts/symbols/msbm7.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `361b5530a4b410c6274e9330c11e993843c62e394323aeaa6e0aee61e8042444` |
| `pzdr.tfm` | `zapfding` | [texmf-dist/fonts/tfm/adobe/zapfding/pzdr.tfm](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/tfm/adobe/zapfding/pzdr.tfm?id=082081a375be008c2e049cd7cf1137314f888b18) | `6b4254217851e285d1d5c6dfe677284396eeffc59f709ad775404b76dc99d513` |
| `tex-text.tec` | `xetex` | [texmf-dist/fonts/misc/xetex/fontmapping/base/tex-text.tec](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/misc/xetex/fontmapping/base/tex-text.tec?id=082081a375be008c2e049cd7cf1137314f888b18) | `511836c4d363daffa1c789956bdb44b89ac526ef3e4215a846c313b717447d40` |
