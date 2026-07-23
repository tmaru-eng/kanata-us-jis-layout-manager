<#
  Runs from Scheduled Tasks (logon / PnP). Its ONLY job is to keep the resident
  kanata running whenever at least one US keyboard is registered.

  It deliberately does NOT auto-open a registration wizard, and does NOT gate on
  the slow / flaky Windows HardwareId present-check. A single Bluetooth connect
  fires many PnP events, and auto-launching wizards used to race, stop/restart
  the resident kanata, and spawn competing Interception probes that swallowed
  all keyboard input.

  kanata itself filters by the numeric HWID list inside the .kbd, so running it
  while the US keyboard is unplugged is harmless (it intercepts nothing). New
  keyboards are registered manually with Reconfigure-KanataKeyboard.ps1.
#>
[CmdletBinding()]
param([string]$InstallRoot = $PSScriptRoot)

. (Join-Path $PSScriptRoot 'KanataLayout.Common.ps1')
$paths = Get-KanataLayoutPaths $InstallRoot
$state = Get-LayoutState $paths.State
$kanataPath = (Get-Content -LiteralPath $paths.KanataInfo -Raw).Trim()

## Never fight an in-progress manual registration probe.
$probe = @(Get-CimInstance Win32_Process -Filter "Name LIKE 'kanata%'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -match 'kanata-layout-hwid-probe' })
if ($probe.Count -gt 0) { exit 0 }

## Start the resident kanata whenever any US keyboard is registered.
## Start-ManagedKanata is mutex-guarded, so concurrent task runs cannot start
## more than one instance.
$hasUs = @($state.devices | Where-Object { $_.layout -eq 'US' }).Count -gt 0
if ($hasUs) { Start-ManagedKanata $paths.Config $kanataPath }
exit 0
