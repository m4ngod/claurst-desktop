#!/usr/bin/env python3
"""Prepare public, fixed LaTeX resources at build time; never compile user input here."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import runpy
import shutil
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / '.build-tools'
VERSION = '0.17.0'
ARCHIVE_SHA256 = 'a3f1cac7c5678f01661a92212f58480ae3b0634115d880dbc59e2953ded45667'
DOWNLOAD = 'https://github.com/tectonic-typesetting/tectonic/releases/download/tectonic%400.17.0/tectonic-0.17.0-aarch64-apple-darwin.tar.gz'
BUNDLE = 'https://relay.fullyjustified.net/default_bundle_v33.tar'
BUNDLE_SHA256 = '6ffe055852f8faf66c0acbe1a7fb27f87b869a90bad1204f3bf4d9683f597c7c'


def digest(path):
    with path.open('rb') as stream:
        result = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--destination', type=Path, required=True)
    args = parser.parse_args()
    if platform.system() != 'Darwin' or platform.machine() != 'arm64':
        raise SystemExit('首个桌面版本只支持 Apple 芯片 Mac。')
    BUILD.mkdir(exist_ok=True)
    archive = BUILD / f'tectonic-{VERSION}.tar.gz'
    if not archive.exists() or digest(archive) != ARCHIVE_SHA256:
        subprocess.run(['curl', '--fail', '--location', '--http1.1', '--retry', '2',
                        '--connect-timeout', '20', '--max-time', '900', '--continue-at', '-',
                        '--output', str(archive), DOWNLOAD], check=True)
    if digest(archive) != ARCHIVE_SHA256:
        raise SystemExit('Tectonic 文件校验失败，未运行编译器。请移除损坏的构建缓存后重试。')
    compiler = BUILD / f'tectonic-{VERSION}' / 'tectonic'
    compiler.parent.mkdir(exist_ok=True)
    with tarfile.open(archive, 'r:gz') as package:
        member = next((item for item in package.getmembers() if item.name == 'tectonic' and item.isfile()), None)
        if member is None:
            raise SystemExit('官方编译器压缩包结构不受支持。')
        with package.extractfile(member) as source, compiler.open('wb') as destination:
            shutil.copyfileobj(source, destination)
    compiler.chmod(0o755)
    cache = BUILD / 'tectonic-cache-v33'
    cache.mkdir(exist_ok=True)
    fixtures = ROOT / 'tests/fixtures/latex-support'
    fixture_hashes = {str(path.relative_to(fixtures)): digest(path) for path in sorted(fixtures.rglob('*')) if path.is_file()}
    stamp = {'compiler': VERSION, 'archive_sha256': ARCHIVE_SHA256, 'bundle': BUNDLE,
             'bundle_sha256': BUNDLE_SHA256, 'fixtures': fixture_hashes}
    marker = BUILD / 'latex-prepared.json'
    prepared = marker.exists() and json.loads(marker.read_text()) == stamp
    environment = {**os.environ, 'TECTONIC_CACHE_DIR': str(cache), 'TECTONIC_UNTRUSTED_MODE': '1'}
    with tempfile.TemporaryDirectory(prefix='latex-prepare-', dir=BUILD) as temporary:
        output = Path(temporary) / 'output'
        output.mkdir()
        seed = Path(temporary) / 'seed'
        shutil.copytree(fixtures, seed)
        # The fixed upstream bundle predates our font set. Only this build-time
        # seed uses its original fonts to populate the pinned TeX/Latin resources.
        for source in seed.rglob('*.tex'):
            source.write_text(source.read_text().replace('fontset=claurst', 'fontset=fandol'))
        # First try offline. Only fixed repository fixtures may fetch missing resources.
        for name in ['minimal.tex', 'main.tex', 'fonts10.tex', 'fonts11.tex', 'fonts12.tex']:
            command = [str(compiler), '-X', 'compile', '--untrusted', '--bundle', BUNDLE,
                       '--keep-logs', '--keep-intermediates', '--outdir', str(output), str(seed / name)]
            if prepared:
                result = subprocess.run(command[:4] + ['--only-cached'] + command[4:],
                                        env=environment, capture_output=True, timeout=180)
                if result.returncode == 0:
                    continue
            subprocess.run(command, env=environment, check=True, timeout=900)
    bundle_hash = cache / 'bundles/hashes/https,58,,47,,47,relay.fullyjustified.net,47,default_bundle_v33.tar'
    if bundle_hash.read_text().strip() != BUNDLE_SHA256:
        raise SystemExit('排版资源版本与已验证版本不同，未打包；需重新核验资源后更新固定版本。')
    marker.write_text(json.dumps(stamp, ensure_ascii=False, sort_keys=True, indent=2) + '\n')
    target = args.destination.resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    staging = tempfile.TemporaryDirectory(prefix='latex-staging-', dir=target.parent)
    destination = Path(staging.name)
    shutil.copy2(compiler, destination / 'tectonic')
    resources = runpy.run_path(str(ROOT / 'scripts/latex-resources.py'))
    local = resources['prepare'](cache, destination, BUILD / 'source-han')
    # Generate formats for our own bundle identity, using fixed fixtures only.
    # Upstream Fandol fonts are never copied into the application.
    with tempfile.TemporaryDirectory(prefix='latex-local-', dir=BUILD) as temporary:
        project = Path(temporary) / 'project'
        shutil.copytree(fixtures, project)
        output = Path(temporary) / 'output'
        output.mkdir()
        local_cache = destination / 'cache'
        local_cache.mkdir()
        environment['TECTONIC_CACHE_DIR'] = str(local_cache)
        for name in ['minimal.tex', 'main.tex', 'fonts10.tex', 'fonts11.tex', 'fonts12.tex', 'chinese-styles.tex']:
            subprocess.run([str(compiler), '-X', 'compile', '--untrusted', '--only-cached',
                            '--bundle', str(destination / 'bundle'), '--keep-logs',
                            '--outdir', str(output), str(project / name)],
                           env=environment, check=True, timeout=180)
    stamp.update(local)
    (destination / 'manifest.json').write_text(json.dumps(stamp, ensure_ascii=False, sort_keys=True, indent=2) + '\n')
    # Publish only a complete support directory; repeated test builds replace it.
    with tempfile.TemporaryDirectory(prefix='latex-previous-', dir=target.parent) as previous:
        backup = Path(previous) / 'support'
        if target.exists():
            target.rename(backup)
        try:
            destination.rename(target)
        except OSError:
            if backup.exists():
                backup.rename(target)
            raise
    staging.cleanup()
    print(f'Prepared Tectonic {VERSION} and fixed Chinese resources: {target}')


if __name__ == '__main__':
    main()
