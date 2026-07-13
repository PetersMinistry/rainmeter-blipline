$ErrorActionPreference = 'Stop'

$version = '0.3.22'
$dist = $PSScriptRoot
$projectRoot = Split-Path -Parent $PSScriptRoot
$gitDir = if (Test-Path -LiteralPath (Join-Path $projectRoot '.git-meta')) { '.git-meta' } else { '.git' }
$zipPath = Join-Path $dist "Blipline_$version-beta.zip"
$rmskinPath = Join-Path $dist "Blipline_$version-beta.rmskin"

Push-Location $projectRoot
try {
    git --git-dir=$gitDir --work-tree=. archive --format=zip HEAD Skins/Blipline -o $zipPath
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to create the Blipline release archive.'
    }
}
finally {
    Pop-Location
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Update)
try {
    $gitkeep = $zip.GetEntry('Skins/Blipline/@Resources/Cache/.gitkeep')
    if ($gitkeep) {
        $gitkeep.Delete()
    }

    if (-not $zip.GetEntry('Skins/Blipline/@Resources/Cache/')) {
        [void]$zip.CreateEntry('Skins/Blipline/@Resources/Cache/')
    }

    $entry = $zip.CreateEntry('RMSKIN.ini')
    $writer = [System.IO.StreamWriter]::new($entry.Open(), [System.Text.Encoding]::ASCII)
    $writer.Write("[rmskin]`r`nName=Blipline`r`nAuthor=PetersMinistry`r`nVersion=$version`r`nLoadType=Skin`r`nLoad=Blipline\Control\Settings.ini`r`nMinimumRainmeter=4.5.0`r`nMinimumWindows=10.0`r`n")
    $writer.Dispose()
}
finally {
    $zip.Dispose()
}

$zipBytes = [System.IO.File]::ReadAllBytes($zipPath)
$footer = New-Object byte[] 16
[BitConverter]::GetBytes([UInt64]$zipBytes.Length).CopyTo($footer, 0)
([byte[]]@(0, 82, 77, 83, 75, 73, 78, 0)).CopyTo($footer, 8)

$out = New-Object byte[] ($zipBytes.Length + $footer.Length)
[Array]::Copy($zipBytes, 0, $out, 0, $zipBytes.Length)
[Array]::Copy($footer, 0, $out, $zipBytes.Length, $footer.Length)
[System.IO.File]::WriteAllBytes($rmskinPath, $out)

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $rmskinPath).Hash.ToLowerInvariant()
$item = Get-Item -LiteralPath $rmskinPath

[pscustomobject]@{
    Path = $item.FullName
    Length = $item.Length
    Sha256 = $hash
    ZipPayloadLength = $zipBytes.Length
}
