#!/usr/bin/env bash
set -euo pipefail
umask 077
version=''
package=''
while (( $# )); do
    case "$1" in
        --version) version=${2:?缺少版本号}; shift 2;;
        --package) package=${2:?缺少本地安装包路径}; shift 2;;
        *) echo "未知参数：$1" >&2; exit 2;;
    esac
done
if [[ $version == latest ]]; then version=''; fi
if [[ -n $version && ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]]; then echo '版本格式无效';exit 2;fi
if [[ -n $package && -z $version ]]; then echo '使用本地安装包时请同时指定 --version。' >&2;exit 2;fi
[[ $EUID -eq 0 ]] || { echo '请使用 root 安装。'; exit 1; }
case $(uname -m) in x86_64|amd64) arch=amd64;;aarch64|arm64) arch=arm64;;*) echo '暂不支持此 CPU 架构';exit 1;;esac
[[ $(uname -s) == Linux ]] || { echo '仅支持 Linux。';exit 1; }
missing=()
for tool in curl python3 tar; do command -v "$tool" >/dev/null || missing+=("$tool"); done
if (( ${#missing[@]} )); then
    command -v apt-get >/dev/null || { echo '请安装 curl、python3、tar 后重试。';exit 1; }
    apt-get update
    apt-get install -y curl python3 tar ca-certificates
fi
command -v systemctl >/dev/null || { echo '此版本需要 systemd。';exit 1; }
tmp=$(mktemp -d)
stage=''
cleanup() { rm -rf "$tmp"; [[ -z $stage ]] || rm -rf "$stage"; }
trap cleanup EXIT
if [[ -z $version ]]; then
    echo '正在获取 cknode 最新已发布版本…'
    if ! curl -fLsS --retry 2 --connect-timeout 15 --max-time 60 \
        -H 'Accept: application/vnd.github+json' \
        'https://api.github.com/repos/pkhosn/cknode/releases?per_page=100' -o "$tmp/releases.json"; then
        echo '无法获取最新版本，请稍后重试；现有安装未修改。' >&2
        exit 1
    fi
    version=$(python3 - "$tmp/releases.json" "$arch" <<'LATEST_VERSION'
import json,re,sys
try:
    releases=json.load(open(sys.argv[1]))
except (OSError,ValueError):
    raise SystemExit('GitHub 版本列表无效；现有安装未修改。')
if not isinstance(releases,list):
    raise SystemExit('无法读取 GitHub 版本列表；现有安装未修改。')
versions=[]
for release in releases:
    if not isinstance(release,dict) or release.get('draft') or not release.get('published_at'):
        continue
    match=re.fullmatch(r'v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?',release.get('tag_name',''))
    if not match:
        continue
    pre=match.group(4)
    key=tuple(map(int,match.group(1,2,3)))+(pre is None,tuple((0,int(v)) if v.isdigit() else (1,v) for v in (pre or '').split('.')))
    versions.append((key,match.group(0).removeprefix('v'),release))
if not versions:
    raise SystemExit('没有可安装的已发布版本；现有安装未修改。')
_,version,release=max(versions,key=lambda value:value[0])
assets={a.get('name') for a in release.get('assets',[]) if isinstance(a,dict) and a.get('state')=='uploaded'}
archive=f'cknode-{version}-linux-{sys.argv[2]}.tar.gz'
if not {archive,archive+'.sha256'} <= assets:
    raise SystemExit(f'最新版本 {version} 尚无完整的 linux-{sys.argv[2]} 安装包；现有安装未修改。')
print(version)
LATEST_VERSION
    )
    echo "最新版本：$version"
fi
name="cknode-$version-linux-$arch.tar.gz"
if [[ -n $package ]]; then
    cp -- "$package" "$tmp/$name"
    cp -- "$package.sha256" "$tmp/$name.sha256"
else
    url="https://github.com/pkhosn/cknode/releases/download/v$version"
    echo "正在下载 cknode $version / linux-${arch}…"
    curl -fLsS --retry 2 --connect-timeout 15 "$url/$name" -o "$tmp/$name"
    curl -fLsS --retry 2 --connect-timeout 15 "$url/$name.sha256" -o "$tmp/$name.sha256"
fi
(cd "$tmp"; sha256sum -c "$name.sha256")
python3 - "$tmp/$name" "$tmp/extracted" "$version" "$arch" <<'PY'
import hashlib,json,pathlib,sys,tarfile
archive,out,version,arch=sys.argv[1:];out=pathlib.Path(out);out.mkdir()
with tarfile.open(archive) as t:
    for m in t.getmembers():
        p=pathlib.PurePosixPath(m.name)
        if p.is_absolute() or '..' in p.parts or m.issym() or m.islnk() or not(m.isfile() or m.isdir()):raise SystemExit('无效安装包成员')
    t.extractall(out)
meta=json.loads((out/'RELEASE.json').read_text())
if meta['version']!=version or meta['arch']!=arch or meta['base_commit']!='5dec4d0e8a8ae1b4d9fde939c02f96781b874bee':raise SystemExit('安装包版本、架构或源码基线不匹配')
for line in (out/'SHA256SUMS').read_text().splitlines():
    expected,name=line.split('  ',1);p=out/name
    if pathlib.PurePosixPath(name).is_absolute() or '..' in pathlib.PurePosixPath(name).parts or not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=expected:raise SystemExit('安装包文件校验失败')
for name in ['cknode','cknode.sh','setup.py','cknode.service']: 
    if not (out/name).is_file():raise SystemExit('安装包缺少 '+name)
PY
# Finish downloads and verification before touching the running installation.
stage=$(mktemp -d /usr/local/cknode-stage.XXXXXX)
cp -a "$tmp/extracted/." "$stage/"
chmod 755 "$stage" "$stage/cknode" "$stage/cknode.sh" "$stage/setup.py"
old_command=false
old_link=false
old_unit=false
[[ ! -e /usr/local/bin/cknode ]] || { cp -a /usr/local/bin/cknode "$tmp/original-command";old_command=true; }
[[ ! -e /usr/bin/cknode && ! -L /usr/bin/cknode ]] || { cp -a /usr/bin/cknode "$tmp/original-link";old_link=true; }
[[ ! -f /etc/systemd/system/cknode.service ]] || { cp -a /etc/systemd/system/cknode.service "$tmp/original-unit";old_unit=true; }
active=false
if systemctl is-active --quiet cknode.service; then active=true;systemctl stop cknode.service;fi
previous=''
if [[ -d /usr/local/cknode ]]; then
    previous="/usr/local/cknode-backup-$(date +%Y%m%d%H%M%S)-$$"
    mv /usr/local/cknode "$previous"
fi
rollback() {
    systemctl stop cknode.service 2>/dev/null || true
    rm -rf /usr/local/cknode
    if [[ -n $previous ]]; then
        mv "$previous" /usr/local/cknode
        install -m 644 /usr/local/cknode/cknode.service /etc/systemd/system/cknode.service
        install -m 755 /usr/local/cknode/cknode.sh /usr/local/bin/cknode
    fi
    rm -f /usr/local/bin/cknode /usr/bin/cknode /etc/systemd/system/cknode.service
    if $old_command; then cp -a "$tmp/original-command" /usr/local/bin/cknode;fi
    if $old_link; then cp -a "$tmp/original-link" /usr/bin/cknode;fi
    if $old_unit; then cp -a "$tmp/original-unit" /etc/systemd/system/cknode.service;fi
    systemctl daemon-reload
    if $active; then systemctl start cknode.service || true;fi
    echo '升级未成功，已尝试恢复上一版本。' >&2
}
trap 'rollback; exit 1' ERR
mv "$stage" /usr/local/cknode
stage=''
# Keep an earlier experimental maintenance command as a backup; never import
# its configuration or change its daemon/service.
if [[ -f /usr/local/bin/cknode ]] && ! cmp -s /usr/local/bin/cknode /usr/local/cknode/cknode.sh; then
    cp -a /usr/local/bin/cknode "/usr/local/bin/cknode.backup-$(date +%Y%m%d%H%M%S)-$$"
fi
install -m 755 /usr/local/cknode/cknode.sh /usr/local/bin/cknode
ln -sfn /usr/local/bin/cknode /usr/bin/cknode
install -d -m 700 /etc/cknode
for asset in geoip.dat geosite.dat geoip.db geosite.db; do
    if [[ ! -e /etc/cknode/$asset && -f /usr/local/cknode/examples/$asset ]]; then
        install -m 644 "/usr/local/cknode/examples/$asset" "/etc/cknode/$asset"
    fi
done
install -m 644 /usr/local/cknode/cknode.service /etc/systemd/system/cknode.service
systemctl daemon-reload
if $active; then
    systemctl start cknode.service
    sleep 3
    systemctl is-active --quiet cknode.service
fi
trap - ERR
printf '\n========================================\n  cknode 安装完成：%s\n========================================\n\n  cknode        中文维护菜单\n  cknode setup  配置向导\n  cknode log    查看日志\n\n' "$version"
if [[ -t 0 ]]; then
    if systemctl is-active --quiet cknode-test.service; then
        read -r -p '检测到旧实验版 cknode-test，是否停用旧服务以避免端口冲突？[Y/n]: ' legacy_answer
        if [[ ${legacy_answer:-y} == [yY] ]]; then
            systemctl disable --now cknode-test.service
            echo '旧实验服务已停用，原程序和配置保留。'
        else
            echo '旧实验服务继续运行；请为新节点使用未占用端口。'
        fi
    fi
    read -r -p '现在进入配置向导？[Y/n]: ' answer
    if [[ ${answer:-y} == [yY] ]]; then /usr/local/bin/cknode setup;fi
else
    echo '运行 cknode setup 开始配置。'
fi
