param(
  [string]$SettingsPath,
  [string]$Config = 'Blipline\Timeline',
  [string]$Measure = 'MeasureTimeline',
  [string]$Min = '70',
  [string]$Max = '145',
  [string]$RainmeterPath = ''
)

$ErrorActionPreference = 'SilentlyContinue'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class BliplineMouse {
  [StructLayout(LayoutKind.Sequential)]
  public struct POINT {
    public int X;
    public int Y;
  }

  [DllImport("user32.dll")]
  public static extern short GetAsyncKeyState(int vKey);

  [DllImport("user32.dll")]
  public static extern bool GetCursorPos(out POINT lpPoint);
}
'@

function Clamp-Int {
  param([int]$Value, [int]$Low, [int]$High)
  if ($Value -lt $Low) { return $Low }
  if ($Value -gt $High) { return $High }
  return $Value
}

function Read-SettingScale {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return 100 }
  $line = Get-Content -LiteralPath $Path | Where-Object { $_ -match '^UiScale=' } | Select-Object -First 1
  if ($line -match '^UiScale=(\d+)') { return [int]$Matches[1] }
  return 100
}

function Save-SettingScale {
  param([string]$Path, [int]$Scale)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $lines = [System.Collections.Generic.List[string]](Get-Content -LiteralPath $Path)
  $found = $false
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^UiScale=') {
      $lines[$i] = "UiScale=$Scale"
      $found = $true
      break
    }
  }
  if (-not $found) {
    $insertAt = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match '^LayoutTemplateIndex=') {
        $insertAt = $i + 1
        break
      }
    }
    $lines.Insert($insertAt, "UiScale=$Scale")
  }
  [System.IO.File]::WriteAllLines($Path, [string[]]$lines, [System.Text.Encoding]::ASCII)
}

function Save-ResizeStatus {
  param([string]$Path, [string]$Status)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $lines = [System.Collections.Generic.List[string]](Get-Content -LiteralPath $Path)
  $found = $false
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^ResizeStatus=') {
      $lines[$i] = "ResizeStatus=$Status"
      $found = $true
      break
    }
  }
  if (-not $found) {
    $insertAt = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match '^UiScaleMax=') {
        $insertAt = $i + 1
        break
      }
    }
    $lines.Insert($insertAt, "ResizeStatus=$Status")
  }
  [System.IO.File]::WriteAllLines($Path, [string[]]$lines, [System.Text.Encoding]::ASCII)
}

function Send-Scale {
  param([int]$Scale)
  $rainmeter = $RainmeterPath
  if ([string]::IsNullOrWhiteSpace($rainmeter)) {
    $rainmeter = Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'
  }
  if (-not (Test-Path -LiteralPath $rainmeter)) { return }
  & $rainmeter '!CommandMeasure' $Measure "PreviewScale($Scale)" $Config | Out-Null
}

$minScale = 70
$maxScale = 145
[void][int]::TryParse($Min, [ref]$minScale)
[void][int]::TryParse($Max, [ref]$maxScale)
if ($maxScale -lt $minScale) { $maxScale = $minScale }

$SettingsPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SettingsPath)
$startScale = Clamp-Int -Value (Read-SettingScale -Path $SettingsPath) -Low $minScale -High $maxScale
Save-ResizeStatus -Path $SettingsPath -Status 'Resize started'

$startPoint = New-Object BliplineMouse+POINT
[BliplineMouse]::GetCursorPos([ref]$startPoint) | Out-Null
$lastScale = $startScale
$lastSent = [DateTime]::MinValue

Send-Scale -Scale $startScale

while (([BliplineMouse]::GetAsyncKeyState(0x01) -band 0x8000) -ne 0) {
  $point = New-Object BliplineMouse+POINT
  [BliplineMouse]::GetCursorPos([ref]$point) | Out-Null

  $delta = [int][Math]::Round((($point.X - $startPoint.X) + ($point.Y - $startPoint.Y)) / 10)
  $scale = Clamp-Int -Value ($startScale + $delta) -Low $minScale -High $maxScale

  if ($scale -ne $lastScale -and ((Get-Date) - $lastSent).TotalMilliseconds -ge 45) {
    Send-Scale -Scale $scale
    $lastScale = $scale
    $lastSent = Get-Date
  }

  Start-Sleep -Milliseconds 20
}

Save-SettingScale -Path $SettingsPath -Scale $lastScale
Save-ResizeStatus -Path $SettingsPath -Status "Resize saved at $lastScale%"
Send-Scale -Scale $lastScale
