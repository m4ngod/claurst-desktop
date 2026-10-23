# 字体原样分发的可执行路径

2026-10-22。复核对象为已保存的 LM 2.005、Fandol 0.3、候选 `pzdr.tfm`，以及官方许可证原文。本记录纠正“所有未修改字体都必须找到设计源工程”的过宽前提；区分已验证事实、条款推断和待做工程验证，不作整个产品的法律保证。只新增本记录及独立研究材料，没有修改应用、collector、catalog 或 goal。

## 结论

| 对象 | 证据支持的发布路径 | 应撤销或保留的阻断 |
| --- | --- | --- |
| Latin Modern 2.005 | 保留原字节字体、完整原始 `lm.zip` 和通知；按 LPPL 的完整作品/安装产物路径组织交付 | **不应以没有独立 METATYPE1 归档为原样分发的硬性阻断**；仍须处理只交付缓存子集的作品完整性 |
| `pzdr.tfm` | 官方 PSNFSS 9.3 的完整作品包含相同 TFM，并有明确 LPPL 1.2 或后续版声明；可选择 1.3c 路径 | **不应再把失效 Adobe Core14 URL 视为这个 TFM 没有许可依据**；额外分发 Adobe AFM/PFB 是另一件事 |
| Fandol 0.3 | 如果 OTF 是首选修改形式，可按 GPL §4 交付它；如果属于非源码形式，则需按 §6 提供对应源码，或采用实际适用的额外许可 | 尚未找到第一方对这项分类的明确声明；字体例外没有免除字体软件本身的源码条件。可改用下面的 OFL 中文字体路线，保留中文及数学编译能力 |

## 条款区别：原样完整作品、安装产物与修改

GUST Font License 1.0 采用 LPPL 1.3c 或后续版，并把派生字体/文件改名写成**请求而非法律要求**。原样分发无须改字体名。这里以发行包内的[原始 GUST 文本](../../third_party/font-notices/lm-2.005/GUST-FONT-LICENSE.TXT)为准；不能把建议改名升级为额外强制条款。

