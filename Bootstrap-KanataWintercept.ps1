<#
.SYNOPSIS
  Installs Kanata wintercept and the per-user layout manager.

.DESCRIPTION
  Prefers the bundled binaries in .\bin (patched kanata build + interception
  runtime, see docs\KANATA-PATCH.md). Only when the bundle is missing does it
  download the official Kanata release and Interception package.

  The driver installation is intentionally interactive: it requests UAC
  elevation and a reboot. Do not run it if another tool depends on a different
  Interception installation.
#>
[CmdletBinding()]
param(
  [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'KanataLayoutManager'),
  [switch]$SkipDriverInstall,
  [switch]$PrepareOnly
)

$ErrorActionPreference = 'Stop'

function Get-GithubLatestRelease([string]$Repository) {
  Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest" -Headers @{ 'User-Agent' = 'KanataLayoutManager' }
}

function Save-GithubAsset($Asset, [string]$Destination) {
  Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $Destination -Headers @{ 'User-Agent' = 'KanataLayoutManager' }
  if ($Asset.digest -and $Asset.digest.StartsWith('sha256:')) {
    $actual = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash.ToLowerInvariant()
    $expected = $Asset.digest.Substring(7).ToLowerInvariant()
    if ($actual -ne $expected) { throw "ダウンロードした $($Asset.name) のSHA-256が一致しません。" }
  }
}

if ($env:OS -ne 'Windows_NT') { throw 'Windowsで実行してください。' }
if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { throw 'InterceptionドライバはこのブートストラップではARM64を対象外とします。' }

$bundleDir = Join-Path $PSScriptRoot 'bin'
$bundledKanata = Join-Path $bundleDir 'kanata_wintercept_cmd_allowed_patched.exe'
$bundledDll = Join-Path $bundleDir 'interception.dll'
$bundledInstaller = Join-Path $bundleDir 'install-interception.exe'
$useBundle = (Test-Path -LiteralPath $bundledKanata) -and (Test-Path -LiteralPath $bundledDll)

$temp = Join-Path ([IO.Path]::GetTempPath()) ('kanata-bootstrap-' + [guid]::NewGuid())
$runtime = Join-Path $InstallRoot 'runtime'
New-Item -ItemType Directory -Path $temp, $runtime -Force | Out-Null

## Replacing the runtime exe fails while it is running; stop only instances
## launched from this runtime directory.
$runtimePattern = [regex]::Escape($runtime)
Get-CimInstance Win32_Process -Filter "Name LIKE 'kanata%'" -ErrorAction SilentlyContinue |
  Where-Object { $_.ExecutablePath -and $_.ExecutablePath -match $runtimePattern } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Start-Sleep -Milliseconds 500

try {
  $installer = $null
  if ($useBundle) {
    Write-Host '同梱バイナリ(パッチ版Kanata)を使用します。ダウンロードは行いません。'
    Copy-Item -LiteralPath $bundledKanata -Destination (Join-Path $runtime 'kanata_wintercept_cmd_allowed.exe') -Force
    Copy-Item -LiteralPath $bundledDll -Destination (Join-Path $runtime 'interception.dll') -Force
    if (Test-Path -LiteralPath $bundledInstaller) { $installer = $bundledInstaller }
  } else {
    Write-Host '同梱バイナリが見つからないため、公式Releaseからダウンロードします。'
    Write-Warning '公式版Kanataには ro/¥ キー出力の未実装(docs\KANATA-PATCH.md参照)があり、_ \ | の入力でIME未確定文字列が消えます。'
    $kanataRelease = Get-GithubLatestRelease 'jtroo/kanata'
    $kanataAsset = @($kanataRelease.assets | Where-Object { $_.name -match '^kanata-windows-binaries-x64-.*\.zip$' }) | Select-Object -First 1
    if (-not $kanataAsset) { throw '公式Kanata ReleaseにWindows x64バンドルが見つかりません。' }
    $kanataZip = Join-Path $temp $kanataAsset.name
    Save-GithubAsset $kanataAsset $kanataZip
    $kanataExtract = Join-Path $temp 'kanata'
    Expand-Archive -LiteralPath $kanataZip -DestinationPath $kanataExtract -Force
    $kanataExe = Get-ChildItem -LiteralPath $kanataExtract -Recurse -File |
      Where-Object { $_.Name -match 'wintercept.*cmd_allowed.*\.exe$' } |
      Select-Object -First 1
    if (-not $kanataExe) { throw 'wintercept cmd_allowed実行ファイルがKanataバンドルにありません。' }
    Copy-Item -LiteralPath $kanataExe.FullName -Destination (Join-Path $runtime 'kanata_wintercept_cmd_allowed.exe') -Force

    $interceptionRelease = Get-GithubLatestRelease 'oblitum/Interception'
    $interceptionAsset = @($interceptionRelease.assets | Where-Object { $_.name -match '\.zip$' }) | Select-Object -First 1
    if (-not $interceptionAsset) { throw '公式Interception ReleaseにZIPアセットが見つかりません。' }
    $interceptionZip = Join-Path $temp $interceptionAsset.name
    Save-GithubAsset $interceptionAsset $interceptionZip
    $interceptionExtract = Join-Path $temp 'interception'
    Expand-Archive -LiteralPath $interceptionZip -DestinationPath $interceptionExtract -Force
    $dll = Get-ChildItem -LiteralPath $interceptionExtract -Recurse -File -Filter 'interception.dll' |
      Where-Object { $_.FullName -match '\\x64\\' } | Select-Object -First 1
    if (-not $dll) { throw 'Interceptionのx64 interception.dllが見つかりません。' }
    Copy-Item -LiteralPath $dll.FullName -Destination (Join-Path $runtime 'interception.dll') -Force
    $installer = (Get-ChildItem -LiteralPath $interceptionExtract -Recurse -File -Filter 'install-interception.exe' | Select-Object -First 1).FullName
  }

  if ($PrepareOnly) {
    & (Join-Path $runtime 'kanata_wintercept_cmd_allowed.exe') --help | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Kanataの--help実行に失敗しました。' }
    Write-Host '準備確認が完了しました。ドライバ、タスク、キーボード設定は変更していません。'
    return
  }

  if (-not $SkipDriverInstall) {
    $answer = Read-Host 'Interception入力ドライバを管理者権限で導入します。再起動が必要です。続行 [y/N]'
    if ($answer -match '^[Yy]') {
      if (-not $installer -or -not (Test-Path -LiteralPath $installer)) { throw 'install-interception.exe が見つかりません。' }
      Start-Process -FilePath $installer -ArgumentList '/install' -Verb RunAs -Wait
    } else {
      Write-Warning 'ドライバ導入を省略しました。既存導入済みでなければwinterceptは動作しません。'
    }
  }

  & (Join-Path $PSScriptRoot 'Install-KanataLayoutManager.ps1') -KanataPath (Join-Path $runtime 'kanata_wintercept_cmd_allowed.exe') -InstallRoot $InstallRoot
  Write-Host '完了しました。ドライバを導入した場合は、必ずWindowsを再起動してください。'
}
finally {
  if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
