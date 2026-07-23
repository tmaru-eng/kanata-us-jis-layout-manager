<# Installs per-user tasks and copies the package to LocalAppData. #>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string]$KanataPath,
  [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'KanataLayoutManager')
)

$KanataPath = (Resolve-Path -LiteralPath $KanataPath).Path
New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
$configSource = Join-Path $PSScriptRoot 'config\kanata-us-to-jis-wintercept.kbd'
$installedConfig = Join-Path $InstallRoot 'kanata-us-to-jis-wintercept.kbd'
$statePath = Join-Path $InstallRoot 'keyboard-layout-state.json'
if (Test-Path -LiteralPath $statePath) {
  if (Test-Path -LiteralPath $installedConfig) {
    $backup = Join-Path $InstallRoot ('kanata-us-to-jis-wintercept.kbd.bak-' + (Get-Date).ToString('yyyyMMddHHmmss'))
    Copy-Item -LiteralPath $installedConfig -Destination $backup -Force
  }
  Copy-Item -LiteralPath $configSource -Destination $installedConfig -Force
} elseif (-not (Test-Path -LiteralPath $installedConfig)) {
  Copy-Item -LiteralPath $configSource -Destination $installedConfig -Force
} else {
  Write-Host '既存のKanata設定ファイルを保持します。'
}
foreach ($file in @('KanataLayout.Common.ps1', 'Reconfigure-KanataKeyboard.ps1', 'Invoke-KanataLayoutManager.ps1', 'Show-KanataKeyboardProfiles.ps1', 'Test-KanataLayoutManager.ps1')) {
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot "src\$file") -Destination (Join-Path $InstallRoot $file) -Force
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Uninstall-KanataLayoutManager.ps1') -Destination (Join-Path $InstallRoot 'Uninstall-KanataLayoutManager.ps1') -Force
if (Test-Path -LiteralPath $statePath) {
  . (Join-Path $InstallRoot 'KanataLayout.Common.ps1')
  Update-KanataConfig (Get-LayoutState $statePath) $installedConfig
}
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'launchers')) {
  $launcherRoot = Join-Path $InstallRoot 'launchers'
  $launcherSourceRoot = Join-Path $PSScriptRoot 'launchers'
  New-Item -ItemType Directory -Path $launcherRoot -Force | Out-Null
  foreach ($launcher in @('Reconfigure-Keyboard.cmd', 'Show-Profiles.cmd', 'Test-Installation.cmd', 'Uninstall.cmd')) {
    Copy-Item -LiteralPath (Join-Path $launcherSourceRoot $launcher) -Destination (Join-Path $launcherRoot $launcher) -Force
  }
}
Set-Content -LiteralPath (Join-Path $InstallRoot 'kanata-path.txt') -Value $KanataPath -Encoding utf8

$manager = Join-Path $InstallRoot 'Invoke-KanataLayoutManager.ps1'
$taskBase = 'Kanata Layout Manager'
$args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$manager`" -InstallRoot `"$InstallRoot`""
## schtasks /SC ONLOGON is denied for non-elevated users; Register-ScheduledTask
## with a current-user logon trigger works without elevation.
## Task Scheduler defaults refuse to start on battery power; this is a laptop
## setup, so allow battery operation explicitly on both tasks.
$taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$logonAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $args
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
Register-ScheduledTask -TaskName "$taskBase - Logon" -Action $logonAction -Trigger $logonTrigger -Settings $taskSettings -Force | Out-Null
& schtasks.exe /Create /TN "$taskBase - PnP" /SC ONEVENT /EC 'Microsoft-Windows-Kernel-PnP/Configuration' /MO '*[System[*]]' /TR "powershell.exe $args" /F | Out-Null
Set-ScheduledTask -TaskName "$taskBase - PnP" -Settings $taskSettings | Out-Null

Write-Host 'インストールしました。既知USが接続されていればKanataを起動します。'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $manager -InstallRoot $InstallRoot
