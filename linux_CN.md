# Linux 部署说明

[English](./linux.md)

本文说明如何在 Linux 上部署 `irisbrige-edge` 或 `irisbrige-local`，并使用 `systemd` 配置自动启动。

包含两种方式：

1. 使用仓库内的安装脚本自动部署。
2. 不使用脚本，手动一步一步部署。

## 目录

- [前提条件](#prerequisites-zh)
- [选择构建版本](#choose-the-build-zh)
- [方式一：使用脚本自动部署](#option-1-zh)
- [直接执行安装脚本](#run-installer-directly-zh)
- [local 构建安装脚本](#local-build-installer-zh)
- [默认安装位置](#default-install-locations-zh)
- [默认运行用户](#default-service-user-zh)
- [常见可覆盖变量](#common-override-variables-zh)
- [如需额外环境变量](#additional-environment-variables-zh)
- [查看服务状态和日志](#status-and-logs-zh)
- [常见管理命令](#common-management-commands-zh)
- [使用脚本卸载](#uninstall-with-the-script-zh)
- [local 构建卸载脚本](#local-build-uninstaller-zh)
- [方式二：不使用脚本，手动部署](#option-2-zh)
- [确认架构](#detect-the-architecture-zh)
- [获取最新版本标签](#resolve-the-latest-release-tag-zh)
- [拼接下载地址](#build-the-download-url-zh)
- [下载并解压](#download-and-extract-zh)
- [安装二进制](#install-the-binary-zh)
- [选择服务运行用户](#choose-the-service-user-zh)
- [创建 systemd 服务文件](#create-the-systemd-service-zh)
- [重新加载 systemd 并启动服务](#reload-systemd-and-start-the-service-zh)
- [检查服务是否正常运行](#verify-the-service-zh)
- [清理临时文件](#clean-up-temporary-files-zh)
- [故障排查](#troubleshooting-zh)

<a id="prerequisites-zh"></a>
## 前提条件

- 操作系统为 Linux。
- 系统使用 `systemd`。
- 已安装 `curl`、`tar`、`systemctl`。
- 具备 `root` 或 `sudo` 权限。

<a id="choose-the-build-zh"></a>
## 选择构建版本

开始之前先选定一个构建版本，后续整篇文档里保持对应名称一致：

| 构建 | 二进制名 | 服务名 | 安装脚本 | 卸载脚本 |
| --- | --- | --- | --- | --- |
| Edge | `irisbrige-edge` | `irisbrige-edge` | `install-irisbrige-edge-linux.sh` | `uninstall-irisbrige-edge-linux.sh` |
| Local | `irisbrige-local` | `irisbrige-local` | `install-irisbrige-local-linux.sh` | `uninstall-irisbrige-local-linux.sh` |

如果你想直接复制后面的命令执行，建议先设置这些变量：

```bash
BINARY_NAME=irisbrige-edge
SERVICE_NAME=irisbrige-edge
INSTALL_SCRIPT=install-irisbrige-edge-linux.sh
UNINSTALL_SCRIPT=uninstall-irisbrige-edge-linux.sh

# 或切换到 local 构建：
# BINARY_NAME=irisbrige-local
# SERVICE_NAME=irisbrige-local
# INSTALL_SCRIPT=install-irisbrige-local-linux.sh
# UNINSTALL_SCRIPT=uninstall-irisbrige-local-linux.sh
```

<a id="option-1-zh"></a>
## 方式一：使用脚本自动部署

设置好 `INSTALL_SCRIPT` 之后，安装脚本链接就是：

```bash
https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/${INSTALL_SCRIPT}
```

<a id="run-installer-directly-zh"></a>
### 1. 直接执行安装脚本

```bash
curl -fsSL \
  "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/${INSTALL_SCRIPT}" | sudo bash
```

脚本会自动完成以下操作：

- 判断当前架构是 `amd64` 还是 `arm64`
- 通过 GitHub `releases/latest` 获取最新版本标签
- 按最新版本和当前架构拼接下载地址
- 下载并解压 `${BINARY_NAME}`
- 安装到 `/usr/local/bin/${BINARY_NAME}`
- 生成 `systemd` 服务文件
- 执行 `systemctl daemon-reload`
- 执行 `systemctl enable ${SERVICE_NAME}`
- 启动或重启服务

<a id="local-build-installer-zh"></a>
### local 构建安装脚本

如果你明确要安装 `irisbrige-local`，可以直接执行专用安装脚本：

```bash
curl -fsSL \
  "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/install-irisbrige-local-linux.sh" | sudo bash
```

这条命令会安装 `irisbrige-local`，并创建 `irisbrige-local` 的 `systemd` 服务。

<a id="default-install-locations-zh"></a>
### 2. 默认安装位置

- 二进制文件：`/usr/local/bin/${BINARY_NAME}`
- systemd 服务文件：`/etc/systemd/system/${SERVICE_NAME}.service`

<a id="default-service-user-zh"></a>
### 3. 默认运行用户

脚本对运行用户的处理规则如下：

- 如果显式传入了 `SERVICE_USER`，则使用该用户
- 如果通过 `sudo` 执行，默认使用 `SUDO_USER`
- 如果直接以 `root` 执行，默认使用 `root`

例如：

```bash
curl -fsSL \
  "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/${INSTALL_SCRIPT}" | \
  sudo env SERVICE_USER=appuser bash
```

<a id="common-override-variables-zh"></a>
### 4. 常见可覆盖变量

例如：

```bash
curl -fsSL \
  "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/${INSTALL_SCRIPT}" | \
  sudo env SERVICE_USER=appuser INSTALL_DIR=/usr/local/bin bash
```

支持的变量：

- `SERVICE_USER`
- `INSTALL_DIR`
- `SERVICE_FILE`
- `REPOSITORY`

<a id="additional-environment-variables-zh"></a>
### 5. 如需额外环境变量

当前脚本不会创建单独的环境变量文件。

如果 `${BINARY_NAME}` 运行时需要额外环境变量，建议直接编辑对应的 systemd 服务文件：

```bash
sudo vi "/etc/systemd/system/${SERVICE_NAME}.service"
```

在 `[Service]` 段中增加例如：

```dotenv
Environment=OPENAI_API_KEY=your-token
```

修改后执行：

```bash
sudo systemctl daemon-reload
sudo systemctl restart "${SERVICE_NAME}"
```

<a id="status-and-logs-zh"></a>
### 6. 查看服务状态和日志

查看服务状态：

```bash
systemctl status "${SERVICE_NAME}" --no-pager
```

实时查看日志：

```bash
journalctl -u "${SERVICE_NAME}" -f
```

<a id="common-management-commands-zh"></a>
### 7. 常见管理命令

启动：

```bash
sudo systemctl start "${SERVICE_NAME}"
```

停止：

```bash
sudo systemctl stop "${SERVICE_NAME}"
```

重启：

```bash
sudo systemctl restart "${SERVICE_NAME}"
```

设置开机自启：

```bash
sudo systemctl enable "${SERVICE_NAME}"
```

取消开机自启：

```bash
sudo systemctl disable "${SERVICE_NAME}"
```

<a id="uninstall-with-the-script-zh"></a>
### 8. 使用脚本卸载

设置好 `UNINSTALL_SCRIPT` 之后，卸载脚本链接就是：

```bash
https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/${UNINSTALL_SCRIPT}
```

直接从 GitHub 执行：

```bash
curl -fsSL \
  "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/${UNINSTALL_SCRIPT}" | sudo bash
```

默认行为：

- 如果服务正在运行，则停止 `systemd` 服务
- 如果服务已安装，则禁用该服务
- 删除 `/etc/systemd/system/${SERVICE_NAME}.service`
- 删除 `/usr/local/bin/${BINARY_NAME}`
- 重新加载 `systemd`

<a id="local-build-uninstaller-zh"></a>
### local 构建卸载脚本

如果你安装的是 `irisbrige-local`，可以直接执行：

```bash
curl -fsSL \
  "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/uninstall-irisbrige-local-linux.sh" | sudo bash
```

<a id="option-2-zh"></a>
## 方式二：不使用脚本，手动部署

以下步骤与脚本逻辑一致，但全部手动执行。

如果你是在新的 shell 里执行手动步骤，先重新设置构建变量：

```bash
BINARY_NAME=irisbrige-edge
SERVICE_NAME="$BINARY_NAME"
UNINSTALL_SCRIPT=uninstall-irisbrige-edge-linux.sh

# 或切换到 local 构建：
# BINARY_NAME=irisbrige-local
# SERVICE_NAME="$BINARY_NAME"
# UNINSTALL_SCRIPT=uninstall-irisbrige-local-linux.sh
```

<a id="detect-the-architecture-zh"></a>
### 1. 确认架构

```bash
uname -m
```

架构映射规则：

- `x86_64` 或 `amd64` 对应发布资产后缀 `amd64`
- `aarch64` 或 `arm64` 对应发布资产后缀 `arm64`

可以直接用下面的命令得到下载架构名：

```bash
case "$(uname -m)" in
  x86_64|amd64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

echo "$ARCH"
```

<a id="resolve-the-latest-release-tag-zh"></a>
### 2. 获取最新版本标签

```bash
LATEST_URL="$(curl -fsSL --location --retry 3 --output /dev/null --write-out '%{url_effective}' https://github.com/Irisbrige/homebrew-irisbrige/releases/latest)"
RELEASE_TAG="${LATEST_URL##*/}"
RELEASE_VERSION="${RELEASE_TAG#v}"

echo "$RELEASE_TAG"
```

例如当前可能得到：

```bash
v0.7.0
```

<a id="build-the-download-url-zh"></a>
### 3. 拼接下载地址

```bash
DOWNLOAD_URL="https://github.com/Irisbrige/homebrew-irisbrige/releases/download/${RELEASE_TAG}/${BINARY_NAME}_${RELEASE_VERSION}_linux_${ARCH}.tar.gz"

echo "$DOWNLOAD_URL"
```

<a id="download-and-extract-zh"></a>
### 4. 下载并解压

```bash
TMP_DIR="$(mktemp -d)"
ARCHIVE_PATH="${TMP_DIR}/${BINARY_NAME}.tar.gz"

curl -fL --retry 3 -o "${ARCHIVE_PATH}" "${DOWNLOAD_URL}"
tar -xzf "${ARCHIVE_PATH}" -C "${TMP_DIR}"
```

如果发布包内带有 macOS 扩展头，Linux 上解压时出现 `Ignoring unknown extended header keyword` 告警通常不影响使用。

<a id="install-the-binary-zh"></a>
### 5. 安装二进制

```bash
sudo install -d /usr/local/bin
sudo install -m 0755 "${TMP_DIR}/${BINARY_NAME}" "/usr/local/bin/${BINARY_NAME}"
```

验证：

```bash
"/usr/local/bin/${BINARY_NAME}" --help
```

<a id="choose-the-service-user-zh"></a>
### 6. 选择服务运行用户

以 `root` 为例：

```bash
APP_USER=root
APP_GROUP=root
APP_HOME=/root
```

如果你希望使用普通用户，例如 `appuser`：

```bash
APP_USER=appuser
APP_GROUP="$(id -gn "${APP_USER}")"
APP_HOME="$(getent passwd "${APP_USER}" | awk -F: '{print $6}')"
```

确认该用户的 home 目录存在：

```bash
test -d "${APP_HOME}"
```

<a id="create-the-systemd-service-zh"></a>
### 7. 创建 systemd 服务文件

```bash
sudo tee "/etc/systemd/system/${SERVICE_NAME}.service" >/dev/null <<EOF
[Unit]
Description=${SERVICE_NAME} service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${APP_HOME}
Environment=HOME=${APP_HOME}
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${APP_HOME}/.local/bin:${APP_HOME}/bin
ExecStart=/usr/local/bin/${BINARY_NAME} server
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
```

如果需要额外环境变量，可以在 `[Service]` 段中继续增加：

```dotenv
Environment=OPENAI_API_KEY=your-token
```

<a id="reload-systemd-and-start-the-service-zh"></a>
### 8. 重新加载 systemd 并启动服务

```bash
sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}"
sudo systemctl start "${SERVICE_NAME}"
```

如果服务已经存在并且你修改了配置，可以改为：

```bash
sudo systemctl daemon-reload
sudo systemctl restart "${SERVICE_NAME}"
```

<a id="verify-the-service-zh"></a>
### 9. 检查服务是否正常运行

查看状态：

```bash
systemctl status "${SERVICE_NAME}" --no-pager
```

查看日志：

```bash
journalctl -u "${SERVICE_NAME}" -f
```

<a id="clean-up-temporary-files-zh"></a>
### 10. 清理临时文件

```bash
rm -rf "${TMP_DIR}"
```

<a id="troubleshooting-zh"></a>
## 故障排查

### 服务启动失败

优先查看：

```bash
systemctl status "${SERVICE_NAME}" --no-pager
journalctl -u "${SERVICE_NAME}" -n 100 --no-pager
```

### 提示找不到二进制

检查文件是否存在且可执行：

```bash
ls -l "/usr/local/bin/${BINARY_NAME}"
```

### 需要彻底移除服务

使用卸载脚本：

```bash
curl -fsSL \
  "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/${UNINSTALL_SCRIPT}" | sudo bash
```

### 提示权限不足

确认安装、写入 `/etc/systemd/system`、`systemctl enable` 和 `systemctl start` 都使用了 `sudo` 或 root 权限。

### 服务需要额外环境变量

直接编辑服务文件：

```bash
sudo vi "/etc/systemd/system/${SERVICE_NAME}.service"
```

在 `[Service]` 段添加 `Environment=KEY=value`，然后执行：

```bash
sudo systemctl daemon-reload
sudo systemctl restart "${SERVICE_NAME}"
```

也可以使用：

```bash
sudo systemctl edit "${SERVICE_NAME}"
```
