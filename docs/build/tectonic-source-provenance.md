# Tectonic 0.17.0 源码与原生依赖来源记录

日期：2026-10-22。对象为项目已下载的 `tectonic-0.17.0-aarch64-apple-darwin.tar.gz`，以及 `build-mHHoqi` 中的排版可执行文件。本轮只做来源、字节与通知材料核对；不据此声明整个应用许可兼容、对应源码要求完成或可以公开分发。

以下初次采集阶段的失败与缺口保留原始记录。后续已补齐全部 437 份锁定注册表归档，包含此前失败的 AWS-LC、libz-sys 和 rustls，FreeType 完整归档也已取得；最新结果见文末，其余材料仍单独跟进。

研究材料根目录为 `.build-tools/third-party-inputs/tectonic-source-research/`，下文以 `R/` 表示。`R/source-collection-manifest.json` 是可供后续收集器读取的清单，`R/tectonic-rust-locked-sources.json` 给出全部 437 个锁定注册表归档的精确 URL 与 Cargo.lock SHA-256。研究目录不随 Git 提交，因此本文同时保存固定来源、关键摘要和重取步骤。

## 已经实际核对的二进制

[官方 Release](https://github.com/tectonic-typesetting/tectonic/releases/tag/tectonic%400.17.0) 的 arm64 macOS 资产为 [tectonic-0.17.0-aarch64-apple-darwin.tar.gz](https://github.com/tectonic-typesetting/tectonic/releases/download/tectonic%400.17.0/tectonic-0.17.0-aarch64-apple-darwin.tar.gz)。保存的 Release API 元数据见 `R/release.json`，发布时间为 2026-07-27T01:00:41Z。

- 本地下载归档为 21,704,674 字节，SHA-256 `a3f1cac7c5678f01661a92212f58480ae3b0634115d880dbc59e2953ded45667`，与官方资产的 `digest` 相同。归档只有 `tectonic` 一个成员，未附源码或通知包。
- 归档成员与 `.build-tools/tectonic-0.17.0/tectonic` 字节一致；后者为 53,998,928 字节，SHA-256 `b52b5a730e2b0b33087304f7720f649603953f270a6b1c88bb031e1ae01f7f9c`。`file` 确认为 Mach-O arm64。
- 应用内签名后的 `Contents/Resources/latex/tectonic` 为 53,703,200 字节，SHA-256 `9b846280a39091ee42adf15172f1255a7bc361ad3c8239f467e401b543b21a65`，不声称整个文件与官方下载相同。只读解析两个 Mach-O 后，17 个有文件内容的 section 的名称、长度与 SHA-256 全部相同；未将零填充 section、load commands 或 `__LINKEDIT` 整体算入此比较。结果见 `R/packaged-section-evidence.json`。
- `otool -L` 列出 Apple 系统框架、`libc++.1.dylib`、`libSystem.B.dylib` 与 `/usr/lib/libiconv.2.dylib`；没有独立的 FreeType、HarfBuzz、ICU 等动态库路径。这只能说明动态链接表，不足以列出或排除所有静态库。
- `nm` 实际发现 `_FT_Init_FreeType`、`_hb_shape_plan_*`、`_zlibVersion`，以及大量 `aws_lc_0_42_0_*` 符号。`strings` 中有 ICU 74 的类型名、`1.6.50`、`1.3.1`、`1.0.8, 13-Jul-2019` 等文本。这些是对应组件的交叉证据，字符串本身不等于完整版本或构建参数证明。
- 可执行文件中的 `/rustc/` 路径指向 `8bab26f4f68e0e26f0bb7960be334d5b520ea452`，见 `R/rustc-path-evidence.json`；不要将项目当前 Rust 工具链的材料自动套到此预构建发行物。

以上均通过读取归档、Mach-O、符号与文本完成，未执行下载的程序或构建脚本。记录见 `binary-evidence.json`、`otool.txt`、`binary-all-selected-symbols.txt`、`binary-crypto-compression-symbols.txt`。

## 官方发布流程声明与能够推导的依赖

主项目固定提交为 [`8c0126a9653239a2e6e0a5274af9b8510f643030`](https://github.com/tectonic-typesetting/tectonic/tree/8c0126a9653239a2e6e0a5274af9b8510f643030)。主源码归档的 **871 个普通文件**全部按 Git blob SHA-1 与该提交的 GitHub tree 核对一致，见 `R/tectonic-archive-tree-checks.json`；这是实际文件内容核对，不只是 URL 中出现提交号。

该提交的 [build_and_test.yml](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/.github/workflows/build_and_test.yml) 将 `aarch64-apple-darwin` 发布任务置于 vcpkg 矩阵，设置 `TECTONIC_DEP_BACKEND=vcpkg`；[Cargo.toml](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/Cargo.toml) 固定 vcpkg 为 `a62ce77d56ee07513b4b67de1ec2daeaebfae51a`，使用 `arm64-osx` triplet，安装 `fontconfig`、`freetype`、`harfbuzz[graphite2]`、`icu`。

macOS 发布调用没有传入 `external-harfbuzz`，默认功能为 `geturl-reqwest` 与 `serialization`。[构建 action](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/.github/actions/build-and-test/action.yml) 默认 `features` 为空但没有关闭 Cargo 默认功能；随后 `cranko cargo package-released-binaries ... -- build --target ... --release` 也未传该可选功能。其他矩阵中测试 `external-harfbuzz` 的记录不能替代 macOS 发布配置。

| 范围 | 固定源码/配置所声明的内容 | 与实际二进制的关系 |
| --- | --- | --- |
| HarfBuzz 默认实现 | gitlink `894a1f72ee93a1fd8dc1d9218cb3fd8f048be29a`，源码版本 8.3.0；`bridge_harfbuzz/build.rs` 编译 `harfbuzz/src/harfbuzz.cc`，开启 Graphite2、Apple CoreText、非 Windows pthread 支持 | 符号确认有 HarfBuzz；尚未从二进制独立证明每个编译选项。不可把 vcpkg 安装的 11.3.3 当成最终 HarfBuzz 版本 |
| 字体发现 | `xetex_layout` 只在非 macOS 依赖 fontconfig；macOS 依赖 `tectonic_mac_core` 并使用 CoreText | CoreText 动态依赖可见；fontconfig 仍是构建安装项，并不因此成为 macOS 最终链接项 |
| 字体/排版原生库 | FreeType、Graphite2、ICU 的 bridge 向 vcpkg 探测；`pdf_io` 通过 `bridge_png` 探测 libpng | 符号/字符串提供部分支持；完整 link map 或实际发布构建记录仍缺 |
| 压缩 | `bridge_flate` 使用 `flate2` 的 `zlib` 功能；锁文件含 `libz-sys 1.1.29`；vcpkg 的 FreeType/libpng 还依赖 zlib | zlib 符号与版本字符串可见；`libz-sys` 自己如何选取系统/vcpkg/内置源码仍须核对完整锁定 crate 的 build.rs |
| TLS 原生代码 | 锁定 `reqwest 0.13.4` 的默认功能沿 `default-tls → rustls → __rustls-aws-lc-rs` 启用 AWS-LC；锁定 `aws-lc-sys 0.42.0` | `aws_lc_0_42_0_*` 已从真实二进制直接确认；不能只收集 vcpkg 库而遗漏这部分 |

来源：[HarfBuzz 构建脚本](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/crates/bridge_harfbuzz/build.rs)、[gitlinks](https://api.github.com/repos/tectonic-typesetting/tectonic/git/trees/8c0126a9653239a2e6e0a5274af9b8510f643030?recursive=1)、[HarfBuzz 版本头](https://github.com/harfbuzz/harfbuzz/blob/894a1f72ee93a1fd8dc1d9218cb3fd8f048be29a/src/hb-version.h)、[macOS 条件依赖](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/crates/xetex_layout/Cargo.toml)、[PNG bridge](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/crates/bridge_png/build.rs)、[flate bridge](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/crates/bridge_flate/Cargo.toml)。reqwest 的实际 `.crate` 已按锁文件 SHA-256 验证，详见后表。

此处是对固定官方源码的静态推导，未声称获得本次 Release 的构建证明。GitHub Actions 按此提交查询返回 0 个 run，不能以此证明没有运行过。尤其 [build-setup](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/.github/actions/build-setup/action.yml) 使用 moving `stable`、latest Cranko；[vcpkg action](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/.github/actions/vcpkg-deps/action.yml) 从 `cargo-vcpkg` 的 `master` 安装工具并使用 Homebrew，构建命令也未写 `--locked`。固定源码和 lockfile 是可执行的收集基准，不足以保证可逐字节重建发行物。

## 固定 vcpkg 安装闭包与补丁

[固定 arm64-osx triplet](https://github.com/microsoft/vcpkg/blob/a62ce77d56ee07513b4b67de1ec2daeaebfae51a/triplets/arm64-osx.cmake) 声明 arm64、Darwin、库静态链接、CRT 动态链接。以下是该提交及所选默认功能推导出的安装闭包；不是精确最终链接清单。所有选中端口的 `vcpkg.json`、`portfile.cmake` 和补丁均已包含在完整 vcpkg 归档中，另将 128 个相关文件复制至 `R/source-inspection/vcpkg/`。

| 端口 | 版本与功能 | 源码/通知及补丁要点 |
| --- | --- | --- |
| fontconfig | 2.15.0，port-version 4；nls/tools 未启用 | `COPYING`；依赖 expat、FreeType、平台条件项；`no-etc-symlinks.patch`、`libgetopt.patch` 等原补丁完整保留 |
| freetype | 2.13.3；根安装项启用默认 brotli、bzip2、png、zlib | `LICENSE.TXT`、`docs/FTL.TXT`、`docs/GPLv2.TXT`；端口禁用 HarfBuzz；保留 brotli-static、bzip2、fix-exports、UWP 补丁。完整源归档尚未成功取得 |
| harfbuzz | 11.3.3；默认 freetype，加请求的 graphite2 | `COPYING`；此安装版本与默认内置 8.3.0 分开。完整安装版归档未下载，避免把无最终链接证据的安装项优先于已确认组件 |
| graphite2 | 1.3.14，port-version 4；固定 Git 提交 `92f59dcc52f73ce747f1cdc831579ed2546884aa` | `COPYING` 与 `LICENSE`；保留 disable-tests/staticmacro 补丁 |
| icu | 74.2，port-version 6 | `LICENSE`；端口列出 10 份补丁，含 Darwin rpath；目标工具关闭、宿主工具另建 |
| expat | 2.7.3 | `expat/COPYING`；工具、测试、示例、文档关闭 |
| brotli | 1.1.0 | `LICENSE`；保留 install、pkgconfig、emscripten、arm-uwp 补丁 |
| bzip2 | 1.0.8 | `LICENSE`；默认 tool 功能也会构建工具；端口自带 `CMakeLists.txt` 及 import/export 修补，应与上游归档一起保存 |
| libpng | 1.6.50；未选择 apng | `LICENSE`；保存 cmake.patch；下载摘要核对的是基础源码的 SHA-512，不是端口中另列的 APNG 补丁摘要 |
| zlib | 1.3.1 | `LICENSE`；保存三个端口补丁及配置处理 |
| libiconv / dirent / pthread | 1.18 / 1.26 / 3.0.0 | 当前 macOS 条件下为空端口/系统提供；libiconv 默认不构建 GNU 实现。二进制的 `/usr/lib/libiconv.2.dylib` 与此一致。不能因此列 GNU libiconv 源码为本次已证实静态链接内容 |

固定端口来源均为 `https://github.com/microsoft/vcpkg/tree/a62ce77d56ee07513b4b67de1ec2daeaebfae51a/ports/<端口名>`。宿主依赖还包括 gperf、vcpkg-cmake、vcpkg-cmake-config、vcpkg-cmake-get-vars、vcpkg-make、vcpkg-tool-meson 以及 ICU 宿主工具。它们的端口脚本已在 vcpkg 归档中；其工具二进制、源码和实际版本不是本轮已收齐项目。`libuuid` 的 `!osx` 条件在此排除。

## 派生代码与原始通知

[主项目 LICENSE](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/LICENSE) 自身就区分 Tectonic 与来源系统的多种许可。主源码完整归档保留了实际使用的派生文件；不能仅复制该 MIT 文件或各 bridge 的 Cargo `license = "MIT"` 作为全部材料。

| 已保存的实际文件 | 原件所表达的内容/后续材料 |
| --- | --- |
| `crates/engine_xdvipdfmx/xdvipdfmx/dvipdfmx.c`、`crates/pdf_io/pdf_io/dpx-dvipdfmx.h`、`dpx-mem.c` 等 | 含 dvipdfm/dvipdfmx 作者通知及 GPL v2 或以后版本说明；由相应 build.rs 明确列入编译。完整 GPL 文本及整体分发处理尚需整理 |
| `crates/engine_xetex/xetex/teckit-Engine.cpp` | 保留 SIL 版权以及 CPL/LGPL 选择说明，并引用 `LICENSING.txt`；此文件未在主归档或 reference_sources 中找到，需按实际派生版本补齐，而非填一份普通 MIT |
| `crates/engine_xetex/xetex/xetex-ext.h` | SIL、Jonathan Kew 等原始版权与许可段落；保留原文件 |
| `crates/engine_xetex/xetex/xetex-synctex.c` | 文件尾保留 SyncTeX 原始完整通知；不能只取文件头摘要 |
| `crates/engine_xetex/xetex/xetex-texmfmp.c` | 文件本身声明 public domain；不从 Cargo 的许可字段改写 |
| HarfBuzz 子模块 `COPYING` 及子目录 COPYING | 根文件明确要求查看不同子部分通知；已同时保留归档中的相应原件，不用普通 MIT 模板替换 Old MIT 文本 |
| AWS `aws-lc-sys/LICENSE` | 保留 AWS-LC/BoringSSL/OpenSSL 及多个第三方部分的复合说明，不能简化成 Apache 或 ISC 单一标签 |

精确主源码入口：[Xdvipdfmx](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/crates/engine_xdvipdfmx/xdvipdfmx/dvipdfmx.c)、[PDF I/O](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/crates/pdf_io/pdf_io/dpx-dvipdfmx.h)、[TECkit](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/crates/engine_xetex/xetex/teckit-Engine.cpp)、[SyncTeX](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/crates/engine_xetex/xetex/xetex-synctex.c)。7 个示例文件的精确 URL、字节数与摘要另存 `R/derived-notice-candidates.json`，均来自完整主归档。这些只是明确识别的例子，不声称完成逐文件许可分类。

## AWS-LC 与 Rust 锁定源码的边界

主锁文件共有 **437 个 crates.io 项及 26 个本地项目项**，范围含其他平台/可选/开发依赖，尚不是经过 Cargo feature 解析后的 macOS normal/build 闭包。此前产品收集器的 362 个注册表源码归档不自动覆盖这份独立锁文件。

`aws-lc-sys 0.42.0` 的锁定 SHA-256 为 `6d9ceb1da931507a12f4fccea479dccd00da1943e1b4ae72d8e502d707361444`，目标 `.crate` 为 9,649,430 字节。[官方静态下载](https://static.crates.io/crates/aws-lc-sys/aws-lc-sys-0.42.0.crate) 和[官方备用路径](https://static.crates.io/crates/aws-lc-sys/0.42.0/download) 均因 60 秒上限只取得部分内容；两份部分归档未通过锁文件校验，不能作为完整源码成功项。

部分归档中可读的 `.cargo_vcs_info.json` 指向 `741dbf573a64b6a1e1e6b7c1131a0f8153a28441`；随后从该固定官方 Git 提交独立读取并按 Git blob SHA 核对了 [Cargo.toml](https://github.com/aws/aws-lc-rs/blob/741dbf573a64b6a1e1e6b7c1131a0f8153a28441/aws-lc-sys/Cargo.toml)、[LICENSE](https://github.com/aws/aws-lc-rs/blob/741dbf573a64b6a1e1e6b7c1131a0f8153a28441/aws-lc-sys/LICENSE) 和 `.gitmodules`。该源码声明版本 0.42.0、符号前缀 `aws_lc_0_42_0`，与二进制一致；但由于发布归档未完整核验，VCS 与整个发布 crate 的关联仍保留这一限制。

完整 LICENSE 已在 `R/source-inspection/aws-lc-rs/aws-lc-sys/LICENSE`，20,337 字节，SHA-256 `728536b4160e051f86d7c9c388f704866b3d512cd7df97ac3516c65279523c4e`。官方树的 native gitlink 与 Cargo metadata 均为 [`6283365b1d43abadfa9b997812cef06b095f7f04`](https://github.com/aws/aws-lc/tree/6283365b1d43abadfa9b997812cef06b095f7f04)；树收据保存为 `R/aws-tree.json`。其[完整 Git 源码归档](https://codeload.github.com/aws/aws-lc/tar.gz/6283365b1d43abadfa9b997812cef06b095f7f04)超过本次 35 MB 单请求上限而中止，也没有算作成功项。下一步应优先从更稳定连接取得较小的锁定 `.crate`，然后核对其内部各第三方通知及来源。

## 已取得的完整归档

下列归档均保存在 `R/archives/`。vcpkg 端口来源归档实际 SHA-512 与固定 `portfile.cmake` 的预期值一致；GitHub 固定提交归档记录本次 SHA-256，主项目另有逐 Git blob 核验。完整原件提取索引见 `R/notice-originals.json`，保持原字节。表后列出请求未完成的项目，二者不混计。

**实际已保存 13 个完整归档，共 92,471,911 字节；另外有 30 份从这些完整归档提取的通知原件及 1 份独立核对的 AWS-LC LICENSE。** 部分下载另计 37,292,304 字节，当前归档与部分文件合计 129,764,215 字节。

| 完整归档 / 固定来源 | 字节 | SHA-256 | 校验关联 |
| --- | ---: | --- | --- |
| [`tectonic-8c0126a96532.tar.gz`](https://codeload.github.com/tectonic-typesetting/tectonic/tar.gz/8c0126a9653239a2e6e0a5274af9b8510f643030) | 3,291,216 | `980f2862937cc084eae921ade500c0390c9ae196e973636e0e1b13f5c9479f01` | 固定 Git 提交；本次下载摘要；871 Git blob 均匹配 |
| [`vcpkg-a62ce77d56ee.tar.gz`](https://codeload.github.com/microsoft/vcpkg/tar.gz/a62ce77d56ee07513b4b67de1ec2daeaebfae51a) | 4,801,435 | `6bb68555a0653a5ff62b2133dd9b96896322ae53e6c4e1f7d9cb8df051b77ca5` | 固定 Git 提交；本次下载摘要 |
| [`harfbuzz-submodule-894a1f72ee93.tar.gz`](https://codeload.github.com/harfbuzz/harfbuzz/tar.gz/894a1f72ee93a1fd8dc1d9218cb3fd8f048be29a) | 36,010,701 | `17eda8a9861d347a6e95cd2b3112301ce90dcc649b0e96623cc89c6ca4180e66` | 固定 Git 提交；本次下载摘要 |
| [`reference-sources-70dbe0603c4b.tar.gz`](https://codeload.github.com/tectonic-typesetting/tectonic-staging/tar.gz/70dbe0603c4b27f17b3b4dcb25a85e9da3050fe9) | 1,553,790 | `ca2c501de06943f01335fd5f4f79745139a68c05cd620313dfec3ce9bf751b91` | 固定 Git 提交；本次下载摘要 |
| [`fontconfig-2.15.0.tar.gz`](https://gitlab.freedesktop.org/fontconfig/fontconfig/-/archive/2.15.0/fontconfig-2.15.0.tar.gz) | 572,009 | `cdebb4b805d33e9bdefcc0ef9743db638d2acb21139bbe1a6a85878d4c3e8c9e` | 与固定端口预期 SHA-512 相同 |
| [`reqwest-0.13.4.crate`](https://static.crates.io/crates/reqwest/reqwest-0.13.4.crate) | 162,754 | `219c5811de6525e5416c7d5d53bb656d3afdbc6c5af816e0802bcfa42dbdc1c3` | 与 Tectonic Cargo.lock SHA-256 相同 |
| [`graphite2-1.3.14.tar.gz`](https://codeload.github.com/silnrsi/graphite/tar.gz/92f59dcc52f73ce747f1cdc831579ed2546884aa) | 6,632,395 | `aeb8ca511ebe76500377b05ec08722f5083de15b84a37a4860980cbd8a78db33` | 与固定端口预期 SHA-512 相同 |
| [`expat-2.7.3.tar.gz`](https://codeload.github.com/libexpat/libexpat/tar.gz/R_2_7_3) | 8,441,347 | `7c853a76f7c2a562c3edfd84ca47e487d9eff3966786191dfb60cc441daf82d6` | 与固定端口预期 SHA-512 相同 |
| [`brotli-1.1.0.tar.gz`](https://codeload.github.com/google/brotli/tar.gz/v1.1.0) | 511,969 | `e720a6ca29428b803f4ad165371771f5398faba397edf6778837a18599ea13ff` | 与固定端口预期 SHA-512 相同 |
| [`bzip2-1.0.8.tar.gz`](https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz) | 810,029 | `ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269` | 与固定端口预期 SHA-512 相同 |
| [`libpng-1.6.50.tar.gz`](https://codeload.github.com/pnggroup/libpng/tar.gz/v1.6.50) | 1,582,079 | `71158e53cfdf2877bc99bcab33641d78df3f48e6e0daad030afe9cb8c031aa46` | 与固定端口预期 SHA-512 相同 |
| [`zlib-1.3.1.tar.gz`](https://codeload.github.com/madler/zlib/tar.gz/v1.3.1) | 1,572,744 | `17e88863f3600672ab49182f217281b6fc4d3c762bde361935e436a95214d05c` | 与固定端口预期 SHA-512 相同 |
| [`icu-74.2.tar.gz`](https://github.com/unicode-org/icu/releases/download/release-74-2/icu4c-74_2-src.tgz) | 26,529,443 | `68db082212a96d6f53e35d60f47d38b962e9f9d207a74cfac78029ae8ff5e08c` | 与固定端口预期 SHA-512 相同 |

完整上游归档不代表其中每个测试/工具都进入最终二进制；保留全量内容用于维持原始材料。具体通知路径例如 `fontconfig-2.15.0/COPYING`、`graphite-92f59dcc52f73ce747f1cdc831579ed2546884aa/{COPYING,LICENSE}`、`libexpat-R_2_7_3/expat/COPYING`、`brotli-1.1.0/LICENSE`、`bzip2-1.0.8/LICENSE`、`libpng-1.6.50/LICENSE`、`zlib-1.3.1/LICENSE`、`icu/LICENSE`、`icu/license.html`。

尚未成功的必要小归档及固定校验值：

| 项目 | 原始精确 URL | 预期校验值 | 当前结果 |
| --- | --- | --- | --- |
| aws-lc-sys 0.42.0 | [固定归档](https://static.crates.io/crates/aws-lc-sys/aws-lc-sys-0.42.0.crate) | SHA-256 `6d9ceb1da931507a12f4fccea479dccd00da1943e1b4ae72d8e502d707361444` | 请求超时；只保留部分字节 |
| libz-sys 1.1.29 | [固定归档](https://static.crates.io/crates/libz-sys/libz-sys-1.1.29.crate) | SHA-256 `85bc9657773828b90eeb625adff10eeac83cc21bbfd8e23a03eaa8a33c9e28d9` | 请求超时；只保留部分字节 |
| rustls 0.23.41 | [固定归档](https://static.crates.io/crates/rustls/rustls-0.23.41.crate) | SHA-256 `6b92b125634d9b795e7beca796cc790df15a7fb38323bf3196fda83292d06b1f` | 请求超时；只保留部分字节 |
| freetype 2.13.3 | [固定归档](https://gitlab.freedesktop.org/freetype/freetype/-/archive/VER-2-13-3/freetype-VER-2-13-3.tar.gz) | SHA-512 `fccfaa15eb79a105981bf634df34ac9ddf1c53550ec0b334903a1b21f9f8bf5eb2b3f9476e554afa112a0fca58ec85ab212d674dfd853670efec876bacbe8a53` | 请求超时；只保留部分字节 |

vcpkg HarfBuzz 安装版 11.3.3 未请求完整归档；如后续决定补足全部构建安装项，使用[固定版本归档](https://codeload.github.com/harfbuzz/harfbuzz/tar.gz/11.3.3)，并核对端口 SHA-512 `1d0f19e6aebc6aa273e749fb7968eff851dcfb15a0b5ef6cf268c74e77a81175d845c20c9285be7e9a7cb79871cb08bdac5c9d802a50fc5bd11a7225d510f48f`。默认实际编译的 8.3.0 gitlink 完整归档已经在成功表中。

## 可以直接执行的后续收集顺序

1. 将已取得的完整归档和 `notice-originals.json` 选定原件纳入正式第三方材料目录；逐项重算表中 SHA-256，端口归档再核对 vcpkg SHA-512。保留原生端口补丁与构建脚本，不只保留上游干净源码。原始主源码加两个 gitlink 归档应作为三个独立对象重组，不能假定 GitHub 主归档含子模块内容。
2. 首先补 `aws-lc-sys 0.42.0` 完整 `.crate`，然后 `libz-sys 1.1.29`、`rustls 0.23.41` 和 FreeType。前两类依据 `tectonic-rust-locked-sources.json` 校验 Cargo.lock SHA-256；FreeType依据固定端口 SHA-512。不要将当前 `.incomplete` 或超时返回的字节改名后当作完整归档。
3. 根据主锁文件清单获取其余注册表源码；可以先按全部 437 项作保守收集，或在隔离环境只做 Cargo metadata/feature 解析，记录 `aarch64-apple-darwin`、默认功能、normal/build 范围后再收实际闭包。不要在这一步运行所下载的 build.rs。为当前 Tectonic 单独记录输入摘要，不复用 Claurst 的闭包标签。
4. 对主源码实际编译列表及 AWS-LC、HarfBuzz、FreeType 等内部第三方文件核对原始通知和首选修改形式。补 TECkit 所引用的 `LICENSING.txt`、相应完整许可文本、必要的生成输入；reference_sources 归档只证明项目固定了该参考树，不证明全部引擎均可由它独立重建。
5. 如需要可重复构建证明，再取得实际发行构建日志、link map/静态库版本记录、Rust 编译器与标准库/LLVM 版本、SDK/Apple 系统库及宿主工具来源；保存源码—构建—发行二进制的关联。当前未取得发布 run 证明，也未重建、签名或运行下载代码。

本轮所有完整归档、部分下载和摘要均位于指定研究目录，整体保存在 150 MB 上限以内。失败原因、大小、原始与最终 URL 保留在机器清单和分阶段收据中。`redistribution_review_complete` 与 `source_requirements_complete` 仍为 false。

## 后续锁文件源码收集

2026-10-22，在另一个材料目录补齐全部 **437 个注册表归档，共 82,289,482 字节**。先从已核对 Git blob 的完整 Tectonic 主源码归档读取 Cargo.lock，逐项核对注册表、名称、版本和 SHA-256；225 项从已有本地归档复用，其余先请求官方 CDN，连接超时后从 rsproxy 下载镜像补缺。所有镜像字节仍须与同一官方锁文件摘要完全一致，原始注册表 URL 与已知实际下载 URL 分列，不把镜像称为官方源。

自包含输出为 `.build/third-party/tectonic-locked-crates`，包含 437 份完整归档、从归档直接保存的 783 份许可/通知原件、Cargo.lock、说明、清单及 SHA256SUMS。清单 SHA-256 为 `f7a71e9545574bd34160f4d876b46f367b2f070dde2a9e9ed5289d1d3bf95b71`。再次核对全部归档摘要及每份通知与归档成员的一致性；原件字节没有改写。单独重取任一归档时，以该主源码提交的 Cargo.lock 校验，官方地址按 `https://static.crates.io/crates/<name>/<name>-<version>.crate` 组成。

此前独立收集的 AWS-LC LICENSE 已与完整 `aws-lc-sys 0.42.0` 归档成员逐字节相同；发布归档中的 `.cargo_vcs_info.json` 也确认提交 `741dbf573a64b6a1e1e6b7c1131a0f8153a28441`。其余之前失败的 `libz-sys 1.1.29` 与 `rustls 0.23.41` 现已按原锁文件校验通过。初次目录中的部分文件没有被改名冒充完整文件。

范围仍是完整锁文件，包含可选、开发和其它平台依赖，不声称每项都进入 macOS 二进制。26 个本地项目包仍在另存的主源码归档；原生库和工具链材料另列。16 个归档没有发现独立通知文件，具体列表及 Cargo 许可声明保存在清单，既不虚构原件，也不将此源码收集结果直接当作整体许可兼容结论。此输出尚未合并进应用候选或公开上传。

## FreeType 完整材料

随后从前表同一官方 GitLab URL 取得完整 FreeType 2.13.3 归档，2,482,495 字节，SHA-256 `bc5c898e4756d373e0d991bab053036c5eb2aa7c0d5c67e8662ddc6da40c4103`。SHA-512 与固定 vcpkg 端口的 `fccfaa15eb79a105981bf634df34ac9ddf1c53550ec0b334903a1b21f9f8bf5eb2b3f9476e554afa112a0fca58ec85ab212d674dfd853670efec876bacbe8a53` 完全一致。

`.build/third-party/tectonic-freetype-2.13.3` 保存该未裁剪归档，以及直接从中提取的 `LICENSE.TXT`、`docs/FTL.TXT`、`docs/GPLv2.TXT` 和逐文件来源清单。它补齐此前这一下载缺口，仍须与固定 vcpkg 归档中的构建配置、补丁和其它组件共同整理，不将下载成功单独等同于整个产品可分发。
