<# Removes per-user scheduled tasks and all saved layout decisions. #>
[CmdletBinding()]
param([string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'KanataLayoutManager'))

& schtasks.exe /Delete /TN 'Kanata Layout Manager - Logon' /F 2>$null | Out-Null
& schtasks.exe /Delete /TN 'Kanata Layout Manager - PnP' /F 2>$null | Out-Null
if (Test-Path -LiteralPath $InstallRoot) { Remove-Item -LiteralPath $InstallRoot -Recurse -Force }
Write-Host 'アンインストールしました。保存済みのUS/JIS判定も削除しました。'
