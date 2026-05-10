param(
    [Parameter(Mandatory = $true)]
    [string]$SettingsPath,

    [int]$MaxFeeds = 8,

    [string]$FeedText = ''
)

$ErrorActionPreference = 'Stop'

function Set-IncValue {
    param(
        [string[]]$Lines,
        [string]$Name,
        [string]$Value
    )

    $escaped = [regex]::Escape($Name)
    $pattern = "^$escaped="
    $replacement = "$Name=$Value"
    $found = $false
    $updated = foreach ($line in $Lines) {
        if (!$found -and $line -match $pattern) {
            $found = $true
            $replacement
        }
        else {
            $line
        }
    }

    if ($found) {
        return @($updated)
    }

    $insertAt = 0
    for ($i = 0; $i -lt $updated.Count; $i++) {
        if ($updated[$i] -match '^\[Variables\]') {
            $insertAt = $i + 1
            break
        }
    }

    if ($insertAt -le 0) {
        return @($replacement) + @($updated)
    }

    return @($updated[0..($insertAt - 1)]) + @($replacement) + @($updated[$insertAt..($updated.Count - 1)])
}

$resolvedPath = [Environment]::ExpandEnvironmentVariables($SettingsPath)
if (!(Test-Path -LiteralPath $resolvedPath)) {
    throw "Settings file not found: $resolvedPath"
}

$max = [Math]::Max(1, [Math]::Min(12, $MaxFeeds))
$raw = $FeedText
if ([string]::IsNullOrWhiteSpace($raw)) {
    $raw = Get-Clipboard -Raw
}
if ([string]::IsNullOrWhiteSpace($raw)) {
    throw 'Clipboard is empty. Copy one or more private iCal URLs first.'
}

$feeds = @(
    $raw -split "\r?\n" |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' -and $_ -notmatch '^\s*#' } |
        ForEach-Object {
            if ($_ -match '^webcal://') {
                $_ -replace '^webcal://', 'https://'
            }
            else {
                $_
            }
        } |
        Select-Object -First $max
)

if ($feeds.Count -eq 0) {
    throw 'Clipboard did not contain any usable feed lines.'
}

$lines = @(Get-Content -LiteralPath $resolvedPath)

for ($i = 1; $i -le $max; $i++) {
    $key = if ($i -eq 1) { 'CalendarUrl' } else { "CalendarUrl$i" }
    $value = if ($i -le $feeds.Count) { $feeds[$i - 1] } else { '' }
    $lines = @(Set-IncValue -Lines $lines -Name $key -Value $value)
}

$lines = @(Set-IncValue -Lines $lines -Name 'UseSample' -Value '0')
$lines = @(Set-IncValue -Lines $lines -Name 'CalendarSlots' -Value ([string]$max))

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($resolvedPath, $lines, $utf8NoBom)

Write-Host ("Imported {0} feed(s) into {1}" -f $feeds.Count, $resolvedPath)
