#!/usr/bin/env python3
"""Collect local dependency evidence; this is not a redistribution clearance."""
import argparse
import hashlib
import json
from pathlib import Path
import runpy
import shutil
import subprocess
import tarfile
import urllib.parse
import zipfile

try:
    import tomllib
except ModuleNotFoundError:
    raise SystemExit('Third-party evidence collection requires Python 3.11 or newer; '
                     'see docs/build/third-party-audit.md.') from None

ROOT = Path(__file__).resolve().parent.parent


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def collect_rust_source(package, source, output, locked_packages):
    if package['source'] is None:
        return {'kind': 'project_source', 'path': str(source.resolve().relative_to(ROOT.resolve()))}
    if package['source'] != 'registry+https://github.com/rust-lang/crates.io-index':
        raise SystemExit('Unsupported dependency source; add an explicit collection rule: ' + package['id'])
    name = package['name'] + '-' + package['version']
    locked = next(p for p in locked_packages if (p['name'], p['version'], p.get('source'))
                  == (package['name'], package['version'], package['source']))
    archive = source.parents[2] / 'cache' / source.parent.name / (name + '.crate')
    checksum = digest(archive)
    if locked.get('checksum') != checksum:
        raise SystemExit('Dependency source archive does not match Cargo.lock: ' + name)
    destination = output / 'rust-sources' / archive.name
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(archive, destination)
    return {'kind': 'registry_archive', 'path': str(destination.relative_to(output)),
            'sha256': checksum, 'origin': 'https://static.crates.io/crates/' + package['name'] + '/' + archive.name}


def collect_license_evidence(package, source, output, catalog, collected_source):
    """Keep embedded/canonical/later evidence distinct from exact-version notices."""
    item = next((item for item in catalog
                 if (item['name'], item['version']) == (package['name'], package['version'])), None)
    if item is None:
        return None
    name = package['name'] + '-' + package['version']
    vcs = json.loads((source / '.cargo_vcs_info.json').read_text())
    if (vcs['git']['sha1'] != item['vcs_revision']
            or package.get('license') != item['declared_license']):
        raise SystemExit('License evidence does not match package provenance: ' + name)
    expected = item['source_archive']['sha256']
    if collected_source['kind'] != 'registry_archive' or collected_source['sha256'] != expected:
        raise SystemExit('License evidence does not match the collected source archive: ' + name)
    archive = output / collected_source['path']
    with tarfile.open(archive, 'r:gz') as contents:
        for entry in item['source_files']:
            local_source = source / entry['path']
            local_source.resolve().relative_to(source.resolve())
            data = contents.extractfile(name + '/' + entry['path']).read()
            if (hashlib.sha256(data).hexdigest() != entry['sha256']
                    or digest(local_source) != entry['sha256']):
                raise SystemExit('License evidence source member does not match: ' + name)
    evidence = dict(item)
    evidence['source_archive'] = dict(item['source_archive'], path=collected_source['path'])
    evidence['documents'] = []
    evidence_root = ROOT / 'third_party/rust-evidence'
    for entry in item['documents']:
        original = evidence_root / entry['path']
        original.resolve().relative_to(evidence_root.resolve())
        if digest(original) != entry['sha256']:
            raise SystemExit('License evidence document digest does not match: ' + name)
        destination = output / 'rust-evidence' / original.relative_to(evidence_root)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(original, destination)
        evidence['documents'].append(dict(entry, path=str(destination.relative_to(output))))
    return evidence


def confined_path(root, relative):
    path = root / relative
    if Path(relative).is_absolute():
        raise SystemExit('Evidence paths must be relative: ' + str(relative))
    path.resolve().relative_to(root.resolve())
    return path


