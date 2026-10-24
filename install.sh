#!/bin/bash
# cknode GitHub download entry. Does not compile or provision extra environments.
set -euo pipefail
if ! command -v python3 >/dev/null 2>&1; then
  echo '缺少 Python 3。Debian/Ubuntu 请先运行：apt-get install -y python3 ca-certificates' >&2
  exit 1
fi
# Keep the calling terminal for the nested configuration wizard.
python3 - "$@" 3<&0 <<'CKNODE_PYTHON'
#!/usr/bin/env python3
"""Download a cknode release, verify it, then use its existing installer."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import subprocess
import sys
import tarfile
import tempfile
import urllib.error
import urllib.request

REPO = 'pkhosn/cknode'
VERSION = re.compile(r'^[0-9]+\.[0-9]+\.[0-9]+-(?:test|pre)\.[0-9]+$')


def download(url, target, limit):
    request = urllib.request.Request(url, headers={'User-Agent': 'cknode-installer'})
    with urllib.request.urlopen(request, timeout=60) as response:
        if not response.geturl().startswith('https://'):
            raise ValueError('拒绝非 HTTPS 下载地址')
        size = 0
        with target.open('xb') as out:
            while True:
                chunk = response.read(65536)
                if not chunk:
                    break
                size += len(chunk)
                if size > limit:
                    raise ValueError('下载超过大小上限')
                out.write(chunk)


def unpack(archive, destination, expected):
    # Inspect all entries before extracting anything, including duplicate paths.
    with tarfile.open(archive, 'r:gz') as tar:
        members = tar.getmembers()
        if not members or len(members) > 10000:
            raise ValueError('发行包文件数量异常')
        seen = set()
        total = 0
        for member in members:
            name = member.name.rstrip('/')
            path = PurePosixPath(name)
            if (not name or path.is_absolute() or
                    any(part in ('', '.', '..') for part in name.split('/')) or
                    path.parts[0] != expected or name in seen or
                    not (member.isfile() or member.isdir()) or
                    member.size < 0 or member.size > 256 << 20):
                raise ValueError('发行包含不安全路径或特殊文件')
            seen.add(name)
            total += member.size
            if total > 512 << 20:
                raise ValueError('发行包解压大小超限')
        for member in members:
            target = destination / member.name
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with tar.extractfile(member) as src, target.open('xb') as dst:
                    while True:
                        chunk = src.read(65536)
                        if not chunk:
                            break
                        dst.write(chunk)
                target.chmod(0o755 if member.mode & 0o111 else 0o644)
    return destination / expected


def install(version, arch, folder, check=False):
    tag = 'v' + version
    name = f'cknode-{version}-linux-{arch}'
    filename = name + '.tar.gz'
    base = f'https://github.com/{REPO}/releases/download/{tag}/'
    archive = folder / filename
    checksum = folder / (filename + '.sha256')
    download(base + filename + '.sha256', checksum, 4096)
    match = re.fullmatch(r'([0-9a-f]{64})  ' + re.escape(filename) + r'\n?',
                         checksum.read_text('ascii'))
    if not match:
        raise ValueError('发行包校验文件无效')
    download(base + filename, archive, 256 << 20)
    digest = hashlib.sha256()
    with archive.open('rb') as src:
        for chunk in iter(lambda: src.read(65536), b''):
            digest.update(chunk)
    if digest.hexdigest() != match.group(1):
        raise ValueError('发行包 SHA-256 不匹配，未执行安装')
    package = unpack(archive, folder, name)
    # The verifier is part of the checksum-verified release, not a system module.
    subprocess.run(['python3', str(package / 'cknode-release.py'),
                    'verify', str(package)], check=True)
    if (package / 'VERSION').read_text().strip() != version or \
            (package / 'ARCH').read_text().strip() != arch:
        raise ValueError('发行包版本或架构不匹配')
    if check:
        print('下载、解压和完整包校验通过；未安装或修改服务。')
        return
    subprocess.run(['bash', str(package / 'install-test.sh')], stdin=3, check=True)


def main():
    parser = argparse.ArgumentParser(description='cknode GitHub 安装入口')
    parser.add_argument('--version', help='指定已验收版本，如 0.20.1-test.1；可加 v 前缀')
    parser.add_argument('--check', action='store_true', help='仅下载校验，不安装')
    args = parser.parse_args()
    if sys.version_info < (3, 11):
        parser.error('需要 Python 3.11 或更新版本')
    if platform.system() != 'Linux':
        parser.error('仅支持 Linux')
    arch = {'x86_64': 'amd64', 'aarch64': 'arm64'}.get(platform.machine())
    if arch is None:
        parser.error('仅支持 amd64/arm64')
    if not args.check and os.geteuid() != 0:
        parser.error('请使用 root 执行安装')
    with tempfile.TemporaryDirectory(prefix='cknode-download-') as temp:
        folder = Path(temp)
        version = args.version
        if version is None:
            metadata = folder / 'latest.json'
            try:
                download(f'https://api.github.com/repos/{REPO}/releases/latest',
                         metadata, 1 << 20)
            except urllib.error.HTTPError as error:
                if error.code == 404:
                    raise ValueError('尚无正式发行版；测试版须使用 --version 明确指定') from None
                raise
            release = json.loads(metadata.read_text())
            if release.get('draft') or release.get('prerelease'):
                raise ValueError('默认安装不选择草稿或预发行版')
            version = release['tag_name']
        version = version.removeprefix('v')
        if not VERSION.fullmatch(version):
            raise ValueError('当前安装格式只接受明确的 test/pre 版本号')
        print(f'cknode {version} / linux-{arch}')
        install(version, arch, folder, args.check)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, tarfile.TarError,
            subprocess.CalledProcessError) as error:
        raise SystemExit('cknode 安装未完成：' + str(error))

CKNODE_PYTHON
