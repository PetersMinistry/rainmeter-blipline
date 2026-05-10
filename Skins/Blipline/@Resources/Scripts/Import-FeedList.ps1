param(
    [Parameter(Mandatory = $true)]
    [string]$SettingsPath,

    [int]$MaxFeeds = 8,

    [string]$FeedText = '',

    [switch]$Clear
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

$palette = @(
    '255,199,50,255',
    '104,170,255,245',
    '126,220,117,245',
    '238,120,150,245',
    '155,111,225,245',
    '24,163,214,245',
    '224,72,72,245',
    '234,191,48,245',
    '255,132,64,245',
    '92,214,168,245',
    '205,214,224,230',
    '255,108,180,245'
)

$resolvedPath = [Environment]::ExpandEnvironmentVariables($SettingsPath)
if (!(Test-Path -LiteralPath $resolvedPath)) {
    throw "Settings file not found: $resolvedPath"
}

$max = [Math]::Max(1, [Math]::Min(12, $MaxFeeds))

$lines = @(Get-Content -LiteralPath $resolvedPath)

if ($Clear) {
    for ($i = 1; $i -le $max; $i++) {
        $key = if ($i -eq 1) { 'CalendarUrl' } else { "CalendarUrl$i" }
        $lines = @(Set-IncValue -Lines $lines -Name $key -Value '')
        $lines = @(Set-IncValue -Lines $lines -Name "Feed${i}Name" -Value '')
        $lines = @(Set-IncValue -Lines $lines -Name "Feed${i}Result" -Value '')
        $lines = @(Set-IncValue -Lines $lines -Name "Feed${i}Count" -Value '')
        $lines = @(Set-IncValue -Lines $lines -Name "Feed${i}Color" -Value '255,255,255,0')
    }

    $lines = @(Set-IncValue -Lines $lines -Name 'UseSample' -Value '1')
    $lines = @(Set-IncValue -Lines $lines -Name 'FeedImportStatus' -Value ('Cleared feeds at ' + (Get-Date -Format 'h:mm tt')))
    $lines = @(Set-IncValue -Lines $lines -Name 'FeedStatusSummary' -Value 'Feeds cleared')

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($resolvedPath, $lines, $utf8NoBom)
    Write-Host ("Cleared feed URLs in {0}" -f $resolvedPath)
    exit 0
}

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

for ($i = 1; $i -le $max; $i++) {
    $key = if ($i -eq 1) { 'CalendarUrl' } else { "CalendarUrl$i" }
    $value = if ($i -le $feeds.Count) { $feeds[$i - 1] } else { '' }
    $lines = @(Set-IncValue -Lines $lines -Name $key -Value $value)
    $lines = @(Set-IncValue -Lines $lines -Name "CalendarColor$i" -Value $palette[($i - 1) % $palette.Count])
    $lines = @(Set-IncValue -Lines $lines -Name "Feed${i}Name" -Value $(if ($i -le $feeds.Count) { "Feed $i pending refresh" } else { '' }))
    $lines = @(Set-IncValue -Lines $lines -Name "Feed${i}Result" -Value $(if ($i -le $feeds.Count) { 'Pending' } else { '' }))
    $lines = @(Set-IncValue -Lines $lines -Name "Feed${i}Count" -Value '')
    $lines = @(Set-IncValue -Lines $lines -Name "Feed${i}Color" -Value $(if ($i -le $feeds.Count) { $palette[($i - 1) % $palette.Count] } else { '255,255,255,0' }))
}

$lines = @(Set-IncValue -Lines $lines -Name 'UseSample' -Value '0')
$lines = @(Set-IncValue -Lines $lines -Name 'CalendarSlots' -Value ([string]$max))
$lines = @(Set-IncValue -Lines $lines -Name 'FeedImportStatus' -Value ('Imported ' + $feeds.Count + ' feed(s) at ' + (Get-Date -Format 'h:mm tt')))
$lines = @(Set-IncValue -Lines $lines -Name 'FeedStatusSummary' -Value ('Imported ' + $feeds.Count + ' feed(s); refresh pending'))

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($resolvedPath, $lines, $utf8NoBom)

Write-Host ("Imported {0} feed(s) into {1}" -f $feeds.Count, $resolvedPath)
