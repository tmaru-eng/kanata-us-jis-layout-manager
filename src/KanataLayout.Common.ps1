Set-StrictMode -Version Latest

function Get-KanataLayoutPaths {
  param([string]$InstallRoot)
  if (-not $InstallRoot) { $InstallRoot = $PSScriptRoot }
  [pscustomobject]@{
    Root       = $InstallRoot
    Config     = Join-Path $InstallRoot 'kanata-us-to-jis-wintercept.kbd'
    State      = Join-Path $InstallRoot 'keyboard-layout-state.json'
    KanataInfo = Join-Path $InstallRoot 'kanata-path.txt'
  }
}

function Get-LayoutState {
  param([string]$StatePath)
  if (Test-Path -LiteralPath $StatePath) {
    return (Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json)
  }
  return [pscustomobject]@{
    version = 1
    ## Lenovo built-in keyboard and the Intel virtual HID collection (INTC816):
    ## suppress the first-time question for both.
    jisHardwareIdPatterns = @('*ACPI\\VEN_LEN&DEV_0071*', '*ACPI\\LEN0071*', '*LEN0071*', '*HID\\INTC816*')
    devices = @()
  }
}

function Save-LayoutState {
  param($State, [string]$StatePath)
  $State | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $StatePath -Encoding utf8
}

function ConvertFrom-KanataHwid {
  param([Parameter(Mandatory)][string]$Hwid)
  $numbers = @($Hwid -split ',' | ForEach-Object { [byte]($_.Trim()) })
  if ($numbers.Count -lt 2) { return @() }
  $text = [Text.Encoding]::Unicode.GetString([byte[]]$numbers).Trim([char]0)
  return @($text -split ([char]0) | Where-Object { $_ })
}

function Get-PresentKeyboard {
  if (-not (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue)) {
    throw 'Get-PnpDevice が利用できません。Windows 10/11 の標準 PowerShell で実行してください。'
  }
  $result = @()
  foreach ($device in (Get-PnpDevice -PresentOnly -Class Keyboard -ErrorAction SilentlyContinue)) {
    $property = Get-PnpDeviceProperty -InstanceId $device.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds' -ErrorAction SilentlyContinue
    $ids = @($property.Data | ForEach-Object { [string]$_ })
    $result += [pscustomobject]@{
      InstanceId = $device.InstanceId
      Name       = Get-FriendlyKeyboardName $device
      HardwareIds = $ids
    }
  }
  return $result
}

function Get-FriendlyKeyboardName {
  param($KeyboardDevice)
  $genericNames = @('HID Keyboard Device', 'Standard PS/2 Keyboard', 'USB Input Device')
  $ownName = [string]$KeyboardDevice.FriendlyName
  if ($ownName -and $ownName -notin $genericNames) { return $ownName }

  ## A Bluetooth keyboard's keyboard-class child is often named only "HID
  ## Keyboard Device". Look for its Bluetooth/USB parent in the same container.
  $container = Get-PnpDeviceProperty -InstanceId $KeyboardDevice.InstanceId -KeyName 'DEVPKEY_Device_ContainerId' -ErrorAction SilentlyContinue
  if ($container.Data) {
    foreach ($candidate in (Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue)) {
      $candidateContainer = Get-PnpDeviceProperty -InstanceId $candidate.InstanceId -KeyName 'DEVPKEY_Device_ContainerId' -ErrorAction SilentlyContinue
      if ($candidateContainer.Data -eq $container.Data -and $candidate.FriendlyName -and $candidate.FriendlyName -notin $genericNames) {
        return [string]$candidate.FriendlyName
      }
    }
  }

  $parent = Get-PnpDeviceProperty -InstanceId $KeyboardDevice.InstanceId -KeyName 'DEVPKEY_Device_Parent' -ErrorAction SilentlyContinue
  if ($parent.Data) {
    $parentDevice = Get-PnpDevice -InstanceId $parent.Data -ErrorAction SilentlyContinue
    if ($parentDevice -and $parentDevice.FriendlyName) { return [string]$parentDevice.FriendlyName }
  }
  if ($ownName) { return $ownName }
  return [string]$KeyboardDevice.InstanceId
}

function Test-HardwareIdMatch {
  param([string[]]$Actual, [string[]]$Expected)
  foreach ($a in $Actual) { foreach ($e in $Expected) { if ($a -ieq $e) { return $true } } }
  return $false
}

