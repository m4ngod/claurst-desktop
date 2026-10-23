#!/usr/bin/env python3
"""Check a local app's actual binaries; this does not certify clean-Mac installation."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import runpy
import subprocess

ROOT = Path(__file__).resolve().parent.parent
BUNDLE_ID = 'local.claurst.desktop.dev'


def run(*arguments):
    return subprocess.run(arguments, check=True, capture_output=True, text=True).stdout


def version(value):
    parts = tuple(int(part) for part in value.split('.'))
    return parts + (0,) * (3 - len(parts))


def verify_signature(path, identity, identifier, errors):
    requirement = f'=identifier "{identifier}" and certificate leaf = H"{identity}"'
    result = subprocess.run(['codesign', '--verify', '--strict', '-R', requirement, str(path)], capture_output=True, text=True)
    if result.returncode:
        errors.append(f'{path.name}: signature verification failed: {result.stderr.strip()}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    app = args.app.resolve()
    identity = (ROOT / '.build-tools/signing/identity.txt').read_text().strip()
    if not re.fullmatch('[0-9A-F]{40}', identity):
        raise SystemExit('Invalid pinned signing identity; configure it before checking a package.')
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    minimum = info['LSMinimumSystemVersion']
    files = {'Contents/MacOS/' + info['CFBundleExecutable']: BUNDLE_ID,
             'Contents/Resources/claurst-desktop-runtime': BUNDLE_ID + '.runtime',
             'Contents/Resources/claurst-document-parser': BUNDLE_ID + '.document-parser',
             'Contents/Resources/claurst-table-parser': BUNDLE_ID + '.table-parser',
             'Contents/Resources/latex/tectonic': BUNDLE_ID + '.latex-compiler'}
    report = {'bundle_id': info['CFBundleIdentifier'], 'declared_minimum_macos': minimum,
              'required_certificate_sha1': identity,
              'binaries': [], 'errors': [], 'clean_mac_verified': False}
    if info['CFBundleIdentifier'] != BUNDLE_ID:
        report['errors'].append('Bundle identifier does not match the fixed development identity.')
    for relative, identifier in files.items():
        path = app / relative
        architecture = run('lipo', '-archs', str(path)).strip()
        if architecture != 'arm64':
            report['errors'].append(relative + ': expected arm64, got ' + architecture)
        load = run('otool', '-l', str(path))
        match = re.search(r'\bminos\s+([\d.]+)', load)
        if match is None:
            match = re.search(r'LC_VERSION_MIN_MACOSX\s+cmdsize\s+\d+\s+version\s+([\d.]+)', load)
        actual_minimum = match.group(1) if match else None
        if actual_minimum is None or version(actual_minimum) > version(minimum):
            report['errors'].append(f'{relative}: binary requires {actual_minimum}, Info.plist declares {minimum}')
        libraries = [line.strip().split(' (', 1)[0] for line in run('otool', '-L', str(path)).splitlines()[1:]]
        for library in libraries:
            if not library.startswith(('/usr/lib/', '/System/Library/')):
                report['errors'].append(relative + ': non-system dynamic dependency ' + library)
        # Check every nested executable explicitly; top-level sealing alone is insufficient.
        verify_signature(path, identity, identifier, report['errors'])
        report['binaries'].append({'path': relative, 'architecture': architecture,
                                  'required_identifier': identifier,
                                  'minimum_macos': actual_minimum, 'libraries': libraries,
                                  'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    verify_signature(app, identity, BUNDLE_ID, report['errors'])
    try:
        report['offline_notice_files'] = runpy.run_path(str(ROOT / 'scripts/prepare-notices.py'))['verify'](
            app / 'Contents/Resources/notices')
    except (ValueError, OSError, KeyError) as error:
        report['errors'].append('Offline notice verification failed: ' + str(error))
    report['latex_manifest'] = json.loads((app / 'Contents/Resources/latex/manifest.json').read_text())
    if report['latex_manifest'].get('resource_layout'):
        try:
            runpy.run_path(str(ROOT / 'scripts/latex-resources.py'))['verify'](
                app / 'Contents/Resources/latex', report['latex_manifest'])
        except (ValueError, OSError, KeyError) as error:
            report['errors'].append('LaTeX directory bundle verification failed: ' + str(error))
    report['passed'] = not report['errors']
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    for error in report['errors']:
        print(error)
    if report['errors']:
        raise SystemExit(1)
    print('PASS: arm64 binaries, declared deployment target, system dynamic libraries and fixed signing identity; clean-Mac install remains unverified')


if __name__ == '__main__':
    main()