[LPPL 1.3c](https://www.latex-project.org/lppl/lppl-1-3c/) §2 允许收到的完整未修改 Work；单独分发其一部分不能直接借用这一条。§3 允许从完整未修改 Work 产生的 Compiled Work，但要求接收者能够安装成自行生成时相同的结果；定义中的处理包括复制组件。§6 对派生作品要求标识修改、记录变化、不暗示原作者支持，并附完整原作或足以取得它的信息；§7 对派生作品的编译形式要求同时交付派生作品。**这些规则不是 GPL 的“首选修改形式/Corresponding Source”规则。**本项目若使用缓存子集，需落实完整作品/安装产物或派生分发路径，不能只用“字体字节没改”跳过作品范围。

[GPL v3](https://www.gnu.org/licenses/gpl-3.0.html) §1 以实际首选修改形式定义源码，而非按扩展名判定；§4 管收到的源码原样副本；§6 管未修改和修改的非源码副本。因此“未修改”不自动免除 §6，“OTF 是二进制”也不自动证明它不是源码。网上发布若采用 §6(d)，须提供对应源码的等价访问及清楚指引，并持续确保其可取得；旧项目链接失效不能当作已经履行这一要求。独立字体与应用的简单聚合还需按 §5 的 aggregate 区分，不自动把整个应用改成 GPL。

## Latin Modern：现有完整包覆盖了作品清单

本地 `.build-tools/third-party-inputs/fonts/lm.zip` 为 18,709,543 字节，SHA-256 `71c48809cb50fbfe09c8eddaa251398957c7b243acdf69f7f807268f0d42c939`，来源为 [CTAN 官方包](https://mirrors.ctan.org/fonts/lm.zip)。[README](../../third_party/font-notices/lm-2.005/README-Latin-Modern.TXT) 标明版本 2.005，并把 Work 定义为 manifest 所列文件；[原始 manifest](../../third_party/font-notices/lm-2.005/MANIFEST-Latin-Modern.TXT) 抬头仍为 2.004，这是已收到原件中的旧元数据，应记录而不擅自改写。

本轮逐项检查：manifest 声明 **1,070 个唯一文件路径**，ZIP 有 **1,094 个非目录文件**。声明路径均能对应到 ZIP；其中仅三份通知的 `.txt`/`.TXT` 大小写不同。manifest 包含 OTF、PFB、TFM、AFM、PFM、编码、映射、宏包和文档，**没有任何 `.mp`、`.mpe`、`.mf` 或 `fonts/source/` 条目**。检查结果在 `tex-final-provenance/distribution-review/lm-manifest-coverage.json`。

**条款推断：**以这份已收到的完整作品原样交付，现有 GUST/LPPL 文本并不另加“必须提供未在作品清单中的 METATYPE1 工程”这一条件。README 关于 `lm2.003mt1.zip` 的技术说明不是独立的分发义务，不能把源码重建便利性当作 §2 的前置条件。

可执行做法：将已校验的完整 `lm.zip` 直接放入交付材料，并保留全部原通知；最好随安装包提供，使用户不依赖可变的外部链接。运行时缓存保持原字节，另记缓存是从完整包选取的安装文件、复制规则和可还原原始目录的方法。若选择仅在线附包而运行时只交付子集，应记录采用 §3 还是 §6/§7、对应安装/变化说明；完整包的链接本身不代替其余条件。**不需要为了这个原样分发方案重新编译字体，也不应继续猜 METATYPE1 下载地址作为发布门槛。**

## `pzdr.tfm`：找到 PSNFSS 的直接分发依据

[PSNFSS 官方 README](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/latex/psnfss/README?id=082081a375be008c2e049cd7cf1137314f888b18) 将 Base35 度量放在 `lw35nfss.zip`，并明确该集合不包含实际的 `.pfb` 和 `.afm` 字体文件。其 [manifest](https://git.texlive.info/texlive/plain/Master/texmf-dist/doc/latex/psnfss/manifest.txt?id=082081a375be008c2e049cd7cf1137314f888b18) 要求整体分发，明确列出 `lw35nfss.zip`（或其中全部文件）。[psfonts.dtx](https://git.texlive.info/texlive/plain/Master/texmf-dist/source/latex/psnfss/psfonts.dtx?id=082081a375be008c2e049cd7cf1137314f888b18) 文件头将 manifest 全部文件定义为该作品，授予 LPPL 1.2 或后续版。

manifest 另将独立来源的 `8r.enc` 排除在整体分发限制之外；完整包应保留它自己的原通知，不能抹去这个例外。此处核实的具体许可关联是 `pzdr.tfm`，不是对所有字体文件统一归类。

本轮取得 [CTAN `lw35nfss.zip`](https://mirrors.ctan.org/macros/latex/required/psnfss/lw35nfss.zip) 和 [完整 `psnfss.zip`](https://mirrors.ctan.org/macros/latex/required/psnfss.zip)，没有编译或执行内容。实际证据为：

| 对象 | SHA-256 / 核验结果 |
| --- | --- |
| `lw35nfss.zip` | 606,024 字节，`829f309489f00a81f1b27ab35a000ef405eeaa521afc54033a7ea4f0fe821b07` |
| 内部 `lw35nfss/fonts/tfm/adobe/zapfding/pzdr.tfm` | 1,528 字节，`6b4254217851e285d1d5c6dfe677284396eeffc59f709ad775404b76dc99d513`，与候选全等 |
| 完整 `psnfss.zip` | 1,211,157 字节，`c289f1e38254201e4d16a2782814cb4d41c5ce8beed5cd193164493c72adbe71`；manifest 的 20 项全部存在，内嵌度量 ZIP 也全等 |
| `README` / `manifest.txt` | 分别为 `0867a7d6010057e13a36c1952e8cf0ffc33e7126f9c2bea2f683aa70774cd9ae` / `e682dec71fca0e094febee3d847f2bfa3f06ff1caadab51f68bf643cb6bbd712`；与固定 TeX Live 2022 原件全等 |
| `psfonts.dtx` | 35,148 字节，`9fed09f2f6e2961c10b46e68ccd3b036fde0ac2b04efbc80793a22cdaec8d478`；完整 ZIP 与固定 TeX Live 原件全等 |

**条款推断与行动：**可以把相同 `pzdr.tfm` 关联到这份明确声明许可、明确定义作品范围的 PSNFSS 包，保留完整原包、其版权/许可文件头和所选 LPPL 全文，按完整作品与安装产物的方式交付。这个路径避免仅凭 TeX Live `zapfding` 包的 URW/GPL 标签作推断，也不要求重建 AFM→TFM。公开材料若还包含 `fonts/afm/adobe/zapfding/pzdr.afm`，那份 AFM 的独立分发条件仍需处理；不能套用 PSNFSS 声明。发布材料可不附并非此 LPPL 作品组成、又未单独确认的 Adobe AFM；这属于后续材料选择变更，本轮未执行。

## Fandol：不能把嵌入例外扩大成源码豁免

已保存 [README](../../third_party/font-notices/fandol-0.3/README) 说明 FontForge/Inkscape 编辑轮廓、AFDKO 编译 OpenType；[COPYING](../../third_party/font-notices/fandol-0.3/COPYING) 为 GPL v3 加字体例外。例外针对使用字体并嵌入字体/未改部分的**文档**，让字体本身不导致结果文档受 GPL；它没有给“作为应用资源分发字体文件”增加普遍的免源码条件。[GNU 官方 FAQ 的 FontException](https://www.gnu.org/licenses/gpl-faq.html#FontException) 也给出这个文档嵌入例外。

当前第一方证据没有明确说“发行 OTF 即首选修改形式”，也没有额外许可豁免 §6。作者关于[旧 Git 项目删除](https://github.com/clerkma/ptex-ng-dist/issues/5#issuecomment-331943498)的评论仅解释仓库去向。反过来，没有找到声明也**不等于字体被禁止使用**：Fandol 有公开许可，未闭合的是本次字体软件分发采用 §4 还是 §6、以及相应形式是否齐备。

保留 Fandol 的可执行分支是：取得足以确认该版本 OTF 为首选修改形式的第一方说明并保存依据，或取得与 0.3 对应的编辑/构建材料后按 §6(d) 同处提供，或取得明确额外许可。修改字体另需 §5 的变化/日期标记等条件。完整 `fandol.zip` 和字体嵌入例外应保留，但不能单独替代尚未确认的 Corresponding Source。这里没有把“必须有某种特定工程后缀”设成规则，也没有未经授权联系作者。

## 不等待 Fandol 分类确认的替代方案

可保留 Latin Modern 及既有数学资源，只将默认中文字体改为 Adobe 官方 Source Han Serif/Sans 的简体中文发行子集。下面是**作者发布的原始子集**，并非本项目裁剪字体；本轮只读取元数据及许可证，没有下载这些字体，也没有修改应用。

| 用途 | 固定官方来源 | 文件 / 字节数 / Git blob SHA-1 |
| --- | --- | --- |
| 中文正文 | [Serif 2.003R，提交 `7889f11b`](https://github.com/adobe-fonts/source-han-serif/tree/7889f11bf31170b5d092a083b357c8c8130f89e0/SubsetOTF/CN) | `SourceHanSerifCN-Regular.otf` / 11,626,108 / `a4feb5f2461886dbf9cfe575974f0a68940c6bf9`；Bold / 12,094,680 / `f8528fae3e7790e4e9a7660841590181826be5a1` |
| 中文无衬线 | [Sans 2.005R，提交 `6c709ca7`](https://github.com/adobe-fonts/source-han-sans/tree/6c709ca72d3d7c46ab42ebecc1a26e7d69595a37/SubsetOTF/CN) | `SourceHanSansCN-Regular.otf` / 8,429,224 / `5e6605995d5cbc432c4273f566a5f2b8c376c682`；Bold / 8,569,308 / `49a623f360e4dfca8e96df4e0681150d76dcaf89` |

四文件合计 40,719,320 字节。下载计划的精确 raw URL 已保存在 `distribution-review/source-han-candidate-plan.json`；实施时还需实际下载、核对 Git blob 并记录 SHA-256。两份固定 [Serif LICENSE](https://github.com/adobe-fonts/source-han-serif/blob/7889f11bf31170b5d092a083b357c8c8130f89e0/LICENSE.txt) / [Sans LICENSE](https://github.com/adobe-fonts/source-han-sans/blob/6c709ca72d3d7c46ab42ebecc1a26e7d69595a37/LICENSE.txt) 都是含 Adobe 版权和 Reserved Font Name `Source` 的 OFL 1.1 原件，应原样保留。OFL 条件允许与软件捆绑，要求保留通知/许可、字体继续受 OFL 约束；改动字体时须处理保留名。官方 [OFL FAQ 1.20、3.6](https://openfontlicense.org/ofl-faq/) 区分应用所需字体/通知与整个设计源工程，没有 GPL 式对应源码交付要求。

工程实现须以真实名称配置 `fontspec/xeCJK`、默认模板和 `ctex` 字体集，覆盖正文、粗体、无衬线、强调及代码场景；不把文件伪装成 Fandol 名称。现有楷体/仿宋外观不会与思源宋体/黑体相同，若需保留这两类外观，另选有明确通知的字体并验收。针对用户文档硬编码 Fandol 的情况，要提供清楚的替换配置或保留用户自备字体路径。

验证范围应包括：空缓存离线编译、中英文混排、粗体/强调/代码、分页与标点、公式/AMS 符号、PDF 文本提取及嵌入字体；确认缓存和 fallback 不会悄悄再次包含待移除字体。这是可实施的功能保留路径，尚未实际运行，不能声称已经替换成功。

## 发布材料下一步

1. LM：按完整作品整理已有 ZIP、通知和缓存安装说明；把独立 METATYPE1 研究从硬性阻断改为可选可复现性改进。
2. `pzdr.tfm`：加入已下载完整 PSNFSS 包及上述固定证据；独立处理材料集中多余的 Adobe AFM，保留现有符号/数学能力。
3. Fandol：保留“源形式判定/§6 交付尚未确认”这一具体项；选择补第一方证据或实施 OFL 中文字体替代，不把问题泛化为所有字体都要源工程。
4. 本轮小型下载、原件和收据均在 `.build-tools/third-party-inputs/tex-final-provenance/distribution-review/`；GPL 官方文本 SHA-256 为 `3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986`。没有下载字体大包，没有改动原有字体字节或采集计划。
