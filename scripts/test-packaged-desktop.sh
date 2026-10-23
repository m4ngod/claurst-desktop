#!/bin/sh
# Exercise the actual extracted bundle, including the macOS /tmp path alias.
set -eu
cd "$(dirname "$0")/.."
if [ "$#" -ne 1 ]; then
  echo 'Usage: sh scripts/test-packaged-desktop.sh app.zip' >&2
  exit 1
fi
test_dir=$(mktemp -d /private/tmp/claurst-package-check-XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
ditto -x -k "$1" "$test_dir"
app="$test_dir/Claurst Desktop.app"
app_alias="/tmp/${test_dir##*/}/Claurst Desktop.app"
python3 scripts/check-desktop-package.py "$app" --report "$test_dir/inspection.json"
swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
  desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskResearchTests.swift \
  -o "$test_dir/research-test"
"$test_dir/research-test" --runtime "$app_alias/Contents/Resources/claurst-desktop-runtime"
printf 'PASS: current DesktopCore with extracted runtime/resources performs real mixed research through /tmp; this is not packaged UI or clean-Mac validation.\n'
