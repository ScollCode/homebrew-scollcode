# Irisbrige Homebrew Tap

[English](./README.md)

`homebrew-irisbrige` 提供 macOS 上 `irisbrige-edge` 和 `irisbrige-local` 的 Homebrew formula，同时提供 `irisbrige-edge` 在其他平台上的安装和部署入口。

## 目录

- [平台说明](#platform-guide-zh)
- [macOS](#macos-zh)
- [Linux](#linux-zh)
- [Windows](#windows-zh)
- [仓库内容](#repository-contents-zh)

<a id="platform-guide-zh"></a>
## 平台说明

- `macOS`：通过 Homebrew 安装和管理服务。
- `Linux`：通过仓库内脚本或手动方式部署，并使用 `systemd` 管理。
- `Windows`：通过仓库内 PowerShell 安装脚本或使用 WinSW 手动部署服务。

<a id="macos-zh"></a>
## macOS

适用于 Apple Silicon 和 Intel Mac。

1. 添加 tap：

```bash
brew tap Irisbrige/irisbrige
```

2. 安装 edge formula：

```bash
brew install irisbrige-edge
```

3. 启动后台服务：

```bash
brew services start irisbrige-edge
```

4. 查看状态：

```bash
brew services list | grep irisbrige
```

5. 查看日志：

```bash
tail -f "$(brew --prefix)/var/log/irisbrige.log"
```

注意：

- 旧的 formula 名 `irisbrige` 已通过 `formula_renames.json` 迁移到 `irisbrige-edge`
- 服务会通过 Homebrew 安装的 wrapper 启动 `irisbrige-edge server`
- 为了平滑迁移，launchd label 和日志文件名仍保留旧的 `irisbrige` 路径
- 运行时要求 `codex` CLI 在 `PATH` 中可用

如果你要安装 local formula：

```bash
brew install irisbrige-local
brew services start irisbrige-local
```

### 服务环境变量

`brew services` 是由 `launchd` 拉起 `irisbrige-edge` 的，它不会自动继承交互式 shell 的环境变量，例如 `.zshrc` 或 `.bashrc` 里的内容。

对于 `irisbrige-edge`，后台服务不依赖 shell 环境继承，而是使用一个固定、可直接编辑的配置文件：

```bash
~/.config/irisbrige-edge/service.env
```

你可以直接创建并编辑这个文件，加入任意 shell 兼容的 `KEY=VALUE`：

```bash
mkdir -p ~/.config/irisbrige-edge
cat > ~/.config/irisbrige-edge/service.env <<'EOF'
MY_PROVIDER_API_KEY=replace-me
MY_CUSTOM_BASE_URL=https://example.com
IRISBRIGE_ENV_CHECK=service-ready
EOF
```

如果你不想手动创建，service wrapper 也会在第一次启动且文件缺失时自动生成一个带注释示例的模板。

wrapper 会在启动 `irisbrige-edge server` 之前加载这个文件。wrapper 也会保留 Homebrew service 的 `PATH`，所以 `codex` CLI 仍然可被找到。

如果使用 `irisbrige-local`，对应路径改为 `~/.config/irisbrige-local/service.env`，服务管理命令改为 `brew services restart irisbrige-local`。

修改文件后需要重启服务：

```bash
brew services restart irisbrige-edge
```

如果你想让 wrapper 帮你生成这个文件模板，可以先启动或重启一次服务：

```bash
brew services start irisbrige-edge
```

要确认这个可编辑 env 文件已经创建或已被重新加载，可以看日志里的 wrapper 记录：

```bash
tail -n 20 "$(brew --prefix)/var/log/irisbrige.log"
```

正常情况下会看到类似下面其中一条：

```text
irisbrige-edge service: created editable env file at /Users/you/.config/irisbrige-edge/service.env
irisbrige-edge service: loaded environment from /Users/you/.config/irisbrige-edge/service.env
```

如果要确认某个非敏感变量已经进入运行中的服务进程，可以这样检查：

```bash
PID="$(launchctl print gui/$(id -u)/homebrew.mxcl.irisbrige | awk '/pid = / {print $3; exit}')"
ps eww -p "$PID" | grep -F 'IRISBRIGE_ENV_CHECK=service-ready'
```

<a id="linux-zh"></a>
## Linux

Linux 部署说明单独放在文档中，包括：

- 使用仓库内 shell 脚本自动部署
- 不使用脚本时手动下载安装并配置 `systemd`

详细说明见：

- [Linux 部署文档](./linux_CN.md)

<a id="windows-zh"></a>
## Windows

Windows 部署说明单独放在文档中，包括：

- 使用仓库内 PowerShell 安装脚本自动部署
- 使用 WinSW 手动部署服务

详细说明见：

- [Windows 部署文档](./windows_CN.md)

<a id="repository-contents-zh"></a>
## 仓库内容

- [Formula/irisbrige-edge.rb](./Formula/irisbrige-edge.rb)：macOS 上 edge 版本的 Homebrew Formula
- [Formula/irisbrige-local.rb](./Formula/irisbrige-local.rb)：macOS 上 local 版本的 Homebrew Formula
- [scripts/install-irisbrige-edge-linux.sh](./scripts/install-irisbrige-edge-linux.sh)：Linux 自动部署脚本
- [scripts/uninstall-irisbrige-edge-linux.sh](./scripts/uninstall-irisbrige-edge-linux.sh)：Linux 卸载脚本
- [scripts/install-irisbrige-edge-windows.ps1](./scripts/install-irisbrige-edge-windows.ps1)：Windows 自动部署脚本
- [scripts/uninstall-irisbrige-edge-windows.ps1](./scripts/uninstall-irisbrige-edge-windows.ps1)：Windows 卸载脚本
- [linux_CN.md](./linux_CN.md)：Linux 中文部署文档
- [windows_CN.md](./windows_CN.md)：Windows 中文部署文档
