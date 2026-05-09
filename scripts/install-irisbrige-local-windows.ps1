[CmdletBinding()]
param(
  [string]$Repository = "Irisbrige/homebrew-irisbrige",
  [string]$WinSWRepository = "winsw/winsw",
  [string]$BinaryName = "irisbrige-local",
  [string]$ServiceId = "irisbrigelocal",
  [string]$DisplayName = "Irisbrige Local",
  [string]$Description = "Irisbrige Local background service",
  [string]$InstallDir = "$env:ProgramFiles\Irisbrige\irisbrige-local",
  [string]$DataDir = "$env:ProgramData\Irisbrige\irisbrige-local",
  [string]$WrapperName = "irisbrige-local-service",
  [ValidateSet("LocalSystem", "LocalService", "NetworkService")]
  [string]$ServiceAccount = "LocalSystem",
  [string]$CodexPath,
  [string]$AdditionalPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:TempDir = $null

function Write-Info {
  param([string]$Message)
  Write-Host "[INFO] $Message"
}

function Fail {
  param([string]$Message)
  throw $Message
}

function Cleanup-TempDir {
  if ($script:TempDir -and (Test-Path -LiteralPath $script:TempDir)) {
    Remove-Item -LiteralPath $script:TempDir -Recurse -Force
  }
}

function Assert-Windows {
  if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    Fail "This installer only supports Windows."
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

function New-TempDir {
  $path = Join-Path ([IO.Path]::GetTempPath()) ("irisbrige-local-install-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $path -Force | Out-Null
  return $path
}

function New-GitHubHeaders {
  $headers = @{
    "Accept" = "application/vnd.github+json"
    "User-Agent" = "irisbrige-local-installer"
  }

  if ($env:GITHUB_TOKEN) {
    $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
  }

  return $headers
}

function Get-LatestRelease {
  param([string]$Repo)

  $uri = "https://api.github.com/repos/$Repo/releases/latest"
  Invoke-RestMethod -Headers (New-GitHubHeaders) -Uri $uri -Method Get
}

function Get-WindowsOsArchitecture {
  $bindingFlags = [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static

  try {
    $runtimeInfoType = [System.Runtime.InteropServices.RuntimeInformation]
  } catch {
    $runtimeInfoType = $null
  }

  if ($runtimeInfoType) {
    $osArchProperty = $runtimeInfoType.GetProperty("OSArchitecture", $bindingFlags)
    if ($osArchProperty) {
      $osArch = $osArchProperty.GetValue($null, $null)
      if ($osArch) {
        return $osArch.ToString()
      }
    }
  }

  $processorArchitecture = $null

  if (Get-Command -Name Get-CimInstance -ErrorAction SilentlyContinue) {
    try {
      $processorArchitecture = (Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1).Architecture
    } catch {
    }
  }

  if ($null -eq $processorArchitecture -and (Get-Command -Name Get-WmiObject -ErrorAction SilentlyContinue)) {
    try {
      $processorArchitecture = (Get-WmiObject -Class Win32_Processor -ErrorAction Stop | Select-Object -First 1).Architecture
    } catch {
    }
  }

  if ($null -ne $processorArchitecture) {
    switch ([int]$processorArchitecture) {
      9 { return "X64" }
      12 { return "Arm64" }
      0 { return "X86" }
    }
  }

  $envArchitecture = if ($env:PROCESSOR_ARCHITEW6432) {
    $env:PROCESSOR_ARCHITEW6432
  } elseif ($env:PROCESSOR_ARCHITECTURE) {
    $env:PROCESSOR_ARCHITECTURE
  } else {
    $null
  }

  if ($envArchitecture) {
    switch ($envArchitecture.ToUpperInvariant()) {
      "AMD64" { return "X64" }
      "X64" { return "X64" }
      "ARM64" { return "Arm64" }
      "X86" { return "X86" }
    }
  }

  Fail "Could not determine the Windows architecture."
}

function Get-WindowsAssetArch {
  $osArch = Get-WindowsOsArchitecture

  switch ($osArch) {
    "X64" { return "amd64" }
    "Arm64" { return "arm64" }
    default { Fail "Unsupported Windows architecture: $osArch" }
  }
}

function Get-AssetByName {
  param(
    [object[]]$Assets,
    [string[]]$CandidateNames
  )

  foreach ($candidate in $CandidateNames) {
    $asset = $Assets | Where-Object { $_.name -eq $candidate } | Select-Object -First 1
    if ($asset) {
      return $asset
    }
  }

  Fail ("Could not find a matching release asset. Tried: " + ($CandidateNames -join ", "))
}

function Invoke-Download {
  param(
    [string]$Url,
    [string]$OutFile
  )

  Invoke-WebRequest -Headers (New-GitHubHeaders) -Uri $Url -OutFile $OutFile -UseBasicParsing
}

function Resolve-CodexDirectory {
  param([string]$ProvidedPath)

  if ($ProvidedPath) {
    if (-not (Test-Path -LiteralPath $ProvidedPath)) {
      Fail "CodexPath does not exist: $ProvidedPath"
    }

    $item = Get-Item -LiteralPath $ProvidedPath
    if ($item.PSIsContainer) {
      return $item.FullName
    }

    return $item.Directory.FullName
  }

  $command = Get-Command codex -ErrorAction SilentlyContinue
  if ($command -and $command.Source) {
    Write-Info "Detected codex on PATH: $($command.Source)"
    return (Split-Path -Path $command.Source -Parent)
  }

  Write-Warning "codex.exe was not found on the current PATH. If $BinaryName requires codex at runtime, rerun this installer with -CodexPath or edit the generated WinSW XML to add its directory to PATH."
  return $null
}

function Join-PathSegments {
  param([string[]]$Segments)

  $seen = @{}
  $ordered = New-Object System.Collections.Generic.List[string]

  foreach ($segmentGroup in $Segments) {
    if (-not $segmentGroup) {
      continue
    }

    foreach ($rawSegment in ($segmentGroup -split ";")) {
      $segment = $rawSegment.Trim()
      if (-not $segment) {
        continue
      }

      $key = $segment.ToLowerInvariant()
      if (-not $seen.ContainsKey($key)) {
        $seen[$key] = $true
        $ordered.Add($segment)
      }
    }
  }

  return ($ordered -join ";")
}

function Build-ServicePath {
  param(
    [string]$InstallPath,
    [string]$CodexDirectory,
    [string]$ExtraPath
  )

  $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
  Join-PathSegments -Segments @($InstallPath, $CodexDirectory, $ExtraPath, $machinePath)
}

function Expand-BinaryArchive {
  param(
    [string]$ArchivePath,
    [string]$DestinationPath,
    [string]$ExeName
  )

  Expand-Archive -Path $ArchivePath -DestinationPath $DestinationPath -Force
  $binary = Get-ChildItem -Path $DestinationPath -Recurse -File -Filter "$ExeName.exe" | Select-Object -First 1
  if (-not $binary) {
    Fail "Archive did not contain $ExeName.exe"
  }

  return $binary.FullName
}

function Escape-Xml {
  param([string]$Value)

  return [Security.SecurityElement]::Escape($Value)
}

function Get-ServiceAccountXml {
  param([string]$Account)

  switch ($Account) {
    "LocalService" {
      return @"
  <serviceaccount>
    <domain>NT AUTHORITY</domain>
    <user>LocalService</user>
  </serviceaccount>
"@
    }
    "NetworkService" {
      return @"
  <serviceaccount>
    <domain>NT AUTHORITY</domain>
    <user>NetworkService</user>
  </serviceaccount>
"@
    }
    default {
      return @"
  <serviceaccount>
    <user>LocalSystem</user>
  </serviceaccount>
"@
    }
  }
}

function Grant-LogDirectoryAccess {
  param(
    [string]$DirectoryPath,
    [string]$Account
  )

  $identity = switch ($Account) {
    "LocalService" { "NT AUTHORITY\LocalService" }
    "NetworkService" { "NT AUTHORITY\NetworkService" }
    default { $null }
  }

  if (-not $identity) {
    return
  }

  $acl = Get-Acl -LiteralPath $DirectoryPath
  $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $identity,
    "Modify",
    "ContainerInherit, ObjectInherit",
    "None",
    "Allow"
  )
  $acl.SetAccessRule($rule)
  Set-Acl -LiteralPath $DirectoryPath -AclObject $acl
}

function Write-ServiceXml {
  param(
    [string]$XmlPath,
    [string]$InternalServiceId,
    [string]$DisplayServiceName,
    [string]$ServiceDescription,
    [string]$ServicePathValue,
    [string]$LogDirectory,
    [string]$AccountXml
  )

  $xml = @"
<service>
  <id>$(Escape-Xml $InternalServiceId)</id>
  <name>$(Escape-Xml $DisplayServiceName)</name>
  <description>$(Escape-Xml $ServiceDescription)</description>
  <executable>%BASE%\$BinaryName.exe</executable>
  <arguments>server</arguments>
  <workingdirectory>%BASE%</workingdirectory>
  <startmode>Automatic</startmode>
  <delayedAutoStart/>
  <env name="PATH" value="$(Escape-Xml $ServicePathValue)" />
  <logpath>$(Escape-Xml $LogDirectory)</logpath>
  <log mode="roll" />
  <onfailure action="restart" delay="10 sec" />
$AccountXml
</service>
"@

  Set-Content -LiteralPath $XmlPath -Value $xml -Encoding ASCII
}

function Remove-ExistingService {
  param(
    [string]$InternalServiceId,
    [string]$WrapperExecutable
  )

  $service = Get-Service -Name $InternalServiceId -ErrorAction SilentlyContinue
  if (-not $service) {
    return
  }

  Write-Info "Existing service detected. Reinstalling $InternalServiceId"

  if (Test-Path -LiteralPath $WrapperExecutable) {
    try {
      & $WrapperExecutable stopwait | Out-Null
    } catch {
    }

    try {
      & $WrapperExecutable uninstall | Out-Null
    } catch {
    }
  }

  Start-Sleep -Seconds 2
  $service = Get-Service -Name $InternalServiceId -ErrorAction SilentlyContinue
  if ($service) {
    & sc.exe stop $InternalServiceId | Out-Null
    Start-Sleep -Seconds 2
    & sc.exe delete $InternalServiceId | Out-Null
    Start-Sleep -Seconds 2
  }
}

function Install-Service {
  param([string]$WrapperExecutable)

  & $WrapperExecutable install | Out-Null
  & $WrapperExecutable start | Out-Null
}

function Print-Summary {
  param(
    [string]$ReleaseTag,
    [string]$WinSWTag,
    [string]$InstallPath,
    [string]$StateDirectory,
    [string]$InternalServiceId
  )

  Write-Host ""
  Write-Host "Installed $BinaryName to: $InstallPath"
  Write-Host "Latest $BinaryName release tag: $ReleaseTag"
  Write-Host "Latest WinSW release tag: $WinSWTag"
  Write-Host "Windows service id: $InternalServiceId"
  Write-Host "Display name: $DisplayName"
  Write-Host "Logs directory: $(Join-Path $StateDirectory 'logs')"
  Write-Host ""
  Write-Host "Useful commands:"
  Write-Host "  Get-Service -Name $InternalServiceId"
  Write-Host "  Get-ChildItem '$(Join-Path $StateDirectory 'logs')'"
  Write-Host "  & '$(Join-Path $InstallPath "$WrapperName.exe")' status"
}

function Main {
  Assert-Windows
  Assert-Administrator
  Assert-ServiceId -InternalServiceId $ServiceId

  $releaseArch = Get-WindowsAssetArch
  $release = Get-LatestRelease -Repo $Repository
  $releaseVersion = $release.tag_name.TrimStart("v")
  $releaseAssetName = "${BinaryName}_${releaseVersion}_windows_${releaseArch}.zip"
  $releaseAsset = Get-AssetByName -Assets $release.assets -CandidateNames @($releaseAssetName)

  $winswRelease = Get-LatestRelease -Repo $WinSWRepository
  $winswAssetCandidates = if ($releaseArch -eq "arm64") {
    @("WinSW-arm64.exe", "WinSW-x64.exe")
  } else {
    @("WinSW-x64.exe")
  }
  $winswAsset = Get-AssetByName -Assets $winswRelease.assets -CandidateNames $winswAssetCandidates

  if ($releaseArch -eq "arm64" -and $winswAsset.name -eq "WinSW-x64.exe") {
    Write-Warning "No native WinSW arm64 wrapper was found in the latest WinSW release. Falling back to WinSW-x64.exe."
  }

  $codexDirectory = Resolve-CodexDirectory -ProvidedPath $CodexPath
  $servicePath = Build-ServicePath -InstallPath $InstallDir -CodexDirectory $codexDirectory -ExtraPath $AdditionalPath

  $script:TempDir = New-TempDir
  $releaseZipPath = Join-Path $script:TempDir "$BinaryName.zip"
  $releaseExtractDir = Join-Path $script:TempDir "package"
  $winswDownloadPath = Join-Path $script:TempDir $winswAsset.name

  New-Item -ItemType Directory -Path $releaseExtractDir -Force | Out-Null

  Write-Info "Downloading $BinaryName $($release.tag_name) for $releaseArch"
  Invoke-Download -Url $releaseAsset.browser_download_url -OutFile $releaseZipPath

  Write-Info "Downloading WinSW wrapper $($winswRelease.tag_name)"
  Invoke-Download -Url $winswAsset.browser_download_url -OutFile $winswDownloadPath

  $binaryPath = Expand-BinaryArchive -ArchivePath $releaseZipPath -DestinationPath $releaseExtractDir -ExeName $BinaryName
  $wrapperTargetPath = Join-Path $InstallDir "$WrapperName.exe"
  $wrapperXmlPath = Join-Path $InstallDir "$WrapperName.xml"
  $binaryTargetPath = Join-Path $InstallDir "$BinaryName.exe"
  $logsDir = Join-Path $DataDir "logs"

  Remove-ExistingService -InternalServiceId $ServiceId -WrapperExecutable $wrapperTargetPath

  New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
  New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
  Grant-LogDirectoryAccess -DirectoryPath $logsDir -Account $ServiceAccount

  Copy-Item -LiteralPath $binaryPath -Destination $binaryTargetPath -Force
  Copy-Item -LiteralPath $winswDownloadPath -Destination $wrapperTargetPath -Force

  $serviceAccountXml = Get-ServiceAccountXml -Account $ServiceAccount
  Write-ServiceXml `
    -XmlPath $wrapperXmlPath `
    -InternalServiceId $ServiceId `
    -DisplayServiceName $DisplayName `
    -ServiceDescription $Description `
    -ServicePathValue $servicePath `
    -LogDirectory $logsDir `
    -AccountXml $serviceAccountXml

  Install-Service -WrapperExecutable $wrapperTargetPath

  Print-Summary `
    -ReleaseTag $release.tag_name `
    -WinSWTag $winswRelease.tag_name `
    -InstallPath $InstallDir `
    -StateDirectory $DataDir `
    -InternalServiceId $ServiceId
}

try {
  Main
} finally {
  Cleanup-TempDir
}
