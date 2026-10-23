# Tectonic 0.17.0 默认 macOS arm64 依赖与重链接路径

日期：2026-10-23。已完成默认 arm64 原生依赖构建、Tectonic 源码构建、修改实际 TECkit 实现后重新链接，以及中文、数学与文字映射 PDF 回归。下文保留最初解析阶段的方法，并追加实际执行证据。本验证不要求新二进制与上游签名或字节相同，也不代表整个产品已满足发布条件。

路径约定：`R=.build-tools/third-party-inputs/tectonic-source-research`；`C=.build/third-party/tectonic-locked-crates`；`D=R/rebuild-research`。这些目录被 Git 忽略；公开源码资产仍须包含实际归档、本文和必要脚本，不能只发布指向本机路径的收据。固定来源与既有下载摘要另见 [源码研究](tectonic-source-provenance.md)，许可履行事项另见 [分发路径](tectonic-distribution-path.md)。

## 已实际解析的默认依赖闭包

主源码为 [`8c0126a9653239a2e6e0a5274af9b8510f643030`](https://github.com/tectonic-typesetting/tectonic/tree/8c0126a9653239a2e6e0a5274af9b8510f643030)，主 `Cargo.lock` SHA-256 为 `4a6e5c44fdb10188005cba9ae6a253fe60d79676b1cef999da669ec71c3850e9`，解析前后完全相同。根包默认功能是 `geturl-reqwest`、`serialization`；未启用 `external-harfbuzz`。这是固定 [Cargo.toml](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/Cargo.toml) 与 [macOS 发布 workflow](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/.github/workflows/build_and_test.yml) 对应的选择，不使用 `--all-features` 或 `--workspace` 扩大最终根包范围。

先逐项验证 `C` 的 **437** 份 `.crate` 摘要与主锁文件一致，再提取到隔离 vendor 目录，生成每包 `.cargo-checksum.json`；共提取 24,176 个普通文件。隔离 `CARGO_HOME` 仅用本地 directory source replacement，移除继承的 Cargo/Rust 包装器和 flags；本机没有适用于该源码目录的祖先 Cargo 配置。随后用已安装的 Cargo **1.99.1 (5f94df478 2026-08-27)** 执行以下命令，四条均返回 0，stderr 为空；没有调用 Cargo build/test/run。

```sh
cargo --version --verbose
cargo metadata --format-version 1 --locked --offline --filter-platform aarch64-apple-darwin
cargo tree -p tectonic --locked --offline --target aarch64-apple-darwin --edges normal,build --prefix depth --format '{p}|{f}'
cargo tree -p tectonic --locked --offline --target aarch64-apple-darwin --edges normal --prefix depth --format '{p}|{f}'
```

| 解析结果（host 和 target 都是 `aarch64-apple-darwin`） | 本地包（含根包） | 注册表包 | 合计 |
| --- | ---: | ---: | ---: |
| 默认根包的 normal + build 闭包 | 24 | 303 | **327** |
| 仅沿 normal 边可达 | 22 | 289 | 311 |
| 加入 build 边后额外出现 | 2 | 14 | 16 |

303 份选中归档共 **33,552,324 字节**；剩余 134 个注册表包不在此选择中。normal 可达包仍包含 14 个 proc-macro 包及其编译器宿主依赖，所以 289 不能称为最终二进制中静态链接的 Rust 包数。build 额外 16 项是两个集合的差，不表示只有这 16 项参与构建。它们为 `autocfg 1.5.1`、`cc 1.2.67`、`cfg_aliases 0.2.1`、`chrono-tz-build 0.3.0`、`cmake 0.1.58`、`find-msvc-tools 0.1.9`、`fs_extra 1.3.0`、`jobserver 0.1.35`、`parse-zoneinfo 0.3.1`、`phf_codegen 0.11.3`、`pkg-config 0.3.33`、`shlex 2.0.1`、`tectonic_cfg_support 0.1.5`、`tectonic_dep_support 0.1.2`、`vcpkg 0.2.15`、`version_check 0.9.5`。工具名包含 msvc 不代表 Windows 运行时代码被分发。

**选择方法不能简化成 metadata 中 normal/build 边的 BFS。** 本轮 metadata 原始 resolve 图按此方法会给出 368 项，比选定根包的 tree 多 41 项。具体例子：`rust_decimal 1.42.1` 的 metadata 节点 features 只有 `std`，仍列出声明为 optional 的 `rkyv` 边；对应 tree 没有 `rkyv` 或 `seahash`。因此本收据用 tree 的实际平台/功能选择确定成员，再用 metadata、锁文件和归档提供身份、功能、摘要；不对这 41 项一概归因为开发依赖。原始输出均保留，可复核该差异。

`rustls-platform-verifier-android 0.1.1` 被排除有明确来源依据：锁定 [rustls-platform-verifier 0.7.0 归档](https://static.crates.io/crates/rustls-platform-verifier/rustls-platform-verifier-0.7.0.crate) 的 `Cargo.toml:133` 将它声明在 `cfg(target_os = "android")` 下；Apple 分支使用 `core-foundation`、`security-framework` 等。目标 macOS 不满足 Android 条件，tree 也没有该包。其额外通用 JNI 声明为 optional，根默认功能不启用相应 docsrs/ffi-testing 功能。`seahash` 也未进入此闭包；这些判断均不是因缺独立 LICENSE 而删包。

此前 16 个“归档无独立通知文件”的包中，实际选中的是 8 个：`ignore-files 3.0.5`、`project-origins 1.4.2`、`watchexec 8.2.0`、`watchexec-events 6.1.0`、`watchexec-filterer-globset 8.0.0`、`watchexec-filterer-ignore 7.0.0`、`watchexec-signals 5.0.1`、`watchexec-supervisor 5.2.0`。它们固定版本的第一方通知已另存 `R/distribution-review`，见 [分发路径](tectonic-distribution-path.md)；本轮不把“归档内没有独立文件”改写成禁止分发。

## 可供收集器读取的证据

| `D/` 下文件 | 内容 / SHA-256 |
| --- | --- |
| `default-aarch64-normal-build.json` | 327 项身份、版本、features、normal/build 分类、proc-macro 标记；303 个锁定 checksum、归档 URL/路径/大小；134 个排除项。SHA-256 `17472486146e47515e2d4ada96ec63577be727b8a867a3f3b432ea6f854c92fd` |
| `selected-registry-SHA256SUMS` | 303 份选中 `.crate` 的名称版本与 SHA-256。自身 SHA-256 `77c117d57461f83b22037d0f844b42e7c3431a528be0e036d55ee1d35d395063` |
| `prepared-inputs.json`、`commands.json` | 437 个实际 resolver 输入；原样命令、返回值、stdout/stderr 摘要及前后锁文件摘要 |
| `metadata.stdout`、`tree-normal-build.stdout`、`tree-normal.stdout` | 本轮 Cargo 原始输出；stderr 另存同名文件 |
| `native-source-layout.json`、`fixed-source-SHA256SUMS` | 主归档/两个子模块/vcpkg 摘要与源码布局；没有把 GitHub 主归档当作含子模块 |
| `native-download-inputs.json` | 七份完整原生源码的精确 URL、字节数、SHA-256/SHA-512、vcpkg 缓存名及固定 portfile 摘要。自身 SHA-256 `c3a3b0e1d8d4175b48e914130cbfd02cff64aee9a5e5ea63737c0153085a70e2` |

本轮离线解析实际保留全部 437 份 vendor 输入；**尚未验证仅放 303 份能否让 Cargo 离线完成锁文件解析**。303 是选定构建的源码依赖集合，不是可直接删除其余 resolver 输入的证明。发布方可以保留全部已验证归档作为保守构建输入，同时清楚标识实际默认闭包。

## 固定源码组装

主归档 SHA-256 为 `980f2862937cc084eae921ade500c0390c9ae196e973636e0e1b13f5c9479f01`，已按固定 Git tree 核对 871 个普通文件。另三个归档本轮重新校验并实际提取如下；固定 URL 和完整摘要见 [来源表](tectonic-source-provenance.md#已取得的完整归档)。

| 固定对象 | 提取位置（相对 `D`） | SHA-256 |
| --- | --- | --- |
| [HarfBuzz `894a1f72ee93a1fd8dc1d9218cb3fd8f048be29a`](https://codeload.github.com/harfbuzz/harfbuzz/tar.gz/894a1f72ee93a1fd8dc1d9218cb3fd8f048be29a)，8.3.0 | `tectonic/crates/bridge_harfbuzz/harfbuzz` | `17eda8a9861d347a6e95cd2b3112301ce90dcc649b0e96623cc89c6ca4180e66` |
| [reference_sources `70dbe0603c4b27f17b3b4dcb25a85e9da3050fe9`](https://codeload.github.com/tectonic-typesetting/tectonic-staging/tar.gz/70dbe0603c4b27f17b3b4dcb25a85e9da3050fe9) | `tectonic/reference_sources` | `ca2c501de06943f01335fd5f4f79745139a68c05cd620313dfec3ce9bf751b91` |
| [vcpkg `a62ce77d56ee07513b4b67de1ec2daeaebfae51a`](https://codeload.github.com/microsoft/vcpkg/tar.gz/a62ce77d56ee07513b4b67de1ec2daeaebfae51a) | `vcpkg` | `6bb68555a0653a5ff62b2133dd9b96896322ae53e6c4e1f7d9cb8df051b77ca5` |

已准备的 `D/tectonic` 可直接用于后续构建。需要独立工作副本时，从仓库根目录运行下列步骤；`rebuild-run` 必须是新目录，脚本拒绝覆盖已有源码。四个 Python 脚本是本轮编写的材料处理脚本，只做校验、提取、解析或本地复制；它们目前依赖这里的仓库布局，公开打包时须一并保留该布局或显式调整输入路径。

```sh
set -e
REPO="$(pwd)"
R="$REPO/.build-tools/third-party-inputs/tectonic-source-research"
D="$R/rebuild-run"
(cd "$R/archives" && shasum -a 256 -c ../rebuild-research/fixed-source-SHA256SUMS)
mkdir "$D"
for script in prepare-offline.py resolve-offline.py summarize-closure.py seed-native-cache.py; do
  cp "$R/rebuild-research/$script" "$D/$script"
done
python3 "$D/prepare-offline.py"
mkdir -p "$D/tectonic/crates/bridge_harfbuzz/harfbuzz" "$D/tectonic/reference_sources" "$D/vcpkg"
tar -xf "$R/archives/harfbuzz-submodule-894a1f72ee93.tar.gz" -C "$D/tectonic/crates/bridge_harfbuzz/harfbuzz" --strip-components=1
tar -xf "$R/archives/reference-sources-70dbe0603c4b.tar.gz" -C "$D/tectonic/reference_sources" --strip-components=1
tar -xf "$R/archives/vcpkg-a62ce77d56ee.tar.gz" -C "$D/vcpkg" --strip-components=1
python3 "$D/seed-native-cache.py"
python3 "$D/resolve-offline.py"
python3 "$D/summarize-closure.py"
```

`seed-native-cache.py` 将七份已取得归档复制成固定 vcpkg helper 期待的文件名，共 **40,121,154 字节**，每份 SHA-512 都与该端口一致：Graphite2 1.3.14、FreeType 2.13.3、Brotli 1.1.0、bzip2 1.0.8、libpng 1.6.50、zlib 1.3.1、ICU 74.2。FreeType 使用 `C` 的同级目录 `tectonic-freetype-2.13.3/freetype-2.13.3.tar.gz` 的完整文件，**不使用 R/archives 中先前下载不全的同名文件**。固定 vcpkg 归档包含端口补丁、CMake 和生成脚本，须与上游源码一同交付。

## 原生构建命令

以下命令在原生 Apple Silicon macOS 上使用已准备的 `D`。需先有 Xcode Command Line Tools/SDK、C/C++ 编译器以及 vcpkg 构建所需宿主工具；[官方 action](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/.github/actions/vcpkg-deps/action.yml) 明列 `autoconf-archive automake libtool pkg-config`，vcpkg 还可能获取 CMake/Ninja/Python 等工具。最初阶段只预置源归档；随后 bootstrap、宿主工具与构建的实际结果见下节。宿主工具和 vcpkg 工具曾从官方端点下载，整个准备流程不能称为完全离线。

```sh
# 续用上面的 REPO、R、D；或令 D="$R/rebuild-research" 使用已组装目录。
export VCPKG_ROOT="$D/vcpkg" VCPKG_DOWNLOADS="$D/vcpkg-downloads"
export VCPKGRS_TRIPLET=arm64-osx TECTONIC_DEP_BACKEND=vcpkg
"$VCPKG_ROOT/bootstrap-vcpkg.sh" -disableMetrics
"$VCPKG_ROOT/vcpkg" install graphite2 freetype icu libpng zlib --triplet arm64-osx --disable-metrics
RUST_BIN="$REPO/.build-tools/rustup/toolchains/1.99.1-aarch64-apple-darwin/bin"
export PATH="$RUST_BIN:$PATH" RUSTC="$RUST_BIN/rustc"
export CARGO_HOME="$D/cargo-home" CARGO_TARGET_DIR="$D/target"
unset RUSTC_WRAPPER RUSTC_WORKSPACE_WRAPPER RUSTFLAGS CARGO_ENCODED_RUSTFLAGS
export CC="$(xcrun -f clang)" CXX="$(xcrun -f clang++)" SDKROOT="$(xcrun --show-sdk-path)"
export PKG_CONFIG_PATH="$VCPKG_ROOT/installed/arm64-osx/lib/pkgconfig"
cd "$D/tectonic"
cargo build -p tectonic --bin tectonic --release --target aarch64-apple-darwin --frozen
```

上述原生安装集合是从实际默认 bridge 推导并已实际构建通过的精简方案，保留 FreeType 默认 brotli/bzip2/png/zlib 功能。[固定 FreeType port](https://github.com/microsoft/vcpkg/blob/a62ce77d56ee07513b4b67de1ec2daeaebfae51a/ports/freetype/portfile.cmake) 禁用其 HarfBuzz 依赖，Tectonic 的 [默认 HarfBuzz build.rs](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/crates/bridge_harfbuzz/build.rs) 则编译已组装的 8.3.0 子模块并使用外部 Graphite2。macOS 使用 CoreText，所以不要求未使用的 fontconfig 安装项。若要照搬官方 CI 的安装全集，把 install 参数改为 `fontconfig freetype 'harfbuzz[graphite2]' icu`；其额外 HarfBuzz 11.3.3 完整源归档目前未取得，不应误标成已组装或实际默认链接版本。

`TECTONIC_DEP_BACKEND` 只控制 Tectonic bridge；锁定 `libz-sys 1.1.29/build.rs` 在 macOS 会检查 pkg-config/系统 zlib，再按条件回退内置源，并不因该变量自动选择 vcpkg。上述 `PKG_CONFIG_PATH` 指向已构建端口；最终实际链接对象仍应从构建日志/link map/`otool -L` 核对。AWS-LC 原生代码在选中的 `aws-lc-sys 0.42.0.crate` 内，不能因其不属于 vcpkg 就遗漏。

## 修改 TECkit 并重新链接

实际编译文件是 `crates/engine_xetex/xetex/teckit-Engine.cpp`；只修改 `reference_sources` 不会替换它。[固定 engine_xetex/build.rs](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/crates/engine_xetex/build.rs) 的 `CXX_FILES` 明列此文件，编译为 `libtectonic_engine_xetex_cxx.a`，并对 `xetex` 目录发出 `cargo:rerun-if-changed`。因此无需拆解现有 Mach-O 或修改签名应用：在上面独立源码副本中修改该 `.cpp`，保留原始版权/许可证并记录补丁，然后用相同环境重新构建最终可执行文件。

```sh
cd "$D/tectonic"
# 在此副本的 crates/engine_xetex/xetex/teckit-Engine.cpp 做所需修改并保存。
cargo clean -p tectonic_engine_xetex --release --target aarch64-apple-darwin
cargo build -p tectonic --bin tectonic --release --target aarch64-apple-darwin --frozen -vv > "$D/relink.log" 2>&1
"$D/target/aarch64-apple-darwin/release/tectonic" --version
```

清理这一个包是明确强制重新编译的步骤；正常文件变更也有 rerun 追踪。验收应保存修改补丁、构建日志、新二进制摘要，并用固定本地 TeX 资源测试中文、数学及真正触发 TECkit 映射的文档；`--version` 只证明程序可启动。可用经典 CLI 的 `--bundle <本地 bundle> --only-cached --keep-logs --outdir <输出目录> <测试.tex>` 避免联网获取排版资源，参数定义见 [compile.rs](https://github.com/tectonic-typesetting/tectonic/blob/8c0126a9653239a2e6e0a5274af9b8510f643030/src/bin/tectonic/compile.rs)。

## 尚未验证与交付边界

- 本轮工具链为 1.99.1；既有二进制 `/rustc/` 证据对应 1.97.1，后者源码材料已另收集。使用 1.97.1 重建需具备该完整工具链并复跑解析/构建；本轮没有为此下载工具链，也不把两个版本的代码生成视为相同。
- 已完成下面记录的本地重建和修改回归；尚未生成最终 linker map 或对上游发行二进制做逐对象来源证明。构建警告如实保留，测试二进制不作为产品候选替换件。
- 现有 327 项是可复核的构建依赖解析结果；未反向证明上游发行二进制每个静态对象都由该锁文件产生。官方发布脚本使用 moving stable/工具版本，且未给出本次 Release 构建证明；逐字节可复现性不作为完成修改后重链接的前提。
- 最终对应源码资产仍应包含主树、实际子模块、原生源码与端口补丁、选中 Rust 源码、所需许可原件和本构建说明；是否保留全部 437 个 resolver 输入须明确标记。忽略目录中的完整材料及处理脚本当前尚未成为正式公开资产，本文件不宣称整体许可兼容。


## 实际构建与修改回归（2026-10-23）

在上述隔离 `D` 内执行，宿主为 Apple Silicon macOS 27.0.1，Xcode Command Line Tools 的 SDK 为 macOS 13.3，Rust/Cargo 为 1.99.1，jobs=2。没有在验收 guest 安装任何开发工具。固定 vcpkg bootstrap 工具摘要与其 `scripts/vcpkg-tool-metadata.txt` 一致；关闭 binary cache，实际构建 Graphite2、FreeType、ICU、libpng、zlib 以及 FreeType 的 Brotli/bzip2 默认依赖。

宿主工具在 `D/host-tools/installed` 从官方源码独立安装：GNU m4 1.4.21、Autoconf 2.73、Automake 1.19、Libtool 2.6.2、autoconf-archive 2024.10.16、pkgconf 3.0.10；另使用本地 CMake 3.31.6。没有修改全局工具。初次原生构建暴露缺少 `pkg-config` 可执行名称，按 pkgconf 的兼容用法增加本地 `pkg-config -> pkgconf` 链接；第二次暴露缺少 autoconf-archive，补齐后 ICU 与全部端口通过。两个失败日志均保留，成功日志 SHA-256 为 `bf6399e7fe7aec0e3f308b84916c710e8c35e219bb0be4ed0d7264849c1fa4e2`。

使用 437 项隔离 vendor 解析输入执行本文 `cargo build ... --frozen`，默认功能、内置 HarfBuzz 与 Cargo.lock 均未改变。主锁文件仍为 `4a6e5c44fdb10188005cba9ae6a253fe60d79676b1cef999da669ec71c3850e9`。原始引擎构建退出 0，233.4 秒；然后仅在实际 `teckit-Engine.cpp` 添加 `<cstdio>` 与 `TECkit_CreateConverter` 内的 `std::fputs("CLAURST-TECKIT-RELINK-CHECK\n", stderr);` 测试标记，保留原版权头。清理 engine_xetex 包后相同环境重新构建，退出 0，24.3 秒。

| 证据 | SHA-256 |
| --- | --- |
| 原始构建日志 `D/baseline-engine-build.log` | `872512b1a8c07db9febeb0fdaac067ad7b86c5196284f097f13301f2d38dacc0` |
| 修改后完整日志 `D/modified-engine-build.log` | `380a34455e4a9f820d88b8ff4c4318f5dfd50d43c700fc2591cc453e98949e91` |
| 原始二进制 | `85ccedaaec8d646f10b629a56e601d170f87cbff343169ea0b911e5ffe69ba6d` |
| 修改后二进制 | `20b8177d51a3fe3101f374f014b2ebf120622b80aa7893f35484733ddab7611c` |

两者均报告 Tectonic 0.17.0。`D/build-native.py`、`D/build-engine.py`、各 JSON 收据、`D/teckit-relink.patch` 与 `D/teckit-change.json` 保存命令、耗时、退出状态、修改前后摘要。它们是隔离调查路径，公开交付的通用重建步骤在材料内 `BUILD.md`。

实际排版使用候选 build-FEED0v 的本地 bundle 和独立复制的 cache，参数为 `-X compile --untrusted --only-cached --bundle ... --keep-logs --outdir ...`。测试采用 `ctexart[UTF8,fontset=claurst]`、`lmroman10-regular.otf[Mapping=tex-text]`，包含英文引号/长破折号、中文“银杏，预算 80 元”及公式 `1+2=3`。两份结果均一页，退出 0；原始运行标记数为 0，修改后为 **14**，证明修改后的实际 TECkit 函数参与了排版，非仅二进制中出现字符串。

`D/mapping-test` 保存源文档、两份二进制、日志与 PDF。PDFium 渲染两份整页并由 Codex 视觉核对：中英文和公式清晰，无缺字、重叠或裁切；提取文本同样显示弯引号与长破折号。原始 PDF SHA-256 `daa18c2424ae2f589c867c9e80e7b489b4d0113ce67a652fabff35385dbd17d6`；修改后 `480617fb128e4d94e2d7ada7a612deb1fcd2b12c509cf46d3c2420a3c58d6bea`。早先使用 article 的简化文档因当前精简 bundle 缺 `TS1cmr.fd` 失败，已保留该日志，并改用产品支持的 ctexart 路径；没有把该失败覆盖成通用 TeX 包支持。

构建有上游 C/C++ 警告、基线 libpng 对 macOS 13.3/11.0 目标差异的 linker 警告，以及本地 Rust 的 rust-objcopy 查找 libLLVM.dylib 失败导致不能剥离调试信息的警告；构建与运行均成功，不宣称无警告或低版本兼容已验证。修改后二进制 `otool -L` 仅列系统库/Framework，未依赖本地 Homebrew/vcpkg 动态库。最终产品仍使用原签名候选的原始引擎，未加入测试标记。