def collect_font_archive(font, archives, output):
    """Preserve the complete upstream distribution, without claiming preferred source."""
    record = {key: font[key] for key in ('name', 'version', 'url', 'archive_sha256')}
    if archives is None:
        return dict(record, status='not_collected')
    archive = confined_path(archives, font['name'] + '.zip')
    if not archive.is_file() or digest(archive) != font['archive_sha256']:
        raise SystemExit('Font archive missing or differs from the catalog: ' + str(archive))
    # Check the declared members as well as the archive: a catalog update must
    # not silently break its association with app resources or original notices.
    with zipfile.ZipFile(archive) as contents:
        members = contents.namelist()
        expected = [(path, entry['sha256']) for entry in font['matches']
                    for path in entry['archive_paths']]
        expected.extend((entry['archive_path'], entry['sha256']) for entry in font['notice_files'])
        for path, checksum in expected:
            if members.count(path) != 1 or hashlib.sha256(contents.read(path)).hexdigest() != checksum:
                raise SystemExit('Font archive member differs from the catalog: ' + path)
    destination = confined_path(output / 'font-distributions', font['name'] + '.zip')
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(archive, destination)
    return dict(record, status='collected', path=str(destination.relative_to(output)),
                size=destination.stat().st_size)


def collect_tex_packages(sources, database, output):
    """Validate and preserve the fixed package selection, not all TeX sources."""
    if sources is None and database is None:
        return {'status': 'not_collected'}
    if sources is None or database is None:
        raise SystemExit('--tex-sources and --tex-package-database must be supplied together.')
    planner = runpy.run_path(str(ROOT / 'scripts/fetch-tex-package-sources.py'))
    expected_plan, expected_records = planner['make_plan'](database)
    plan_path = confined_path(sources, 'plan.json')
    plan_bytes = plan_path.read_bytes()
    if json.loads(plan_bytes) != expected_plan:
        raise SystemExit('TeX package source plan differs from the fixed database/catalog.')
    records_path = confined_path(sources, 'package-records.json')
    records_bytes = records_path.read_bytes()
    if json.loads(records_bytes) != expected_records:
        raise SystemExit('TeX package records differ from the fixed database.')
    ledger_path = confined_path(sources, 'results.json')
    ledger_bytes = ledger_path.read_bytes()
    ledger = json.loads(ledger_bytes)
    database_bytes = database.read_bytes()
    if hashlib.sha256(database_bytes).hexdigest() != planner['TLPDB_SHA256']:
        raise SystemExit('TeX package database changed during validation.')
    if (ledger.get('complete') is not True
            or ledger.get('plan_sha256') != hashlib.sha256(plan_bytes).hexdigest()
            or ledger.get('revision') != expected_plan['revision']):
        raise SystemExit('TeX package source collection is incomplete or belongs to another plan.')
    rows = ledger['files']
    receipts = {row['path']: row for row in rows}
    paths = {row['path'] for row in expected_plan['files']}
    if len(receipts) != len(rows) or set(receipts) != paths:
        raise SystemExit('TeX source receipts have missing, extra or duplicate paths.')
    for entry in expected_plan['files']:
        path = entry['path']
        row = receipts[path]
        url = ('https://git.texlive.info/texlive/plain/Master/'
               + urllib.parse.quote(path) + '?id=' + expected_plan['revision'])
        source = confined_path(sources / 'files', path)
        if (row.get('returncode') != 0 or row.get('owners') != entry['owners']
                or row.get('url') != url or not source.is_file()
                or source.stat().st_size != row.get('size') or digest(source) != row.get('sha256')):
            raise SystemExit('TeX source receipt or bytes differ: ' + path)
    catalog = json.loads((ROOT / 'third_party/tex-notices/sources.json').read_text())
    for entry in catalog['matches']:
        if entry['source_kind'] == 'texlive' and entry['package'] not in expected_plan['excluded_font_archives']:
            if receipts.get(entry['source_path'], {}).get('sha256') != entry['sha256']:
                raise SystemExit('TeX package source differs from the app resource evidence: ' + entry['cache'])
    destination = output / 'tex-package-sources'
    destination.mkdir(parents=True, exist_ok=False)
    metadata = [(plan_bytes, 'plan.json'), (records_bytes, 'package-records.json'),
                (ledger_bytes, 'results.json'), (database_bytes, 'texlive.tlpdb')]
    files = [(confined_path(sources / 'files', path), 'files/' + path) for path in sorted(paths)]
    copied = []
    for source, relative in metadata + files:
        expected = (hashlib.sha256(source).hexdigest() if isinstance(source, bytes)
                    else receipts[relative[6:]]['sha256'])
        target = confined_path(destination, relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(source, bytes):
            target.write_bytes(source)
        else:
            shutil.copyfile(source, target)
        if digest(target) != expected:
            raise SystemExit('TeX package material changed while copying: ' + relative)
        copied.append({'path': relative, 'sha256': expected, 'size': target.stat().st_size})
    manifest = destination / 'manifest.json'
    manifest.write_text(json.dumps({'files': copied}, indent=2) + '\n')
    return {'status': 'collected', 'revision': expected_plan['revision'],
            'packages': len(expected_plan['packages']), 'package_files': len(paths),
            'package_file_bytes': sum(row['size'] for row in rows),
            'manifest': str(manifest.relative_to(output)), 'manifest_sha256': digest(manifest),
            'scope': 'Selected fixed TeX Live packages: docfiles, srcfiles and runfiles; '
                     'explicit file exclusions are recorded in plan.json. '
                     'font distributions and bundler patches are separate. Not complete product source.'}


def collect_latex_extras(latex, output, files, sources):
    """Preserve derived-config evidence separately from unchanged upstream files."""
    if sources is None:
        return {'status': 'not_collected', 'derived_data_files': [],
                'additional_runtime_matches': [], 'catalog_files_not_in_app': []}
    catalog_path = ROOT / 'third_party/tex-notices/generated-sources.json'
    catalog_bytes = catalog_path.read_bytes()
    catalog = json.loads(catalog_bytes)
    manifest = json.loads((latex / 'manifest.json').read_text())
    identifier = manifest.get('upstream_bundle_sha256', manifest['bundle_sha256'])
    if catalog['schema_version'] != 1 or catalog['bundle_identifier'] != identifier:
        raise SystemExit('Generated LaTeX source catalog differs from the app bundle.')
    source_bytes = {}
    for entry in catalog['sources']:
        path = entry['path']
        if path.casefold() in {item.casefold() for item in source_bytes}:
            raise SystemExit('Duplicate generated LaTeX source path: ' + path)
        data = confined_path(sources, path).read_bytes()
        if len(data) != entry['size'] or hashlib.sha256(data).hexdigest() != entry['sha256']:
            raise SystemExit('Generated LaTeX source bytes differ: ' + path)
        if 'git_blob_sha1' in entry:
            blob = b'blob ' + str(len(data)).encode() + b'\0' + data
            if hashlib.sha1(blob).hexdigest() != entry['git_blob_sha1']:
                raise SystemExit('Generated LaTeX Git blob differs: ' + path)
        source_bytes[path] = data
    transformer_path = ROOT / 'scripts/latex-source-transforms.py'
    transformer = runpy.run_path(str(transformer_path))['reconstruct']
    generated = {entry['cache']: transformer(entry, source_bytes) for entry in catalog['configs']}
    if len(generated) != len(catalog['configs']):
        raise SystemExit('Duplicate generated LaTeX cache name.')
    prefix = 'bundle/' if manifest.get('resource_layout') == 'directory-v1' else 'cache/bundles/data/' + identifier + '/'
    derived = []
    additional = []
    absent = []

    def match_app(entry, data, records, collected_file):
        name = entry['cache']
        if Path(name).is_absolute() or len(Path(name).parts) != 1 or name in ('.', '..'):
            raise SystemExit('Invalid generated LaTeX cache name: ' + name)
        relative = prefix + name
        if relative not in files:
            absent.append(relative)
            return
        if files[relative] != entry['sha256'] or confined_path(latex, relative).read_bytes() != data:
            raise SystemExit('App LaTeX resource differs from derived evidence: ' + name)
        records.append({'path': relative, 'sha256': entry['sha256'],
                        'evidence': entry, 'collected_file': 'latex-extra-sources/'
                        + collected_file})

    for entry in catalog['configs']:
        match_app(entry, generated[entry['cache']], derived, 'generated/' + entry['cache'])
    for entry in catalog['additional_runtime_matches']:
        match_app(entry, source_bytes[entry['source_path']], additional, entry['source_path'])
    material = dict(source_bytes)
    material.update(('generated/' + name, data) for name, data in generated.items())
    material['catalog.json'] = catalog_bytes
    material['latex-source-transforms.py'] = transformer_path.read_bytes()
    destination = output / 'latex-extra-sources'
    destination.mkdir(parents=True, exist_ok=False)
    copied = []
    for relative, data in material.items():
        target = confined_path(destination, relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        checksum = hashlib.sha256(data).hexdigest()
        if digest(target) != checksum:
            raise SystemExit('Generated LaTeX material changed while copying: ' + relative)
        copied.append({'path': str(target.relative_to(output)), 'sha256': checksum, 'size': len(data)})
    return {'status': 'collected', 'catalog_sha256': hashlib.sha256(catalog_bytes).hexdigest(),
            'source_files': copied, 'derived_data_files': derived,
            'additional_runtime_matches': additional, 'catalog_files_not_in_app': absent,
            'limitations': catalog['limitations']}


def collect_latex_evidence(latex, output, tex_files, font_archives=None,
                           tex_sources=None, tex_package_database=None, latex_extra_sources=None):
    """Bind partial upstream evidence to the files actually inside this app."""
    tex_root = ROOT / 'third_party/tex-notices'
    font_root = ROOT / 'third_party/font-notices'
    catalog = json.loads((tex_root / 'sources.json').read_text())
    fonts = json.loads((font_root / 'sources.json').read_text())
    manifest = json.loads((latex / 'manifest.json').read_text())
    identifier = catalog['bundle_identifier']
    if catalog['schema_version'] != 1 or manifest.get('upstream_bundle_sha256', manifest['bundle_sha256']) != identifier:
        raise SystemExit('LaTeX evidence catalog does not match the app bundle identifier.')
    directory_bundle = manifest.get('resource_layout') == 'directory-v1'
    if manifest.get('resource_layout') and not directory_bundle:
        raise SystemExit('Unknown LaTeX resource layout')
    if directory_bundle:
        runpy.run_path(str(ROOT / 'scripts/latex-resources.py'))['verify'](latex, manifest)
    prefix = 'bundle/' if directory_bundle else 'cache/bundles/data/' + identifier + '/'
    files = {entry['path']: entry['sha256'] for entry in tex_files}
    matched = {}
    absent = []
    notices = []
    used_fonts = []

    def add_match(entry, provenance):
        name = entry['cache']
        if Path(name).is_absolute() or len(Path(name).parts) != 1 or name in ('.', '..'):
            raise SystemExit('Invalid cache filename in LaTeX evidence: ' + name)
        relative = prefix + name
        if relative not in files:
            absent.append(relative)
            return None
        source = confined_path(latex, relative)
        if files[relative] != entry['sha256'] or digest(source) != entry['sha256']:
            raise SystemExit('LaTeX resource differs from its upstream evidence: ' + relative)
        matched.setdefault(relative, {'path': relative, 'sha256': entry['sha256'],
                                      'upstream_evidence': []})['upstream_evidence'].append(provenance)
        return source

    def copy_notice(root, entry, category, provenance):
        original = confined_path(root, entry['path'])
        if digest(original) != entry['sha256']:
            raise SystemExit('LaTeX notice digest differs from its catalog: ' + entry['path'])
        destination = confined_path(output / 'latex-notices' / category, entry['path'])
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(original, destination)
        notices.append(dict(provenance, path=str(destination.relative_to(output)), sha256=entry['sha256']))

    for entry in catalog['matches']:
        provenance = {key: entry[key] for key in ('package', 'source_path', 'url', 'revision', 'source_kind')}
        source = add_match(entry, provenance)
        if source is not None:
            destination = confined_path(output / 'latex-resource-files',
                                        entry['source_kind'] + '/' + entry['source_path'])
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
            provenance['collected_file'] = str(destination.relative_to(output))
    for entry in catalog['notice_files']:
        copy_notice(tex_root, entry, 'tex',
                    {key: entry[key] for key in ('package', 'source_path', 'url', 'revision')})
    for font in fonts:
        used = False
        for entry in font['matches']:
            source = add_match(entry, {'package': font['name'], 'version': font['version'],
                              'url': font['url'], 'archive_sha256': font['archive_sha256'],
                              'archive_paths': entry['archive_paths'], 'source_kind': 'font_distribution'})
            used = used or source is not None
        if used:
            used_fonts.append(font)
        for entry in font['notice_files'] if used else []:
            copy_notice(font_root, entry, 'fonts',
                        {'package': font['name'], 'version': font['version'], 'url': font['url'],
                         'archive_sha256': font['archive_sha256'], 'archive_path': entry['archive_path']})
    project_resources = []
    if directory_bundle:
        han_root = ROOT / 'third_party/source-han'
        han = json.loads((han_root / 'sources.json').read_text())
        for family in han['sources']:
            for entry in family['files']:
                source = add_match(dict(entry, cache=entry['name']),
                                   {'package': family['repo'], 'revision': family['commit'],
                                    'url': entry['url'], 'source_kind': 'official_font_binary'})
                if source is None:
                    raise SystemExit('Missing Source Han font: ' + entry['name'])
                target = output / 'source-han' / entry['name']
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)
            notice = family['notice']
            packaged = confined_path(latex / 'notices/source-han', notice['path'])
            if digest(packaged) != notice['sha256']:
                raise SystemExit('Packaged Source Han notice differs: ' + notice['path'])
            copy_notice(han_root, notice, 'source-han',
                        {'package': family['repo'], 'revision': family['commit'], 'url': family['license_url']})
        config = ROOT / 'desktop/Resources/latex/ctex-fontset-claurst.def'
        resource = confined_path(latex, prefix + config.name)
        if digest(resource) != digest(config):
            raise SystemExit('Project font configuration differs from the application')
        project_resources.append({'path': prefix + config.name, 'sha256': digest(config),
                                  'source_path': str(config.relative_to(ROOT)),
                                  'source_kind': 'project_source'})
        config_target = output / 'latex-project-resources' / config.name
        config_target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(config, config_target)
        shutil.copyfile(han_root / 'sources.json', output / 'source-han/sources.json')
    # Index and prefetch files live beside the bundle directories, not inside one.
    data_files = ({'bundle/' + name for name in manifest['members']} if directory_bundle else
                  {entry['path'] for entry in tex_files
                   if entry['path'].startswith('cache/bundles/data/') and len(Path(entry['path']).parts) > 4})
    extras = collect_latex_extras(latex, output, files, latex_extra_sources)
    derived_files = {entry['path'] for entry in extras['derived_data_files']}
    project_files = {entry['path'] for entry in project_resources}
    return {
        'source_requirements_complete': False,
        'bundle_identifier': identifier,
        'tex_catalog_sha256': digest(tex_root / 'sources.json'),
        'font_catalog_sha256': digest(font_root / 'sources.json'),
        'matched_data_files': [matched[key] for key in sorted(matched)],
        'derived_data_files': extras['derived_data_files'],
        'project_data_files': project_resources,
        'data_files_without_source_match': [entry for entry in tex_files
                                            if entry['path'] in data_files and entry['path'] not in matched
                                            and entry['path'] not in derived_files and entry['path'] not in project_files],
        'other_cache_files': [entry for entry in tex_files
                              if entry['path'] not in data_files],
        'catalog_files_not_in_app': sorted(set(absent + extras['catalog_files_not_in_app'])),
        'notice_files': notices,
        'font_distributions': [collect_font_archive(font, font_archives, output) for font in used_fonts],
        'tex_packages': collect_tex_packages(tex_sources, tex_package_database, output),
        'extra_source_evidence': extras,
        'limitations': catalog['limitations'],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--font-archives', type=Path,
                        help='Directory containing the catalog-matched fandol.zip and lm.zip; '
                             'omitting it records these distributions as not collected.')
    parser.add_argument('--tex-sources', type=Path,
                        help='Completed output of fetch-tex-package-sources.py.')
    parser.add_argument('--tex-package-database', type=Path,
                        help='Fixed texlive.tlpdb used to independently regenerate the package plan.')
    parser.add_argument('--latex-extra-sources', type=Path,
                        help='Directory of catalog-matched generated-config and XeTeX source originals.')
    args = parser.parse_args()
    if (args.tex_sources is None) != (args.tex_package_database is None):
        parser.error('--tex-sources and --tex-package-database must be supplied together.')
    resources = args.app.resolve() / 'Contents/Resources'
    build_info = json.loads((resources / 'build-info.json').read_text())
    snapshot = runpy.run_path(str(ROOT / 'scripts/build-manifest.py'))['inputs']()
    relevant = lambda path: path.startswith('vendor/claurst/src-rust/') or path == 'vendor/claurst/LICENSE.md'
    expected = {path: value for path, value in build_info['source_sha256'].items() if relevant(path)}
    actual = {path: value for path, value in snapshot.items() if relevant(path)}
    if expected != actual:
        raise SystemExit('App and current Rust source/notice inputs differ; use matching sources.')
    lock = 'vendor/claurst/src-rust/Cargo.lock'
    metadata = json.loads(subprocess.check_output([
        'cargo', 'metadata', '--format-version', '1', '--locked', '--offline',
        '--filter-platform', 'aarch64-apple-darwin', '--manifest-path',
        str(ROOT / 'vendor/claurst/src-rust/Cargo.toml'),
    ], cwd=ROOT))
    packages = {package['id']: package for package in metadata['packages']}
    nodes = {node['id']: node for node in metadata['resolve']['nodes']}
    pending = [p['id'] for p in packages.values() if p['name'] in ('claurst-acp', 'claurst-tools')]
    if len(pending) != 2:
        raise SystemExit('Expected both desktop runtime dependency roots.')
    included = set()
    while pending:
        package_id = pending.pop()
        if package_id in included:
            continue
        included.add(package_id)
        pending.extend(dep['pkg'] for dep in nodes[package_id]['deps']
                       if any(kind['kind'] != 'dev' for kind in dep['dep_kinds']))
    args.output.mkdir(parents=True, exist_ok=False)
    supplements_root = ROOT / 'third_party/rust-notices'
    supplements = json.loads((supplements_root / 'sources.json').read_text())
    evidence_catalog_path = ROOT / 'third_party/rust-evidence/sources.json'
    evidence_catalog = json.loads(evidence_catalog_path.read_text())
    locked_packages = tomllib.loads((ROOT / lock).read_text())['package']
    records = []
    missing = []
    for package_id in sorted(included, key=lambda key: (packages[key]['name'], packages[key]['version'])):
        package = packages[package_id]
        source = Path(package['manifest_path']).parent
        name = package['name'] + '-' + package['version']
        collected_source = collect_rust_source(package, source, args.output, locked_packages)
        notices = []
        for path in sorted(source.rglob('*')):
            if path.is_symlink() or not path.is_file():
                continue
            upper = path.name.upper()
            if upper.startswith(('LICENSE', 'LICENCE', 'COPYING', 'NOTICE', 'UNLICENSE', 'COPYRIGHT')):
                # A symlinked parent must not turn a notice into an outside file.
                try:
                    path.resolve().relative_to(source.resolve())
                except ValueError:
                    continue
                relative = path.relative_to(source)
                destination = args.output / 'rust' / name / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(path, destination)
                notices.append({'path': str(destination.relative_to(args.output)), 'sha256': digest(path)})
        declaration = package.get('license')
        if not notices and package['name'].startswith('claurst-') and package['source'] is None:
            upstream = ROOT / 'vendor/claurst/LICENSE.md'
            destination = args.output / 'rust' / name / 'LICENSE.md'
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(upstream, destination)
            notices.append({'path': str(destination.relative_to(args.output)), 'sha256': digest(upstream),
                            'origin': 'vendor/claurst/LICENSE.md; upstream project notice'})
        if not notices:
            for item in supplements:
                if (item['name'], item['version']) != (package['name'], package['version']):
                    continue
                original = supplements_root / item['path']
                original.resolve().relative_to(supplements_root.resolve())
                vcs = json.loads((source / '.cargo_vcs_info.json').read_text())
                if vcs['git']['sha1'] != item['vcs_revision'] or digest(original) != item['sha256']:
                    raise SystemExit('Supplemental notice does not match package provenance: ' + name)
                destination = args.output / 'rust' / name / original.name
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(original, destination)
                notices.append({'path': str(destination.relative_to(args.output)), 'sha256': item['sha256'],
                                'origin': item['url'], 'vcs_revision': item['vcs_revision']})
        if not notices:
            missing.append(name)
        records.append({'name': package['name'], 'version': package['version'],
                        'declared_license': declaration, 'repository': package.get('repository'),
                        'source': package['source'], 'notice_files': notices,
                        'collected_source': collected_source,
                        'license_evidence': collect_license_evidence(
                            package, source, args.output, evidence_catalog, collected_source)})
    latex = resources / 'latex'
    tex_files = [{'path': str(path.relative_to(latex)), 'sha256': digest(path)}
                 for folder in ('cache', 'bundle') for path in sorted((latex / folder).rglob('*')) if path.is_file()]
    report = {
        'redistribution_review_complete': False,
        'app_source_revision': build_info['source_revision'],
        'cargo_lock_sha256': digest(ROOT / lock),
        'collector_script_sha256': digest(Path(__file__)),
        'supplement_catalog_sha256': digest(supplements_root / 'sources.json'),
        'license_evidence_catalog_sha256': digest(evidence_catalog_path),
        'scope': 'Conservative normal/build closure for arm64 macOS; workspace feature union may include unused crates.',
        'rust_packages': records,
        'rust_packages_without_notice_files': missing,
        'latex_manifest': json.loads((latex / 'manifest.json').read_text()),
        'latex_cache_files': tex_files,
        'latex_evidence': collect_latex_evidence(latex, args.output, tex_files, args.font_archives,
                                                args.tex_sources, args.tex_package_database, args.latex_extra_sources),
        'remaining': ['Resolve missing crate notices and source requirements.',
                      'Audit Tectonic native/transitive components and corresponding sources.',
                      'Map every cached TeX/font/format resource to its matching version, notice and source requirements.'],
    }
    (args.output / 'inventory.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    (args.output / 'README.txt').write_text(
        'Local dependency evidence only; not a complete notice bundle or permission to publish.\n'
        'Rust notices preserve bytes from installed locked packages or version-pinned upstream supplements.\n'
        'Separate license_evidence records retain embedded source notices, canonical texts and later upstream files.\n'
        'Those records do not remove packages from the missing independent notice list.\n'
        'rust-sources preserves all registry archives in this conservative runtime dependency closure, verified against Cargo.lock.\n'
        'Local project sources are referenced by repository path and app_source_revision; use the matching project source ZIP.\n'
        'This does not include all Tectonic/native/font/TeX preferred sources or establish overall redistribution compliance.\n'
        'latex-resource-files preserves matched runtime resource bytes; it is not the complete preferred source of every package.\n'
        'latex_evidence separately lists unmatched data, cache metadata and partial notice materials.\n'
        'font-distributions, when requested, preserves complete catalog-matched upstream ZIPs; '
        'their contents do not establish that all preferred sources are included.\n'
        'tex-package-sources, when requested, preserves the complete fixed package selection with its database, '
        'plan and verified download receipts; it is not all TeX Live or complete product source.\n'
        'latex-extra-sources, when requested, preserves explicit generated-config recipes, their fixed '
        'source inputs and XeTeX project evidence; derived matches remain distinct from unchanged upstream files.\n'
        'Declarations do not establish license compatibility. Read inventory.json remaining items.\n')
    latex_evidence = report['latex_evidence']
    print(f'Collected {len(records)} Rust package records; {len(missing)} lack notice files; '
          f'{len(tex_files)} LaTeX cache files inventoried, '
          f'{len(latex_evidence["matched_data_files"])} data files matched, '
          f'{len(latex_evidence["derived_data_files"])} data files linked by explicit transformations, '
          f'{len(latex_evidence["data_files_without_source_match"])} data files unmatched. '
          f'Review remains incomplete: {args.output}')


if __name__ == '__main__':
    main()
