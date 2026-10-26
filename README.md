# cknode

V2Board 节点后端。发行与安装入口在本仓库；控制层源码保存在私有仓库。目前测试版：[0.20.1-test.8](https://github.com/pkhosn/cknode/releases/tag/v0.20.1-test.8)。

## 安装或升级（Linux amd64）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/pkhosn/cknode/main/install.sh) --version 0.20.1-test.8
```

新装按引导输入面板地址、通信密钥和节点ID；后端读取面板配置。REALITY无需本机证书。已有程序但配置失败时，升级后运行 `cknode setup`。

本版修复 REALITY 被共享 TLS 编辑器默认字段误拒绝的问题，兼容字符串 allow_insecure 默认值、目的地址和端口留空、合法空 short ID；服务器参数错误报告具体字段原因。已用 wl 真实 V2Board 的完整默认配置和面板正常生成的密钥，先复现 test.7 错误，再完成候选包及上述公开一键命令的独立首次安装验收：REALITY 无需证书、服务启动与自启、官方 Xray 客户端完整传输校验、面板流量回执及待报流量清零。详细证据见 Release 的 LIVE-VALIDATION.json。

## 维护

```text
cknode           中文维护菜单
cknode setup     配置引导
cknode status    运行状态
cknode log       日志
cknode nodes     节点同步状态
cknode cert      普通TLS证书管理
cknode rollback  回退上一版本
```

当前为Linux amd64预发行版本。核心对应源码、固定离线依赖及许可文件随Release提供；复用库保留原作者和许可证。
