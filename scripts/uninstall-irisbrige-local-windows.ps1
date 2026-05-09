[CmdletBinding()]
param(
  [string]$ServiceId = "irisbrigelocal",
  [string]$InstallDir = "$env:ProgramFiles\Irisbrige\irisbrige-local",
  [string]$DataDir = "$env:ProgramData\Irisbrige\irisbrige-local",
  [string]$WrapperName = "irisbrige-local-service",
  [switch]$RemoveData
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info {
  param([string]$Message)
  Write-Host "[INFO] $Message"
}

function Fail {
  param([string]$Message)
  throw $Message
}

function Assert-Windows {
  if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    Fail "This uninstaller only supports Windows."
  }
}

function Assert-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Fail "Please run this script from an elevated PowerShell session."
  }
}

function Assert-ServiceId {
  param([string]$InternalServiceId)

  if ($InternalServiceId -notmatch '^[A-Za-z0-9]+$') {
    Fail "ServiceId must contain only letters and numbers for WinSW compatibility: $InternalServiceId"
  }
}

function Get-WrapperExecutable {
  param(
    [string]$ProgramDirectory,
    [string]$WinSWName
  )

  Join-Path $ProgramDirectory "$WinSWName.exe"
}

function Remove-ServiceRegistration {
  param(
    [string]$InternalServiceId,
    [string]$WrapperExecutable
  )

  $service = Get-Service -Name $InternalServiceId -ErrorAction SilentlyContinue
  if (-not $service) {
    Write-Info "Windows service $InternalServiceId is not installed."
    return
  }

  if (Test-Path -LiteralPath $WrapperExecutable) {
    Write-Info "Stopping service with WinSW wrapper"
    try {
      & $WrapperExecutable stopwait | Out-Null
    } catch {
      Write-Warning "WinSW stopwait failed: $($_.Exception.Message)"
    }

    Write-Info "Uninstalling service with WinSW wrapper"
    try {
      & $WrapperExecutable uninstall | Out-Null
    } catch {
      Write-Warning "WinSW uninstall failed: $($_.Exception.Message)"
    }
  }

  Start-Sleep -Seconds 2
  $service = Get-Service -Name $InternalServiceId -ErrorAction SilentlyContinue
  if ($service) {
    Write-Info "Removing remaining service registration with sc.exe"
    try {
      & sc.exe stop $InternalServiceId | Out-Null
    } catch {
    }

    Start-Sleep -Seconds 2
    & sc.exe delete $InternalServiceId | Out-Null
    Start-Sleep -Seconds 2
  }
}

function Remove-DirectoryIfExists {
  param(
    [string]$DirectoryPath,
    [string]$Label
  )

  if (-not (Test-Path -LiteralPath $DirectoryPath)) {
    Write-Info "$Label does not exist: $DirectoryPath"
    return
  }

  Write-Info "Removing $Label: $DirectoryPath"
  Remove-Item -LiteralPath $DirectoryPath -Recurse -Force
}

function Print-Summary {
  param(
    [string]$InternalServiceId,
    [string]$ProgramDirectory,
    [string]$StateDirectory,
    [bool]$DataWasRemoved
  )

  Write-Host ""
  Write-Host "Removed Windows service id: $InternalServiceId"
  Write-Host "Removed install directory: $ProgramDirectory"
  if ($DataWasRemoved) {
    Write-Host "Removed data directory: $StateDirectory"
  } else {
    Write-Host "Preserved data directory: $StateDirectory"
    Write-Host "Re-run with -RemoveData to remove it as well."
  }
}

function Main {
  Assert-Windows
  Assert-Administrator
  Assert-ServiceId -InternalServiceId $ServiceId

  $wrapperExecutable = Get-WrapperExecutable -ProgramDirectory $InstallDir -WinSWName $WrapperName

  Remove-ServiceRegistration -InternalServiceId $ServiceId -WrapperExecutable $wrapperExecutable
  Remove-DirectoryIfExists -DirectoryPath $InstallDir -Label "install directory"

  if ($RemoveData) {
    Remove-DirectoryIfExists -DirectoryPath $DataDir -Label "data directory"
  }

  Print-Summary `
    -InternalServiceId $ServiceId `
    -ProgramDirectory $InstallDir `
    -StateDirectory $DataDir `
    -DataWasRemoved $RemoveData.IsPresent
}

Main
