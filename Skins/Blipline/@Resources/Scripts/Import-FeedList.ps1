param(
    [Parameter(Mandatory = $true)]
    [string]$SettingsPath,

    [int]$MaxFeeds = 15,

    [string]$FeedText = '',

    [ValidateSet('Add', 'Remove', 'Clear')]
    [string]$Mode = 'Add',

    [int[]]$Slots = @(),

    [switch]$Clear,

    [switch]$ConfirmClear
)

$ErrorActionPreference = 'Stop'

$localizationScript = Join-Path $PSScriptRoot 'Localization.ps1'
if (Test-Path -LiteralPath $localizationScript) {
    . $localizationScript
}

function Get-RainmeterIncludeEncoding {
    try {
        [System.Text.Encoding]::RegisterProvider([System.Text.CodePagesEncodingProvider]::Instance)
    } catch {}

    try {
        $ansiCodePage = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage
        if ($ansiCodePage -gt 0) {
            return [System.Text.Encoding]::GetEncoding($ansiCodePage)
        }
    } catch {}

    return [System.Text.Encoding]::Default
}

function Get-IncValue {
    param(
        [string[]]$Lines,
        [string]$Name,
        [string]$Default = ''
    )

    $pattern = '^' + [regex]::Escape($Name) + '=(.*)$'
    foreach ($line in $Lines) {
        if ($line -match $pattern) {
            return $Matches[1]
        }
    }
    return $Default
}

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

    if ($updated.Count -eq $insertAt) {
        return @($updated) + @($replacement)
    }

    return @($updated[0..($insertAt - 1)]) + @($replacement) + @($updated[$insertAt..($updated.Count - 1)])
}

function Get-LanguageCode {
    param([string[]]$Lines)

    $available = @(Get-BliplineAvailableLanguageCodes)
    $candidates = @(
        (Get-IncValue -Lines $Lines -Name 'Language' -Default ''),
        (Get-IncValue -Lines $Lines -Name 'LanguageLabel' -Default '')
    )

    foreach ($candidate in $candidates) {
        $code = Resolve-BliplineLanguageCode -Code $candidate -Fallback ''
        if ($code -in $available) {
            return $code
        }
    }

    return 'en'
}

function Get-ImportLabels {
    param([string]$Code)

    $resolvedCode = Resolve-BliplineLanguageCode -Code $Code -Fallback 'en'
    return Get-BliplineLocaleSection -Code $resolvedCode -Section 'Import'
}

function Format-ImportText {
    param(
        [hashtable]$Labels,
        [string]$Key,
        [object[]]$FormatArgs = @()
    )

    $template = if ($Labels.ContainsKey($Key)) { $Labels[$Key] } else { $Key }
    if ($FormatArgs.Count -gt 0) {
        return ($template -f $FormatArgs)
    }
    return $template
}

function Get-FeedUrlKey {
    param([int]$Slot)
    if ($Slot -eq 1) {
        return 'CalendarUrl'
    }
    return "CalendarUrl$Slot"
}

function Normalize-FeedUrl {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    $clean = $Text.Trim()
    $clean = $clean.Trim('"', "'", '<', '>')
    if ($clean -match '^webcal://') {
        $clean = $clean -replace '^webcal://', 'https://'
    }
    return $clean
}

function Test-FeedUrlShape {
    param([string]$Url)

    $result = @{
        IsUsable = $false
        MessageKey = 'InvalidGeneric'
    }

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $result
    }

    $uri = $null
    if (![Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri)) {
        return $result
    }

    if ($uri.Scheme -notin @('http', 'https', 'webcal')) {
        return $result
    }

    $full = $uri.AbsoluteUri.ToLowerInvariant()
    $uriHost = $uri.Host.ToLowerInvariant()
    $path = $uri.AbsolutePath.ToLowerInvariant()

    if ($uriHost -match '(^|\.)calendar\.google\.com$' -and $path -notmatch '/calendar/ical/') {
        $result.MessageKey = 'GooglePage'
        return $result
    }

    if ($full -match '\.ics($|[?#])' -or $path -match '/ical/' -or $path -match '/ics/' -or $full -match 'ical') {
        $result.IsUsable = $true
        $result.MessageKey = ''
        return $result
    }

    $result.MessageKey = 'UrlNotIcal'
    return $result
}

