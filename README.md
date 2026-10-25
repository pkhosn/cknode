# cknode（私有测试发行）

本仓库及 pkhosn/cknode-source 均保持私有。目前最新修复预发行版：[0.20.1-test.4](https://github.com/pkhosn/cknode/releases/tag/v0.20.1-test.4)。

## 首次配置修复

0.20.1-test.3 的向导把 VLESS 全部带入证书流程，REALITY 也被要求申请证书；它仅验收了固定本机目标，不是完整的 REALITY 部署入口。0.20.1-test.4 修复面板 REALITY 参数对接、首次配置和固定远端目标支持。

REALITY 不需要申请本机 TLS 证书。新版先从面板识别安全类型，使用面板下发的 private_key、server_name、short_id、dest/server_port；私钥不在向导回显。当前 REALITY 组合为 VLESS TCP/raw＋Vision。

## 私有包安装/升级

登录 GitHub，从上方 Release 下载 Linux amd64 包及同名 .sha256，上传目标服务器同一目录后运行：

```bash
sha256sum -c cknode-0.20.1-test.4-linux-amd64.tar.gz.sha256
tar -xzf cknode-0.20.1-test.4-linux-amd64.tar.gz
cd cknode-0.20.1-test.4-linux-amd64
bash install-test.sh
```

程序已安装但首次配置失败时，无需卸载。升级后运行 `cknode setup` 继续。已有有效配置不会自动覆盖。

仓库已私有，之前匿名 raw.githubusercontent.com 一键安装命令不是可靠的私有下载方式；不应把个人 GitHub 令牌写入脚本、配置或聊天。

## 维护

```text
cknode          中文维护菜单
cknode setup    首次配置
cknode status   运行状态
cknode log      日志
cknode nodes    同步节点状态
cknode cert     普通 TLS 证书管理
cknode rollback 回退上一版本
```

当前仅提供 Linux amd64 测试包。wl Ubuntu 24.04 已验证面板 REALITY 无证书初始化、真实远端目标、独立客户端请求与计量；完整长稳、其他系统和全部组合未完成。不是正式生产稳定版。

核心对应源码和固定 vendor 依赖随每个 Release 提供，控制层源码保留在私有仓库。
