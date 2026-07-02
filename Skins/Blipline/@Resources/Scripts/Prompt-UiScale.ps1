param(
  [string]$SettingsPath,
  [string]$Current = '100',
  [string]$Min = '70',
  [string]$Max = '145'
)

$ErrorActionPreference = 'SilentlyContinue'

function Clamp-Int {
  param([int]$Value, [int]$Low, [int]$High)
  if ($Value -lt $Low) { return $Low }
  if ($Value -gt $High) { return $High }
  return $Value
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

  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllLines($Path, [string[]]$lines, $utf8NoBom)
}

$minScale = 70
$maxScale = 145
$currentScale = 100
[void][int]::TryParse($Min, [ref]$minScale)
[void][int]::TryParse($Max, [ref]$maxScale)
[void][int]::TryParse(($Current -replace '[^0-9]', ''), [ref]$currentScale)
if ($maxScale -lt $minScale) { $maxScale = $minScale }
$currentScale = Clamp-Int -Value $currentScale -Low $minScale -High $maxScale

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Blipline timeline scale'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(320, 150)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.TopMost = $true

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(14, 14)
$label.Size = New-Object System.Drawing.Size(276, 22)
$label.Text = "Enter timeline scale percent ($minScale-$maxScale)."
$form.Controls.Add($label)

$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(18, 42)
$textBox.Size = New-Object System.Drawing.Size(120, 24)
$textBox.Text = [string]$currentScale
$form.Controls.Add($textBox)

$okButton = New-Object System.Windows.Forms.Button
$okButton.Location = New-Object System.Drawing.Point(142, 78)
$okButton.Size = New-Object System.Drawing.Size(72, 26)
$okButton.Text = 'OK'
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $okButton
$form.Controls.Add($okButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(220, 78)
$cancelButton.Size = New-Object System.Drawing.Size(72, 26)
$cancelButton.Text = 'Cancel'
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.CancelButton = $cancelButton
$form.Controls.Add($cancelButton)

$form.Add_Shown({ $textBox.SelectAll(); $textBox.Focus() })
$result = $form.ShowDialog()
if ($result -ne [System.Windows.Forms.DialogResult]::OK) { return }

$inputValue = $textBox.Text
if ([string]::IsNullOrWhiteSpace($inputValue)) { return }

$cleanValue = ($inputValue -replace '[^0-9]', '')
if ([string]::IsNullOrWhiteSpace($cleanValue)) { return }

$requestedScale = $currentScale
[void][int]::TryParse($cleanValue, [ref]$requestedScale)
$scale = Clamp-Int -Value $requestedScale -Low $minScale -High $maxScale

$SettingsPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SettingsPath)
Save-SettingScale -Path $SettingsPath -Scale $scale
