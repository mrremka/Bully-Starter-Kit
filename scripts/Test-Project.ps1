param(
    [switch]$Release
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$Errors = New-Object System.Collections.Generic.List[string]

function Fail([string]$Message) {
    $script:Errors.Add($Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}
function Pass([string]$Message) { Write-Host "[ OK ] $Message" -ForegroundColor Green }

$required = @(
    'Start_BullyStarterKit.bat','.gitattributes','src\BullyStarterKit.ps1','mods.json',
    'locales\ru.json','locales\en.json','README.md','README_EN.md',
    'THIRD_PARTY.md','CHANGELOG.md','RELEASE_NOTES.md','CONTRIBUTING.md','CONTRIBUTING_RU.md','SECURITY.md','LICENSE',
    'docs\RUSSIAN_LANGUAGE.md','docs\RUSSIAN_LANGUAGE_EN.md',
    'docs\NEXUS_PUBLIC_RELEASE.md','docs\NEXUS_PUBLIC_RELEASE_EN.md','docs\NEXUS_FREE_ACCOUNTS.md','docs\NEXUS_FREE_ACCOUNTS_EN.md','docs\PUBLISHING_RU.md',
    'assets\app-preview.svg','assets\app-preview.png','assets\github-header.svg',
    'assets\github-social-preview.svg','assets\github-social-preview.png','assets\bully-starter-kit.ico'
)
foreach ($rel in $required) {
    if (Test-Path (Join-Path $Root $rel)) { Pass "Exists: $rel" } else { Fail "Missing required file: $rel" }
}


# CMD launcher must be strict ASCII + CRLF. Old cmd.exe builds can misparse LF-only UTF-8 batch files.
$launcherPath = Join-Path $Root 'Start_BullyStarterKit.bat'
if (Test-Path $launcherPath) {
    $launcherBytes = [System.IO.File]::ReadAllBytes($launcherPath)
    if ($launcherBytes.Length -ge 3 -and $launcherBytes[0] -eq 0xEF -and $launcherBytes[1] -eq 0xBB -and $launcherBytes[2] -eq 0xBF) {
        Fail 'CMD launcher must not contain a UTF-8 BOM.'
    } else { Pass 'CMD launcher has no UTF-8 BOM.' }

    $nonAscii = @($launcherBytes | Where-Object { $_ -gt 0x7F })
    if ($nonAscii.Count -gt 0) { Fail 'CMD launcher must contain ASCII bytes only.' }
    else { Pass 'CMD launcher is ASCII-only.' }

    $launcherText = [System.Text.Encoding]::ASCII.GetString($launcherBytes)
    if ($launcherText -match '(?<!\r)\n' -or $launcherText -match '\r(?!\n)') {
        Fail 'CMD launcher must use CRLF line endings only.'
    } else { Pass 'CMD launcher uses CRLF line endings.' }

    if ($launcherText -notmatch [regex]::Escape('%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe')) {
        Fail 'CMD launcher must call Windows PowerShell using the absolute System32 path.'
    } else { Pass 'CMD launcher uses the absolute Windows PowerShell path.' }

    if ($launcherText -notmatch '--launcher-test') { Fail 'CMD launcher is missing the CI self-test mode.' }
    else { Pass 'CMD launcher exposes --launcher-test.' }
}

$sourcePath = Join-Path $Root 'src\BullyStarterKit.ps1'
$source = if (Test-Path $sourcePath) { Get-Content $sourcePath -Raw -Encoding UTF8 } else { '' }

# Parse PowerShell without executing the WPF application.
if ($source) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($sourcePath, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        foreach ($e in $parseErrors) { Fail "PowerShell syntax: $($e.Message) at line $($e.Extent.StartLineNumber)" }
    } else { Pass 'PowerShell syntax is valid.' }
}

$mods = $null
try {
    $mods = Get-Content (Join-Path $Root 'mods.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Pass 'mods.json is valid JSON.'
} catch { Fail "mods.json is invalid: $($_.Exception.Message)" }

$localeObjects = @{}
foreach ($lang in @('ru','en')) {
    try {
        $obj = Get-Content (Join-Path $Root "locales\$lang.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $localeObjects[$lang] = $obj
        Pass "locales/$lang.json is valid JSON."
    } catch { Fail "locales/$lang.json is invalid: $($_.Exception.Message)" }
}

if ($localeObjects.Count -eq 2 -and $source) {
    $ruKeys = @($localeObjects.ru.PSObject.Properties.Name | Sort-Object)
    $enKeys = @($localeObjects.en.PSObject.Properties.Name | Sort-Object)
    $missingEn = @($ruKeys | Where-Object { $_ -notin $enKeys })
    $missingRu = @($enKeys | Where-Object { $_ -notin $ruKeys })
    if ($missingEn.Count -or $missingRu.Count) {
        if ($missingEn.Count) { Fail "Missing EN locale keys: $($missingEn -join ', ')" }
        if ($missingRu.Count) { Fail "Missing RU locale keys: $($missingRu -join ', ')" }
    } else { Pass 'RU/EN locale keys match.' }

    $used = [regex]::Matches($source, "(?:L|LF)\s+'([A-Z0-9_]+)'|\{\{([A-Z0-9_]+)\}\}") | ForEach-Object {
        if ($_.Groups[1].Success) { $_.Groups[1].Value } else { $_.Groups[2].Value }
    } | Sort-Object -Unique
    $missing = @($used | Where-Object { $_ -notin $ruKeys })
    if ($missing.Count) { Fail "Locale keys used by installer but missing from JSON: $($missing -join ', ')" }
    else { Pass 'All installer locale keys exist.' }

    # RU and EN must use the same composite-format placeholder indexes.
    foreach ($key in $ruKeys) {
        $ruText = [string]$localeObjects.ru.PSObject.Properties[$key].Value
        $enText = [string]$localeObjects.en.PSObject.Properties[$key].Value
        $ruIndexes = @([regex]::Matches($ruText, '(?<!\{)\{(\d+)(?:[^}]*)\}(?!\})') | ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Unique)
        $enIndexes = @([regex]::Matches($enText, '(?<!\{)\{(\d+)(?:[^}]*)\}(?!\})') | ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Unique)
        if (($ruIndexes -join ',') -ne ($enIndexes -join ',')) {
            Fail "Locale format placeholders differ for $key: RU=[$($ruIndexes -join ',')] EN=[$($enIndexes -join ',')]"
            continue
        }
        $maxIndex = -1
        if ($ruIndexes.Count -gt 0) { $maxIndex = ($ruIndexes | Measure-Object -Maximum).Maximum }
        $dummy = @()
        for ($i = 0; $i -le $maxIndex; $i++) { $dummy += "arg$i" }
        try { [void]($ruText -f $dummy); [void]($enText -f $dummy) }
        catch { Fail "Invalid composite format string for $key: $($_.Exception.Message)" }
    }
    if (-not ($source -match 'function\s+LF[\s\S]*?\$FormatArgs') -or $source -match 'function\s+LF\s*\([^)]*\$Args') {
        Fail 'LF formatter must use FormatArgs and must not declare the PowerShell automatic $Args variable.'
    } else { Pass 'Localization formatter avoids the automatic $Args variable.' }
    
    if ($source -notmatch 'LOG_EF_LAYOUT_FALLBACK' -or $source -notmatch 'GetExtension\(\$entry\.Name\)' -or $source -notmatch "segment -match 'toscripts'") {
        Fail 'Essential Fixes installer must support normalized To Scripts detection and .lur fallback.'
    } else { Pass 'Essential Fixes archive-layout fallback is present.' }
    if ($source -match '\[string\]::Format\(\(L\s+') {
        Fail 'Direct String.Format calls on localized strings are forbidden; use LF instead.'
    } else { Pass 'Localized formatted strings are routed through LF.' }
}


if ($source) {
    if ($source -notmatch 'Resolve-NexusArchiveManual') { Fail 'Stable public build requires the no-API Nexus browser resolver.' } else { Pass 'No-API Nexus browser resolver is present.' }

    if ($source -notmatch 'Set-DownloadMode' -or $source -notmatch 'DOWNLOAD_MODE_AUTO' -or $source -notmatch 'DOWNLOAD_MODE_SLOW') {
        Fail 'Release UI must expose Auto and Slow Download modes.'
    } else { Pass 'Auto / Slow Download release switch is present.' }
    if ($source -match 'FontWeight="Black"') {
        Fail 'Release UI must not use synthetic Black font weight.'
    } else { Pass 'Release typography avoids synthetic Black weight.' }

    if ($source -notmatch 'Wait-For-NexusBrowserDownload' -or $source -notmatch 'Get-HttpStatusCode') {
        Fail 'Nexus Free fallback helpers are missing.'
    } else { Pass 'Nexus Free fallback helpers are present.' }

    if ($source -notmatch '\$status\s*=\s*Get-HttpStatusCode\s+\$_' -or $source -notmatch '\$status\s*-ne\s*403') {
        Fail 'Nexus 403 must be handled explicitly instead of failing the whole install.'
    } else { Pass 'Nexus 403 has an explicit official-web fallback.' }

    if ($source -notmatch 'Test-ZipMatchesMod') {
        Fail 'Downloaded Nexus ZIPs must be validated before installation.'
    } else { Pass 'Nexus ZIP validation is enabled.' }

    if ($source -notmatch "essential\.\*fix\.\*improvement" -or $source -notmatch "-396-") {
        Fail 'Essential Fixes ZIP validation must tolerate official Nexus filenames when archive directory entries vary.'
    } else { Pass 'Essential Fixes validator includes official Nexus filename fallback.' }

    $efMatch = [regex]::Match($source, '(?s)function\s+Install-EssentialFixes\s*\{(.*?)\n\}')
    if (!$efMatch.Success) {
        Fail 'Essential Fixes installer function is missing.'
    } else {
        $efBody = $efMatch.Groups[1].Value
        if ($efBody -match 'Expand-ZipFresh') {
            Fail 'Essential Fixes must not use the generic ZIP extraction pipeline.'
        } elseif ($efBody -notmatch 'ZipFile.*OpenRead' -or $efBody -notmatch 'To Scripts' -or $efBody -notmatch 'Optional' -or $efBody -notmatch 'default\.idb') {
            Fail 'Essential Fixes must directly read To Scripts and Optional from the official ZIP while excluding default.idb.'
        } else { Pass 'Essential Fixes uses dedicated direct-ZIP installation.' }
    }

    if ($source -notmatch 'function\s+Copy-ZipEntryToGameSafe') {
        Fail 'Direct ZIP components require the safe ZIP-entry writer helper.'
    } else { Pass 'Safe direct ZIP-entry writer is present.' }

    if ($source -notmatch 'function\s+Get-SafeZipRelativePath' -or $source -notmatch 'GetInvalidFileNameChars' -or $source -notmatch "\$part -eq '\.\.'") {
        Fail 'ZIP extraction must validate path segments before calling GetFullPath.'
    } else { Pass 'ZIP extraction validates path segments before Windows path resolution.' }

    if ($source -notmatch 'catch \[System\.NotSupportedException\]' -or $source -notmatch 'catch \[System\.IO\.PathTooLongException\]') {
        Fail 'ZIP extraction must tolerate Windows-incompatible nonessential entry names without aborting the full install.'
    } else { Pass 'ZIP extraction handles unsupported/too-long Windows entry names per entry.' }

    if ($source -match 'GetFullPath\(\(Join-Path \$Destination \$relative\)\)') {
        Fail 'Unsafe regression: raw ZIP entry must not be passed directly from Join-Path into GetFullPath.'
    } else { Pass 'Raw ZIP entry names are not passed directly into GetFullPath.' }

    $opbMatch = [regex]::Match($source, '(?s)function\s+Install-OnePercentBetter\s*\{(.*?)\n\}')
    if (!$opbMatch.Success) {
        Fail 'One Percent Better installer function is missing.'
    } else {
        $opbBody = $opbMatch.Groups[1].Value
        if ($opbBody -match 'Expand-ZipFresh') {
            Fail 'One Percent Better must not use the generic ZIP extraction pipeline.'
        } elseif ($opbBody -notmatch 'gsa_info\.dat' -or $opbBody -notmatch 'ZipFile.*OpenRead') {
            Fail 'One Percent Better installer must read gsa_info.dat directly from the official Main ZIP.'
        } else { Pass 'One Percent Better uses dedicated direct gsa_info.dat installation.' }
    }

    if ($source -notmatch 'VISUAL_FAIL_CONTINUE' -or $source -notmatch 'VISUAL_DOWNLOAD_FAIL_CONTINUE') {
        Fail 'Optional graphics failures must offer a continue-without-visuals path.'
    } else { Pass 'Optional graphics failures are non-fatal when the user chooses to continue.' }
}

if ($mods -and $source) {
    $m = [regex]::Match($source, '\$PackVersion\s*=\s*''([^'']+)''')
    if (!$m.Success) { Fail 'Could not read $PackVersion from installer.' }
    elseif ($m.Groups[1].Value -ne [string]$mods.packVersion) { Fail "Version mismatch: installer=$($m.Groups[1].Value), mods.json=$($mods.packVersion)" }
    else { Pass "Version is consistent: $($mods.packVersion)" }

    $version = [string]$mods.packVersion
    foreach ($doc in @('README.md','README_EN.md','CHANGELOG.md')) {
        $text = Get-Content (Join-Path $Root $doc) -Raw -Encoding UTF8
        if ($text -match [regex]::Escape($version)) { Pass "$doc references current version." }
        else { Fail "$doc does not reference current version $version." }
    }

    foreach ($mod in $mods.mods) {
        if ([string]::IsNullOrWhiteSpace([string]$mod.author)) { Fail "Missing author for mod '$($mod.id)'" }
        if ([string]::IsNullOrWhiteSpace([string]$mod.source)) { Fail "Missing source for mod '$($mod.id)'" }
        elseif (-not ([string]$mod.source).StartsWith('https://')) { Fail "Non-HTTPS source for '$($mod.id)': $($mod.source)" }
    }

    if ([int]$mods.gameLocalization.steamLanguageCode -ne 1049) {
        Fail 'Steam Russian localization code must be 1049.'
    } else { Pass 'Steam Russian localization code is 1049.' }

    if ($Release) {
        if ([string]$mods.nexus.publicDefaultMode -ne 'official-browser-assisted') {
            Fail 'Stable release requires official-browser-assisted as the public default Nexus mode.'
        } else { Pass 'Stable public Nexus mode is browser-assisted and does not require a user API key.' }
    }
}

# Do not accidentally commit third-party mod archives or credentials.
$archives = @(Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.zip','.7z','.rar') })
if ($archives.Count -gt 0) {
    foreach ($a in $archives) { Fail "Unexpected archive committed to repository: $($a.FullName.Substring($Root.Length).TrimStart('\'))" }
} else { Pass 'No third-party archives are committed.' }

$secretCandidates = @(Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -match '(?i)(api[-_]?key|token|credential|secret)' -and $_.Extension -notin @('.md')
})
if ($secretCandidates.Count -gt 0) {
    foreach ($f in $secretCandidates) { Fail "Suspicious credential-like filename in repository: $($f.FullName.Substring($Root.Length).TrimStart('\'))" }
} else { Pass 'No credential-like data files found.' }

# The downloads directory should be empty except for .gitkeep in source control.
$downloadDir = Join-Path $Root 'downloads'
if (Test-Path $downloadDir) {
    $unexpected = @(Get-ChildItem -LiteralPath $downloadDir -Force -File | Where-Object { $_.Name -ne '.gitkeep' })
    if ($unexpected.Count) { foreach ($f in $unexpected) { Fail "Unexpected file in downloads/: $($f.Name)" } }
    else { Pass 'downloads/ contains no bundled mod files.' }
}

if ($Errors.Count -gt 0) {
    Write-Host "`nValidation failed with $($Errors.Count) error(s)." -ForegroundColor Red
    exit 1
}
Write-Host "`nBully Starter Kit validation passed." -ForegroundColor Green

# Regression: New-Item does not support -LiteralPath in Windows PowerShell 5.1.
$mainScriptText = Get-Content -LiteralPath (Join-Path $Root 'src\BullyStarterKit.ps1') -Raw
if ($mainScriptText -match '(?im)\bNew-Item\b[^\r\n]*-LiteralPath\b') {
    throw 'Unsupported New-Item -LiteralPath found. Use System.IO.Directory.CreateDirectory or New-Item -Path.'
}
