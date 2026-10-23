#!/bin/sh
# Build three native fixtures. Launch independently, in printed order, via the UI.
# Never use CLI child launches: their responsible application can mask ACL changes.
set -eu
cd "$(dirname "$0")/.."
. scripts/env.sh
. scripts/signing-identity.sh
if [ "${1:-}" = verify ]; then
  python3 - "$2" <<'PY'
from pathlib import Path
import sys
folder = Path(sys.argv[1])
for name in ('first', 'changed-identity', 'second'):
    result = (folder / (name + '.result')).read_text()
    assert result.startswith('PASS:'), result
    print(name + ': ' + result)
PY
  exit 0
fi
# Keep fixture data outside privacy-protected Documents. The deliberately wrong
# signer must reach Keychain access rather than block on an unrelated TCC prompt.
probe_dir=$(mktemp -d /private/tmp/claurst-keychain-test-XXXXXX)
probe_service="local.claurst.desktop.signing-test.$(uuidgen)"
probe_identifier=local.claurst.desktop.dev.signing-test
for probe_name in first second changed-identity; do
  probe_app="$probe_dir/$probe_name.app"
  mkdir -p "$probe_app/Contents/MacOS"
  if [ "$probe_name" = first ]; then
    swiftc -module-cache-path .build-tools/swift-cache -parse-as-library -D FIRST_BUILD \
      desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskSigningTests.swift -o "$probe_app/Contents/MacOS/SigningProbe"
  elif [ "$probe_name" = second ]; then
    swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
      desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskSigningTests.swift -o "$probe_app/Contents/MacOS/SigningProbe"
  else
    cp "$probe_dir/second.app/Contents/MacOS/SigningProbe" "$probe_app/Contents/MacOS/SigningProbe"
  fi
  python3 - "$probe_app" "$probe_name" "$probe_dir" "$probe_service" "$probe_identifier" <<'PY'
import plistlib, sys
from pathlib import Path
app, name, folder, service, identifier = sys.argv[1:]
(Path(app) / 'Contents/Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier=identifier, CFBundleName='Claurst Signing Test', CFBundleExecutable='SigningProbe', CFBundlePackageType='APPL', LSMinimumSystemVersion='13.0', ProbeName=name, ProbeDirectory=folder, ProbeService=service)))
PY
  if [ "$probe_name" = changed-identity ]; then
    codesign --force --sign - --identifier "$probe_identifier" "$probe_app"
  else
    sign_development_code "$probe_app" "$probe_identifier"
  fi
done
./scripts/test-signing-continuity.sh "$probe_dir/first.app" "$probe_dir/second.app"
printf 'Launch first.app, changed-identity.app, then second.app independently; run and quit each.\nTest directory: %s\nDisposable Keychain service to clean after verification: %s\n' "$probe_dir" "$probe_service"
