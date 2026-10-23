#!/usr/bin/env python3
"""Package only synthetic inputs and the clean-Mac acceptance instructions."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
inputs = {
    'report.pdf': 'tests/fixtures/documents/report.pdf',
    'report.docx': 'tests/fixtures/documents/report.docx',
    'sales.xlsx': 'tests/fixtures/tables/sales.xlsx',
    'sales.csv': 'tests/fixtures/tables/sales.csv',
    'scanned.pdf': 'tests/fixtures/scans/scanned.pdf',
    'printed.png': 'tests/fixtures/scans/printed.png',
}
files = {'workspace/' + name: (ROOT / source).read_bytes() for name, source in inputs.items()}
files['workspace/notes.md'] = (
    '# 合成验收素材\n项目：银杏\n实际总体、样本量和 PDF/Word 版本关系未知，不得推断。\n'
    '全部数据仅用于功能验收，不代表真实研究。\n'
).encode()
files['验收说明.md'] = (ROOT / 'docs/build/clean-mac-acceptance.md').read_bytes()
manifest = {
    'repository_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
    'provenance': 'repository_head is context only; sha256 records the exact packaged bytes, including any local edits.',
    'purpose': 'Synthetic test inputs only; no acceptance result is implied.',
    'sha256': {name: hashlib.sha256(data).hexdigest() for name, data in files.items()},
}
files['manifest.json'] = (json.dumps(manifest, ensure_ascii=False, indent=2) + '\n').encode()
parent = ROOT / '.build/packages'
parent.mkdir(parents=True, exist_ok=True)
destination = Path(tempfile.mkdtemp(prefix='acceptance-inputs-', dir=parent))
archive = destination / 'Claurst-synthetic-acceptance.zip'
with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as output:
    for name, data in files.items():
        output.writestr('claurst-acceptance/' + name, data)
(destination / 'SHA256SUMS').write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + '  ' + archive.name + '\n')
print(destination)
