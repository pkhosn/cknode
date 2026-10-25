# cknode

V2Board 节点后端。发行与安装入口在本仓库；控制层源码保存在私有仓库。目前测试版：[0.20.1-test.7](https://github.com/pkhosn/cknode/releases/tag/v0.20.1-test.7)。

## 安装或升级（Linux amd64）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/pkhosn/cknode/main/install.sh) --version 0.20.1-test.7
```

新装按引导输入面板地址、通信密钥和节点ID；后端读取面板配置。REALITY无需本机证书。已有程序但配置失败时，升级后运行 `cknode setup`。

本版修复面板原生传输默认值导致配置失败、严格umask导致首次安装目录不可执行，以及核心快速启停竞态。已在wl的真实V2Board面板完成从空配置到REALITY真实传输和计费回执的完整候选验收；公开入口的独立复测见Release附件。

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