function Get-ExistingFeeds {
    param(
        [string[]]$Lines,
        [int]$Max
    )

    $feeds = @{}
    for ($i = 1; $i -le $Max; $i++) {
        $key = Get-FeedUrlKey -Slot $i
        $value = Get-IncValue -Lines $Lines -Name $key
        if ($i -eq 1 -and [string]::IsNullOrWhiteSpace($value)) {
            $value = Get-IncValue -Lines $Lines -Name 'CalendarUrl1'
        }
        $feeds[$i] = (Normalize-FeedUrl $value)
    }
    return $feeds
}

function Get-EmptyFeedSlots {
    param(
        [hashtable]$Feeds,
        [int]$Max
    )

    $slots = New-Object System.Collections.Generic.List[int]
    for ($i = 1; $i -le $Max; $i++) {
        if ([string]::IsNullOrWhiteSpace([string]$Feeds[$i])) {
            [void]$slots.Add($i)
        }
    }
    return @($slots)
}

function Clear-FeedSlot {
    param(
        [string[]]$Lines,
        [int]$Slot
    )

    $key = Get-FeedUrlKey -Slot $Slot
    $Lines = @(Set-IncValue -Lines $Lines -Name $key -Value '')
    if ($Slot -eq 1) {
        $Lines = @(Set-IncValue -Lines $Lines -Name 'CalendarUrl1' -Value '')
    }
    $Lines = @(Set-IncValue -Lines $Lines -Name "Feed${Slot}Name" -Value '')
    $Lines = @(Set-IncValue -Lines $Lines -Name "Feed${Slot}Result" -Value '')
    $Lines = @(Set-IncValue -Lines $Lines -Name "Feed${Slot}Count" -Value '')
    $Lines = @(Set-IncValue -Lines $Lines -Name "Feed${Slot}Color" -Value '255,255,255,0')
    return @($Lines)
}

function Set-Status {
    param(
        [string[]]$Lines,
        [string]$ImportStatus,
        [string]$Summary
    )

    $Lines = @(Set-IncValue -Lines $Lines -Name 'FeedImportStatus' -Value $ImportStatus)
    $Lines = @(Set-IncValue -Lines $Lines -Name 'FeedStatusSummary' -Value $Summary)
    return @($Lines)
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
    '255,108,180,245',
    '130,204,255,245',
    '186,220,88,245',
    '200,156,255,245',
    '205,214,224,230',
    '255,255,255,245',
    '230,147,139,245',
    '176,150,136,245',
    '255,176,96,245',
    '90,220,220,245',
    '128,144,255,245',
    '168,235,140,245',
    '255,214,120,245',
    '172,172,172,245'
)

if ($Clear) {
    $Mode = 'Clear'
    $ConfirmClear = $true
}

$resolvedPath = [Environment]::ExpandEnvironmentVariables($SettingsPath)
if (!(Test-Path -LiteralPath $resolvedPath)) {
    throw "Settings file not found: $resolvedPath"
}

$max = [Math]::Max(1, [Math]::Min(15, $MaxFeeds))
$settingsEncoding = Get-RainmeterIncludeEncoding
$lines = @([System.IO.File]::ReadAllLines($resolvedPath, $settingsEncoding))
$languageCode = Get-LanguageCode -Lines $lines
$importLabels = Get-ImportLabels -Code $languageCode

if ($Mode -eq 'Clear') {
    if (!$ConfirmClear) {
        $lines = @(Set-Status -Lines $lines -ImportStatus (Format-ImportText -Labels $importLabels -Key 'ClearPrompt') -Summary (Format-ImportText -Labels $importLabels -Key 'ClearPromptSummary'))
        [System.IO.File]::WriteAllLines($resolvedPath, $lines, $settingsEncoding)
        Write-Host (Format-ImportText -Labels $importLabels -Key 'ClearPromptSummary')
        exit 0
    }

    for ($i = 1; $i -le $max; $i++) {
        $lines = @(Clear-FeedSlot -Lines $lines -Slot $i)
    }

    $lines = @(Set-IncValue -Lines $lines -Name 'UseSample' -Value '1')
    $lines = @(Set-IncValue -Lines $lines -Name 'CalendarSlots' -Value ([string]$max))
    $lines = @(Set-Status -Lines $lines -ImportStatus (Format-ImportText -Labels $importLabels -Key 'Cleared' -FormatArgs @((Get-Date -Format 'h:mm tt'))) -Summary (Format-ImportText -Labels $importLabels -Key 'ClearedSummary'))
    [System.IO.File]::WriteAllLines($resolvedPath, $lines, $settingsEncoding)
    Write-Host (Format-ImportText -Labels $importLabels -Key 'ClearedSummary')
    exit 0
}

