# Tectonic source materials: rebuild and replace TECkit

This directory is a source and notice collection for the default Tectonic 0.17.0
macOS arm64 build. It includes 303 selected registry archives, the full main
source, both fixed submodules, native source archives, vcpkg ports and patches,
and Rust 1.97.1 standard-library sources. A local native build and modified
TECkit relink were verified with Rust 1.99.1 on 2026-10-23; see the appended
execution evidence in `tectonic-rebuild.md`. This is not an upstream-binary
reproducibility claim.

Verify the delivered files first:

```sh
shasum -a 256 -c SHA256SUMS
```

Use an Apple Silicon Mac with Xcode Command Line Tools, a Rust toolchain,
Python 3, and the native build tools required by vcpkg: m4, Autoconf,
Automake, Libtool, autoconf-archive, and pkg-config (pkgconf needs a compatible
`pkg-config` command name). CMake is also required. The upstream binary used
Rust 1.97.1; the recorded dependency resolution used Cargo 1.99.1. This is not a
promise of bit-identical rebuilding, nor a completely offline build environment.
The compiler, SDK, registry index and host build tools are separate prerequisites.

From this material directory, create a new build directory:

```sh
set -e
MATERIALS="$(pwd)"
BUILD="$MATERIALS/rebuild"
mkdir "$BUILD"
mkdir "$BUILD/tectonic" "$BUILD/vcpkg"
tar -xf "$MATERIALS/archives/tectonic-8c0126a96532.tar.gz" -C "$BUILD/tectonic" --strip-components=1
mkdir -p "$BUILD/tectonic/crates/bridge_harfbuzz/harfbuzz" "$BUILD/tectonic/reference_sources"
tar -xf "$MATERIALS/archives/harfbuzz-submodule-894a1f72ee93.tar.gz" -C "$BUILD/tectonic/crates/bridge_harfbuzz/harfbuzz" --strip-components=1
tar -xf "$MATERIALS/archives/reference-sources-70dbe0603c4b.tar.gz" -C "$BUILD/tectonic/reference_sources" --strip-components=1
tar -xf "$MATERIALS/archives/vcpkg-a62ce77d56ee.tar.gz" -C "$BUILD/vcpkg" --strip-components=1
```

The main archive does not embed its submodules: both extraction steps above are
required. Keep the supplied Cargo.lock unchanged. Native inputs can be seeded
into a vcpkg download cache using the filenames recorded in the fixed portfiles;
the archives in `archives/` preserve original bytes. The attached
`tectonic-rebuild.md` records the exact seven default native inputs and their
versions. Its investigation paths are historical, not installed directories.

Build with the default internal HarfBuzz (do not enable `external-harfbuzz`):

```sh
export VCPKG_ROOT="$BUILD/vcpkg" VCPKGRS_TRIPLET=arm64-osx TECTONIC_DEP_BACKEND=vcpkg
"$VCPKG_ROOT/bootstrap-vcpkg.sh" -disableMetrics
"$VCPKG_ROOT/vcpkg" install graphite2 freetype icu libpng zlib --triplet arm64-osx --disable-metrics
export CARGO_HOME="$BUILD/cargo-home" CARGO_TARGET_DIR="$BUILD/target"
export PKG_CONFIG_PATH="$VCPKG_ROOT/installed/arm64-osx/lib/pkgconfig"
export CC="$(xcrun -f clang)" CXX="$(xcrun -f clang++)" SDKROOT="$(xcrun --show-sdk-path)"
unset RUSTC_WRAPPER RUSTC_WORKSPACE_WRAPPER RUSTFLAGS CARGO_ENCODED_RUSTFLAGS
cd "$BUILD/tectonic"
cargo build -p tectonic --bin tectonic --release --target aarch64-apple-darwin --locked
```

This command may access official registries and tool-download endpoints. The
303 delivered `.crate` files under `rust/archives/` are source archives, not a
ready Cargo directory-source replacement. Cargo may resolve optional workspace
metadata from the lockfile even though those packages are absent from the chosen
build; do not claim that copying just these archives makes resolution offline.
Their checksums and the selected package identities are in `manifest.json` and
the original Cargo.lock. Full crate contents can be unpacked for inspection or
used with Cargo's documented source replacement/vendor workflow.

To replace the actual embedded TECkit implementation, modify
`crates/engine_xetex/xetex/teckit-Engine.cpp` in this independent source tree,
preserve its copyright and license notices, record the changes, then rebuild:

```sh
cargo clean -p tectonic_engine_xetex --release --target aarch64-apple-darwin
cargo build -p tectonic --bin tectonic --release --target aarch64-apple-darwin --locked -vv > "$BUILD/relink.log" 2>&1
"$BUILD/target/aarch64-apple-darwin/release/tectonic" --version
```

Changing `reference_sources` alone does not replace the compiled TECkit file.
The resulting binary must also be tested on a document using TECkit mapping;
`--version` is only a startup check. Use a local TeX bundle with `--only-cached`
for document tests. The original signed application need not be modified to
build and run the replacement executable. The recorded test inserted a unique
stderr marker into `TECkit_CreateConverter` in that actual `.cpp` file and added
`<cstdio>`, then rebuilt. A local document using `Mapping=tex-text` produced the
marker 14 times only with the modified binary and successfully rendered Chinese,
math, curly quotation marks and an em dash. Remove this diagnostic marker from
any normal-use build; retain original component notices. The execution record
also preserves build warnings and the tested document/bundle limitations.

The preserved component notices and the discussion in
`tectonic-distribution-path.md` describe the GPLv3 engine distribution path,
the LGPL 2.1-or-later TECkit option, Graphite's GPL alternative, and FreeType's
FTL attribution requirements. These are distinct component terms. Packaging
source materials does not by itself complete the product's publication review.
