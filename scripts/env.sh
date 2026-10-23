#!/bin/sh
# Source from project root; all compiler caches remain in this checkout.
export CARGO_HOME="$PWD/.build-tools/cargo"
export RUSTUP_HOME="$PWD/.build-tools/rustup"
export PATH="$CARGO_HOME/bin:$PWD/.build-tools/bin:$PATH"
export CLANG_MODULE_CACHE_PATH="$PWD/.build-tools/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build-tools/swift-cache"
export PATH="$PWD/.build-tools/python/cmake/data/bin:$PATH"
