param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (!$Condition) {
        throw $Message
    }
}

function Get-IniValue {
    param(
        [string]$Path,
        [string]$Name
    )

    $pattern = '^\s*' + [regex]::Escape($Name) + '\s*=\s*(.*)$'
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match $pattern) {
            return $matches[1].Trim()
        }
    }

    return ''
}

$skinRoot = Join-Path $ProjectRoot 'Skins\Blipline'
$settingsPath = Join-Path $skinRoot '@Resources\UserSettings.inc'
$cacheRoot = Join-Path $skinRoot '@Resources\Cache'

Assert-True (Test-Path -LiteralPath $settingsPath) 'Missing source UserSettings.inc.'

for ($i = 1; $i -le 12; $i++) {
    $key = if ($i -eq 1) { 'CalendarUrl' } else { "CalendarUrl$i" }
    Assert-True ([string]::IsNullOrWhiteSpace((Get-IniValue -Path $settingsPath -Name $key))) "Release settings contains $key."
}

Assert-True ([string]::IsNullOrWhiteSpace((Get-IniValue -Path $settingsPath -Name 'FetchHelperPath'))) 'Release settings contains FetchHelperPath.'

for ($i = 1; $i -le 12; $i++) {
    foreach ($suffix in @('Name', 'Result', 'Count')) {
        $key = "Feed$i$suffix"
        Assert-True ([string]::IsNullOrWhiteSpace((Get-IniValue -Path $settingsPath -Name $key))) "Release settings contains runtime feed status $key."
    }
}

$cacheFiles = @(Get-ChildItem -LiteralPath $cacheRoot -Force -File | Where-Object { $_.Name -ne '.gitkeep' })
Assert-True ($cacheFiles.Count -eq 0) ('Source cache folder contains release-unsafe files: ' + (($cacheFiles | ForEach-Object Name) -join ', '))

$packageFiles = @(Get-ChildItem -LiteralPath $skinRoot -Recurse -Force -File | Where-Object {
    $_.FullName -notmatch '\\@Resources\\Cache\\\.gitkeep$'
})

$blockedPatterns = @(
    'calendar\.google\.com/calendar/ical/.+basic\.ics',
    '/private-[^/\s]+/',
    'C:\\Users\\Peter',
    'codex-runtimes',
    'Event\d+Title=',
    'EventCount=[1-9]',
    'BEGIN:VCALENDAR'
)

foreach ($file in $packageFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    foreach ($pattern in $blockedPatterns) {
        if ($text -match $pattern) {
            $relative = $file.FullName.Substring($ProjectRoot.Length + 1)
            throw "Release privacy pattern '$pattern' matched $relative."
        }
    }
}

Write-Host 'Blipline release privacy checks passed.'
