#!/usr/bin/env python3
"""Record the exact public source inputs of a local desktop build."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
PREFIXES = ('desktop/Sources/', 'desktop/Resources/latex/', 'desktop/Resources/notices/', 'vendor/claurst/src-rust/',
            'tests/fixtures/latex-support/', 'third_party/source-han/')
FILES = {'LICENSE', 'scripts/build-desktop.sh', 'scripts/env.sh', 'scripts/signing-identity.sh',
         'scripts/prepare-latex.py', 'scripts/latex-resources.py', 'scripts/build-manifest.py',
         'third_party/tex-notices/sources.json', 'third_party/font-notices/sources.json',
         'third_party/tex-notices/generated-sources.json',
         'scripts/check-desktop-package.py', 'scripts/prepare-notices.py', 'vendor/claurst/LICENSE.md'}


def git(*args):
    return subprocess.run(['git', *args], cwd=ROOT, capture_output=True, check=True).stdout


def inputs():
    paths = set(git('ls-files', '--cached', '--others', '--exclude-standard', '-z').decode().split('\0'))
    return {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
            for path in sorted(paths) if path in FILES or path.startswith(PREFIXES)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['capture', 'verify'])
    parser.add_argument('manifest', type=Path)
    args = parser.parse_args()
    revision = git('rev-parse', 'HEAD').decode().strip()
    sources = inputs()
    if args.action == 'capture':
        changed = set(git('diff', '--name-only', 'HEAD', '-z').decode().split('\0'))
        changed.update(git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0'))
        manifest = {'source_revision': revision, 'source_sha256': sources,
                    'uncommitted_source_inputs': sorted(changed.intersection(sources)),
                    'profile': 'development', 'clean_mac_verified': False}
        args.manifest.write_text(json.dumps(manifest, ensure_ascii=False, sort_keys=True, indent=2) + '\n')
    else:
        before = json.loads(args.manifest.read_text())
        if before['source_revision'] != revision or before['source_sha256'] != sources:
            raise SystemExit('Source inputs changed during the build. No latest-app pointer was published; rebuild from stable sources.')


if __name__ == '__main__':
    main()
