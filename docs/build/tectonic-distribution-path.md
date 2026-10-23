# Tectonic 0.17.0：实际分发材料与剩余工作

核对日期：2026-10-22。范围是当前 `aarch64-apple-darwin` 发布二进制及实际随包提供的源码/通知；不覆盖字体，不改变产品许可证，不构成整体许可兼容保证。固定来源、二进制关联及原始归档摘要见 [源码研究](tectonic-source-provenance.md)。本文把可以直接完成的材料工作与仍需明确的许可选择分开。

材料简称：`R = .build-tools/third-party-inputs/tectonic-source-research`，本轮新增材料 `D = R/distribution-review`，锁定 crate 全集 `C = .build/third-party/tectonic-locked-crates`。目录均未公开上传。

## 结论及建议交付形态

已有主源码、两个 gitlink、固定 vcpkg 端口/补丁、原生库和 437 个锁定 crate，接近可以整理成相邻的“源码与通知”下载资产。**缺少逐字节重建、全部非链接开发依赖的额外源码、或名为 LICENSE 的文件，均不能单独推导出禁止分发。** 真实剩余工作是：明确派生代码采用的许可分支；将原件、必要构建输入和使用说明纳入实际交付；补正确版本的 Rust 标准库通知；避免把某个源码包漏识别的通知当成无授权。

建议的具体路径（属于根据原文提出的方案，尚未替发行者作法律确认）：为独立 `tectonic` 可执行文件及其对应源码明确 GPLv3 交付方案，保留各部分原许可；TECkit 选择 LGPL 2.1+ 并按静态链接路径交付；Graphite 选择明示的 GPL 2-or-later 分支中的 GPLv3。这样无需猜测 Graphite 未注明版号的 MPL，也不需选择 TECkit 的 CPL 分支。另行记录 Claurst 如何调用独立进程，不能仅凭“独立文件”或“同一个 DMG”就推断整个产品许可边界。

