#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build-tools
. scripts/env.sh
if [ ! -x "$CARGO_HOME/bin/rustup" ]; then
  curl --fail --location https://static.rust-lang.org/rustup/dist/aarch64-apple-darwin/rustup-init -o .build-tools/rustup-init
  chmod +x .build-tools/rustup-init
  .build-tools/rustup-init -y --no-modify-path --profile minimal --default-toolchain 1.99.1
fi
"$CARGO_HOME/bin/rustup" toolchain install 1.99.1 --profile minimal
"$CARGO_HOME/bin/rustup" default 1.99.1
if ! command -v cmake >/dev/null 2>&1; then
  python3 -m pip install --target .build-tools/python 'cmake==3.31.6'
fi
rustup component add rustfmt clippy
