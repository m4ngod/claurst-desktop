#!/bin/sh
# Produce a local, inspectable candidate; publication and notarization are separate.
set -eu
cd "$(dirname "$0")/.."
if [ "$#" -gt 1 ]; then
  echo 'Usage: sh scripts/package-desktop.sh [app-path]' >&2
  exit 1
fi
if [ "$#" -eq 1 ]; then
  app=$1
else
  IFS= read -r app < .build/latest-desktop-app.txt
fi
manifest="$app/Contents/Resources/build-info.json"
revision=$(python3 - "$manifest" <<'PY'
import json, sys
from pathlib import Path
manifest = json.loads(Path(sys.argv[1]).read_text())
if manifest['uncommitted_source_inputs']:
    raise SystemExit('Commit build inputs and rebuild before packaging; this bundle contains uncommitted sources.')
print(manifest['source_revision'])
PY
)
mkdir -p .build/packages
candidate=$(mktemp -d "$PWD/.build/packages/candidate-XXXXXX")
python3 scripts/check-desktop-package.py "$app" --report "$candidate/inspection.json"
ditto -c -k --sequesterRsrc --keepParent "$app" "$candidate/Claurst-Desktop-local-arm64.zip"
git archive --format=zip --prefix=claurst-source/ --output="$candidate/source.zip" "$revision"
python3 - "$manifest" "$candidate/source.zip" <<'PY'
import hashlib, json, sys, zipfile
from pathlib import Path
manifest = json.loads(Path(sys.argv[1]).read_text())
with zipfile.ZipFile(sys.argv[2]) as archive:
    for path, expected in manifest['source_sha256'].items():
        if hashlib.sha256(archive.read('claurst-source/' + path)).hexdigest() != expected:
            raise SystemExit('Source archive does not match built input: ' + path)
PY
cp "$manifest" "$candidate/build-info.json"
sh scripts/test-packaged-desktop.sh "$candidate/Claurst-Desktop-local-arm64.zip" > "$candidate/functional-check.log" 2>&1
cat > "$candidate/README.txt" <<'TEXT'
Claurst Desktop 本地候选包

这是本机开发签名的候选包，不是公开发布版，也未完成 Developer ID 分发、公证、干净 Mac 安装与全部真实服务验收。
双击 Claurst-Desktop-local-arm64.zip 解压后可查看应用；不要覆盖正在运行的旧应用。
source.zip 是 build-info.json 指定提交的源码，inspection.json 保存实际组件、签名验证结果和依赖检查。
最低目标是 macOS 13；当前实际验证宿主为 macOS 27.0.1，不能将编译目标当作其它系统已通过安装测试。
第三方许可证及对应源码材料仍须完成发布核对，不能据此候选包声明具备公开分发条件。
TEXT
python3 - "$candidate" <<'PY'
from pathlib import Path
import hashlib, sys
root = Path(sys.argv[1])
lines = []
for path in sorted(root.iterdir()):
    if path.is_file():
        value = hashlib.sha256()
        with path.open('rb') as stream:
            for part in iter(lambda: stream.read(1024 * 1024), b''):
                value.update(part)
        lines.append(value.hexdigest() + '  ' + path.name)
(root / 'SHA256SUMS').write_text('\n'.join(lines) + '\n')
PY
printf 'Local candidate (not a public release): %s\n' "$candidate"
