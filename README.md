# cknode

对接 pkhosn/v2board 的独立节点后端。首批以 VLESS 的实际部署与维护为重点。

## 当前状态

本仓库是公开安装与发行入口，不包含私有控制层源码。目前尚未发布可下载的 GitHub Release；请勿把安装入口已上传理解为生产版已完成验收。

安装入口支持 Debian 12/13、Ubuntu 24.04 的 amd64/arm64 管理式安装包；实际系统校验由包内安装器执行。需要 Bash、Python 3.11+、CA 证书及下载脚本所用的 curl。不会安装虚拟机、容器或 Go 编译环境。

## 发行后的安装方式

以下命令须在对应版本已发布后使用；当前没有 Release 时会明确报错，不会改动节点服务。

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/pkhosn/cknode/main/install.sh)
```

测试版必须明确指定已发布版本：在上述命令后添加 `--version 版本号`。仅下载并校验可再加 `--check`。

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
