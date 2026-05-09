# Windows 部署说明

[English](./windows.md)

本文说明如何在 Windows 上部署 `irisbrige-edge` 或 `irisbrige-local`，并让它作为 Windows 服务长期运行。

包含两种方式：

1. 使用仓库内的 PowerShell 脚本自动部署。
2. 使用 WinSW 手动部署。

## 目录

- [前提条件](#prerequisites-zh)
- [选择构建版本](#choose-the-build-zh)
- [方式一：使用脚本自动部署](#option-1-zh)
- [以管理员身份打开 PowerShell](#open-an-elevated-powershell-session-zh)
- [执行安装脚本](#run-the-installer-zh)
- [local 构建安装脚本](#local-build-installer-zh)
- [默认安装位置](#default-locations-zh)
- [默认服务设置](#default-service-settings-zh)
- [常用参数](#common-parameters-zh)
- [查看服务状态和日志](#check-service-status-and-logs-zh)
- [如需额外环境变量](#additional-environment-variables-zh)
- [使用脚本卸载](#uninstall-with-the-script-zh)
- [local 构建卸载脚本](#local-build-uninstaller-zh)
- [方式二：手动部署](#option-2-zh)
- [检测架构](#detect-the-architecture-zh)
- [获取最新构建 release](#resolve-the-latest-build-release-zh)
- [获取最新 WinSW release](#resolve-the-latest-winsw-release-zh)
- [下载并解压文件](#download-and-extract-files-zh)
- [安装文件](#install-the-files-zh)
- [生成 WinSW XML](#create-the-winsw-xml-zh)
- [安装并启动服务](#install-and-start-the-service-zh)
- [验证服务](#verify-the-service-zh)
- [清理临时文件](#remove-temporary-files-zh)
- [故障排查](#troubleshooting-zh)

<a id="prerequisites-zh"></a>
## 前提条件

- Windows 10、Windows 11 或 Windows Server。
- PowerShell 5.1 或更新版本。
- 具备管理员权限。
- 可以访问 GitHub Releases。

如果选中的构建运行时依赖 `codex.exe`：

- 要么确保 `codex.exe` 已经在 `PATH` 中，
- 要么在安装脚本中传入 `-CodexPath`，
- 要么手动编辑生成的 WinSW XML，把正确目录加入 `PATH`

<a id="choose-the-build-zh"></a>
## 选择构建版本

开始之前先选定一个构建版本，后续整篇文档里保持对应名称一致：

| 构建 | 二进制名 | 服务 id | 安装脚本 | 卸载脚本 | 程序目录 |
| --- | --- | --- | --- | --- | --- |
| Edge | `irisbrige-edge` | `irisbrigeedge` | `install-irisbrige-edge-windows.ps1` | `uninstall-irisbrige-edge-windows.ps1` | `C:\Program Files\Irisbrige\irisbrige-edge` |
| Local | `irisbrige-local` | `irisbrigelocal` | `install-irisbrige-local-windows.ps1` | `uninstall-irisbrige-local-windows.ps1` | `C:\Program Files\Irisbrige\irisbrige-local` |

如果你想直接复制后面的命令执行，建议先设置这些变量：

```powershell
$binaryName = "irisbrige-edge"
$serviceId = "irisbrigeedge"
$displayName = "Irisbrige Edge"
$installScript = "install-irisbrige-edge-windows.ps1"
$uninstallScript = "uninstall-irisbrige-edge-windows.ps1"
$installDir = "C:\Program Files\Irisbrige\irisbrige-edge"
$dataDir = "C:\ProgramData\Irisbrige\irisbrige-edge"
$wrapperName = "irisbrige-edge-service"

# 或切换到 local 构建：
# $binaryName = "irisbrige-local"
# $serviceId = "irisbrigelocal"
# $displayName = "Irisbrige Local"
# $installScript = "install-irisbrige-local-windows.ps1"
# $uninstallScript = "uninstall-irisbrige-local-windows.ps1"
# $installDir = "C:\Program Files\Irisbrige\irisbrige-local"
# $dataDir = "C:\ProgramData\Irisbrige\irisbrige-local"
# $wrapperName = "irisbrige-local-service"
```

<a id="option-1-zh"></a>
## 方式一：使用脚本自动部署

设置好 `$installScript` 之后，脚本链接就是：

```powershell
"https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/$installScript"
```

<a id="open-an-elevated-powershell-session-zh"></a>
### 1. 以管理员身份打开 PowerShell

使用“以管理员身份运行”。

<a id="run-the-installer-zh"></a>
### 2. 执行安装脚本

直接从 GitHub 执行：

```powershell
$scriptUrl = "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/$installScript"
& ([ScriptBlock]::Create((Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing).Content))
```

脚本会自动完成以下操作：

- 判断当前 Windows 架构是 `amd64` 还是 `arm64`
- 通过 GitHub 自动获取最新 `$binaryName` release
- 下载匹配当前架构的 Windows zip 包
- 通过 GitHub 自动获取最新 WinSW release
- 优先使用原生 arm64 WinSW wrapper；如果不存在，则回退到 `WinSW-x64.exe`
- 解压 `$binaryName.exe`
- 安装可执行文件和 WinSW wrapper
- 生成 WinSW XML 配置
- 安装并启动 Windows 服务

<a id="local-build-installer-zh"></a>
### local 构建安装脚本

如果你明确要安装 `irisbrige-local`，可以直接执行专用安装脚本：

```powershell
$scriptUrl = "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/install-irisbrige-local-windows.ps1"
& ([ScriptBlock]::Create((Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing).Content))
```

这条命令会安装 `irisbrige-local`，生成 WinSW wrapper 文件，并注册对应的 Windows 服务。

<a id="default-locations-zh"></a>
### 3. 默认安装位置

- 程序目录：`$installDir`
- 数据目录：`$dataDir`
- 日志目录：`$(Join-Path $dataDir 'logs')`
- Wrapper 可执行文件：`$(Join-Path $installDir "$wrapperName.exe")`
- Wrapper XML：`$(Join-Path $installDir "$wrapperName.xml")`

<a id="default-service-settings-zh"></a>
### 4. 默认服务设置

- 内部服务 id：`$serviceId`
- 显示名称：`$displayName`
- 服务账户：`LocalSystem`
- 启动方式：自动启动并启用 delayed auto start

<a id="common-parameters-zh"></a>
### 5. 常用参数

例如：

```powershell
$scriptUrl = "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/$installScript"
& ([ScriptBlock]::Create((Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing).Content)) `
  -BinaryName $binaryName `
  -ServiceId $serviceId `
  -DisplayName $displayName `
  -InstallDir $installDir `
  -DataDir $dataDir `
  -WrapperName $wrapperName `
  -CodexPath "C:\Users\rose\AppData\Local\Programs\codex"
```

支持的参数：

- `Repository`
- `WinSWRepository`
- `BinaryName`
- `ServiceId`
- `DisplayName`
- `Description`
- `InstallDir`
- `DataDir`
- `WrapperName`
- `ServiceAccount`
- `CodexPath`
- `AdditionalPath`

`ServiceAccount` 当前支持：

- `LocalSystem`
- `LocalService`
- `NetworkService`

<a id="check-service-status-and-logs-zh"></a>
### 6. 查看服务状态和日志

查看服务：

```powershell
Get-Service -Name $serviceId
```

查看 wrapper 状态：

```powershell
& (Join-Path $installDir "$wrapperName.exe") status
```

列出日志文件：

```powershell
Get-ChildItem (Join-Path $dataDir "logs")
```

持续查看日志：

```powershell
Get-Content (Join-Path $dataDir "logs\*.log") -Wait
```

<a id="additional-environment-variables-zh"></a>
### 7. 如需额外环境变量

当前脚本不会创建单独的环境变量文件。

如果服务需要额外环境变量，直接编辑：

```powershell
Join-Path $installDir "$wrapperName.xml"
```

增加类似：

```xml
<env name="OPENAI_API_KEY" value="your-token" />
```

然后重启服务：

```powershell
& (Join-Path $installDir "$wrapperName.exe") restart
```

<a id="uninstall-with-the-script-zh"></a>
### 8. 使用脚本卸载

设置好 `$uninstallScript` 之后，卸载脚本链接就是：

```powershell
"https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/$uninstallScript"
```

默认行为：

- 删除 Windows 服务注册
- 删除程序安装目录
- 保留数据目录

执行：

```powershell
$scriptUrl = "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/$uninstallScript"
& ([ScriptBlock]::Create((Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing).Content))
```

如果你还想删除数据目录和日志：

```powershell
$scriptUrl = "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/$uninstallScript"
& ([ScriptBlock]::Create((Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing).Content)) -RemoveData
```

<a id="local-build-uninstaller-zh"></a>
### local 构建卸载脚本

如果你安装的是 `irisbrige-local`，可以直接执行：

```powershell
$scriptUrl = "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/uninstall-irisbrige-local-windows.ps1"
& ([ScriptBlock]::Create((Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing).Content))
```

如果还要一起删除数据目录和日志：

```powershell
$scriptUrl = "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/uninstall-irisbrige-local-windows.ps1"
& ([ScriptBlock]::Create((Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing).Content)) -RemoveData
```

<a id="option-2-zh"></a>
## 方式二：手动部署

以下步骤与安装脚本逻辑一致，但全部手动完成。

如果你是在新的 PowerShell 会话里执行手动步骤，先重新设置构建变量：

```powershell
$binaryName = "irisbrige-edge"
$serviceId = "irisbrigeedge"
$displayName = "Irisbrige Edge"
$description = "Irisbrige Edge background service"
$uninstallScript = "uninstall-irisbrige-edge-windows.ps1"
$installDir = "C:\Program Files\Irisbrige\irisbrige-edge"
$dataDir = "C:\ProgramData\Irisbrige\irisbrige-edge"
$wrapperName = "irisbrige-edge-service"

# 或切换到 local 构建：
# $binaryName = "irisbrige-local"
# $serviceId = "irisbrigelocal"
# $displayName = "Irisbrige Local"
# $description = "Irisbrige Local background service"
# $uninstallScript = "uninstall-irisbrige-local-windows.ps1"
# $installDir = "C:\Program Files\Irisbrige\irisbrige-local"
# $dataDir = "C:\ProgramData\Irisbrige\irisbrige-local"
# $wrapperName = "irisbrige-local-service"
```

### 1. 以管理员身份打开 PowerShell

使用“以管理员身份运行”。

<a id="detect-the-architecture-zh"></a>
### 2. 检测架构

```powershell
function Get-IrisbrigeWindowsArch {
  $bindingFlags = [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static

  try {
    $runtimeInfoType = [System.Runtime.InteropServices.RuntimeInformation]
  } catch {
    $runtimeInfoType = $null
  }

  if ($runtimeInfoType) {
    $osArchProperty = $runtimeInfoType.GetProperty("OSArchitecture", $bindingFlags)
    if ($osArchProperty) {
      switch ($osArchProperty.GetValue($null, $null).ToString()) {
        "X64"   { return "amd64" }
        "Arm64" { return "arm64" }
      }
    }
  }

  $hint = if ($env:PROCESSOR_ARCHITEW6432) {
    $env:PROCESSOR_ARCHITEW6432
  } else {
    $env:PROCESSOR_ARCHITECTURE
  }

  switch ($hint.ToUpperInvariant()) {
    "AMD64" { return "amd64" }
    "ARM64" { return "arm64" }
    default { throw "Unsupported architecture: $hint" }
  }
}

$arch = Get-IrisbrigeWindowsArch
$arch
```

<a id="resolve-the-latest-build-release-zh"></a>
### 3. 获取最新构建 release

```powershell
$headers = @{
  Accept = "application/vnd.github+json"
  "User-Agent" = "irisbrige-windows-installer"
}

$edgeRelease = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/Irisbrige/homebrew-irisbrige/releases/latest"
$edgeTag = $edgeRelease.tag_name
$edgeVersion = $edgeTag.TrimStart("v")
$edgeAssetName = "${binaryName}_${edgeVersion}_windows_${arch}.zip"
$edgeAsset = $edgeRelease.assets | Where-Object { $_.name -eq $edgeAssetName } | Select-Object -First 1

$edgeAsset.browser_download_url
```

<a id="resolve-the-latest-winsw-release-zh"></a>
### 4. 获取最新 WinSW release

```powershell
$winswRelease = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/winsw/winsw/releases/latest"

$winswAssetCandidates = if ($arch -eq "arm64") {
  @("WinSW-arm64.exe", "WinSW-x64.exe")
} else {
  @("WinSW-x64.exe")
}

$winswAsset = foreach ($candidate in $winswAssetCandidates) {
  $match = $winswRelease.assets | Where-Object { $_.name -eq $candidate } | Select-Object -First 1
  if ($match) {
    $match
    break
  }
}

$winswAsset.browser_download_url
```

<a id="download-and-extract-files-zh"></a>
### 5. 下载并解压文件

```powershell
$logsDir = Join-Path $dataDir "logs"
$tempDir = Join-Path $env:TEMP ("$binaryName-install-" + [guid]::NewGuid().ToString("N"))

New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$edgeZip = Join-Path $tempDir "$binaryName.zip"
$edgeExtractDir = Join-Path $tempDir "edge"
$winswExe = Join-Path $tempDir $winswAsset.name

Invoke-WebRequest -Headers $headers -Uri $edgeAsset.browser_download_url -OutFile $edgeZip -UseBasicParsing
Invoke-WebRequest -Headers $headers -Uri $winswAsset.browser_download_url -OutFile $winswExe -UseBasicParsing

Expand-Archive -Path $edgeZip -DestinationPath $edgeExtractDir -Force
$edgeExe = Get-ChildItem -Path $edgeExtractDir -Recurse -Filter "$binaryName.exe" -File | Select-Object -First 1
```

<a id="install-the-files-zh"></a>
### 6. 安装文件

```powershell
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
New-Item -ItemType Directory -Path $logsDir -Force | Out-Null

Copy-Item $edgeExe.FullName (Join-Path $installDir "$binaryName.exe") -Force
Copy-Item $winswExe (Join-Path $installDir "$wrapperName.exe") -Force
```

<a id="create-the-winsw-xml-zh"></a>
### 7. 生成 WinSW XML

下面使用的 Windows 内部服务 id 使用 `$serviceId`。

```powershell
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$servicePath = "$installDir;$machinePath"
$xmlPath = Join-Path $installDir "$wrapperName.xml"

@"
<service>
  <id>$serviceId</id>
  <name>$displayName</name>
  <description>$description</description>
  <executable>%BASE%\$binaryName.exe</executable>
  <arguments>server</arguments>
  <workingdirectory>%BASE%</workingdirectory>
  <startmode>Automatic</startmode>
  <delayedAutoStart/>
  <env name="PATH" value="$servicePath" />
  <logpath>$logsDir</logpath>
  <log mode="roll" />
  <onfailure action="restart" delay="10 sec" />
  <serviceaccount>
    <user>LocalSystem</user>
  </serviceaccount>
</service>
"@ | Set-Content -Path $xmlPath -Encoding ASCII
```

如果 `codex.exe` 不在 machine PATH 中，请先把它的目录追加到 `$servicePath`，再写入 XML。

<a id="install-and-start-the-service-zh"></a>
### 8. 安装并启动服务

```powershell
$wrapper = Join-Path $installDir "$wrapperName.exe"

& $wrapper install
& $wrapper start
```

<a id="verify-the-service-zh"></a>
### 9. 验证服务

```powershell
Get-Service -Name $serviceId
& $wrapper status
Get-ChildItem $logsDir
```

<a id="remove-temporary-files-zh"></a>
### 10. 清理临时文件

```powershell
Remove-Item -Path $tempDir -Recurse -Force
```

<a id="troubleshooting-zh"></a>
## 故障排查

### 服务启动后立即退出

优先查看：

```powershell
Get-ChildItem (Join-Path $dataDir "logs")
Get-Content (Join-Path $dataDir "logs\*.log") -Tail 200
```

### 找不到 `codex.exe`

重新执行安装脚本并传入 `-CodexPath`，或者编辑 WinSW XML，把正确目录加入 `PATH` 环境变量。

### 服务已经存在，但需要重新安装

```powershell
& (Join-Path $installDir "$wrapperName.exe") stop
& (Join-Path $installDir "$wrapperName.exe") uninstall
```

然后重新运行安装脚本。

### 需要彻底移除服务

使用卸载脚本：

```powershell
$scriptUrl = "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/$uninstallScript"
& ([ScriptBlock]::Create((Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing).Content))
```

如果还要删除数据目录：

```powershell
$scriptUrl = "https://raw.githubusercontent.com/Irisbrige/homebrew-irisbrige/refs/heads/main/scripts/$uninstallScript"
& ([ScriptBlock]::Create((Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing).Content)) -RemoveData
```
