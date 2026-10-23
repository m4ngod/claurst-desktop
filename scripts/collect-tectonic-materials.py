#!/usr/bin/env python3
"""Assemble pinned Tectonic source/notice evidence without executing upstream code."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import tarfile
import tomllib

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / 'third_party/tectonic-materials/inputs.json'
NATIVE_NAMES = {
    'tectonic', 'vcpkg', 'harfbuzz-submodule', 'reference-sources',
    'fontconfig', 'graphite2', 'expat', 'brotli', 'bzip2', 'libpng', 'zlib', 'icu',
}


def digest(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def confined(root, name):
    relative = PurePosixPath(name)
    if relative.is_absolute() or '..' in relative.parts or str(relative) in ('', '.'):
        raise ValueError('Unsafe relative path: ' + name)
    candidate = root.joinpath(*relative.parts)
    candidate.resolve().relative_to(root.resolve())
    for parent in [candidate, *candidate.parents]:
        if parent == root:
            break
        if parent.is_symlink():
            raise ValueError('Symlink input/output is not permitted: ' + name)
    return candidate


def verify(path, record):
    if not path.is_file() or path.stat().st_size != record['size'] or digest(path) != record['sha256']:
        raise ValueError('Missing or changed fixed input: ' + str(path))


def assemble(args):
    catalog = json.loads(CATALOG.read_text())
    roots = {'research': args.research.resolve(), 'crates': args.crates.resolve(),
             'freetype': args.freetype.resolve()}
    documents = {}
    for entry in catalog['input_manifests']:
        path = confined(roots[entry['input']], entry['path'])
        verify(path, entry)
        documents[(entry['input'], entry['path'])] = json.loads(path.read_text())
    research = documents['research', 'source-collection-manifest.json']
    crates = documents['crates', 'manifest.json']
    closure = documents['research', 'rebuild-research/default-aarch64-normal-build.json']
    freetype = documents['freetype', 'manifest.json']
    supplements = documents['research', 'distribution-review/retrieved-originals.json']
    rust = documents['research', 'distribution-review/rust-1.97.1-notices.json']
    if any(value['tectonic_commit'] != catalog['tectonic_commit'] for value in (research, crates)):
        raise ValueError('Unexpected Tectonic revision')
    if closure['cargo_lock_sha256'] != catalog['cargo_lock_sha256']:
        raise ValueError('Dependency selection uses a different lockfile')

    # Build an explicit copy plan before creating any successful-looking output.
    plan = {}
    def add(group, source, destination, record, origin=None):
        path = confined(roots[group], source)
        verify(path, record)
        confined(args.output, destination)
        key = destination.casefold()
        if key in plan:
            raise ValueError('Duplicate or case-colliding destination: ' + destination)
        plan[key] = (path, {'path': destination, 'size': record['size'],
                           'sha256': record['sha256'], 'origin': origin or source})

    native = {entry['name']: entry for entry in research['archives']
              if entry['name'] in NATIVE_NAMES}
    if native.keys() != NATIVE_NAMES or any(x['status'] != 'downloaded' for x in native.values()):
        raise ValueError('Required complete native source archive is missing')
    for entry in native.values():
        add('research', 'archives/' + entry['filename'], 'archives/' + entry['filename'], entry, entry['url'])
    add('freetype', freetype['path'], 'archives/' + freetype['path'], freetype, freetype['url'])
    for entry in research['notice_originals']:
        add('research', entry['relative_path'], entry['relative_path'], entry,
            entry['source_archive'] + ':' + entry['archive_member'])
    for entry in freetype['notice_files']:
        add('freetype', entry['path'], 'notice-originals/freetype/' + entry['path'], entry,
            freetype['path'] + ':' + entry['archive_member'])

    # The source archive itself is the authority for the exact Cargo.lock bytes.
    main = roots['research'] / 'archives' / native['tectonic']['filename']
    with tarfile.open(main) as archive:
        member = 'tectonic-' + catalog['tectonic_commit'] + '/Cargo.lock'
        lock_bytes = archive.extractfile(member).read()
    if hashlib.sha256(lock_bytes).hexdigest() != catalog['cargo_lock_sha256']:
        raise ValueError('Main source archive and dependency lock differ')
    locked = {(x['name'], x['version']): x for x in tomllib.loads(lock_bytes.decode())['package']}
    selected = [entry for entry in closure['packages'] if entry['source']]
    local = [entry for entry in closure['packages'] if not entry['source']]
    if (len(selected), len(local)) != (catalog['selected_registry_packages'], catalog['selected_local_packages']):
        raise ValueError('Unexpected default dependency selection')
    all_crates = {(x['name'], x['version']): x for x in crates['archives']}
    if len(all_crates) != len(crates['archives']):
        raise ValueError('Duplicate crate archive records')
    packages = []
    needs_supplement = set()
    for item in selected:
        key = (item['name'], item['version'])
        entry = all_crates[key]
        if entry['sha256'] != item['checksum'] or entry['sha256'] != locked[key]['checksum']:
            raise ValueError('Selected crate checksum is not the source lock checksum: ' + str(key))
        add('crates', entry['path'], 'rust/' + entry['path'], entry, entry['url'])
        for notice in entry['notice_files']:
            add('crates', notice['path'], 'rust/' + notice['path'], notice,
                entry['url'] + '#' + notice['archive_member'])
        package_name = item['name'] + '-' + item['version']
        if not entry['notice_files']:
            needs_supplement.add(package_name)
        packages.append({key: item[key] for key in ('name', 'version', 'checksum', 'license',
                         'normal_reachable', 'build_only_addition', 'is_proc_macro')})
    supplied = set()
    for entry in supplements:
        component = PurePosixPath(entry['path']).parts[0]
        if component in needs_supplement or component in ('teckit', 'rust-1.97.1'):
            add('research', 'distribution-review/' + entry['path'],
                'supplemental-notices/' + entry['path'], entry, entry['url'])
            supplied.add(component)
    if needs_supplement - supplied:
        raise ValueError('A selected crate has no original or supplemental notice')

    std = catalog['rust_standard_library']
    add('research', std['path'], 'archives/rust-src-1.97.1.tar.xz', std, std['url'])
    for entry in rust['notice_files']:
        add('research', 'distribution-review/' + entry['path'], entry['path'], entry,
            std['url'] + '#' + entry['archive_member'])

    args.output.mkdir(parents=True, exist_ok=False)
    rows = []
    for source, record in sorted(plan.values(), key=lambda pair: pair[1]['path']):
        target = confined(args.output, record['path'])
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        verify(target, record)
        rows.append(record)

    # The pinned Rust notice index already includes both top-level licenses.
    (args.output / 'Cargo.lock').write_bytes(lock_bytes)
    for name in ('tectonic-rebuild.md', 'tectonic-distribution-path.md', 'tectonic-source-provenance.md'):
        shutil.copyfile(ROOT / 'docs/build' / name, args.output / name)
    shutil.copyfile(ROOT / 'third_party/tectonic-materials/BUILD.md', args.output / 'BUILD.md')
    shutil.copyfile(ROOT / 'vendor/claurst/LICENSE.md', args.output / 'GPL-3.0.txt')
    shutil.copyfile(CATALOG, args.output / 'input-provenance.json')
    manifest = {
        'schema_version': 1, 'tectonic_commit': catalog['tectonic_commit'],
        'cargo_lock_sha256': catalog['cargo_lock_sha256'], 'target': catalog['target'],
        'source_collection_complete_for_catalog': True, 'rebuild_verified': False,
        'redistribution_review_complete': False,
        'selection': closure['selection'], 'selection_receipt_sha256': next(
            x['sha256'] for x in catalog['input_manifests'] if x['path'].endswith('default-aarch64-normal-build.json')),
        'registry_packages': packages,
        'local_packages': [{'name': x['name'], 'version': x['version']} for x in local],
        'source_and_notice_files': rows,
        'limits': ['This is the default arm64 source closure, not a final binary linker map.',
                   'Optional and other-platform registry archives are not included.',
                   'Cargo may need registry index data to resolve the full upstream lockfile.',
                   'Compiler, SDK and other build tools are not bundled. See BUILD.md.',
                   'This collector does not perform rebuilding or modified TECkit relinking. See tectonic-rebuild.md for separate verification evidence.',
                   'Final release review remains pending.'],
    }
    (args.output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    (args.output / 'README.txt').write_text(
        'Tectonic 0.17.0 source and notice materials for aarch64-apple-darwin.\n'
        'Start with BUILD.md. Read manifest.json for the exact scope and unfinished validation.\n'
        'Original source archives and notices retain their upstream licenses.\n'
        'This collection does not itself establish final release readiness or overall license compatibility.\n')
    checksums = [digest(p) + '  ' + str(p.relative_to(args.output))
                 for p in sorted(args.output.rglob('*')) if p.is_file()]
    (args.output / 'SHA256SUMS').write_text('\n'.join(checksums) + '\n')
    print(f'Collected {len(selected)} registry sources, {len(local)} local package records, '
          f'{len(native) + 1} main/native archives and Rust 1.97.1 source: {args.output}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('research', 'crates', 'freetype', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Output must be a new directory')
    try:
        assemble(args)
    except (ValueError, KeyError, OSError, tarfile.TarError) as error:
        raise SystemExit(str(error)) from error


if __name__ == '__main__':
    main()
