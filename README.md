# cknode

V2Board 节点后端。发行与安装入口在本仓库；控制层源码保存在私有仓库。目前测试版：[0.20.1-test.5](https://github.com/pkhosn/cknode/releases/tag/v0.20.1-test.5)。

## 安装或升级（Linux amd64）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/pkhosn/cknode/main/install.sh) --version 0.20.1-test.5
```

新装按引导输入面板地址、通信密钥和节点 ID；后端自动读取面板配置。REALITY 无需本机证书。若程序已安装但首次配置失败，升级后执行 `cknode setup`，无需卸载。

0.20.1-test.5 修复面板存在路由规则时无法初始化的问题，支持标准 block 和 dns 动作。域名/IP 正则、协议屏蔽与 DNS 配置会实际执行，不需要关闭面板规则。

## 维护

```text
cknode           中文维护菜单
cknode setup     配置引导
cknode status    运行状态
cknode log       日志
cknode nodes     节点同步状态
cknode cert      普通 TLS 证书管理
cknode rollback  回退上一版本
```

已验证 Ubuntu 24.04 的 REALITY、面板标准规则及现有 TLS 节点回归；当前为预发行测试版，尚未完成生产高并发与本版本长期稳定性验收。

核心对应源码、固定离线依赖及许可文件随 Release 提供；复用库保留原作者和许可证。
