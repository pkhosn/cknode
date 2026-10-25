# cknode

对接 pkhosn/v2board 的独立节点后端。首批以 VLESS 的实际部署与维护为重点。

## 当前状态

本仓库是公开安装与发行入口，不包含私有控制层源码。首个预发行版为 [0.20.1-test.3](https://github.com/pkhosn/cknode/releases/tag/v0.20.1-test.3)，以 VLESS 自用试运行为重点；对应核心源码随 Release 提供。尚无正式稳定版。

安装入口支持 Debian 12/13、Ubuntu 24.04 的 amd64/arm64 管理式安装包；实际系统校验由包内安装器执行。需要 Bash、Python 3.11+、CA 证书及下载脚本所用的 curl。不会安装虚拟机、容器或 Go 编译环境。

## 安装测试版

当前只发布 Linux amd64 测试包。Ubuntu 24.04 amd64 已完成管理式升级、回退和 VLESS 业务验收；空白主机首次安装、Debian 12/13 和 arm64 尚未完成本版实机验收。

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/pkhosn/cknode/main/install.sh) --version 0.20.1-test.3
```

测试版必须明确指定版本。仅下载并校验可在上述命令后再加 `--check`。新安装完成后按向导配置面板与节点，维护时输入 `cknode`。

默认入口只查找最新正式 Release，绝不自动选择预发行版。当前包格式仅支持 `X.Y.Z-test.N` / `X.Y.Z-pre.N`，正式稳定版本格式接入前不会发布 stable。

## 安装及维护体验

下载包 → SHA-256 校验 → 安全解压 → 包内清单校验 → 安装/升级 → 中文首次配置向导。

已有配置在升级时保留；首次配置需填写面板地址、通信密钥、节点 ID 和证书方式。

```text
cknode                中文维护菜单
cknode setup          首次配置
cknode status         服务状态
cknode log            服务日志
cknode cert           证书管理
cknode releases       版本状态
cknode upgrade DIR    从已校验的本地候选包升级
cknode rollback       回退上一版本
```

在线安装入口可以重复运行来更新至所选发行版。现有维护命令尚无 `cknode update` 子命令。现阶段系统服务和状态目录沿用 `cknode-test` 布局，后续变更会提供明确说明。

## 发布约定

Tag 使用 `v版本号`，附件为 `cknode-版本号-linux-架构.tar.gz` 和对应 `.tar.gz.sha256`。

校验和用于检查文件完整性，不能代替独立发行签名。测试版必须标记为 prerelease，并注明已测协议、资源限制和未验证项目。发布二进制前须同时准备其第三方许可证及所需对应源码，不将私有仓库当作公开源码交付。

不会上传面板密钥、TLS 私钥、运行时用户列表或流量账本。
