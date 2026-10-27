# cknode

**0.22.0-test.1：完成全局审查的预发行版，仍需生产长稳验证。**

基于 **pkhosn/v2bx** 完整框架的 V2Board 节点后端，固定上游提交 `5dec4d0`。沿用原有面板、协议、核心选择、同步、限速、计费与证书逻辑；采用 cknode 品牌和中文安装维护入口。0.20及更早实验版记录保留，新版不自动导入旧配置。

## 安装 / 升级（Linux amd64）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/pkhosn/cknode/main/install.sh)
```

不带版本号时自动安装最新已发布版本（包含测试版、排除草稿）。需要固定版本时仍可追加 `--version 0.22.0-test.1`。`cknode update` 默认升级到最新版本。

按引导选择核心、协议，填写面板地址、通信密钥和节点ID。选择 REALITY 后跳过证书；普通TLS支持HTTP/DNS自动证书及已有文件。检测到旧cknode-test服务时会询问是否停用，避免端口冲突；原文件保留。

```text
cknode              中文维护菜单
cknode setup        配置向导
cknode node list     节点列表
cknode node add      添加节点
cknode status       运行状态
cknode log          实时日志
cknode restart      重启
cknode update       升级到最新版本
cknode uninstall    卸载，可保留配置
```

## 本轮验证

在 wl Ubuntu24.04 上，原版与cknode使用相同配置完成VLESS TCP+TLS、WS+TLS、REALITY+Vision的本机客户端跨公网传输和完整内容校验。面板限速、计费与在线上报、用户新增与禁用、配置引导、启停/重启/自启、版本切换、卸载保留配置及重装恢复均有实测记录。公开首次安装结果见 [发行附件](https://github.com/pkhosn/cknode/releases/tag/v0.22.0-test.1) 的 LIVE-VALIDATION.json。

普通TLS验证复用了既有有效证书，首次ACME及DNS签发尚未实测。其他协议和sing-box运行、生产容量及长期稳定性尚未完成本轮验收；保留上游代码不等于全部组合已验证。

对应守护程序源码、固定vendor依赖和许可证随发行附件提供，可离线构建。上游作者与第三方许可保留；源码开发位于私有仓库cknode/v2bx-foundation分支。

新增彩色菜单、完整原版高级入口、节点/证书/REALITY/命名实例管理；原版30个维护函数、18项菜单及原生配置能力保留。配置/证书/模板/节点/实例在 `/etc/cknode`，程序在 `/usr/local/cknode`，不新增 `/opt` 布局。

`cknode advanced` 打开高级工具；`cknode generate` 使用原版完整配置向导；`cknode config show` 默认隐藏密钥，`cknode config edit` 保留原生编辑；`cknode cert` 管理证书绑定；`cknode instance` 查看独立实例。`cknode update_shell` 仅支持同版本、相同daemon指纹的独立维护文件更新。

系统级BBR/内核/防火墙操作保留但不自动执行。其他协议、OpenRC/其他架构、首次ACME/DNS、生产容量/长稳以及上报持久化等剩余边界见Release说明。REA仅恢复选定heki函数的静态证据，不代表完整heki源码或全功能复刻。
