<#
.SYNOPSIS
  Performs checks that do not require an external keyboard.
#>
[CmdletBinding()]
param([string]$InstallRoot = $PSScriptRoot)

$ErrorActionPreference = 'Stop'
$errors = @()
function Check([string]$Name, [scriptblock]$Action) {
  try { & $Action; Write-Host "PASS  $Name" -ForegroundColor Green }
  catch { $script:errors += "$Name : $($_.Exception.Message)"; Write-Host "FAIL  $Name" -ForegroundColor Red }
}

Check 'Windows PowerShell' {
  if ($env:OS -ne 'Windows_NT') { throw 'Windowsではありません。' }
}
Check 'Kanata設定ファイル' {
  $config = Join-Path $InstallRoot 'kanata-us-to-jis-wintercept.kbd'
  if (-not (Test-Path -LiteralPath $config)) { throw '設定ファイルがありません。' }
  $text = Get-Content -LiteralPath $config -Raw
  if ($text -notmatch 'US_HWIDS_BEGIN' -or $text -notmatch 'US_HWIDS_END') { throw 'HWIDマーカーがありません。' }
}
Check 'PowerShellスクリプト構文' {
  foreach ($path in (Get-ChildItem -LiteralPath $InstallRoot -Filter '*.ps1' -File)) {
    $tokens = $null; $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($path.FullName, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) { throw "$($path.Name): $($parseErrors[0].Message)" }
  }
}
Check 'Kanata実行ファイル' {
  $pathFile = Join-Path $InstallRoot 'kanata-path.txt'
  if (-not (Test-Path -LiteralPath $pathFile)) { throw 'kanata-path.txtがありません。' }
  $kanata = (Get-Content -LiteralPath $pathFile -Raw).Trim()
  if (-not (Test-Path -LiteralPath $kanata)) { throw "Kanataがありません: $kanata" }
  & $kanata --help | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Kanata --help が失敗しました。' }
}
Check 'Interception DLL' {
  $kanata = (Get-Content -LiteralPath (Join-Path $InstallRoot 'kanata-path.txt') -Raw).Trim()
  if (-not (Test-Path -LiteralPath (Join-Path (Split-Path $kanata -Parent) 'interception.dll'))) { throw 'Kanataと同じフォルダにinterception.dllがありません。' }
}
Check 'スケジュールタスク' {
  foreach ($task in @('Kanata Layout Manager - Logon', 'Kanata Layout Manager - PnP')) {
    & schtasks.exe /Query /TN $task 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "$task が登録されていません。" }
  }
}

if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Host $_ -ForegroundColor Red }; exit 1 }
Write-Host '外部キーボード不要の確認はすべて成功しました。'