if ($Mode -eq 'Remove') {
    $validSlots = @($Slots | Where-Object { $_ -ge 1 -and $_ -le $max } | Select-Object -Unique)
    if ($validSlots.Count -eq 0) {
        $lines = @(Set-Status -Lines $lines -ImportStatus (Format-ImportText -Labels $importLabels -Key 'NoSlotSelected') -Summary (Format-ImportText -Labels $importLabels -Key 'NoCalendarsRemoved'))
    }
    else {
        foreach ($slot in $validSlots) {
            $lines = @(Clear-FeedSlot -Lines $lines -Slot $slot)
        }
        $remainingFeeds = Get-ExistingFeeds -Lines $lines -Max $max
        $remainingCount = @($remainingFeeds.Values | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) }).Count
        $lines = @(Set-IncValue -Lines $lines -Name 'UseSample' -Value $(if ($remainingCount -gt 0) { '0' } else { '1' }))
        $slotText = ($validSlots -join ', ')
        $lines = @(Set-Status -Lines $lines -ImportStatus (Format-ImportText -Labels $importLabels -Key 'Removed' -FormatArgs @($slotText, (Get-Date -Format 'h:mm tt'))) -Summary (Format-ImportText -Labels $importLabels -Key 'RemovedSummary' -FormatArgs @($slotText)))
    }

    [System.IO.File]::WriteAllLines($resolvedPath, $lines, $settingsEncoding)
    Write-Host (Get-IncValue -Lines $lines -Name 'FeedImportStatus' -Default (Format-ImportText -Labels $importLabels -Key 'NoCalendarsRemoved'))
    exit 0
}

$raw = $FeedText
if ([string]::IsNullOrWhiteSpace($raw)) {
    $raw = Get-Clipboard -Raw
}

if ([string]::IsNullOrWhiteSpace($raw)) {
    $lines = @(Set-Status -Lines $lines -ImportStatus (Format-ImportText -Labels $importLabels -Key 'ClipboardEmpty') -Summary (Format-ImportText -Labels $importLabels -Key 'NoIcalFound'))
    [System.IO.File]::WriteAllLines($resolvedPath, $lines, $settingsEncoding)
    Write-Host (Format-ImportText -Labels $importLabels -Key 'ClipboardEmpty')
    exit 0
}

$candidates = @(
    $raw -split "\r?\n" |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' -and $_ -notmatch '^\s*#' } |
        ForEach-Object { Normalize-FeedUrl $_ } |
        Where-Object { $_ -ne '' }
)

if ($candidates.Count -eq 0) {
    $lines = @(Set-Status -Lines $lines -ImportStatus (Format-ImportText -Labels $importLabels -Key 'NoUsable') -Summary (Format-ImportText -Labels $importLabels -Key 'NoIcalFound'))
    [System.IO.File]::WriteAllLines($resolvedPath, $lines, $settingsEncoding)
    Write-Host (Format-ImportText -Labels $importLabels -Key 'NoUsable')
    exit 0
}

$existingFeeds = Get-ExistingFeeds -Lines $lines -Max $max
$existingLookup = @{}
foreach ($url in $existingFeeds.Values) {
    if (![string]::IsNullOrWhiteSpace([string]$url)) {
        $existingLookup[[string]$url] = $true
    }
}

$emptySlots = New-Object System.Collections.Queue
foreach ($slot in (Get-EmptyFeedSlots -Feeds $existingFeeds -Max $max)) {
    $emptySlots.Enqueue($slot)
}

$seenCandidates = @{}
$added = 0
$duplicates = 0
$invalid = 0
$notFit = 0
$firstInvalidMessage = ''

