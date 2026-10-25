# cknode

V2Board 节点后端。发行与安装入口在本仓库；控制层源码保存在私有仓库。目前测试版：[0.20.1-test.6](https://github.com/pkhosn/cknode/releases/tag/v0.20.1-test.6)。

## 安装或升级（Linux amd64）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/pkhosn/cknode/main/install.sh) --version 0.20.1-test.6
```

新装按引导输入面板地址、通信密钥和节点 ID；后端读取面板配置。REALITY 无需本机证书。若程序已安装但首次配置失败，升级后执行 `cknode setup`。

本版补齐面板读取的环境代理、短暂失败重试、同源重定向与网络原因诊断。保留标准 block/dns 规则执行，以及一次流量上报和结果不确定台账。

已在 wl 实际对照运行用户提供的 heki v1.2.8，并使用现有真实 V2Board 面板验证其 VLESS+TLS 配置、传输和上报流程。cknode test.6 另通过 Linux 面板断连接恢复、REALITY、DNS/屏蔽规则及现有 TLS 节点升级计量回归。

用户特定生产服务器的网络失败仍需根据实际诊断确认；以上结果不等于所有网络和生产高并发均验收通过。

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

核心对应源码、固定离线依赖及许可文件随 Release 提供；复用库保留原作者和许可证。
