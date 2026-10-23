#!/usr/bin/env python3
"""Verify and install the checked-in offline notices without network access."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import zipfile

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'desktop/Resources/notices'


def verify(folder):
    catalog = json.loads((folder / 'index.json').read_text())
    if not (folder / 'README.txt').read_text().strip():
        raise ValueError('Notice overview is empty')
    for entry in catalog['entries']:
        path = folder / entry['path']
        if path.is_symlink() or not path.resolve().is_relative_to(folder.resolve()):
            raise ValueError('Unsafe notice path: ' + entry['path'])
        data = path.read_bytes()
        if len(data) != entry['size'] or hashlib.sha256(data).hexdigest() != entry['sha256']:
            raise ValueError('Notice differs from original: ' + entry['path'])
    return len(catalog['entries'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--destination', type=Path, required=True)
    args = parser.parse_args()
    catalog = json.loads((SOURCE / 'index.json').read_text())
    for path, digest in catalog['dependency_inputs'].items():
        if hashlib.sha256((ROOT / path).read_bytes()).hexdigest() != digest:
            raise ValueError('Dependency inputs changed; refresh notice collection: ' + path)
    entries = {item['path']: item for item in catalog['entries']}
    if len(entries) != len(catalog['entries']):
        raise ValueError('Duplicate notice catalog entries')
    with zipfile.ZipFile(SOURCE / 'originals.zip') as archive:
        members = archive.infolist()
        if len(members) != len(entries) or {x.filename for x in members} != set(entries):
            raise ValueError('Archive and notice catalog disagree')
        # Validate the full archive before creating output; never extract arbitrary paths.
        for item in members:
            parts = PurePosixPath(item.filename).parts
            if not parts or item.filename.startswith('/') or '..' in parts or item.is_dir():
                raise ValueError('Unsafe notice archive path')
            entry = entries[item.filename]
            if item.file_size != entry['size'] or item.file_size > 8 * 1024 * 1024:
                raise ValueError('Invalid notice length')
            if hashlib.sha256(archive.read(item)).hexdigest() != entry['sha256']:
                raise ValueError('Notice checksum mismatch: ' + item.filename)
        args.destination.mkdir(parents=True, exist_ok=False)
        for item in members:
            path = args.destination / item.filename
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(archive.read(item))
    for name in ('index.json', 'README.txt'):
        shutil.copyfile(SOURCE / name, args.destination / name)
    print(f'PASS: {verify(args.destination)} offline notice originals')


if __name__ == '__main__':
    main()
