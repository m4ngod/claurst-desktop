#!/usr/bin/env python3
"""Fetch fixed TeX Live package files for the app's source-material investigation."""
import argparse
import concurrent.futures
import fcntl
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import threading
import urllib.parse

ROOT = Path(__file__).resolve().parent.parent
REVISION = '082081a375be008c2e049cd7cf1137314f888b18'
TLPDB_SHA256 = 'c518358e4c5f1f512bc67af18c8f0f60c264b1722f75551fda37462ffbf88822'
# This optional AFM is not a runtime resource. Keep the unchanged TFM and
# PSNFSS sources; the separate AFM's distribution terms remain unverified.
EXCLUDED_FILES = {
    'texmf-dist/fonts/afm/adobe/zapfding/pzdr.afm': {
        'sha256': '3328cb027cca61175005fa1fd56de4fe17f7d0cbea3a4a8bfff1b6da6439c70c',
        'reason': 'Non-runtime supplementary AFM; independent distribution permission not verified.',
    },
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def confined(root, relative):
    path = root / relative
    if Path(relative).is_absolute() or '..' in Path(relative).parts:
        raise SystemExit('Invalid source path: ' + relative)
    path.resolve().relative_to(root.resolve())
    return path


def write_json(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


def make_plan(tlpdb):
    if digest(tlpdb) != TLPDB_SHA256:
        raise SystemExit('TeX Live package database differs from the fixed source revision.')
    catalog_path = ROOT / 'third_party/tex-notices/sources.json'
    catalog = json.loads(catalog_path.read_text())
    matches = [entry for entry in catalog['matches'] if entry['source_kind'] == 'texlive']
    if any(entry['revision'] != REVISION for entry in matches):
        raise SystemExit('TeX source catalog contains a different revision.')
    # Include the upstream packages for the patched format/backend and generated
    # language configuration. Complete font ZIPs are collected separately.
    names = ({entry['package'] for entry in matches} | {'latex', 'l3backend', 'hyph-utf8'}) - {'fandol', 'lm'}
    records = {block.splitlines()[0][5:]: block for block in tlpdb.read_text().split('\n\n')
               if block.startswith('name ')}
    packages = []
    files = {}
    for name in sorted(names):
        if name not in records:
            raise SystemExit('Package absent from fixed database: ' + name)
        record = records[name]
        paths = []
        section = None
        for line in record.splitlines():
            if not line.startswith(' '):
                section = line.split()[0] if line else None
            elif section in ('docfiles', 'srcfiles', 'runfiles'):
                path = line.split()[0]
                confined(ROOT, path)
                paths.append(path)
                files.setdefault(path, []).append({'package': name, 'section': section})
        packages.append({'name': name, 'tlpdb_record_sha256': hashlib.sha256(record.encode()).hexdigest(),
                         'paths': paths})
    if len({path.casefold() for path in files}) != len(files):
        raise SystemExit('Selected source paths collide on a case-insensitive filesystem.')
    if set(EXCLUDED_FILES) - files.keys():
        raise SystemExit('An excluded source file is absent from the fixed package selection.')
    if any(entry['source_path'] in EXCLUDED_FILES for entry in matches):
        raise SystemExit('An excluded source file is required by a runtime resource.')
    for path in EXCLUDED_FILES:
        del files[path]
    for package in packages:
        package['paths'] = [path for path in package['paths'] if path not in EXCLUDED_FILES]
    plan = {'revision': REVISION, 'tlpdb_sha256': TLPDB_SHA256,
            'tex_catalog_sha256': digest(catalog_path), 'excluded_font_archives': ['fandol', 'lm'],
            'excluded_files': EXCLUDED_FILES,
            'packages': packages,
            'files': [{'path': path, 'owners': files[path]} for path in sorted(files)]}
    return plan, {name: records[name] for name in sorted(names)}


def fetch_file(row, output, previous, stop=None):
    stop = stop or threading.Event()
    relative = row['path']
    destination = confined(output / 'files', relative)
    url = 'https://git.texlive.info/texlive/plain/Master/' + urllib.parse.quote(relative) + '?id=' + REVISION
    old = previous.get(relative)
    if (old and old.get('returncode') == 0 and old.get('url') == url
            and destination.is_file() and digest(destination) == old['sha256']):
        return old
    if stop.is_set():
        return dict(row, url=url, returncode=130, error='Collection interrupted.')
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.download-', dir=destination.parent) as temporary:
        downloaded = Path(temporary) / 'file'
        process = subprocess.Popen([
            'curl', '--fail', '--silent', '--show-error', '--location', '--compressed',
            '--connect-timeout', '20', '--max-time', '180', '--max-filesize', '64000000',
            url, '-o', str(downloaded),
        ], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        while process.poll() is None:
            if stop.wait(0.1):
                process.terminate()
                try:
                    process.communicate(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.communicate()
                return dict(row, url=url, returncode=130, error='Collection interrupted.')
        stderr = process.communicate()[1]
        record = dict(row, url=url, returncode=process.returncode)
        if process.returncode:
            return dict(record, error=stderr[-700:])
        data = downloaded.read_bytes()
        # Keep unsuccessful or interrupted responses out of the completed files.
        downloaded.replace(destination)
        return dict(record, sha256=hashlib.sha256(data).hexdigest(), size=len(data))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tlpdb', type=Path, required=True,
                        help='texlive.tlpdb from the fixed TeX Live revision, verified by SHA-256')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--plan-only', action='store_true')
    args = parser.parse_args()
    plan, records = make_plan(args.tlpdb)
    args.output.mkdir(parents=True, exist_ok=True)
    with (args.output / '.fetch.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise SystemExit('Another collection is using this output directory.') from None
        plan_path = args.output / 'plan.json'
        if plan_path.exists() and json.loads(plan_path.read_text()) != plan:
            raise SystemExit('Collection plan changed; choose a separate output directory.')
        if not plan_path.exists():
            write_json(plan_path, plan)
        write_json(args.output / 'package-records.json', records)
        if args.plan_only:
            print(f'Planned {len(records)} packages and {len(plan["files"])} files; no downloads performed.')
            return
        plan_hash = digest(plan_path)
        ledger = args.output / 'results.json'
        prior = json.loads(ledger.read_text()) if ledger.exists() else {'plan_sha256': plan_hash, 'files': []}
        if prior['plan_sha256'] != plan_hash:
            raise SystemExit('Saved results belong to a different collection plan.')
        previous = {row['path']: row for row in prior['files']}
        results = []

        def save():
            complete = len(results) == len(plan['files']) and all(row['returncode'] == 0 for row in results)
            # Retain earlier receipts while revalidating them, so interruption
            # does not discard successful work that this run has not reached.
            retained = {row['path']: previous[row['path']] for row in plan['files'] if row['path'] in previous}
            retained.update((row['path'], row) for row in results)
            write_json(ledger, {'plan_sha256': plan_hash, 'revision': REVISION, 'complete': complete,
                                'files': [retained[path] for path in sorted(retained)]})

        save()  # Invalidate an earlier complete=true before any revalidation.
        stop = threading.Event()
        pool = concurrent.futures.ThreadPoolExecutor(max_workers=4)
        pending = {}
        rows = iter(plan['files'])
        try:
            while True:
                while len(pending) < 4:
                    row = next(rows, None)
                    if row is None:
                        break
                    pending[pool.submit(fetch_file, row, args.output, previous, stop)] = row
                if not pending:
                    break
                done, _ = concurrent.futures.wait(pending, timeout=0.25,
                                                  return_when=concurrent.futures.FIRST_COMPLETED)
                for future in done:
                    results.append(future.result())
                    del pending[future]
                    if len(results) % 10 == 0:
                        save()
                    if len(results) % 50 == 0:
                        print(json.dumps({'finished': len(results), 'total': len(plan['files']),
                                          'failed': sum(row['returncode'] != 0 for row in results)}), flush=True)
        finally:
            stop.set()
            for future in pending:
                future.cancel()
            pool.shutdown(wait=True, cancel_futures=True)
            for future, row in pending.items():
                if future.cancelled():
                    continue
                error = future.exception()
                results.append(dict(row, returncode=1, error=str(error)) if error else future.result())
            save()
        failed = sum(row['returncode'] != 0 for row in results)
        print(f'Collected {len(results) - failed}/{len(plan["files"])} files; {failed} failed. '
              'This does not establish complete product source or redistribution requirements.')
        if failed:
            raise SystemExit(1)


if __name__ == '__main__':
    main()