foreach ($candidate in $candidates) {
    if ($seenCandidates.ContainsKey($candidate) -or $existingLookup.ContainsKey($candidate)) {
        $duplicates++
        continue
    }
    $seenCandidates[$candidate] = $true

    $shape = Test-FeedUrlShape -Url $candidate
    if (!$shape.IsUsable) {
        $invalid++
        if ([string]::IsNullOrWhiteSpace($firstInvalidMessage)) {
            $firstInvalidMessage = Format-ImportText -Labels $importLabels -Key $shape.MessageKey
        }
        continue
    }

    if ($emptySlots.Count -le 0) {
        $notFit++
        continue
    }

    $slot = [int]$emptySlots.Dequeue()
    $key = Get-FeedUrlKey -Slot $slot
    $lines = @(Set-IncValue -Lines $lines -Name $key -Value $candidate)
    if ($slot -eq 1) {
        $lines = @(Set-IncValue -Lines $lines -Name 'CalendarUrl1' -Value $candidate)
    }

    $color = Get-IncValue -Lines $lines -Name "CalendarColor$slot"
    if ([string]::IsNullOrWhiteSpace($color)) {
        $color = $palette[($slot - 1) % $palette.Count]
        $lines = @(Set-IncValue -Lines $lines -Name "CalendarColor$slot" -Value $color)
    }

    $lines = @(Set-IncValue -Lines $lines -Name "Feed${slot}Name" -Value (Format-ImportText -Labels $importLabels -Key 'PendingName' -FormatArgs @($slot)))
    $lines = @(Set-IncValue -Lines $lines -Name "Feed${slot}Result" -Value (Format-ImportText -Labels $importLabels -Key 'Pending'))
    $lines = @(Set-IncValue -Lines $lines -Name "Feed${slot}Count" -Value '')
    $lines = @(Set-IncValue -Lines $lines -Name "Feed${slot}Color" -Value $color)
    $added++
}

$parts = New-Object System.Collections.Generic.List[string]
if ($added -gt 0) {
    [void]$parts.Add((Format-ImportText -Labels $importLabels -Key 'AddedPart' -FormatArgs @($added)))
    if ($duplicates -gt 0) { [void]$parts.Add((Format-ImportText -Labels $importLabels -Key 'SkippedDuplicates' -FormatArgs @($duplicates))) }
    if ($invalid -gt 0) { [void]$parts.Add((Format-ImportText -Labels $importLabels -Key 'SkippedInvalid' -FormatArgs @($invalid))) }
    if ($notFit -gt 0) { [void]$parts.Add((Format-ImportText -Labels $importLabels -Key 'DidNotFit' -FormatArgs @($notFit))) }
}

if ($added -eq 0) {
    if (![string]::IsNullOrWhiteSpace($firstInvalidMessage)) {
        $status = $firstInvalidMessage
    }
    elseif ($duplicates -gt 0) {
        $status = Format-ImportText -Labels $importLabels -Key 'DuplicateOnly'
    }
    elseif ($emptySlots.Count -le 0) {
        $status = Format-ImportText -Labels $importLabels -Key 'SlotsFull'
    }
    else {
        $status = Format-ImportText -Labels $importLabels -Key 'NoNew'
    }
}
else {
    $status = Format-ImportText -Labels $importLabels -Key 'AddedAt' -FormatArgs @(($parts -join '; '), (Get-Date -Format 'h:mm tt'))
}

if ($added -gt 0) {
    $lines = @(Set-IncValue -Lines $lines -Name 'UseSample' -Value '0')
}
$lines = @(Set-IncValue -Lines $lines -Name 'CalendarSlots' -Value ([string]$max))
$summary = if ($added -gt 0) { Format-ImportText -Labels $importLabels -Key 'SummaryAdded' -FormatArgs @($added) } else { Format-ImportText -Labels $importLabels -Key 'SummaryNoAdded' }
if ($duplicates -gt 0) { $summary += '; ' + (Format-ImportText -Labels $importLabels -Key 'SummaryDuplicates' -FormatArgs @($duplicates)) }
if ($invalid -gt 0) { $summary += '; ' + (Format-ImportText -Labels $importLabels -Key 'SummaryInvalid' -FormatArgs @($invalid)) }
if ($notFit -gt 0) { $summary += '; ' + (Format-ImportText -Labels $importLabels -Key 'SummaryFull' -FormatArgs @($notFit)) }
$lines = @(Set-Status -Lines $lines -ImportStatus $status -Summary $summary)

[System.IO.File]::WriteAllLines($resolvedPath, $lines, $settingsEncoding)

Write-Host $status