选择 GPLv3 的理由具体而有限：编译进引擎的 xdvipdfmx 文件明确 GPL 2-or-later；运行时又包含 Apache-2.0-only 材料。ASF 明确认可 Apache 2.0 可进入 GPLv3 作品，不能直接以 GPLv2 处理该组合；这不是对全部组件的兼容性结论。[ASF 原文](https://www.apache.org/licenses/GPL-compatibility)

实际交付宜包含：二进制、可读的第三方通知/许可选择说明，以及同一发布页面上等效可取得的完整对应源码资产；源码资产包含固定提交、子模块、实际本地修改、构建脚本/补丁和依赖来源。提供源码位置与重建/替换 TECkit 的步骤，不要求得到与原发布文件逐字节相同的签名产物。[GPLv3 §1、§6(d)](https://www.gnu.org/licenses/gpl-3.0.html)、[LGPL 2.1 §6(a)/(d)](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html)

## 派生引擎与原生组件：真实要求

| 组件 / 第一方证据 | 实际需要落实的材料与限制 | 已有及具体剩余 |
| --- | --- | --- |
| [Tectonic 顶层 LICENSE](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/LICENSE) | 顶层 MIT 自己明确派生部分另有许多许可；MIT 不能替换这些许可。保留原文与已有版权。 | `R/notice-originals/tectonic/LICENSE` 已有；发布说明应描述多许可组成，不能仅标整包 MIT。 |
| [xdvipdfmx/dvipdfmx.c](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/crates/engine_xdvipdfmx/xdvipdfmx/dvipdfmx.c)、`pdf_io/dpx-mem.c` 等 | 文件头 GPLv2-or-later，`build.rs` 明确编译这些文件。随附适用 GPL 文本、版权、变更信息和完整对应源码，不能只给顶层 MIT。 | 主归档保存实际修改后的文件与构建脚本，reference_sources 保存固定参考树；不是要求用未修改 XeTeX 重建。需要写入采用版本和下载资产/源码说明。 |
| [TECkit 引擎](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/crates/engine_xetex/xetex/teckit-Engine.cpp) | 头部授权 CPL 或 LGPL；LGPL 2.1 §6 要求使用提示、许可原文，允许用户为自身用途修改和为调试这些修改而逆向；静态链接时 §6(a) 允许提供“使用该库的作品”的目标码**和/或源码**，使用户能修改库并重新链接，并非一律必须提供 `.o`。 | 已有实际修改后源码；补到的历史 SIL `LICENSING.txt`、LGPL/CPL 原文在 `D/teckit/`。将这些原件和重链接所需构建输入/步骤加入发布资产即可继续；不能只给干净 TECkit 官网入口。 |
| [Graphite 1.3.14 COPYING](https://github.com/silnrsi/graphite/blob/92f59dcc52f73ce747f1cdc831579ed2546884aa/COPYING) | 明示 LGPL 2.1+，或 MPL（未写版本），或 GPL 2+；不是必须同时满足三种。建议选明确 GPLv3 分支，与引擎对应源码一起交付。若选 LGPL，则另核对 §6 静态链接条件。 | 固定完整归档、COPYING、LGPL 原文已有。版本未明的 MPL 是该分支的具体解释问题，不应直接填成 MPL-2.0 或把所有分支一起判死。 |
| [XeTeX `xetex-ext.h`](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/crates/engine_xetex/xetex/xetex-ext.h)、`xetex-synctex.c`、`xetex-texmfmp.c` | 各自的 SIL/作者许可、SyncTeX 通知和公有领域声明保留原样；XeTeX 来源并不意味着每个文件都是同一许可证。 | 主完整源码中原件已有；通知汇总需保留这些实际编译文件的头/尾部原文，不用普通 MIT 模板覆盖。 |
| [HarfBuzz 8.3.0 COPYING](https://github.com/harfbuzz/harfbuzz/blob/894a1f72ee93a1fd8dc1d9218cb3fd8f048be29a/COPYING) | Old MIT 原文和版权；其中明确有子目录的其他许可。随包源码保留全部子通知，二进制通知关注实际编译部分。 | 默认内置 8.3.0 gitlink 源码及通知已有；无需因 vcpkg 安装了 11.3.3 就要求把它当成实际链接版本。 |
| [FreeType 2.13.3 FTL](https://gitlab.freedesktop.org/freetype/freetype/-/blob/VER-2-13-3/docs/FTL.TXT) | 可选择 FTL；二进制分发文档必须说明部分基于 FreeType Team 工作；源码保留 FTL/版权并说明修改。 | `.build/third-party/tectonic-freetype-2.13.3` 已有完整源码、LICENSE/FTL/GPL。需把归属说明放入交付文档；不因有 GPLv2 原文而强制同时选择 GPLv2。 |
| [aws-lc-sys 0.42.0 LICENSE](https://github.com/aws/aws-lc-rs/blob/741dbf573a64b6a1e1e6b7c1131a0f8153a28441/aws-lc-sys/LICENSE) | 实际二进制有 `aws_lc_0_42_0_*` 符号。此固定版本明确 OpenSSL 派生部分已用 Apache-2.0，BoringSSL 有 ISC/Apache 分支，另有 Fiat、s2n-bignum、Jitter 等子通知。不能根据旧 OpenSSL 印象套旧广告条款，也不能统一替换成 MIT。 | `C` 完整 `.crate` 与锁文件匹配，LICENSE 与先前独立原件相同；保留该复合原文及其所指子文件。该原文明确测试工具部分不因链接 libcrypto/libssl 而触发，发布这些测试源码本身则仍需保留其通知。 |
| ICU、Expat、Brotli、bzip2、libpng、zlib | 按所选版本原文保留要求的归属、许可和免责声明；源码与 vcpkg 补丁保持关联。不能把“完整源码已保存”当成已放入发行物。 | `R/archives` 和 `notice-originals.json` 已有原件；材料整合与下载入口检查即可，不必为所有未链接工具另开无限源码收集。 |

TECkit 的版本证据：Tectonic 文件头为 SIL 2002–2016，内嵌版本 2.5.4；找到 SIL 官方历史提交 [`ef1b2af717365220ade2ca87bb6ed7513b0ba5f4`](https://github.com/silnrsi/teckit/blob/ef1b2af717365220ade2ca87bb6ed7513b0ba5f4/license/LICENSING.txt)，其 Engine 文件使用同一版权和授权头，LICENSING 明确 **CPL 0.5-or-later / LGPL 2.1-or-later**。这是历史许可范围的佐证，不声称整个 Engine 与 Tectonic 修改版本逐字节相同，也不把当前 2026 新版权文本冒充原始 2016 通知。`D/teckit/LICENSING.txt` SHA-256：`775b7c2503b1ecb7575dea73d4e8a8212f74cfa84f19be5d4564b7e7b478a8fb`。

## Rust 标准库与 libgcc

**Tectonic 的 Rust 版本是 1.97.1，而不是 Claurst 本次构建所用的 1.99.1。** 二进制内 rustc 路径 `8bab26f4f68e0e26f0bb7960be334d5b520ea452`、官方 [1.97.1 tag](https://github.com/rust-lang/rust/tree/1.97.1)、[src/version](https://github.com/rust-lang/rust/blob/8bab26f4f68e0e26f0bb7960be334d5b520ea452/src/version) 与 [2026-07-16 发布清单](https://static.rust-lang.org/dist/channel-rust-1.97.1.toml)一致；这证明工具链版本关联，不是标准库每个机器码字节的重建证明。

- 已取得官方 [rust-src-1.97.1.tar.xz](https://static.rust-lang.org/dist/2026-07-16/rust-src-1.97.1.tar.xz)，**5,660,384 字节**，SHA-256 **`e9a1e616d04c6845895c827a178b9227f7c7199f3f4a80af81ab3aff7b80156b`**；与官方清单 `rust-src.target.*.xz_hash` 相同。包括标准库、compiler-builtins/libm、LLVM libunwind 源码和 36 个 vendor 目录；未运行这些代码。
- 保存位置 `D/rust-src-1.97.1.tar.xz`；74 份归档内 LICENSE/COPYING/COPYRIGHT 文件已按原字节提取到 `D/rust-1.97.1-notices/`，索引 `D/rust-1.97.1-notices.json`。固定提交的 `COPYRIGHT`、`REUSE.toml`、`license-metadata.json` 及平台链接源码在 `D/rust-1.97.1/`。完整源码仍保留内联版权，74 不是“只需 74 份就覆盖全部版权”的断言。
- Rust [COPYRIGHT](https://github.com/rust-lang/rust/blob/8bab26f4f68e0e26f0bb7960be334d5b520ea452/COPYRIGHT) 明确标准库也有第三方材料；应把这些通知纳入交付，不能只用 Rust 顶层 MIT/Apache。可选择从本轮源码及许可元数据整理标准库通知，也可取得官方生成的 `COPYRIGHT-library.html` 进行核对；**该 HTML 文件名本身不是许可证规定的必须文件**。
- HTML 的已验证生成/安装入口是固定提交 [`dist.rs`](https://github.com/rust-lang/rust/blob/8bab26f4f68e0e26f0bb7960be334d5b520ea452/src/bootstrap/src/core/build_steps/dist.rs) 的 `Rustc` 分发步骤，路径 `rustc/share/doc/rust/COPYRIGHT-library.html`。下一步可从[官方 rustc 1.97.1 arm64 组件](https://static.rust-lang.org/dist/2026-07-16/rustc-1.97.1-aarch64-apple-darwin.tar.xz)提取；清单预期 SHA-256 `6076cad38ccabaa24325f26a74080a363a2633a9cd34c473a8977255d8a593cb`。本轮未下载这个大组件；尝试 `doc.rust-lang.org/1.97.1/COPYRIGHT-library.html` 返回 404，不再猜测公开文档路径。
- **当前没有证据要求额外收集一套 libgcc 才能分发这个 macOS 二进制。** Mach-O 动态依赖记录是 Apple 框架、libSystem、libc++ 和系统 libiconv；没有 libgcc。Rust 固定版本 [`std` Apple 分支](https://github.com/rust-lang/rust/blob/8bab26f4f68e0e26f0bb7960be334d5b520ea452/library/std/src/sys/pal/unix/mod.rs)链接 `System`，[`unwind` 中 gcc 链接](https://github.com/rust-lang/rust/blob/8bab26f4f68e0e26f0bb7960be334d5b520ea452/library/unwind/src/lib.rs)是其它平台条件。上述证据不等同排除一切静态派生代码，但也不能从跨平台依赖名单推导实际随包 libgcc。
- 如果未来实际分发 GCC 运行库，才按其确定版本核对 GPL 和适用的 [GCC Runtime Library Exception 3.1](https://www.gnu.org/licenses/gcc-exception-3.1.en.html)：该例外对符合条件的编译产物提供额外分发许可，并非要求所有使用 GCC 的独立程序都改成 GPL，也不免除另行分发运行库自身应遵循的条件。本次不将未识别版本的 GCC 全源码列为发布硬门槛。

## 16 个“无独立 notice”crate 的实际结果

Cargo 的 `license` 字段是发布者声明包采用的许可证，`license-file` 是另一种提供文本的方法；没有独立文件不等于没有许可。[Cargo 官方说明](https://doc.rust-lang.org/cargo/reference/manifest.html#the-license-and-license-file-fields) 本轮从完整、已与锁文件匹配的 `.crate` 保存 `Cargo.toml(.orig)`、README、AUTHORS、VCS 信息到 `D/crate-declarations/`，清单 `D/crate-declarations.json`；不改原有 `C` 收据，也不把上游仓库文件冒充发布包成员。

| 包（16 项全部列出） | 第一方声明 / 此次补充 | 对本次交付的意义 |
| --- | --- | --- |
| ignore-files 3.0.5、project-origins 1.4.2、watchexec 8.2.0、watchexec-events 6.1.0、watchexec-filterer-globset 8.0.0、watchexec-filterer-ignore 7.0.0、watchexec-signals 5.0.1、watchexec-supervisor 5.2.0（8） | Apache-2.0；其中 events/signals/supervisor 的 Cargo 声明另有 MIT 选择。已按每包 `.cargo_vcs_info.json` 固定提交取得仓库根 LICENSE；8 份精确 URL、SHA 与本地路径在 `D/retrieved-originals.json`。 | 主 Tectonic 正常依赖直接引用 watchexec 系列，不能一概当开发依赖忽略。可选择 Apache 分支并补入根原文；§4(d) 仅在上游有 NOTICE 时要求传递其中归属，不要求凭空创造上游 NOTICE。 |
| defmt-parser 1.0.0（1） | MIT OR Apache-2.0；README 指向上级 LICENSE。已取[对应提交 Apache 原文](https://github.com/knurling-rs/defmt/blob/4a8cdb44891ed57b8ff5a023b6bec7137c48708f/LICENSE-APACHE)。 | 位于 defmt-macros 依赖链；完整锁文件不能证明它进入默认 macOS 二进制。补原文即可解决“没有独立文件”的材料问题。 |
| jni 0.22.4、jni-macros 0.22.4、jni-sys-macros 0.4.1（3） | MIT OR Apache-2.0；3 个各自固定 VCS 提交的根 Apache 原文已保存。 | rustls-platform-verifier 的主要 JNI 路径受 Android 条件限制，另有可选 JNI 依赖；不能把锁文件出现当成已链接证据。若发布全源码资产，保留补充原文。 |
| valuable 0.1.1（1） | MIT；已取[固定提交根 LICENSE](https://github.com/tokio-rs/valuable/blob/9efc29b6e58cef28f6566a47aa7e142a55fead77/LICENSE)。 | tracing-core 中位于 `cfg(tracing_unstable)` 且 optional。补通知，不因锁文件存在就要求证明额外运行库源码。 |
| r-efi 6.0.0（1） | **归档自身 AUTHORS 已含完整 MIT 文本、版权及三选许可声明**，与[同提交官方 AUTHORS](https://github.com/r-efi/r-efi/blob/7e1b0322d31d625f81a5656096330934f9cd835d/AUTHORS)逐字节相同。 | 此项是按文件名扫描漏识别，不是真正缺通知。getrandom 的对应依赖受 UEFI/efi_rng 条件限制。选 MIT 并保留 AUTHORS 可继续整理。 |
| seahash 4.1.0（1） | 发布包 `Cargo.toml(.orig)` 明示 MIT，列作者 ticki、Tom Almeida，VCS `94b632aeac099031c373599313d5b5f0acbbaec0`。官方 GitLab 该提交 `/LICENSE` 请求 404；未取到独立原件。 | rkyv 的正常依赖，不能直接忽略。将发布者的 MIT 声明、原始作者字段及标准 MIT 条款分开保留，不捏造版权年份或声称找到上游 LICENSE；若发行方需要更强授权证据，剩余问题是该具体声明的充分性/原件补证，而非“没有 LICENSE 所以禁止”。 |
| rustls-platform-verifier-android 0.1.1（1） | 发布包明示 MIT OR Apache-2.0，无 `.cargo_vcs_info.json`，含 Maven AAR。未拿另一版本根许可假充该版本原件。 | 在 verifier 中受 Android 条件限制，不构成当前 macOS 二进制已链接证据。若仅交付实际闭包可排除该 Android 材料；若选择公开全 437 源码包，仍保留其声明并补对应 Android 项目的版本通知关联。 |

计数：**13 个包补到了各自固定仓库提交的原文 + 1 个包在 AUTHORS 找到现有原文 + 2 个包保留明确发布许可声明而尚无单独版本原件 = 16**。13 份外取原件与 r-efi AUTHORS 已在 `D`，并未写入正式 collector/catalog。是否需要每个可选包的源码/通知，应取决于二进制实际组成以及是否另外公开该包源码；选择发布全 437 包属于保守全集，会使原本未链接包也成为源码分发对象。

## 剩余工作的可执行边界

1. **真实交付要求**：登记上述引擎许可选择；合并已有完整主源码/子模块/固定补丁和实际依赖，保留原件；加入 TECkit 使用、许可与重新链接说明、FreeType 归属；将 Rust 1.97.1 材料与 1.99.1 材料分列；验证公开二进制旁的源码和许可资产实际可取得。此处需要的是可用对应源码，不是源码压缩包个数。
2. **材料补充**：采用本轮 13 份 crate 根原件与 r-efi AUTHORS；对 seahash 保留发布包 MIT 证据并明确是否还需作者确认；Android-only 包只有在发布保守源码全集时才需要其额外版本关联。Rust 可用已取得源码/元数据整理通知，或从明确的 rustc 组件提取生成 HTML；不能以 HTML 未取到就忽略标准库，也不能把该文件本身变成独立许可条件。
3. **保守全集**：437 个锁包、所有平台端口、测试/工具源码和所有非链接通知可留作归档，但不能把每一项都称为当前 macOS 运行时硬要求。发布该全集时仍保持各文件许可，不以“未链接”删除已经一起分发的源码通知。
4. **可选可复现性**：精确 CI 日志、link map、全部开发工具的源码、原 SDK、每个机器码字节重现和原签名重建不作为本次材料收尾的先决条件；若后续发现实际修改/输入缺失，按具体缺口补齐。许可证要求的构建/安装脚本及修改库后可重新链接所需输入仍属于第 1 项，不能混入“可选”而省略。

本轮新下载只有 5.66 MB 的 Rust 源归档及小型原文/元数据，无超过 20 MB 的新归档、无构建/执行下载代码、无应用或签名修改。`D/retrieved-originals.json` 记录 23 个固定来源文件的 URL、SHA-256、Git blob SHA-1；其它下载的源 URL/摘要在本文及 Rust 通知索引。未声称实际链接闭包已全部重建、发布审核已完成，亦未将超时/404 改写为成功或禁止授权结论。
