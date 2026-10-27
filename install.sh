#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
version=''
package=''
scripts_only=false
channel=latest
while (( $# )); do
    case "$1" in
        --version) version=${2:?缺少版本号}; shift 2;;
        --package) package=${2:?缺少本地安装包路径}; shift 2;;
        --scripts-only) scripts_only=true; shift;;
        --channel) channel=${2:?缺少更新通道}; shift 2;;
        *) echo "未知参数：$1" >&2; exit 2;;
    esac
done
case $channel in latest|stable|beta) ;; *) echo '更新通道必须是 latest、stable 或 beta。' >&2;exit 2;;esac
if [[ $version == latest ]]; then version=''; fi
if [[ -n $version && ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]]; then echo '版本格式无效';exit 2;fi
if [[ -n $package && -z $version ]]; then echo '使用本地安装包时请同时指定 --version。' >&2;exit 2;fi
[[ $EUID -eq 0 ]] || { echo '请使用 root 安装。'; exit 1; }
[[ $(uname -s) == Linux ]] || { echo '仅支持 Linux。';exit 1; }
case $(uname -m) in
    x86_64|amd64) arch=amd64;;
    aarch64|arm64) arch=arm64;;
    s390x) arch=s390x;;
    *) echo '没有匹配此 CPU 架构的 cknode 安装包，未修改现有安装。' >&2;exit 1;;
esac

# Preserve the original distribution family coverage. Package availability and
# service-manager behavior are checked locally; detection is not runtime proof.
os_id=unknown
os_like=''
if [[ -r /etc/os-release ]]; then
    os_id=$(sed -n 's/^ID=//p' /etc/os-release | tr -d '\"')
    os_like=$(sed -n 's/^ID_LIKE=//p' /etc/os-release | tr -d '\"')
