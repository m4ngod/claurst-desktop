"""Build a pinned, flat Tectonic directory bundle; never include arbitrary cache files."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
UPSTREAM = '6ffe055852f8faf66c0acbe1a7fb27f87b869a90bad1204f3bf4d9683f597c7c'
LAYOUT = 'directory-v1'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def flat_name(name):
    if not name or name in ('.', '..') or Path(name).name != name or '/' in name or '\\' in name:
        raise ValueError('Invalid resource filename: ' + name)
    return name


def identifier(members):
    return hashlib.sha256(json.dumps(members, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def upstream_members():
    tex = json.loads((ROOT / 'third_party/tex-notices/sources.json').read_text())
    fonts = json.loads((ROOT / 'third_party/font-notices/sources.json').read_text())
    generated = json.loads((ROOT / 'third_party/tex-notices/generated-sources.json').read_text())
    if tex['bundle_identifier'] != UPSTREAM or generated['bundle_identifier'] != UPSTREAM:
        raise ValueError('Upstream resource catalog identity differs')
    entries = tex['matches'] + generated['configs'] + generated['additional_runtime_matches']
    entries += [entry for font in fonts for entry in font['matches']]
    members = {}
    for entry in entries:
        name = flat_name(entry['cache'])
        if name.startswith('Fandol') and name.endswith('.otf'):
            continue
        if name in members and members[name] != entry['sha256']:
            raise ValueError('Conflicting pinned resource: ' + name)
        members[name] = entry['sha256']
    return members


def source_han():
    return json.loads((ROOT / 'third_party/source-han/sources.json').read_text())['sources']


def prepare(cache, destination, downloads):
    """Populate a fresh destination from checked upstream and official font bytes."""
    bundle = destination / 'bundle'
    bundle.mkdir()  # Require a fresh staging directory; stale resources must not survive.
    members = upstream_members()
    for name, checksum in members.items():
        source = cache / 'bundles/data' / UPSTREAM / name
        if digest(source) != checksum:
            raise ValueError('Upstream resource changed: ' + name)
        shutil.copyfile(source, bundle / name)
    downloads.mkdir(parents=True, exist_ok=True)
    for family in source_han():
        notice = family['notice']
        source_notice = ROOT / 'third_party/source-han' / notice['path']
        if digest(source_notice) != notice['sha256']:
            raise ValueError('Source Han notice changed: ' + notice['path'])
        target_notice = destination / 'notices/source-han' / notice['path']
        target_notice.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source_notice, target_notice)
        for entry in family['files']:
            name = flat_name(entry['name'])
            local = downloads / name
            if not local.is_file() or digest(local) != entry['sha256']:
                partial = downloads / (name + '.part')
                subprocess.run(['curl', '--fail', '--location', '--retry', '2',
                                '--connect-timeout', '20', '--max-time', '600',
                                '-H', 'Accept: application/vnd.github.raw+json',
                                '--output', str(partial), entry['download_url']], check=True)
                if partial.stat().st_size != entry['size'] or digest(partial) != entry['sha256']:
                    raise ValueError('Source Han download checksum differs: ' + name)
                partial.replace(local)
            if local.stat().st_size != entry['size']:
                raise ValueError('Source Han size differs: ' + name)
            shutil.copyfile(local, bundle / name)
            members[name] = entry['sha256']
    config = ROOT / 'desktop/Resources/latex/ctex-fontset-claurst.def'
    shutil.copyfile(config, bundle / config.name)
    members[config.name] = digest(config)
    checksum = identifier(members)
    (bundle / 'SHA256SUM').write_text(checksum + '\n')
    manifest = {'resource_layout': LAYOUT, 'upstream_bundle_sha256': UPSTREAM,
                'bundle_sha256': checksum, 'members': members}
    verify(destination, manifest)
    return manifest


def verify(support, manifest):
    """Check complete membership and bytes, including the cache identity marker."""
    if manifest['resource_layout'] != LAYOUT:
        raise ValueError('Unknown LaTeX resource layout')
    bundle = support / 'bundle'
    members = manifest['members']
    for name in members:
        flat_name(name)
    if {path.name for path in bundle.iterdir()} != set(members) | {'SHA256SUM'}:
        raise ValueError('LaTeX directory bundle membership differs')
    for name, checksum in members.items():
        path = bundle / name
        if path.is_symlink() or not path.is_file() or digest(path) != checksum:
            raise ValueError('LaTeX directory resource changed: ' + name)
    checksum = identifier(members)
    if manifest['bundle_sha256'] != checksum or (bundle / 'SHA256SUM').read_text() != checksum + '\n':
        raise ValueError('LaTeX directory bundle identity differs')
