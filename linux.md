# Linux Deployment Guide

[中文说明](./linux_CN.md)

This document explains how to deploy `irisbrige-edge` or `irisbrige-local` on Linux and manage it with `systemd`.

It covers two approaches:

1. Deploy automatically with the repository shell script.
2. Deploy manually without using the script.

## Contents

- [Prerequisites](#prerequisites)
- [Choose the Build](#choose-the-build)
- [Option 1: Deploy with the Script](#option-1)
- [Run the installer directly](#run-installer-directly)
- [Default install locations](#default-install-locations)
- [Default service user](#default-service-user)
- [Common override variables](#common-override-variables)
- [Additional environment variables](#additional-environment-variables)
- [Status and logs](#status-and-logs)
- [Common management commands](#common-management-commands)
- [Uninstall with the script](#uninstall-with-the-script)
- [Option 2: Manual Deployment](#option-2)
- [Detect the architecture](#detect-the-architecture)
- [Resolve the latest release tag](#resolve-the-latest-release-tag)
- [Build the download URL](#build-the-download-url)
- [Download and extract](#download-and-extract)
- [Install the binary](#install-the-binary)
- [Choose the service user](#choose-the-service-user)
- [Create the systemd service](#create-the-systemd-service)
- [Reload systemd and start the service](#reload-systemd-and-start-the-service)
- [Verify the service](#verify-the-service)
- [Clean up temporary files](#clean-up-temporary-files)
- [Troubleshooting](#troubleshooting)

<a id="prerequisites"></a>
## Prerequisites

- A Linux system.
- `systemd` is available.
- `curl`, `tar`, and `systemctl` are installed.
- You have `root` or `sudo` privileges.

<a id="choose-the-build"></a>
## Choose the Build

Pick one build and keep the matching names together throughout this guide:

| Build | Binary | Service | Installer script | Uninstaller script |
| --- | --- | --- | --- | --- |
| Edge | `irisbrige-edge` | `irisbrige-edge` | `install-irisbrige-edge-linux.sh` | `uninstall-irisbrige-edge-linux.sh` |
| Local | `irisbrige-local` | `irisbrige-local` | `install-irisbrige-local-linux.sh` | `uninstall-irisbrige-local-linux.sh` |

For copy-pasteable commands, set these variables first:

```bash
BINARY_NAME=irisbrige-edge
SERVICE_NAME=irisbrige-edge
INSTALL_SCRIPT=install-irisbrige-edge-linux.sh
UNINSTALL_SCRIPT=uninstall-irisbrige-edge-linux.sh

# Or switch to the local build:
# BINARY_NAME=irisbrige-local
# SERVICE_NAME=irisbrige-local
# INSTALL_SCRIPT=install-irisbrige-local-linux.sh
# UNINSTALL_SCRIPT=uninstall-irisbrige-local-linux.sh
```

<a id="option-1"></a>
## Option 1: Deploy with the Script

After setting `INSTALL_SCRIPT`, the script URL is:

```bash
https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/${INSTALL_SCRIPT}
```

<a id="run-installer-directly"></a>
### 1. Run the installer directly

```bash
curl -fsSL \
  "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/${INSTALL_SCRIPT}" | sudo bash
```

The script automatically:

- detects whether the current machine is `amd64` or `arm64`
- resolves the latest GitHub release tag
- builds the download URL for the current architecture
- downloads and extracts `${BINARY_NAME}`
- installs the binary to `/usr/local/bin/${BINARY_NAME}`
- writes the `systemd` service file
- runs `systemctl daemon-reload`
- runs `systemctl enable ${SERVICE_NAME}`
- starts or restarts the service

<a id="default-install-locations"></a>
### 2. Default install locations

- Binary: `/usr/local/bin/${BINARY_NAME}`
- systemd unit: `/etc/systemd/system/${SERVICE_NAME}.service`

<a id="default-service-user"></a>
### 3. Default service user

The script chooses the service user as follows:

- if `SERVICE_USER` is set, that user is used
- if the script is run through `sudo`, it uses `SUDO_USER`
- otherwise it uses `root`

Example:

```bash
curl -fsSL \
  "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/${INSTALL_SCRIPT}" | \
  sudo env SERVICE_USER=appuser bash
```

<a id="common-override-variables"></a>
### 4. Common override variables

Example:

```bash
curl -fsSL \
  "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/${INSTALL_SCRIPT}" | \
  sudo env SERVICE_USER=appuser INSTALL_DIR=/usr/local/bin bash
```

Supported variables:

- `SERVICE_USER`
- `INSTALL_DIR`
- `SERVICE_FILE`
- `REPOSITORY`

<a id="additional-environment-variables"></a>
### 5. Additional environment variables

The script does not create a separate environment file.

If `${BINARY_NAME}` needs extra environment variables, edit the systemd service file directly:

```bash
sudo vi "/etc/systemd/system/${SERVICE_NAME}.service"
```

Add lines such as this under `[Service]`:

```dotenv
Environment=OPENAI_API_KEY=your-token
```

Then reload and restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart "${SERVICE_NAME}"
```

<a id="status-and-logs"></a>
### 6. Status and logs

Check service status:

```bash
systemctl status "${SERVICE_NAME}" --no-pager
```

Follow logs:

```bash
journalctl -u "${SERVICE_NAME}" -f
```

<a id="common-management-commands"></a>
### 7. Common management commands

Start:

```bash
sudo systemctl start "${SERVICE_NAME}"
```

Stop:

```bash
sudo systemctl stop "${SERVICE_NAME}"
```

Restart:

```bash
sudo systemctl restart "${SERVICE_NAME}"
```

Enable at boot:

```bash
sudo systemctl enable "${SERVICE_NAME}"
```

Disable at boot:

```bash
sudo systemctl disable "${SERVICE_NAME}"
```

<a id="uninstall-with-the-script"></a>
### 8. Uninstall with the script

After setting `UNINSTALL_SCRIPT`, the uninstaller URL is:

```bash
https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/${UNINSTALL_SCRIPT}
```

Run it directly from GitHub:

```bash
curl -fsSL \
  "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/${UNINSTALL_SCRIPT}" | sudo bash
```

Default behavior:

- stops the `systemd` service if it is running
- disables the service if it is installed
- removes `/etc/systemd/system/${SERVICE_NAME}.service`
- removes `/usr/local/bin/${BINARY_NAME}`
- reloads `systemd`

<a id="option-2"></a>
## Option 2: Manual Deployment

These steps mirror the script logic, but everything is done manually.

If you open a new shell for the manual steps, set the build variables again first:

```bash
BINARY_NAME=irisbrige-edge
SERVICE_NAME="$BINARY_NAME"
UNINSTALL_SCRIPT=uninstall-irisbrige-edge-linux.sh

# Or switch to the local build:
# BINARY_NAME=irisbrige-local
# SERVICE_NAME="$BINARY_NAME"
# UNINSTALL_SCRIPT=uninstall-irisbrige-local-linux.sh
```

<a id="detect-the-architecture"></a>
### 1. Detect the architecture

```bash
uname -m
```

Architecture mapping:

- `x86_64` or `amd64` maps to release suffix `amd64`
- `aarch64` or `arm64` maps to release suffix `arm64`

You can resolve it with:

```bash
case "$(uname -m)" in
  x86_64|amd64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

echo "$ARCH"
```

<a id="resolve-the-latest-release-tag"></a>
### 2. Resolve the latest release tag

```bash
LATEST_URL="$(curl -fsSL --location --retry 3 --output /dev/null --write-out '%{url_effective}' https://github.com/Irisbrige/homebrew-irisbrige/releases/latest)"
RELEASE_TAG="${LATEST_URL##*/}"
RELEASE_VERSION="${RELEASE_TAG#v}"

echo "$RELEASE_TAG"
```

Example output:

```bash
v0.7.0
```

<a id="build-the-download-url"></a>
### 3. Build the download URL

```bash
DOWNLOAD_URL="https://github.com/Irisbrige/homebrew-irisbrige/releases/download/${RELEASE_TAG}/${BINARY_NAME}_${RELEASE_VERSION}_linux_${ARCH}.tar.gz"

echo "$DOWNLOAD_URL"
```

<a id="download-and-extract"></a>
### 4. Download and extract

```bash
TMP_DIR="$(mktemp -d)"
ARCHIVE_PATH="${TMP_DIR}/${BINARY_NAME}.tar.gz"

curl -fL --retry 3 -o "${ARCHIVE_PATH}" "${DOWNLOAD_URL}"
tar -xzf "${ARCHIVE_PATH}" -C "${TMP_DIR}"
```

If the archive contains macOS extended headers, Linux may print `Ignoring unknown extended header keyword`. That warning usually does not affect installation.

<a id="install-the-binary"></a>
### 5. Install the binary

```bash
sudo install -d /usr/local/bin
sudo install -m 0755 "${TMP_DIR}/${BINARY_NAME}" "/usr/local/bin/${BINARY_NAME}"
```

Verify:

```bash
"/usr/local/bin/${BINARY_NAME}" --help
```

<a id="choose-the-service-user"></a>
### 6. Choose the service user

Example with `root`:

```bash
APP_USER=root
APP_GROUP=root
APP_HOME=/root
```

If you want a regular user such as `appuser`:

```bash
APP_USER=appuser
APP_GROUP="$(id -gn "${APP_USER}")"
APP_HOME="$(getent passwd "${APP_USER}" | awk -F: '{print $6}')"
```

Confirm the home directory exists:

```bash
test -d "${APP_HOME}"
```

<a id="create-the-systemd-service"></a>
### 7. Create the systemd service

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

If you need extra environment variables, add more `Environment=KEY=value` lines under `[Service]`.

<a id="reload-systemd-and-start-the-service"></a>
### 8. Reload systemd and start the service

```bash
sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}"
sudo systemctl start "${SERVICE_NAME}"
```

If the service already exists and you changed its configuration:

```bash
sudo systemctl daemon-reload
sudo systemctl restart "${SERVICE_NAME}"
```

<a id="verify-the-service"></a>
### 9. Verify the service

Status:

```bash
systemctl status "${SERVICE_NAME}" --no-pager
```

Logs:

```bash
journalctl -u "${SERVICE_NAME}" -f
```

<a id="clean-up-temporary-files"></a>
### 10. Clean up temporary files

```bash
rm -rf "${TMP_DIR}"
```

<a id="troubleshooting"></a>
## Troubleshooting

### Service failed to start

Check:

```bash
systemctl status "${SERVICE_NAME}" --no-pager
journalctl -u "${SERVICE_NAME}" -n 100 --no-pager
```

### Binary not found

Verify the file exists and is executable:

```bash
ls -l "/usr/local/bin/${BINARY_NAME}"
```

### You want to remove the service completely

Use the uninstall script:

```bash
curl -fsSL \
  "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/${UNINSTALL_SCRIPT}" | sudo bash
```

### Permission denied

Make sure installation, writing `/etc/systemd/system`, `systemctl enable`, and `systemctl start` are all run with `sudo` or as `root`.

### Extra environment variables are required

Edit the service file directly:

```bash
sudo vi "/etc/systemd/system/${SERVICE_NAME}.service"
```

Add `Environment=KEY=value` lines under `[Service]`, then run:

```bash
sudo systemctl daemon-reload
sudo systemctl restart "${SERVICE_NAME}"
```

You can also use:

```bash
sudo systemctl edit "${SERVICE_NAME}"
```
