#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
./scripts/build-desktop.sh
IFS= read -r first < .build/latest-desktop-app.txt
before=$(shasum -a 256 "$first/Contents/MacOS/ClaurstDesktop")
./scripts/build-desktop.sh
IFS= read -r second < .build/latest-desktop-app.txt
[ "$first" != "$second" ]
[ "$before" = "$(shasum -a 256 "$first/Contents/MacOS/ClaurstDesktop")" ]
codesign --verify --strict "$first"
codesign --verify --strict "$second"
./scripts/test-signing-continuity.sh "$first" "$second"
printf 'PASS: independent app builds preserve the previous executable and signatures\n'
