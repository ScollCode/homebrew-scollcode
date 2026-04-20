# Irisbrige Homebrew Tap

[中文说明](./README_CN.md)

`homebrew-irisbrige` provides macOS Homebrew formulae for `irisbrige-edge` and `irisbrige-local`, plus deployment entry points for `irisbrige-edge` on other supported platforms.

## Contents

- [Platform Guide](#platform-guide)
- [macOS](#macos)
- [Linux](#linux)
- [Windows](#windows)
- [Repository Contents](#repository-contents)

<a id="platform-guide"></a>
## Platform Guide

- `macOS`: install and manage the service with Homebrew.
- `Linux`: deploy with the included script or manually, then manage with `systemd`.
- `Windows`: deploy with the included PowerShell installer or manually with WinSW.

<a id="macos"></a>
## macOS

Supports both Apple Silicon and Intel Macs.

1. Add the tap:

```bash
brew tap Irisbrige/irisbrige
```

2. Install the edge formula:

```bash
brew install irisbrige-edge
```

3. Start the background service:

```bash
brew services start irisbrige-edge
```

4. Check service status:

```bash
brew services list | grep irisbrige
```

5. View logs:

```bash
tail -f "$(brew --prefix)/var/log/irisbrige.log"
```

Notes:

- The old formula name `irisbrige` is renamed to `irisbrige-edge` via `formula_renames.json`
- The `irisbrige-edge` service starts `irisbrige-edge server` through a Homebrew-installed wrapper
- The launchd label is `homebrew.mxcl.irisbrige-edge`
- The log file names still use the legacy `irisbrige` paths
- The `irisbrige-local` launchd label is `homebrew.mxcl.irisbrige-local`
- The `irisbrige-local` log files are `irisbrige-local.log` and `irisbrige-local.error.log`
- The runtime expects the `codex` CLI to be available on `PATH`

Alternative local formula:

```bash
brew install irisbrige-local
brew services start irisbrige-local
```

### Legacy label migration

Older `irisbrige-edge` releases used the launchd label `homebrew.mxcl.irisbrige`.
If you already have that LaunchAgent, unload and remove it once before starting
the current service so you do not leave two jobs behind:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/homebrew.mxcl.irisbrige.plist 2>/dev/null || true
rm -f ~/Library/LaunchAgents/homebrew.mxcl.irisbrige.plist
brew services start irisbrige-edge
```

### Service environment

`brew services` starts `irisbrige-edge` under `launchd`. It does not inherit environment variables from your interactive shell startup files such as `.zshrc` or `.bashrc`.

For both `irisbrige-edge` and `irisbrige-local`, the background service uses one shared editable file:

```bash
~/.config/irisbrige/service.env
```

You can create and edit that file directly:

```bash
mkdir -p ~/.config/irisbrige
cat > ~/.config/irisbrige/service.env <<'EOF'
MY_PROVIDER_API_KEY=replace-me
MY_CUSTOM_BASE_URL=https://example.com
IRISBRIGE_ENV_CHECK=service-ready
EOF
```

If you prefer, the service wrapper also creates this file with commented examples on first start when it is missing.

Both wrappers load this file before they start `irisbrige-edge server` or `irisbrige-local server`. The wrapper also preserves Homebrew's service `PATH`, so the `codex` CLI remains discoverable even if you add more variables here.

If you previously used `~/.config/irisbrige-edge/service.env` or `~/.config/irisbrige-local/service.env`, move any custom entries into `~/.config/irisbrige/service.env`.

Each service keeps its own launchd label and logs. For `irisbrige-local`:

```bash
$(brew --prefix)/var/log/irisbrige-local.log
$(brew --prefix)/var/log/irisbrige-local.error.log
```

After changing the file, restart each service that should pick up the change:

```bash
brew services restart irisbrige-edge
brew services restart irisbrige-local
```

If you want the wrapper to create the file template for you, start either service once:

```bash
brew services start irisbrige-edge
```

To verify that the editable env file was created or reloaded, check the matching service log for the wrapper message. For `irisbrige-edge`:

```bash
tail -n 20 "$(brew --prefix)/var/log/irisbrige.log"
```

You should see a line similar to one of these:

```text
irisbrige-edge service: created editable env file at /Users/you/.config/irisbrige/service.env
irisbrige-edge service: loaded environment from /Users/you/.config/irisbrige/service.env
```

To verify that a specific non-secret variable reached the running service process:

```bash
PID="$(launchctl print gui/$(id -u)/homebrew.mxcl.irisbrige-edge | awk '/pid = / {print $3; exit}')"
ps eww -p "$PID" | grep -F 'IRISBRIGE_ENV_CHECK=service-ready'
```

<a id="linux"></a>
## Linux

Linux deployment is documented separately. The Linux guide includes:

- automatic deployment with the repository shell script
- manual deployment without the script, including `systemd` setup

See:

- [Linux Deployment Guide](./linux.md)

<a id="windows"></a>
## Windows

Windows deployment is documented separately. The Windows guide includes:

- automatic deployment with the repository PowerShell installer
- manual deployment with WinSW

See:

- [Windows Deployment Guide](./windows.md)

<a id="repository-contents"></a>
## Repository Contents

- [Formula/irisbrige-edge.rb](./Formula/irisbrige-edge.rb): Homebrew formula for the edge macOS build
- [Formula/irisbrige-local.rb](./Formula/irisbrige-local.rb): Homebrew formula for the local macOS build
- [scripts/install-irisbrige-edge-linux.sh](./scripts/install-irisbrige-edge-linux.sh): automated Linux deployment script
- [scripts/uninstall-irisbrige-edge-linux.sh](./scripts/uninstall-irisbrige-edge-linux.sh): Linux uninstaller script
- [scripts/install-irisbrige-edge-windows.ps1](./scripts/install-irisbrige-edge-windows.ps1): automated Windows deployment script
- [scripts/uninstall-irisbrige-edge-windows.ps1](./scripts/uninstall-irisbrige-edge-windows.ps1): Windows uninstaller script
- [linux.md](./linux.md): detailed Linux deployment guide
- [windows.md](./windows.md): detailed Windows deployment guide
