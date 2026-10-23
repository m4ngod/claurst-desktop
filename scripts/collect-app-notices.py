#!/usr/bin/env python3
"""Make offline notice resources from an already verified material collection."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--materials', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    materials = args.materials.resolve()
    expected = {}
    for line in (materials / 'SHA256SUMS').read_text().splitlines():
        digest, path = line.split('  ', 1)
        parts = PurePosixPath(path).parts
        if not parts or path.startswith('/') or '..' in parts or path in expected:
            raise ValueError('Unsafe or duplicate material path: ' + path)
        expected[path] = digest

    def read(path):
        source = materials / path
        if not source.resolve().is_relative_to(materials) or source.is_symlink():
            raise ValueError('Material path escapes collection: ' + path)
        data = source.read_bytes()
        if sha(data) != expected[path]:
            raise ValueError('Material checksum mismatch: ' + path)
        return data

    documents = {}
    records = []

    def add(path, title, category, detail='', data=None):
        if path in documents:
            return
        data = read(path) if data is None else data
        documents[path] = data
        records.append(dict(path=path, title=title, category=category, detail=detail,
                            size=len(data), sha256=sha(data)))

    license_data = (ROOT / 'LICENSE').read_bytes()
    if license_data != (ROOT / 'vendor/claurst/LICENSE.md').read_bytes():
        raise ValueError('Expected the confirmed, unmodified GPLv3 text')
    add('LICENSE', 'Claurst Desktop · GPLv3', '项目许可',
        '项目新增代码采用 GPL-3.0-only；第三方保留各自条款。', license_data)

    base = 'components/claurst-and-tex/'
    inventory = json.loads(read(base + 'inventory.json'))
    for package in inventory['rust_packages']:
        title = package['name'] + ' ' + package['version']
        detail = '上游声明：' + (package['declared_license'] or '见原文')
        for notice in package['notice_files']:
            add(base + notice['path'], title + ' · ' + Path(notice['path']).name,
                'Claurst 与 Rust 依赖', detail)
        evidence = package['license_evidence']
        if evidence:
            for notice in evidence['documents']:
                note = detail
                if notice['kind'] == 'later_upstream_notice':
                    note += '。此原文来自后续 0.2.4 提交，并非 0.2.3 归档原件。'
                add(base + notice['path'], title + ' · ' + Path(notice['path']).name,
                    'Claurst 与 Rust 依赖', note)
            archive = base + evidence['source_archive']['path']
            read(archive)  # Verify the archive before reading its selected members.
            with tarfile.open(materials / archive) as tar:
                for item in evidence['source_files']:
                    member = tar.getmember(package['name'] + '-' + package['version'] + '/' + item['path'])
                    if not member.isfile():
                        raise ValueError('Expected a regular source file')
                    data = tar.extractfile(member).read()
                    if sha(data) != item['sha256']:
                        raise ValueError('Embedded notice checksum mismatch')
                    add(base + 'embedded/' + title.replace(' ', '-') + '/' + item['path'],
                        title + ' · ' + item['path'], 'Claurst 与 Rust 依赖',
                        detail + '；发布归档中的源码或声明原文。', data)

    for notice in inventory['latex_evidence']['notice_files']:
        add(base + notice['path'], notice['package'] + ' · ' + Path(notice['path']).name,
            'TeX 与字体', notice.get('url', ''))

    base = 'components/tectonic/'
    tectonic = json.loads(read(base + 'manifest.json'))
    for item in tectonic['source_and_notice_files']:
        path = item['path']
        if path.startswith(('archives/', 'rust/archives/')):
            continue
        category = 'Tectonic 与依赖'
        if path.startswith('rust-1.97.1-notices/'):
            category = 'Rust 标准库'
        add(base + path, path, category, item.get('origin', ''))

    base = 'components/rust-1.99.1/'
    rust = json.loads(read(base + 'inventory.json'))
    for item in rust['files']:
        if item['path'].startswith(('LICENSE', 'COPYRIGHT')):
            add(base + item['path'], 'Rust 1.99.1 · ' + item['path'], 'Rust 标准库')
    for name in ('LPPL-1.3c.txt', 'psnfss-README', 'psnfss-manifest.txt', 'psnfss-psfonts.dtx'):
        add('components/psnfss-9.3/' + name, 'PSNFSS 9.3 · ' + name, 'TeX 与字体')

    # Bind this collection to dependency-defining inputs, not a UI-only commit.
    inputs = ['LICENSE', 'vendor/claurst/src-rust/Cargo.lock', 'vendor/claurst/LICENSE.md',
              'scripts/prepare-latex.py', 'scripts/latex-resources.py',
              'third_party/source-han/sources.json', 'third_party/tex-notices/sources.json',
              'third_party/font-notices/sources.json', 'third_party/tex-notices/generated-sources.json',
              'third_party/tectonic-materials/inputs.json']
    inputs += [str(p.relative_to(ROOT)) for p in sorted((ROOT / 'desktop/Resources/latex').rglob('*')) if p.is_file()]
    candidate = json.loads(read('candidate/build-info.json'))
    inputs += sorted(path for path in candidate['source_sha256']
                     if path.startswith('vendor/claurst/src-rust/') and path.endswith('/Cargo.toml'))
    pinned_tectonic = json.loads((ROOT / 'third_party/tectonic-materials/inputs.json').read_text())
    for key in ('tectonic_commit', 'cargo_lock_sha256', 'target'):
        if pinned_tectonic[key] != tectonic[key]:
            raise ValueError('Tectonic inputs differ from material collection: ' + key)
    for path in inputs:
        if path in ('LICENSE', 'third_party/tectonic-materials/inputs.json'):
            continue  # Its upstream commit, lockfile and target were compared above.
        if sha((ROOT / path).read_bytes()) != candidate['source_sha256'].get(path):
            raise ValueError('Dependency input differs from material collection: ' + path)
    catalog = dict(schema_version=1, material_checksums_sha256=sha((materials / 'SHA256SUMS').read_bytes()),
                   dependency_inputs={p: sha((ROOT / p).read_bytes()) for p in inputs},
                   entries=sorted(records, key=lambda x: (x['category'], x['title'], x['path'])))
    args.output.mkdir(parents=True, exist_ok=False)
    with zipfile.ZipFile(args.output / 'originals.zip', 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for path, data in sorted(documents.items()):
            info = zipfile.ZipInfo(path, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data)
    (args.output / 'index.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
    print(f'Collected {len(records)} offline documents; {sum(len(x) for x in documents.values())} bytes')


if __name__ == '__main__':
    main()
