<#
  Manual reconfiguration. It works for both previously-US and previously-JIS
  keyboards: press a key on the target device, then choose its physical layout.
#>
[CmdletBinding()]
param([string]$InstallRoot = $PSScriptRoot)

. (Join-Path $PSScriptRoot 'KanataLayout.Common.ps1')
$paths = Get-KanataLayoutPaths $InstallRoot
$kanataPath = (Get-Content -LiteralPath $paths.KanataInfo -Raw).Trim()
$state = Get-LayoutState $paths.State

## Only one probe may own the Interception input at a time; concurrent probes
## also used to fight over temp files and could swallow keyboard input.
$otherProbe = @(Get-CimInstance Win32_Process -Filter "Name LIKE 'kanata%'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -match 'kanata-layout-hwid-probe' })
if ($otherProbe.Count -gt 0) {
  throw '別の再設定プローブが実行中です。そのウィザードを完了するか閉じてから再実行してください。'
}

$probeId = [guid]::NewGuid().ToString('N')
$probePath = Join-Path ([IO.Path]::GetTempPath()) "kanata-layout-hwid-probe-$probeId.kbd"
$outPath = Join-Path ([IO.Path]::GetTempPath()) "kanata-layout-hwid-probe-$probeId.out"
$errPath = Join-Path ([IO.Path]::GetTempPath()) "kanata-layout-hwid-probe-$probeId.err"
$process = $null

try {
  $requestedName = Read-Host '表示名 (空欄なら検出後に自動設定)'
  $layout = $null
  while (-not $layout) {
    $choice = Read-Host 'このキーボードの物理配列 [U]S / [J]IS'
    switch -Regex ($choice) {
      '^[Uu]' { $layout = 'US' }
      '^[Jj]' { $layout = 'JIS' }
      default { Write-Host 'U または J を入力してください。' }
    }
  }

  Stop-ManagedKanata $paths.Config
  ## PS5.1 Get-Content/Set-Content misread BOM-less UTF-8 as ANSI and corrupt
  ## the config; use explicit encodings.
  $probeContent = [IO.File]::ReadAllText($paths.Config, [Text.Encoding]::UTF8)
  $probeContent = [regex]::Replace($probeContent, '(?s)    ;; US_HWIDS_BEGIN.*?    ;; US_HWIDS_END', "    ;; US_HWIDS_BEGIN`r`n    ;; US_HWIDS_END")
  [IO.File]::WriteAllText($probePath, $probeContent, (New-Object System.Text.UTF8Encoding($false)))

  Write-Host 'キーボードをスキャンしています。設定を変更したいキーボードでキーを1つ押してください。Enterでも検出できます。'
  $process = Start-Process -FilePath $kanataPath -ArgumentList @('--debug', '-c', $probePath) -RedirectStandardOutput $outPath -RedirectStandardError $errPath -PassThru -WindowStyle Hidden
  $match = $null
  $deadline = (Get-Date).AddSeconds(30)
  while ((Get-Date) -lt $deadline -and -not $match) {
    Start-Sleep -Milliseconds 200
    $log = @((Get-Content -LiteralPath $outPath -Raw -ErrorAction SilentlyContinue), (Get-Content -LiteralPath $errPath -Raw -ErrorAction SilentlyContinue)) -join "`n"
    ## [regex]::Match returns a truthy Match object even on failure; keep only a success.
    $candidate = [regex]::Match($log, '(?<!\d)(?:\d{1,3},\s*){4,}\d{1,3}(?!\d)')
    if ($candidate.Success) { $match = $candidate }
  }
  if ($process -and -not $process.HasExited) {
    Stop-Process -Id $process.Id -Force
    $process.WaitForExit(3000)
  }
  if (-not $match) {
    throw 'HWIDを取得できませんでした。もう一度実行し、30秒以内に対象キーボードのキーを押してください。'
  }
  Clear-ConsoleInputBuffer

  $hwid = $match.Value -replace '\s+', ' '
  ## Drop generic compatible IDs (HID_DEVICE_SYSTEM_KEYBOARD etc.): they match
  ## every HID keyboard and would make unrelated devices look "registered".
  $hardwareIds = @(ConvertFrom-KanataHwid $hwid | Where-Object { $_ -notmatch '^HID_DEVICE' })
  $existing = @($state.devices | Where-Object { $_.kanataHwid -eq $hwid -or (Test-HardwareIdMatch $_.hardwareIds $hardwareIds) }) | Select-Object -First 1
  $matchedKeyboard = @(Get-PresentKeyboard | Where-Object { Test-HardwareIdMatch $_.HardwareIds $hardwareIds }) | Select-Object -First 1
  $defaultName = if ($existing -and $existing.name) { $existing.name } elseif ($matchedKeyboard) { $matchedKeyboard.Name } else { 'Keyboard' }
  $displayName = $requestedName
  if ([string]::IsNullOrWhiteSpace($displayName)) { $displayName = $defaultName }

  $state.devices = @($state.devices | Where-Object { $_.kanataHwid -ne $hwid -and -not (Test-HardwareIdMatch $_.hardwareIds $hardwareIds) })
  $state.devices += [pscustomobject]@{ name = $displayName; kanataHwid = $hwid; hardwareIds = $hardwareIds; layout = $layout; updatedAt = (Get-Date).ToString('o') }
  Save-LayoutState $state $paths.State
  Update-KanataConfig $state $paths.Config
  Write-Host "登録しました: $displayName ($layout)"
}
finally {
  ## Whatever happened above, never leave the resident kanata stopped.
  if ($process -and -not $process.HasExited) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
  Remove-Item -LiteralPath $probePath, $outPath, $errPath -Force -ErrorAction SilentlyContinue
  $currentState = Get-LayoutState $paths.State
  $knownUsPresent = $false
  foreach ($keyboard in (Get-PresentKeyboard)) {
    if (@($currentState.devices | Where-Object { $_.layout -eq 'US' -and (Test-HardwareIdMatch $keyboard.HardwareIds $_.hardwareIds) }).Count -gt 0) {
      $knownUsPresent = $true
      break
    }
  }
  if ($knownUsPresent) { Start-ManagedKanata $paths.Config $kanataPath }
}
