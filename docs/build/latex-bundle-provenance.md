# 固定 LaTeX bundle 的来源核对

2026-10-22。本记录补充固定 bundle 的上游关联、逐文件比对与许可原件入口，不是完整分发材料，也不作许可证兼容结论。研究下载保存在 `.build-tools/third-party-inputs/bundle-v33-research/`，尚未嵌入候选应用或公开发布包。

后续核对及材料保存进展见[剩余资源记录](latex-remaining-resource-provenance.md)：其余 65 项字体/度量/转换文件及两份先前超时的大文本已匹配；当前累计 418/421，原件与来源清单已部分纳入版本控制。下文保留本批次的实际结果与当时缺口。

## 已证实的版本关联

当前 bundle 的元数据仍是 `SVNREV=62885`、`GITHASH=082081a375be008c2e049cd7cf1137314f888b18`，与此前按字节范围取得的两项原件一致。此前访问的是错误的 Git 仓库：这个 GITHASH 属于构建输入的 TeX Live 镜像，不属于 Tectonic 引擎或 bundle builder 自身。

直接读取 [TeX Live 镜像的该提交](https://git.texlive.info/texlive/commit/?id=082081a375be008c2e049cd7cf1137314f888b18) 已获得以下内容：

- 提交日期为 2022-04-03，标题为 `texlive-2022.0 tag based on r62882`。
- tree 为 `f991cb0aa718eda3e63b856228c8e3e07d8c5b83`。
- `git-svn-id` 指向 `svn://tug.org/texlive/tags/texlive-2022.0@62885`。因此 r62885 是这一标签提交的修订号，不应改称全部文件最后修改于 r62885。

这与 [2022 年的官方 bundler README](https://github.com/tectonic-typesetting/tectonic-texlive-bundles/blob/8710e253efcde4e84c3d2ba8a54db2d85bc27fb0/README.md) 描述的 `git.texlive.info/texlive` 输入仓库相符。[`get_repo_version()`](https://github.com/tectonic-typesetting/tectonic-texlive-bundles/blob/8710e253efcde4e84c3d2ba8a54db2d85bc27fb0/scripts/ttb_utils.py) 从 `/state/repo` 读取 Git HEAD 与 `git-svn-id`，而 [`make-installation.py`](https://github.com/tectonic-typesetting/tectonic-texlive-bundles/blob/8710e253efcde4e84c3d2ba8a54db2d85bc27fb0/scripts/make-installation.py) 将二者写入 GITHASH/SVNREV。[同一历史提交的 bundle 定义](https://github.com/tectonic-typesetting/tectonic-texlive-bundles/blob/8710e253efcde4e84c3d2ba8a54db2d85bc27fb0/bundles/tlextras/bundle.toml) 写明 `tlextras`、`2022.0r0`。

`8710e253…` 是本次读取的官方历史源码快照；本记录没有得到生成线上整个归档时 builder HEAD 的独立证明，不能把它说成已认证的完整构建提交。下述三个文件与该快照相同，是逐文件证据。

## 本次实际比较范围

先重新计算 `.build-tools/tectonic-cache-v33` 内文件摘要，原 `inspection-12ebfce/inventory.json` 的 **426 项全部相同**。其中 421 项位于 bundle 的文件数据目录；另 5 项为索引、prefetch/lock/URL 记录及生成的 LaTeX 格式缓存，不能全部称为 426 个上游宏包文件。

从固定 TeX Live 提交取得 [Master/tlpkg/texlive.tlpdb](https://git.texlive.info/texlive/plain/Master/tlpkg/texlive.tlpdb?id=082081a375be008c2e049cd7cf1137314f888b18)，大小 15,844,622 字节，SHA-256 为 `c518358e4c5f1f512bc67af18c8f0f60c264b1722f75551fda37462ffbf88822`。它提供文件原始路径与包记录，而不是仅凭 basename 猜包名。本次排除 OTF/TFM/PFB/TEC，选择 303 个缓存文件名的 312 条候选路径；路径重复时分别比较，未把同名异内容计入匹配。

结果是 **296 个文件与固定 TeX Live 提交字节相同**，另 **3 个文件与官方 bundler 历史源码字节相同**，合计 299 个文件。逐项记录在研究目录 `verified-matches.json`，包括缓存名、包名、固定源码路径、URL 和 SHA-256；已重新逐字节比较保存的源码与缓存。完整原始请求结果在 `download-results.json`，重试与新增通知在 `remaining-results.json`。

统计口径：303 个 tlpdb 候选缓存名包含 `latex.ltx` 和 `l3backend-xetex.def` 两个补丁文件，所以分为 296 个直接匹配、2 个补丁匹配、5 个未完成匹配。`tectonic-format-latex.tex` 没有 tlpdb 候选，是额外核对的第 304 个文件。因此本轮总数为 299 个匹配、5 个未完成匹配，后文的五项缺口没有少计或多计。

研究证据文件摘要：`verified-matches.json` 为 `1f2283e00d4127d89461fc87832210ed858e270f171d6213d5a478ec0c311415`；`download-results.json` 为 `11de6425cec88afa91ee68ef1d03f74054b1ad72a7c29f8492e99cbd7730acb8`；`remaining-results.json` 为 `a9adfcb6d0d23fd4c63a5aa3621b8324e04372e62712d29db2e90655fd0fcbe3`。若研究目录丢失，可按固定 tlpdb 中的路径，从 `https://git.texlive.info/texlive/plain/Master/<文件路径>?id=082081a375be008c2e049cd7cf1137314f888b18` 重新取得内容，与当前候选清单的对应 SHA-256 比较；必须重新确认摘要，不能只依赖包名或版本标签。

296 个 TeX Live 匹配文件中，有 172 项来自 `hyphen-*` 包，包括模式、加载器及 `hyphen-base` 文件；另有 LaTeX base 32 项、ctex 11 项、amsmath 5 项、hyperref 5 项、graphics 4 项、dehyph-exptl 4 项、fontspec 3 项、xeCJK 3 项、unicode-data 3 项等。这里的数量只是文件来源匹配，**不是已核完对应包全部许可或全部源码材料的数量**。

这 299 项与既有 Fandol/Latin Modern 53 项记录有 `ts1lmr.fd` 一项重叠；去重合计为 351 个缓存数据文件有字节匹配证据。不能直接相加成 352，也不能据此宣称 351 项均已满足公开分发条件。字体既有记录见 [`third_party/font-notices/sources.json`](../../third_party/font-notices/sources.json)。

### Tectonic 特有或补丁文件

| 缓存文件 | 精确来源 | SHA-256 |
| --- | --- | --- |
| `latex.ltx` | [bundles/tlextras/patched/latex.ltx](https://github.com/tectonic-typesetting/tectonic-texlive-bundles/blob/8710e253efcde4e84c3d2ba8a54db2d85bc27fb0/bundles/tlextras/patched/latex.ltx) | `70ba1d0d113a986e4966e5a7ebb5afa3fbb17843ec4395bd0187d2aa266b5646` |
| `l3backend-xetex.def` | [bundles/tlextras/patched/l3backend-xetex.def](https://github.com/tectonic-typesetting/tectonic-texlive-bundles/blob/8710e253efcde4e84c3d2ba8a54db2d85bc27fb0/bundles/tlextras/patched/l3backend-xetex.def) | `47e2f4fc8bda65ba3f5d295145da3f7bb783b71f2a07f11a4038e84b2fd5cd13` |
| `tectonic-format-latex.tex` | [bundles/tlextras/extras/tectonic-format-latex.tex](https://github.com/tectonic-typesetting/tectonic-texlive-bundles/blob/8710e253efcde4e84c3d2ba8a54db2d85bc27fb0/bundles/tlextras/extras/tectonic-format-latex.tex) | `86d8d12cfdfbe74a81b9df7c5b38a766303a772d57e7cb0d228e1e7b9294cf34` |

GitHub 连接器返回的 base64 按原字节保存，并核对 Git blob SHA。前两项不等于 TeX Live 原文件：本地差异显示 `latex.ltx` 将等待终端输入的缺失文件流程改为报错，`l3backend-xetex.def` 将执行 `extractbb --version` 改为已知版本常量。差异保存在研究目录的同名 `.patch` 文件。官方 [`ZipMaker.go()`](https://github.com/tectonic-typesetting/tectonic-texlive-bundles/blob/8710e253efcde4e84c3d2ba8a54db2d85bc27fb0/scripts/ttb_utils.py) 正是先加入 extras/patched，再跳过安装树中的同名补丁文件。这不是本项目新写的补丁，也不能用 builder 根目录的 MIT 说明覆盖宏包原有通知。

## 已取得的非字体通知与材料入口

以下十份原件均来自同一固定 TeX Live 提交，保存于研究目录 `texlive-fixed/` 下的原始路径。URL 和 SHA-256 同时保存在 `remaining-results.json`；这些文件不在本次缓存匹配计数内。其内容用于定位原文，不是对整个候选包的法律判断。

| 材料 | 固定源码原件 | SHA-256 |
| --- | --- | --- |
| LaTeX base 版权与分发说明 | [doc/latex/base/legal.txt](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/latex/base/legal.txt?id=082081a375be008c2e049cd7cf1137314f888b18) | `a258aa1193a2012f9deb25c7c09507b0744b97875cc80ddf11a975919fa0ce20` |
| LaTeX base 的 LPPL 1.3c 原文 | [doc/latex/base/lppl.txt](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/latex/base/lppl.txt?id=082081a375be008c2e049cd7cf1137314f888b18) | `ca3227f672053cb608959d7e1d476c7a13efea11be3f6e53758a68b650c918e8` |
| LaTeX base 文件清单 | [doc/latex/base/manifest.txt](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/latex/base/manifest.txt?id=082081a375be008c2e049cd7cf1137314f888b18) | `b908af23074df86c49155ef1f34cef412bcbcef26a34d4f17683f52d9fdcd75b` |
| ctex 的包组成与通知 | [doc/latex/ctex/README.md](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/latex/ctex/README.md?id=082081a375be008c2e049cd7cf1137314f888b18) | `0156e6b4e5161e6deb1926f157598273dd2469f5c821af396046c797e565a38b` |
| xeCJK 的包组成与通知 | [doc/xelatex/xecjk/README.md](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/xelatex/xecjk/README.md?id=082081a375be008c2e049cd7cf1137314f888b18) | `441286cddfc31178aa16e23c126e6583dfb64c26e9df4dab63712a9efe4a97d9` |
| fontspec 许可原文 | [doc/latex/fontspec/LICENSE](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/latex/fontspec/LICENSE?id=082081a375be008c2e049cd7cf1137314f888b18) | `5f05fcf6ef25a6c31bccd2df7c0c46b23107bbeb2ce5cdba74efb5cc357f4dbb` |
| Unicode 宏包与数据分别适用的通知 | [doc/generic/unicode-data/README.md](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/generic/unicode-data/README.md?id=082081a375be008c2e049cd7cf1137314f888b18) | `39648292bbef208400943776a75c2483c49e2886450bd717d014cf72408f5924` |
| CJK 包携带的 GPL v2 原文 | [doc/latex/cjk/doc/COPYING](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/latex/cjk/doc/COPYING?id=082081a375be008c2e049cd7cf1137314f888b18) | `c4120c6752c910c299e3bd9cb3a46ff262c268303ca2069b61f92f10a5656c18` |
| hyph-utf8 生成工具说明 | [source/generic/hyph-utf8/README](https://git.texlive.info/texlive/plain/Master/texmf-dist/source/generic/hyph-utf8/README?id=082081a375be008c2e049cd7cf1137314f888b18) | `16c8d814c9917bc21b751d1e0b01f277edc169f679e59a8716347cfe7018502c` |
| hyph-utf8 发行布局说明 | [doc/generic/hyph-utf8/hyphenation-distribution.tex](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/generic/hyph-utf8/hyphenation-distribution.tex?id=082081a375be008c2e049cd7cf1137314f888b18) | `b5b93889ec91010a1ff0ef2b442a47bf0871add1e3c612fd538d9c98ea671e2f` |

需要保留原文中的细分：Unicode README 将宏包说明和 Unicode 数据通知分开；CJK 的 `CJKfntef.sty` 自身文件头写 GPL v2 或后续版本；hyph-utf8 的语言文件并非统一许可。已匹配的 `hyph-en-us.tex` 保留本文件的复制/分发通知，`hyph-de-1996.tex` 带 MIT 文本，`hyph-ru.tex` 标示 LPPL 1.2 或后续版本，`loadhyph-ru.tex` 又有生成器与自由使用/修改/分发说明。因此不能仅用 tlpdb 的单个 `catalogue-license` 标签替代这些文件头。[美国英语模式](https://git.texlive.info/texlive/plain/Master/texmf-dist/tex/generic/hyph-utf8/patterns/tex/hyph-en-us.tex?id=082081a375be008c2e049cd7cf1137314f888b18)、[德语模式](https://git.texlive.info/texlive/plain/Master/texmf-dist/tex/generic/hyph-utf8/patterns/tex/hyph-de-1996.tex?id=082081a375be008c2e049cd7cf1137314f888b18)、[俄语模式](https://git.texlive.info/texlive/plain/Master/texmf-dist/tex/generic/hyph-utf8/patterns/tex/hyph-ru.tex?id=082081a375be008c2e049cd7cf1137314f888b18)。

## 尚未证实及下一步

1. **两份大文本未完成来源字节比对**：固定提交的 `UnicodeData.txt` 和 `expl3-code.tex` 连续两次读取超时；收到的局部内容不计匹配。缓存文件自身未变。`pdftex.map` 也超时，且缓存文件头已表明它是安装时生成的配置，不能用超时结果判断其内容是否相同。
2. **三个生成配置仍需完整输入关联**：`language.dat`、`kanjix.map`、`pdftex.map` 的缓存文件头分别指向 tlmgr/updmap 生成过程；前两项已取得的同名静态文件不同。来源规则可定位，但本次没有重建生成过程或证明所有组成输入，因此保持未匹配。保存的文件头含 `/state/installs/tlextras-2022.0r0/`，这是上游路径，不是本机用户目录。
3. **完整源码材料仍须按包补齐**：例如固定 tlpdb 已列出 `texmf-dist/source/latex/base/*.dtx`、`source/latex/fontspec/*.dtx`、`source/latex/ctex/ctex.dtx`、`source/xelatex/xecjk/xeCJK.dtx` 及 hyph-utf8 生成器路径。取得运行文件和通知不等于已取得原文所指的整个作品；本次没有下载整个包、所有源码或整个 TeX Live 归档。`legal.txt`、manifest 与每包 README 是继续确定材料范围的直接入口。
4. **其余字体、度量和转换资源继续沿既有清单核对**：本次未扩展下载 OTF/TFM/PFB/TEC，也未改变既有字体材料结论。格式 `.fmt` 是本地生成缓存，须关联编译器、输入及可重复生成流程，不能给它虚构一个上游原始文件地址。
5. **正式保存与打包尚未完成**：应把经核对且实际需分发的原件及逐文件来源清单移入版本控制的材料目录，并让收集器验证实际候选包的文件摘要；研究目录中的下载和本记录本身不能充当已嵌入应用的通知包。

官方 builder 的过滤逻辑会忽略若干 README/许可文件名，并以 basename 扁平化文件；它还用文件名及各内容摘要计算 bundle 标识。`6ffe0558…` 因此是这套构建规则中的内容集合标识，不能在未下载整个 tar 的情况下宣称已验证 2.88 GB tar 的 SHA-256。[过滤与摘要算法](https://github.com/tectonic-typesetting/tectonic-texlive-bundles/blob/8710e253efcde4e84c3d2ba8a54db2d85bc27fb0/scripts/ttb_utils.py)。

没有下载完整 bundle，没有访问凭据，也没有将这次调查当成公开发布放行。