fi
install_dependencies() {
    local manager='' candidate
    case " $os_id $os_like " in
        *' alpine '*) manager=apk;;
        *' arch '*|*' manjaro '*) manager=pacman;;
        *' debian '*|*' ubuntu '*) manager=apt-get;;
        *' fedora '*|*' rhel '*|*' centos '*|*' rocky '*|*' almalinux '*)
            if command -v dnf >/dev/null; then manager=dnf; else manager=yum; fi;;
    esac
    if [[ -z $manager ]] || ! command -v "$manager" >/dev/null; then
        manager=''
        for candidate in apt-get dnf yum pacman apk; do
            if command -v "$candidate" >/dev/null; then manager=$candidate;break;fi
        done
    fi
    case "$manager" in
        apt-get) apt-get update; apt-get install -y bash curl python3 tar ca-certificates coreutils;;
        dnf) dnf install -y bash curl python3 tar ca-certificates coreutils;;
        yum) yum install -y bash curl python3 tar ca-certificates coreutils;;
        pacman) pacman -Sy --needed --noconfirm bash curl python tar ca-certificates coreutils;;
        apk) apk add --no-cache bash curl python3 tar ca-certificates coreutils;;
        *) echo '请安装 bash、curl、python3、tar、coreutils、ca-certificates 后重试。' >&2; return 1;;
    esac
}
missing=()
for tool in curl python3 tar install; do command -v "$tool" >/dev/null || missing+=("$tool"); done
if (( ${#missing[@]} )); then install_dependencies; fi
for tool in curl python3 tar install; do
    command -v "$tool" >/dev/null || { echo "仍缺少依赖：$tool" >&2; exit 1; }
done

backend=''
if ! $scripts_only; then
    if command -v rc-service >/dev/null && command -v rc-update >/dev/null && [[ -d /run/openrc || ! -d /run/systemd/system ]]; then
        backend=openrc
    elif command -v systemctl >/dev/null; then
        backend=systemd
    else
        echo '未检测到可用的 systemd 或 OpenRC，现有安装未修改。' >&2;exit 1
    fi
fi

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
    version=$(python3 - "$tmp/releases.json" "$arch" "$channel" <<'LATEST_VERSION'
import json,re,sys
try:
    releases=json.load(open(sys.argv[1]))
except (OSError,ValueError):
    raise SystemExit('GitHub 版本列表无效；现有安装未修改。')
if not isinstance(releases,list):
    raise SystemExit('无法读取 GitHub 版本列表；现有安装未修改。')
channel=sys.argv[3] if len(sys.argv)>3 else 'latest'
versions=[]
for release in releases:
    if not isinstance(release,dict) or release.get('draft') or not release.get('published_at'):
        continue
    match=re.fullmatch(r'v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?',release.get('tag_name',''))
    if not match:
        continue
    pre=match.group(4)
    is_beta=bool(release.get('prerelease')) or pre is not None
    if channel=='stable' and is_beta:continue
    if channel=='beta' and not is_beta:continue
    key=tuple(map(int,match.group(1,2,3)))+(pre is None,tuple((0,int(v)) if v.isdigit() else (1,v) for v in (pre or '').split('.')))
    versions.append((key,match.group(0).removeprefix('v'),release))
if not versions:
    raise SystemExit('所选通道没有可安装的已发布版本；现有安装未修改。')
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
    if ! curl -fLsS --retry 2 --connect-timeout 15 --max-time 120 "$url/$name" -o "$tmp/$name" || \
       ! curl -fLsS --retry 2 --connect-timeout 15 --max-time 120 "$url/$name.sha256" -o "$tmp/$name.sha256"; then
        echo "无法取得完整的 $version / linux-$arch 发布资产；未回退其他架构或更旧版本，现有安装未修改。" >&2
        exit 1
    fi
fi
python3 - "$tmp/$name" "$tmp/extracted" "$version" "$arch" <<'VERIFY_PACKAGE'
import hashlib,json,pathlib,re,sys,tarfile
archive,out,version,arch=sys.argv[1:]
archive=pathlib.Path(archive);out=pathlib.Path(out)
checks=pathlib.Path(str(archive)+'.sha256').read_text().splitlines()
if len(checks)!=1 or not re.fullmatch(r'[a-fA-F0-9]{64}  '+re.escape(archive.name),checks[0]):
    raise SystemExit('无效安装包校验文件')
if hashlib.sha256(archive.read_bytes()).hexdigest()!=checks[0].split('  ',1)[0].lower():
    raise SystemExit('安装包 SHA256 校验失败')
out.mkdir()
with tarfile.open(archive) as t:
    seen=set()
    for m in t.getmembers():
        p=pathlib.PurePosixPath(m.name)
        if p.is_absolute() or '..' in p.parts or m.issym() or m.islnk() or not(m.isfile() or m.isdir()) or p.as_posix() in seen:
            raise SystemExit('无效安装包成员')
        seen.add(p.as_posix())
    t.extractall(out)
meta=json.loads((out/'RELEASE.json').read_text())
if meta['version']!=version or meta['arch']!=arch or meta['base_commit']!='5dec4d0e8a8ae1b4d9fde939c02f96781b874bee':
    raise SystemExit('安装包版本、架构或源码基线不匹配')
verified=set()
for line in (out/'SHA256SUMS').read_text().splitlines():
    expected,name=line.split('  ',1);p=out/name;relative=pathlib.PurePosixPath(name)
    if relative.is_absolute() or '..' in relative.parts or name in verified or not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=expected:
        raise SystemExit('安装包文件校验失败')
    verified.add(name)
actual={f.relative_to(out).as_posix() for f in out.rglob('*') if f.is_file() and f!=out/'SHA256SUMS'}
if verified!=actual:raise SystemExit('安装包文件清单不完整')
required=['cknode','cknode.sh','v2bx-native.sh','setup.py','manage.py','cknode.service','cknode@.service','cknode.initd']
required += ['templates/'+n for n in ['core.xray.json','core.sing.json','core.hysteria2.json','dns.json','route.json','custom_inbound.json','custom_outbound.json','sing_origin.json','hy2config.yaml']]
for name in required:
    if name not in verified:raise SystemExit('安装包缺少 '+name)
if meta.get('daemon_sha256') and meta['daemon_sha256']!=hashlib.sha256((out/'cknode').read_bytes()).hexdigest():
    raise SystemExit('安装包 daemon 指纹不匹配')
VERIFY_PACKAGE

if $scripts_only; then
    # Require the exact existing daemon. A matching tag alone cannot prove that
    # newer management tools can safely operate an older build's capabilities.
    python3 - /usr/local/cknode "$tmp/extracted" <<'VERIFY_SCRIPTS_COMPAT'
import hashlib,json,pathlib,sys
installed,candidate=map(pathlib.Path,sys.argv[1:])
try:
    old=json.loads((installed/'RELEASE.json').read_text())
    new=json.loads((candidate/'RELEASE.json').read_text())
    if any(old.get(k)!=new.get(k) for k in ['version','arch','base_commit']):raise ValueError('版本、架构或源码基线不同')
    if hashlib.sha256((installed/'cknode').read_bytes()).digest()!=hashlib.sha256((candidate/'cknode').read_bytes()).digest():raise ValueError('daemon 二进制不同')
except (OSError,ValueError) as e:
    raise SystemExit('拒绝仅更新维护脚本：'+str(e)+'；当前仅支持相同版本且 daemon 指纹一致的维护更新，请使用完整 cknode update 升级。')
VERIFY_SCRIPTS_COMPAT
fi

# Downloads, all payloads and script compatibility are verified before stopping
# a service or modifying the installed tree. Only this brand's exact units are
# enumerated; cknode-test and all other services are deliberately untouched.
active_services=()
openrc_services=()
service_active() {
    if [[ $backend == systemd ]]; then systemctl is-active --quiet "$1";
    else rc-service "$1" status >/dev/null 2>&1; fi
}
service_action() {
    local action=$1 unit=$2
    if [[ $backend == systemd ]]; then systemctl "$action" "$unit";
    else rc-service "$unit" "$action"; fi
}
if ! $scripts_only; then
    if [[ $backend == systemd ]]; then
        if service_active cknode.service; then active_services+=(cknode.service); fi
        # list-units includes loaded transient/disabled instances as well as enabled ones.
        systemctl list-units --all --type=service --no-legend --plain > "$tmp/units"
        while read -r unit rest; do
            if [[ $unit =~ ^cknode@[A-Za-z0-9][A-Za-z0-9_-]{0,31}\.service$ ]] && service_active "$unit"; then
                active_services+=("$unit")
            fi
        done < "$tmp/units"
    else
        for file in /etc/init.d/cknode /etc/init.d/cknode.*; do
            [[ -f $file ]] || continue
            unit=${file##*/}
            if [[ $unit == cknode || $unit =~ ^cknode\.[A-Za-z0-9][A-Za-z0-9_-]{0,31}$ ]]; then
                openrc_services+=("$unit")
                if service_active "$unit"; then active_services+=("$unit"); fi
            fi
        done
    fi
fi
printf '%s\n' "${active_services[@]+"${active_services[@]}"}" > "$tmp/original-active-services"

stage=$(mktemp -d /usr/local/cknode-stage.XXXXXX)
if $scripts_only; then
    for file in cknode.sh v2bx-native.sh setup.py manage.py; do
        install -m 755 "$tmp/extracted/$file" "$stage/$file"
    done
    cp "$tmp/extracted/RELEASE.json" "$stage/MANAGEMENT.json"
else
    cp -a "$tmp/extracted/." "$stage/"
    chmod 755 "$stage" "$stage/cknode" "$stage/cknode.sh" "$stage/v2bx-native.sh" "$stage/setup.py" "$stage/manage.py"
    rm -rf "$stage/templates"
    ln -s /etc/cknode/templates "$stage/templates"
fi

restore_paths=()
snapshot_path() {
    local path=$1 relative=${1#/}
    restore_paths+=("$path")
    if [[ -e $path || -L $path ]]; then
        mkdir -p "$tmp/snapshot/$(dirname "$relative")"
        cp -a "$path" "$tmp/snapshot/$relative"
    fi
}
snapshot_path /usr/local/bin/cknode
snapshot_path /usr/bin/cknode
snapshot_path /etc/cknode/templates
if $scripts_only; then
    for file in cknode.sh v2bx-native.sh setup.py manage.py MANAGEMENT.json templates; do
        snapshot_path "/usr/local/cknode/$file"
    done
fi
if ! $scripts_only; then
    for asset in geoip.dat geosite.dat geoip.db geosite.db dns.json route.json custom_inbound.json custom_outbound.json sing_origin.json hy2config.yaml; do
        snapshot_path "/etc/cknode/$asset"
    done
    if [[ $backend == systemd ]]; then
        snapshot_path /etc/systemd/system/cknode.service
        snapshot_path /etc/systemd/system/cknode@.service
    else
        snapshot_path /etc/init.d/cknode
        for unit in "${openrc_services[@]+"${openrc_services[@]}"}"; do
            [[ $unit == cknode ]] || snapshot_path "/etc/init.d/$unit"
        done
    fi
fi
previous=''
program_moved=false
new_program=false
rollback() {
    trap - ERR INT TERM
    set +e
    if ! $scripts_only; then
        for unit in "${active_services[@]+"${active_services[@]}"}"; do service_action stop "$unit"; done
    fi
    if $new_program; then rm -rf /usr/local/cknode; fi
    if $program_moved; then mv "$previous" /usr/local/cknode; fi
    for path in "${restore_paths[@]}"; do
        rm -rf "$path"
        if [[ -e $tmp/snapshot/${path#/} || -L $tmp/snapshot/${path#/} ]]; then
            mkdir -p "$(dirname "$path")"
            cp -a "$tmp/snapshot/${path#/}" "$path"
        fi
    done
    if ! $scripts_only; then
        [[ $backend != systemd ]] || systemctl daemon-reload
        for unit in "${active_services[@]+"${active_services[@]}"}"; do
            if ! service_action start "$unit"; then echo "恢复服务失败：$unit" >&2; fi
        done
    fi
    echo '升级未成功，已按原活动实例清单尝试恢复上一安装。' >&2
}
trap 'rollback; exit 1' ERR
trap 'rollback; exit 130' INT
trap 'rollback; exit 143' TERM
if ! $scripts_only; then
    for unit in "${active_services[@]+"${active_services[@]}"}"; do service_action stop "$unit"; done
fi
if $scripts_only; then
    # Never rename/copy/replace the daemon itself in maintenance-only mode.
    for file in cknode.sh v2bx-native.sh setup.py manage.py; do
        install -m 755 "$stage/$file" "/usr/local/cknode/$file"
    done
    install -m 644 "$stage/MANAGEMENT.json" /usr/local/cknode/MANAGEMENT.json
    rm -rf /usr/local/cknode/templates
    ln -s /etc/cknode/templates /usr/local/cknode/templates
else
    if [[ -d /usr/local/cknode ]]; then
        previous="/usr/local/cknode-backup-$(date +%Y%m%d%H%M%S)-$$"
        mv /usr/local/cknode "$previous"
        program_moved=true
    fi
    mv "$stage" /usr/local/cknode
    stage=''
    new_program=true
fi
# Keep the previous maintenance entry for manual recovery as well.
if [[ -f /usr/local/bin/cknode ]] && ! cmp -s /usr/local/bin/cknode /usr/local/cknode/cknode.sh; then
    cp -a /usr/local/bin/cknode "/usr/local/bin/cknode.backup-$(date +%Y%m%d%H%M%S)-$$"
fi
install -m 755 /usr/local/cknode/cknode.sh /usr/local/bin/cknode
ln -sfn /usr/local/bin/cknode /usr/bin/cknode
install -d -m 700 /etc/cknode /etc/cknode/instances /etc/cknode/certs /etc/cknode/nodes
rm -rf /etc/cknode/templates
install -d -m 700 /etc/cknode/templates
cp -a "$tmp/extracted/templates/." /etc/cknode/templates/
if ! $scripts_only; then
    for asset in geoip.dat geosite.dat geoip.db geosite.db; do
        if [[ ! -e /etc/cknode/$asset && -f /usr/local/cknode/examples/$asset ]]; then
            install -m 644 "/usr/local/cknode/examples/$asset" "/etc/cknode/$asset"
        fi
    done
    for asset in dns.json route.json custom_inbound.json custom_outbound.json sing_origin.json hy2config.yaml; do
        if [[ ! -e /etc/cknode/$asset ]]; then
            install -m 600 "/etc/cknode/templates/$asset" "/etc/cknode/$asset"
        fi
    done
    if [[ $backend == systemd ]]; then
        install -m 644 /usr/local/cknode/cknode.service /etc/systemd/system/cknode.service
        install -m 644 /usr/local/cknode/cknode@.service /etc/systemd/system/cknode@.service
        systemctl daemon-reload
    else
        install -m 755 /usr/local/cknode/cknode.initd /etc/init.d/cknode
        for unit in "${openrc_services[@]+"${openrc_services[@]}"}"; do
            [[ $unit == cknode ]] || install -m 755 /usr/local/cknode/cknode.initd "/etc/init.d/$unit"
        done
    fi
    for unit in "${active_services[@]+"${active_services[@]}"}"; do service_action start "$unit"; done
    if (( ${#active_services[@]} )); then sleep 3; fi
    for unit in "${active_services[@]+"${active_services[@]}"}"; do service_active "$unit"; done
fi
trap - ERR INT TERM
if $scripts_only; then
    echo "cknode 维护文件已更新：${version}；daemon 未替换，服务未重启。"
    exit 0
fi
printf '\n========================================\n  cknode 安装完成：%s / %s\n========================================\n\n  cknode        中文维护菜单\n  cknode setup  配置向导\n  cknode log    查看日志\n\n' "$version" "$backend"
if [[ -t 0 ]]; then
    legacy_active=false
    if [[ $backend == systemd ]] && systemctl is-active --quiet cknode-test.service;then legacy_active=true;fi
    if [[ $backend == openrc ]] && [[ -f /etc/init.d/cknode-test ]] && rc-service cknode-test status >/dev/null 2>&1;then legacy_active=true;fi
    if $legacy_active;then
        read -r -p '检测到旧实验版 cknode-test，是否停用旧服务以避免端口冲突？[Y/n]: ' legacy_answer
        if [[ ${legacy_answer:-y} == [yY] ]];then
            if [[ $backend == systemd ]];then systemctl disable --now cknode-test.service
            else rc-service cknode-test stop;rc-update del cknode-test default;fi
            echo '旧实验服务已停用，原程序和配置保留。'
        else echo '旧实验服务继续运行；新节点请使用未占用端口。';fi
    fi
    read -r -p '现在进入配置向导？[Y/n]: ' answer
    if [[ ${answer:-y} == [yY] ]]; then /usr/local/bin/cknode setup;fi
else
    echo '运行 cknode setup 开始配置。'
fi
