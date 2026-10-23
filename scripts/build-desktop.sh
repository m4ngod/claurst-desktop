#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
. scripts/env.sh
. scripts/signing-identity.sh
mkdir -p .build/desktop-builds
build_dir=$(mktemp -d "$PWD/.build/desktop-builds/build-XXXXXX")
python3 scripts/build-manifest.py capture "$build_dir/build-info.json"
cargo build --manifest-path vendor/claurst/src-rust/Cargo.toml -p claurst-acp -p claurst-tools --bin claurst-desktop-runtime --bin claurst-table-parser --locked
app="$build_dir/Claurst Desktop.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
swiftc -target arm64-apple-macos13.0 -module-cache-path .build-tools/swift-cache -parse-as-library -O \
  desktop/Sources/DesktopCore/*.swift desktop/Sources/AssistantApp/*.swift \
  -o "$app/Contents/MacOS/ClaurstDesktop"
swiftc -target arm64-apple-macos13.0 -module-cache-path .build-tools/swift-cache -parse-as-library -O \
  desktop/Sources/DocumentParser/*.swift -o "$app/Contents/Resources/claurst-document-parser"
sign_development_code "$app/Contents/Resources/claurst-document-parser" local.claurst.desktop.dev.document-parser
cp vendor/claurst/src-rust/target/debug/claurst-desktop-runtime "$app/Contents/Resources/"
cp vendor/claurst/src-rust/target/debug/claurst-table-parser "$app/Contents/Resources/"
sign_development_code "$app/Contents/Resources/claurst-table-parser" local.claurst.desktop.dev.table-parser
sign_development_code "$app/Contents/Resources/claurst-desktop-runtime" local.claurst.desktop.dev.runtime
python3 scripts/prepare-latex.py --destination "$app/Contents/Resources/latex"
sign_development_code "$app/Contents/Resources/latex/tectonic" local.claurst.desktop.dev.latex-compiler
cp vendor/claurst/LICENSE.md "$app/Contents/Resources/CLAURST-LICENSE.txt"
python3 scripts/prepare-notices.py --destination "$app/Contents/Resources/notices"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ClaurstDesktop</string>
<key>CFBundleIdentifier</key><string>local.claurst.desktop.dev</string>
<key>CFBundleName</key><string>Claurst Desktop</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
python3 scripts/build-manifest.py verify "$build_dir/build-info.json"
cp "$build_dir/build-info.json" "$app/Contents/Resources/build-info.json"
# A running app must keep the same on-disk identity for Keychain access.
# Publish a pointer only after the new bundle is fully built and sealed.
sign_development_code "$app" local.claurst.desktop.dev
codesign --verify --strict "$app"
python3 scripts/check-desktop-package.py "$app" --report "$build_dir/inspection.json"
pointer=$(mktemp "$PWD/.build/.latest-desktop-app.XXXXXX")
printf '%s\n' "$app" > "$pointer"
mv "$pointer" .build/latest-desktop-app.txt
printf 'Built %s\nRun ./scripts/open-desktop.sh to open this build.\n' "$app"
