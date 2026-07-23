[CmdletBinding()]
param([string]$InstallRoot = $PSScriptRoot)

. (Join-Path $PSScriptRoot 'KanataLayout.Common.ps1')
$paths = Get-KanataLayoutPaths $InstallRoot
$state = Get-LayoutState $paths.State
$present = @(Get-PresentKeyboard)

@($state.devices | ForEach-Object {
  $profile = $_
  [pscustomobject]@{
    Name = if ($profile.name) { $profile.name } else { '名称未設定' }
    Layout = $profile.layout
    Connected = @($present | Where-Object { Test-HardwareIdMatch $_.HardwareIds $profile.hardwareIds }).Count -gt 0
    UpdatedAt = $profile.updatedAt
  }
}) | Format-Table -AutoSize