function Test-JisPatternMatch {
  param([string[]]$HardwareIds, [string[]]$Patterns)
  foreach ($id in $HardwareIds) {
    foreach ($pattern in $Patterns) {
      if ([WildcardPattern]::new($pattern, 'IgnoreCase').IsMatch($id)) { return $true }
    }
  }
  return $false
}

function Clear-ConsoleInputBuffer {
  param([int]$Milliseconds = 600)
  $deadline = (Get-Date).AddMilliseconds($Milliseconds)
  while ((Get-Date) -lt $deadline) {
    try {
      while ([Console]::KeyAvailable) {
        [void][Console]::ReadKey($true)
      }
    }
    catch {
      return
    }
    Start-Sleep -Milliseconds 50
  }
}

function Update-KanataConfig {
  param($State, [string]$ConfigPath)
  $hwids = @($State.devices | Where-Object { $_.layout -eq 'US' } | ForEach-Object { $_.kanataHwid } | Sort-Object -Unique)
  $items = @($hwids | ForEach-Object { '    "' + $_ + '"' })
  $block = "    ;; US_HWIDS_BEGIN`r`n" + ($items -join "`r`n")
  if ($items.Count -gt 0) { $block += "`r`n" }
  $block += '    ;; US_HWIDS_END'
  ## Windows PowerShell 5.1 の Get-Content は BOM無しUTF-8 を ANSI として誤読し、
  ## 全角文字の化けと改行の欠落で設定を破壊するため、明示的にUTF-8で読み書きする。
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  $content = [IO.File]::ReadAllText($ConfigPath, [Text.Encoding]::UTF8)
  $content = [regex]::Replace($content, '(?s)    ;; US_HWIDS_BEGIN.*?    ;; US_HWIDS_END', $block)
  [IO.File]::WriteAllText($ConfigPath, $content, $utf8NoBom)
}

function Stop-ManagedKanata {
  param([string]$ConfigPath)
  $needle = [regex]::Escape($ConfigPath)
  Get-CimInstance Win32_Process -Filter "Name LIKE 'kanata%'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match $needle } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
}

function Start-ManagedKanata {
  param([string]$ConfigPath, [string]$KanataPath)
  if (-not (Test-Path -LiteralPath $KanataPath)) { throw "Kanataが見つかりません: $KanataPath" }

  ## A single device connect fires Logon + several PnP task runs almost at
  ## once. Their "is kanata already running?" checks are otherwise not atomic,
  ## so two runs can both decide to launch, producing two Interception clients
  ## that swallow ALL keyboard input. Serialize the whole check-then-launch
  ## with a machine-wide named mutex.
  $mutex = New-Object System.Threading.Mutex($false, 'Global\KanataLayoutManager-Start')
  $acquired = $false
  try {
    try { $acquired = $mutex.WaitOne([TimeSpan]::FromSeconds(20)) } catch [System.Threading.AbandonedMutexException] { $acquired = $true }
    if (-not $acquired) { return }

    $kanataProcs = @(Get-CimInstance Win32_Process -Filter "Name LIKE 'kanata%'" -ErrorAction SilentlyContinue)
    ## While an HWID probe owns the Interception input, starting the resident
    ## kanata would create a second Interception client. The probe's finally
    ## block restarts the resident kanata afterwards.
    if (@($kanataProcs | Where-Object { $_.CommandLine -match 'kanata-layout-hwid-probe' }).Count -gt 0) { return }

    ## Reconcile to exactly one resident instance: if duplicates already exist
    ## (e.g. from an older build), keep the oldest and kill the rest.
    $needle = [regex]::Escape($ConfigPath)
    $running = @($kanataProcs | Where-Object { $_.CommandLine -match $needle } | Sort-Object CreationDate)
    if ($running.Count -gt 1) {
      $running | Select-Object -Skip 1 | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    }
    ## Hidden: the TTY build opens a console window; a resident remapper does
    ## not need one (stop via Stop-ManagedKanata or lctl+spc+esc).
    if ($running.Count -eq 0) { Start-Process -FilePath $KanataPath -ArgumentList @('-c', $ConfigPath) -WindowStyle Hidden }
  }
  finally {
    if ($acquired) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
  }
}
