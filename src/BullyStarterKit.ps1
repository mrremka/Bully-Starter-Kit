# Bully Starter Kit v0.4.0 Release
# Windows 10/11, Windows PowerShell 5.1+

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.IO.Compression.FileSystem
try { Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue } catch {}

$ErrorActionPreference = 'Stop'
$PackVersion = '0.4.0'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$DownloadsDir = Join-Path $RepoRoot 'downloads'
$SettingsDir = Join-Path $env:APPDATA 'BullyStarterKit'
$SavedKeyPath = Join-Path $SettingsDir 'nexus-api-key.dat'
$ModsConfigPath = Join-Path $RepoRoot 'mods.json'
$LocalesDir = Join-Path $RepoRoot 'locales'
$LanguagePrefPath = Join-Path $SettingsDir 'ui-language.txt'
$PowerShellExe = Join-Path $PSHOME 'powershell.exe'

function Get-PreferredUiLanguage {
    try {
        if (Test-Path $LanguagePrefPath) {
            $savedLang = (Get-Content -LiteralPath $LanguagePrefPath -Raw).Trim().ToLowerInvariant()
            if ($savedLang -in @('ru','en')) { return $savedLang }
        }
    } catch {}
    try {
        if ([System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'ru') { return 'ru' }
    } catch {}
    return 'en'
}

$Script:UiLanguage = Get-PreferredUiLanguage
$LocalePath = Join-Path $LocalesDir ($Script:UiLanguage + '.json')
if (!(Test-Path $LocalePath)) { $LocalePath = Join-Path $LocalesDir 'en.json'; $Script:UiLanguage = 'en' }
$Script:Strings = Get-Content -LiteralPath $LocalePath -Raw -Encoding UTF8 | ConvertFrom-Json

function L([string]$Key) {
    $prop = $Script:Strings.PSObject.Properties[$Key]
    if ($prop) { return [string]$prop.Value }
    return $Key
}

function LF {
    param(
        [Parameter(Mandatory=$true, Position=0)][string]$Key,
        [Parameter(Position=1)][object[]]$FormatArgs = @()
    )
    $format = L $Key
    try {
        return ($format -f $FormatArgs)
    } catch {
        throw "Localization format error for '$Key': $($_.Exception.Message)"
    }
}

function Expand-LocTemplate([string]$Template) {
    return [regex]::Replace($Template, '\{\{([A-Z0-9_]+)\}\}', {
        param($m)
        return [System.Security.SecurityElement]::Escape((L $m.Groups[1].Value))
    })
}

function Switch-UiLanguage {
    $newLang = if ($Script:UiLanguage -eq 'ru') { 'en' } else { 'ru' }
    Set-Content -LiteralPath $LanguagePrefPath -Value $newLang -Encoding ASCII
    try {
        [System.Windows.MessageBox]::Show((L 'RESTART_LANG'), (L 'TITLE_DEFAULT'), 'OK', 'Information') | Out-Null
        $restartArgs = "-NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File `"$PSCommandPath`""
        Start-Process -FilePath $PowerShellExe -ArgumentList $restartArgs
    } finally {
        if ($Script:Window) { $Script:Window.Close() }
    }
}
New-Item -ItemType Directory -Path $DownloadsDir -Force | Out-Null
New-Item -ItemType Directory -Path $SettingsDir -Force | Out-Null

$Config = Get-Content -LiteralPath $ModsConfigPath -Raw | ConvertFrom-Json
$Script:LogBox = $null
$Script:GamePathBox = $null
$Script:SilentCheck = $null
$Script:EssentialCheck = $null
$Script:VisualCheck = $null
$Script:FpsBox = $null
$Script:NexusKeyBox = $null
$Script:RememberKeyCheck = $null
$Script:NexusStatus = $null
$Script:DownloadStatus = $null
$Script:InstallProgress = $null
$Script:InstallButton = $null
$Script:NewFiles = New-Object System.Collections.Generic.List[string]
$Script:ResolvedDownloads = @{}

function Write-UiLog {
    param([string]$Message)
    $stamp = Get-Date -Format 'HH:mm:ss'
    if ($Script:LogBox) {
        $Script:LogBox.AppendText("[$stamp] $Message`r`n")
        $Script:LogBox.ScrollToEnd()
    }
    [System.Windows.Forms.Application]::DoEvents()
}

function Show-Info([string]$text, [string]$title='') {
    if ([string]::IsNullOrWhiteSpace($title)) { $title = L 'TITLE_DEFAULT' }
    [System.Windows.MessageBox]::Show($text, $title, 'OK', 'Information') | Out-Null
}

function Show-Warn([string]$text, [string]$title='') {
    if ([string]::IsNullOrWhiteSpace($title)) { $title = L 'TITLE_DEFAULT' }
    [System.Windows.MessageBox]::Show($text, $title, 'OK', 'Warning') | Out-Null
}

function Show-LocalizedQuestion([string]$Text, [string]$Title) {
    $questionXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Height="280" Width="560" WindowStartupLocation="CenterOwner" ResizeMode="NoResize"
        Background="#090A0D" Foreground="#F7F7F8" FontFamily="Segoe UI" ShowInTaskbar="False" TextOptions.TextFormattingMode="Display" TextOptions.TextRenderingMode="ClearType">
    <Grid Margin="24">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
        <TextBlock x:Name="QuestionTitle" FontSize="21" FontWeight="Bold"/>
        <TextBlock x:Name="QuestionText" Grid.Row="1" TextWrapping="Wrap" Foreground="#C5C8CE" FontSize="13" LineHeight="20" Margin="0,16,0,18"/>
        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Button x:Name="NoButton" Content="{{NO}}" Height="42" Margin="0,0,6,0" Background="#1D2027" Foreground="#F7F7F8" BorderBrush="#343946" FontWeight="Bold"/>
            <Button x:Name="YesButton" Grid.Column="1" Content="{{YES}}" Height="42" Margin="6,0,0,0" Background="#F6C945" Foreground="#151515" BorderBrush="#F6C945" FontWeight="Bold"/>
        </Grid>
    </Grid>
</Window>
'@
    $questionXaml = Expand-LocTemplate $questionXaml
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$questionXaml)
    $dialog = [Windows.Markup.XamlReader]::Load($reader)
    if ($Script:Window) { $dialog.Owner = $Script:Window }
    $dialog.Title = $Title
    $dialog.FindName('QuestionTitle').Text = $Title
    $dialog.FindName('QuestionText').Text = $Text
    $script:QuestionResult = $false
    $dialog.FindName('YesButton').Add_Click({ $script:QuestionResult = $true; $dialog.DialogResult = $true; $dialog.Close() })
    $dialog.FindName('NoButton').Add_Click({ $script:QuestionResult = $false; $dialog.DialogResult = $false; $dialog.Close() })
    [void]$dialog.ShowDialog()
    return [bool]$script:QuestionResult
}

function Get-SafePathWithinRoot {
    param([string]$Root,[string]$Path)
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\','/') + [System.IO.Path]::DirectorySeparatorChar
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    if (!$pathFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw (LF 'ERR_UNSAFE_PATH' @($pathFull))
    }
    return $pathFull
}

function Get-SteamLibraryRoots {
    $roots = New-Object System.Collections.Generic.List[string]
    $candidates = @()
    try {
        $reg = Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -ErrorAction Stop
        if ($reg.SteamPath) { $candidates += [string]$reg.SteamPath }
    } catch {}
    if (${env:ProgramFiles(x86)}) { $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Steam') }
    if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles 'Steam') }

    foreach ($steamRoot in $candidates | Select-Object -Unique) {
        if ([string]::IsNullOrWhiteSpace($steamRoot)) { continue }
        if (Test-Path $steamRoot) {
            if (-not $roots.Contains($steamRoot)) { $roots.Add($steamRoot) }
            $vdf = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
            if (Test-Path $vdf) {
                try {
                    $text = Get-Content -LiteralPath $vdf -Raw
                    foreach ($m in [regex]::Matches($text, '"path"\s*"([^"]+)"')) {
                        $p = $m.Groups[1].Value -replace '\\\\','\'
                        if ($p -and (Test-Path $p) -and -not $roots.Contains($p)) { $roots.Add($p) }
                    }
                } catch {}
            }
        }
    }
    return @($roots)
}

function Test-BullyPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    return Test-Path (Join-Path $Path 'Bully.exe')
}

function Find-BullyInstall {
    $candidates = @()
    foreach ($libraryRoot in (Get-SteamLibraryRoots)) {
        $candidates += (Join-Path $libraryRoot 'steamapps\common\Bully Scholarship Edition')
    }
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Rockstar Games\Bully Scholarship Edition')
    }
    if ($env:ProgramFiles) {
        $candidates += (Join-Path $env:ProgramFiles 'Rockstar Games\Bully Scholarship Edition')
    }
    $candidates += 'C:\Games\Bully Scholarship Edition'
    $candidates += 'D:\Games\Bully Scholarship Edition'
    $candidates += 'E:\Games\Bully Scholarship Edition'

    foreach ($p in $candidates | Select-Object -Unique) {
        if (Test-BullyPath $p) { return $p }
    }
    return ''
}

function Get-BullyVersionText([string]$GamePath) {
    try {
        $exe = Join-Path $GamePath 'Bully.exe'
        if (!(Test-Path $exe)) { return 'unknown' }
        $v = (Get-Item $exe).VersionInfo.FileVersion
        if ($v) { return $v }
    } catch {}
    return 'unknown'
}

function Select-GameFolder {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = L 'STEP1_DESC'
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        if (Test-BullyPath $dialog.SelectedPath) {
            $Script:GamePathBox.Text = $dialog.SelectedPath
            Write-UiLog (LF 'LOG_GAME_SELECTED' @($dialog.SelectedPath))
            Write-UiLog (LF 'LOG_GAME_VERSION' @((Get-BullyVersionText $dialog.SelectedPath)))
        } else {
            Show-Warn (L 'ERR_BULLY_NOT_FOUND')
        }
    }
}

function Save-NexusApiKey([string]$ApiKey) {
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { return }
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($ApiKey.Trim())
        $encrypted = [System.Security.Cryptography.ProtectedData]::Protect(
            $bytes,
            $null,
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        [System.IO.File]::WriteAllText($SavedKeyPath, [Convert]::ToBase64String($encrypted), [System.Text.Encoding]::UTF8)
        Write-UiLog (L 'LOG_KEY_SAVED')
    } catch {
        throw (LF 'ERR_KEY_SAVE' @($_.Exception.Message))
    }
}

function Load-NexusApiKey {
    if (!(Test-Path $SavedKeyPath)) { return '' }
    try {
        $encoded = [System.IO.File]::ReadAllText($SavedKeyPath, [System.Text.Encoding]::UTF8).Trim()
        if (!$encoded) { return '' }
        $encrypted = [Convert]::FromBase64String($encoded)
        $plain = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $encrypted,
            $null,
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        return [System.Text.Encoding]::UTF8.GetString($plain)
    } catch {
        Write-UiLog (L 'LOG_KEY_DECRYPT_FAIL')
        return ''
    }
}

function Clear-NexusApiKey {
    Remove-Item -LiteralPath $SavedKeyPath -Force -ErrorAction SilentlyContinue
    if ($Script:NexusKeyBox) { $Script:NexusKeyBox.Password = '' }
    $Script:NexusStatus.Text = L 'NOT_CONNECTED'
    $Script:NexusStatus.Foreground = '#F6C945'
    Write-UiLog (L 'NEXUS_SAVED_CLEARED')
}

function Get-NexusApiKey {
    $typed = ''
    if ($Script:NexusKeyBox) { $typed = $Script:NexusKeyBox.Password.Trim() }
    if ($typed) {
        if ($Script:RememberKeyCheck.IsChecked) { Save-NexusApiKey $typed }
        return $typed
    }
    return (Load-NexusApiKey)
}

function Invoke-NexusApi {
    param(
        [ValidateSet('GET','POST')][string]$Method,
        [string]$Path,
        [string]$ApiKey
    )
    $headers = @{
        'apikey' = $ApiKey
        'Application-Name' = 'BullyStarterKit'
        'Application-Version' = $PackVersion
        'User-Agent' = "BullyStarterKit/$PackVersion"
        'Accept' = 'application/json'
    }
    $uri = 'https://api.nexusmods.com/v3' + $Path
    if ($Method -eq 'POST') {
        return Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType 'application/json'
    }
    return Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
}

function Test-NexusConnection {
    $key = Get-NexusApiKey
    if (!$key) {
        $Script:NexusStatus.Text = L 'NOT_CONNECTED'
        $Script:NexusStatus.Foreground = '#F6C945'
        Show-Warn (L 'NEXUS_NEEDS_AUTH')
        return $false
    }
    try {
        Write-UiLog (L 'LOG_NEXUS_CHECK')
        $test = Invoke-NexusApi -Method GET -Path "/games/$($Config.nexus.gameDomain)/mods/148" -ApiKey $key
        if ($test.data.id) {
            $Script:NexusStatus.Text = L 'NEXUS_CONNECTED'
            $Script:NexusStatus.Foreground = '#7EE787'
            Write-UiLog (L 'LOG_NEXUS_OK')
            return $true
        }
        throw (L 'ERR_NEXUS_UNEXPECTED')
    } catch {
        $Script:NexusStatus.Text = L 'NEXUS_FAILED'
        $Script:NexusStatus.Foreground = '#FF7B72'
        Write-UiLog (LF 'LOG_NEXUS_ERROR' @($_.Exception.Message))
        Show-Warn (L 'NEXUS_CHECK_KEY')
        return $false
    }
}

function Get-NexusModConfig([string]$Id) {
    return $Config.mods | Where-Object { $_.id -eq $Id } | Select-Object -First 1
}

function Test-ZipArchive([string]$Path) {
    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
        $count = $archive.Entries.Count
        $archive.Dispose()
        return ($count -gt 0)
    } catch { return $false }
}

function Invoke-DownloadWithRetry {
    param([string]$Uri,[string]$OutFile,[hashtable]$Headers=@{},[int]$Attempts=3)
    $last = $null
    for ($i=1; $i -le $Attempts; $i++) {
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -Headers $Headers
            if ((Test-Path $OutFile) -and (Get-Item $OutFile).Length -ge 1024) { return }
            throw (L 'ERR_DOWNLOAD_SMALL')
        } catch {
            $last = $_
            Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
            if ($i -lt $Attempts) { Start-Sleep -Seconds (2 * $i) }
        }
    }
    throw $last.Exception
}


function Get-HttpStatusCode {
    param($ErrorRecord)
    try {
        if ($ErrorRecord.Exception.Response -and $ErrorRecord.Exception.Response.StatusCode) {
            return [int]$ErrorRecord.Exception.Response.StatusCode
        }
    } catch {}
    try {
        if ([string]$ErrorRecord.Exception.Message -match '\((\d{3})\)') {
            return [int]$Matches[1]
        }
    } catch {}
    return 0
}

function Get-DownloadsFolder {
    try {
        $shellPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
        $valueName = '{374DE290-123F-4565-9164-39C4925E467B}'
        $raw = (Get-ItemProperty -Path $shellPath -Name $valueName -ErrorAction Stop).$valueName
        if ($raw) {
            $expanded = [Environment]::ExpandEnvironmentVariables([string]$raw)
            if (Test-Path $expanded) { return $expanded }
        }
    } catch {}
    $fallback = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads'
    return $fallback
}

function Test-ZipMatchesMod {
    param([string]$Path,[string]$ModId)
    if (!(Test-ZipArchive $Path)) { return $false }
    $archive = $null
    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
        $entries = @($archive.Entries | ForEach-Object { $_.FullName -replace '\\','/' })
        $fileName = [System.IO.Path]::GetFileName($Path)

        switch ($ModId) {
            'essential-fixes' {
                # Nexus/archiver layouts are not guaranteed to preserve explicit directory entries,
                # so inspect every entry path rather than requiring one exact folder record.
                $hasToScripts = [bool]($entries | Where-Object {
                    $parts = @($_ -split '/')
                    @($parts | Where-Object { (($_ -replace '[^A-Za-z0-9]','').ToLowerInvariant()) -eq 'toscripts' }).Count -gt 0
                } | Select-Object -First 1)
                if ($hasToScripts) { return $true }

                $hasMainCompiled = [bool]($entries | Where-Object { $_ -match '(?i)(^|/)Main/Compiled(/|$)' } | Select-Object -First 1)
                $hasReadme = [bool]($entries | Where-Object { [System.IO.Path]::GetFileName($_) -match '(?i)^readme(?:\..+)?$' } | Select-Object -First 1)
                if ($hasMainCompiled -and $hasReadme) { return $true }

                # Last-resort identity check for the official Nexus download. Nexus appends
                # mod/file/version IDs to filenames, while the internal archive layout may vary.
                if ($fileName -match '(?i)essential.*fix.*improvement' -or $fileName -match '(?i)bully.*essential.*fix' -or $fileName -match '(?i)-396-') {
                    return $true
                }
                return $false
            }
            'one-percent-better' {
                $hasGsa = [bool]($entries | Where-Object { [System.IO.Path]::GetFileName($_) -ieq 'gsa_info.dat' } | Select-Object -First 1)
                if ($hasGsa) { return $true }
                if ($fileName -match '(?i)one.*percent.*better' -or $fileName -match '(?i)-148-') { return $true }
                return $false
            }
            default { return $true }
        }
    } catch {
        return $false
    } finally {
        if ($archive) { $archive.Dispose() }
    }
}

function Find-NewNexusZip {
    param(
        [string]$Folder,
        [datetime]$Since,
        [string]$ModId
    )
    if (!(Test-Path $Folder)) { return $null }
    $candidates = @(Get-ChildItem -LiteralPath $Folder -File -Filter '*.zip' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $Since.AddSeconds(-3) -and $_.Length -ge 1024 } |
        Sort-Object LastWriteTime -Descending)
    foreach ($candidate in $candidates) {
        try {
            $stream = [System.IO.File]::Open($candidate.FullName, 'Open', 'Read', 'None')
            $stream.Dispose()
        } catch { continue }
        if (Test-ZipMatchesMod -Path $candidate.FullName -ModId $ModId) {
            return $candidate.FullName
        }
    }
    return $null
}

function Wait-For-NexusBrowserDownload {
    param(
        [psobject]$Mod,
        [string]$SpecificFileUrl,
        [datetime]$StartedAt
    )

    $downloadFolder = Get-DownloadsFolder
    if (!(Test-Path $downloadFolder)) {
        New-Item -ItemType Directory -Path $downloadFolder -Force | Out-Null
    }

    Write-UiLog (LF 'LOG_NEXUS_FREE_MODE' @($Mod.name))
    Write-UiLog (LF 'LOG_NEXUS_OPEN_BROWSER' @($SpecificFileUrl))
    try { Start-Process $SpecificFileUrl } catch {
        throw (LF 'ERR_OPEN_BROWSER' @($_.Exception.Message))
    }

    $assistXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Height="390" Width="680" WindowStartupLocation="CenterOwner" ResizeMode="NoResize"
        Background="#090A0D" Foreground="#F7F7F8" FontFamily="Segoe UI" ShowInTaskbar="False" TextOptions.TextFormattingMode="Display" TextOptions.TextRenderingMode="ClearType">
    <Grid Margin="26">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBlock x:Name="AssistTitle" FontSize="22" FontWeight="Bold"/>
        <TextBlock x:Name="AssistBody" Grid.Row="1" TextWrapping="Wrap" Foreground="#C5C8CE" FontSize="13" LineHeight="20" Margin="0,14,0,12"/>
        <Border Grid.Row="2" Background="#12151B" BorderBrush="#303641" BorderThickness="1" CornerRadius="8" Padding="12" Margin="0,0,0,12">
            <StackPanel>
                <TextBlock x:Name="AssistMod" FontWeight="Bold" Foreground="#F6C945"/>
                <TextBlock x:Name="AssistFolder" Margin="0,5,0,0" Foreground="#AEB4BE" TextWrapping="Wrap"/>
            </StackPanel>
        </Border>
        <StackPanel Grid.Row="3">
            <TextBlock x:Name="AssistStatus" TextWrapping="Wrap" Foreground="#7EE787" FontWeight="SemiBold"/>
            <ProgressBar x:Name="AssistProgress" IsIndeterminate="True" Height="6" Margin="0,12,0,0"/>
        </StackPanel>
        <Grid Grid.Row="4" Margin="0,18,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Button x:Name="ReopenButton" Content="{{NEXUS_REOPEN_PAGE}}" Height="42" Margin="0,0,6,0" Background="#1D2027" Foreground="#F7F7F8" BorderBrush="#343946" FontWeight="Bold"/>
            <Button x:Name="PickButton" Grid.Column="1" Content="{{NEXUS_PICK_FILE}}" Height="42" Margin="6,0,6,0" Background="#1D2027" Foreground="#F7F7F8" BorderBrush="#343946" FontWeight="Bold"/>
            <Button x:Name="CancelButton" Grid.Column="2" Content="{{NEXUS_CANCEL}}" Height="42" Margin="6,0,0,0" Background="#2A1719" Foreground="#FFB4AB" BorderBrush="#6E343A" FontWeight="Bold"/>
        </Grid>
    </Grid>
</Window>
'@
    $assistXaml = Expand-LocTemplate $assistXaml
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$assistXaml)
    $dialog = [Windows.Markup.XamlReader]::Load($reader)
    if ($Script:Window) { $dialog.Owner = $Script:Window }
    $dialog.Title = L 'NEXUS_FREE_TITLE'
    $dialog.FindName('AssistTitle').Text = L 'NEXUS_FREE_TITLE'
    $dialog.FindName('AssistBody').Text = L 'NEXUS_FREE_BODY'
    $dialog.FindName('AssistMod').Text = (LF 'NEXUS_FREE_MOD' @($Mod.name))
    $dialog.FindName('AssistFolder').Text = (LF 'NEXUS_FREE_FOLDER' @($downloadFolder))
    $dialog.FindName('AssistStatus').Text = L 'NEXUS_FREE_WAITING'

    $state = @{
        Result = ''
        Cancelled = $false
        Deadline = (Get-Date).AddMinutes(15)
    }

    $timer = New-Object Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(1)
    $timer.Add_Tick({
        if ((Get-Date) -gt $state.Deadline) {
            $dialog.FindName('AssistStatus').Text = L 'NEXUS_FREE_TIMEOUT'
            $dialog.FindName('AssistStatus').Foreground = '#F6C945'
            $dialog.FindName('AssistProgress').IsIndeterminate = $false
            $timer.Stop()
            return
        }
        $found = Find-NewNexusZip -Folder $downloadFolder -Since $StartedAt -ModId $Mod.id
        if ($found) {
            $state.Result = $found
            $timer.Stop()
            $dialog.DialogResult = $true
            $dialog.Close()
        }
    })

    $dialog.FindName('ReopenButton').Add_Click({
        try { Start-Process $SpecificFileUrl } catch {}
    })
    $dialog.FindName('PickButton').Add_Click({
        $picker = New-Object System.Windows.Forms.OpenFileDialog
        $picker.Title = L 'NEXUS_PICK_TITLE'
        $picker.Filter = 'ZIP archives (*.zip)|*.zip|All files (*.*)|*.*'
        $picker.InitialDirectory = $downloadFolder
        if ($picker.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            if (Test-ZipMatchesMod -Path $picker.FileName -ModId $Mod.id) {
                $state.Result = $picker.FileName
                $timer.Stop()
                $dialog.DialogResult = $true
                $dialog.Close()
            } else {
                Show-Warn (LF 'NEXUS_WRONG_ARCHIVE' @($Mod.name))
            }
        }
    })
    $dialog.FindName('CancelButton').Add_Click({
        $state.Cancelled = $true
        $timer.Stop()
        $dialog.DialogResult = $false
        $dialog.Close()
    })

    $timer.Start()
    [void]$dialog.ShowDialog()
    $timer.Stop()

    if ($state.Cancelled -or [string]::IsNullOrWhiteSpace([string]$state.Result)) {
        throw (L 'ERR_NEXUS_FREE_CANCELLED')
    }

    Write-UiLog (LF 'LOG_NEXUS_FREE_FOUND' @($state.Result))
    return [string]$state.Result
}

function Resolve-NexusArchive {
    param(
        [psobject]$Mod,
        [string]$ApiKey,
        [string]$DestinationZip
    )
    $domain = $Config.nexus.gameDomain
    Write-UiLog (LF 'LOG_NEXUS_RESOLVE' @($Mod.name))

    $modResponse = Invoke-NexusApi -Method GET -Path "/games/$domain/mods/$($Mod.nexusModId)" -ApiKey $ApiKey
    $modUid = $modResponse.data.id
    if (!$modUid) { throw (LF 'ERR_NEXUS_NO_MOD_ID' @($Mod.name)) }

    $filesResponse = Invoke-NexusApi -Method GET -Path "/mods/$modUid/files" -ApiKey $ApiKey
    $fileGroups = @($filesResponse.data.mod_files | Where-Object { $_.is_active -eq $true })
    if ($fileGroups.Count -eq 0) { throw (LF 'ERR_NEXUS_NO_FILES' @($Mod.name)) }

    $chosenGroup = $null
    if ($Mod.preferredFileName) {
        $chosenGroup = $fileGroups | Where-Object { $_.name -ieq $Mod.preferredFileName } | Select-Object -First 1
        if (!$chosenGroup) {
            $needle = [regex]::Escape([string]$Mod.preferredFileName)
            $chosenGroup = $fileGroups | Where-Object { $_.name -match $needle } | Select-Object -First 1
        }
    }
    if (!$chosenGroup -and $fileGroups.Count -eq 1) { $chosenGroup = $fileGroups[0] }
    if (!$chosenGroup) {
        $chosenGroup = $fileGroups |
            Where-Object { $_.name -notmatch '(?i)source|optional|old' } |
            Sort-Object last_file_uploaded_at -Descending |
            Select-Object -First 1
    }
    if (!$chosenGroup) { throw (LF 'ERR_NEXUS_MAIN_FILE' @($Mod.name)) }

    $versionsResponse = Invoke-NexusApi -Method GET -Path "/mod-files/$($chosenGroup.id)/versions" -ApiKey $ApiKey
    $versions = @($versionsResponse.data.versions)
    if ($versions.Count -eq 0) { throw (LF 'ERR_NEXUS_NO_VERSIONS' @($Mod.name)) }

    $chosenVersion = $versions |
        Sort-Object @{Expression={ try { [datetime]$_.uploaded_at } catch { [datetime]::MinValue } }; Descending=$true} |
        Select-Object -First 1
    if (!$chosenVersion.id) { throw (LF 'ERR_NEXUS_NO_DOWNLOADABLE' @($Mod.name)) }

    Write-UiLog (LF 'LOG_NEXUS_RESOLVED' @($Mod.name, $chosenVersion.name, $chosenVersion.version))

    $downloadedByBrowser = $false
    try {
        $downloadResponse = Invoke-NexusApi -Method POST -Path "/mod-file-versions/$($chosenVersion.id)/download-repacked" -ApiKey $ApiKey
        $downloadUrl = $downloadResponse.download_url
        if (!$downloadUrl -and $downloadResponse.data) { $downloadUrl = $downloadResponse.data.download_url }
        if (!$downloadUrl) {
            throw (LF 'ERR_NEXUS_NO_DOWNLOAD_URL' @($Mod.name))
        }

        Write-UiLog (LF 'LOG_NEXUS_DOWNLOAD' @($Mod.name))
        Invoke-DownloadWithRetry -Uri $downloadUrl -OutFile $DestinationZip -Headers @{ 'User-Agent' = "BullyStarterKit/$PackVersion"; 'Application-Name'='BullyStarterKit'; 'Application-Version'=$PackVersion }
    } catch {
        $status = Get-HttpStatusCode $_
        if ($status -ne 403) { throw }

        # Nexus does not provide unattended API download links to free accounts.
        # Smoothly move the UI to Slow Download and continue through the official website.
        Write-UiLog (L 'LOG_AUTO_FALLBACK')
        Set-DownloadMode -Mode 'slow'
        $specificId = [string]$chosenVersion.game_scoped_id
        if ($specificId -match '^\d+$') {
            $filePage = $Mod.source + '?tab=files&file_id=' + [uri]::EscapeDataString($specificId)
        } else {
            $filePage = $Mod.source + '?tab=files'
        }
        $browserStart = Get-Date
        $browserZip = Wait-For-NexusBrowserDownload -Mod $Mod -SpecificFileUrl $filePage -StartedAt $browserStart
        Copy-Item -LiteralPath $browserZip -Destination $DestinationZip -Force
        $downloadedByBrowser = $true
    }

    if (!(Test-ZipArchive $DestinationZip)) { throw (LF 'ERR_INVALID_ZIP' @($Mod.name)) }
    if (!(Test-ZipMatchesMod -Path $DestinationZip -ModId $Mod.id)) { throw (LF 'NEXUS_WRONG_ARCHIVE' @($Mod.name)) }

    return [ordered]@{
        id = $Mod.id
        name = $Mod.name
        source = $Mod.source
        nexusModId = $Mod.nexusModId
        modFileId = $chosenGroup.id
        modFileName = $chosenGroup.name
        versionId = $chosenVersion.id
        version = $chosenVersion.version
        uploadedAt = $chosenVersion.uploaded_at
        downloadedAt = (Get-Date).ToString('o')
        archive = $DestinationZip
        sha256 = (Get-FileHash -LiteralPath $DestinationZip -Algorithm SHA256).Hash
        downloadMode = $(if ($downloadedByBrowser) { 'nexus-web-free' } else { 'nexus-api-direct' })
    }
}


function Resolve-NexusArchiveManual {
    param(
        [psobject]$Mod,
        [string]$DestinationZip
    )
    Write-UiLog (LF 'LOG_NEXUS_MANUAL_MODE' @($Mod.name))
    $page = [string]$Mod.source + '?tab=files'
    $started = Get-Date
    $browserZip = Wait-For-NexusBrowserDownload -Mod $Mod -SpecificFileUrl $page -StartedAt $started
    Copy-Item -LiteralPath $browserZip -Destination $DestinationZip -Force
    if (!(Test-ZipArchive $DestinationZip)) { throw (LF 'ERR_INVALID_ZIP' @($Mod.name)) }
    if (!(Test-ZipMatchesMod -Path $DestinationZip -ModId $Mod.id)) { throw (LF 'NEXUS_WRONG_ARCHIVE' @($Mod.name)) }
    return [ordered]@{
        id = $Mod.id
        name = $Mod.name
        source = $Mod.source
        nexusModId = $Mod.nexusModId
        downloadedAt = (Get-Date).ToString('o')
        archive = $DestinationZip
        sha256 = (Get-FileHash -LiteralPath $DestinationZip -Algorithm SHA256).Hash
        downloadMode = 'nexus-official-browser-assisted'
    }
}

function Download-SilentPatch([string]$DestinationZip) {
    $fallback = 'https://github.com/CookiePLMonster/SilentPatchBully/releases/download/BUILD-3-TEST/SilentPatchBully.zip'
    $downloadUrl = $fallback

    Write-UiLog (L 'LOG_SP_RESOLVE')
    try {
        $headers = @{ 'User-Agent' = "BullyStarterKit/$PackVersion" }
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/CookiePLMonster/SilentPatchBully/releases/latest' -Headers $headers
        $asset = $release.assets | Where-Object { $_.name -ieq 'SilentPatchBully.zip' } | Select-Object -First 1
        if ($asset.browser_download_url) { $downloadUrl = $asset.browser_download_url }
    } catch {
        Write-UiLog (L 'LOG_SP_FALLBACK')
    }

    Write-UiLog (L 'LOG_SP_DOWNLOAD')
    Invoke-DownloadWithRetry -Uri $downloadUrl -OutFile $DestinationZip -Headers @{ 'User-Agent' = "BullyStarterKit/$PackVersion"; 'Application-Name'='BullyStarterKit'; 'Application-Version'=$PackVersion }
    if (!(Test-ZipArchive $DestinationZip)) { throw (L 'ERR_SP_INVALID_ZIP') }
    return [ordered]@{
        id = 'silentpatch'
        name = 'SilentPatch for Bully'
        source = 'https://github.com/CookiePLMonster/SilentPatchBully'
        downloadedAt = (Get-Date).ToString('o')
        archive = $DestinationZip
        sha256 = (Get-FileHash -LiteralPath $DestinationZip -Algorithm SHA256).Hash
    }
}

function Download-SelectedMods {
    param([string]$TempDir)
    $Script:ResolvedDownloads = @{}
    $downloadManifest = New-Object System.Collections.Generic.List[object]

    if ($Script:SilentCheck.IsChecked) {
        $zip = Join-Path $TempDir 'SilentPatchBully.zip'
        $meta = Download-SilentPatch -DestinationZip $zip
        $Script:ResolvedDownloads['silentpatch'] = $zip
        $downloadManifest.Add($meta)
    }

    $mode = if ($Script:DownloadMode -eq 'auto') { 'auto' } else { 'slow' }
    $apiKey = ''
    if ($Script:EssentialCheck.IsChecked -or $Script:VisualCheck.IsChecked) {
        if ($mode -eq 'auto') {
            $apiKey = Get-NexusApiKey
            if ([string]::IsNullOrWhiteSpace($apiKey)) {
                Write-UiLog (L 'LOG_AUTO_NO_KEY_SWITCH')
                Set-DownloadMode -Mode 'slow'
                $mode = 'slow'
            } else {
                if ($Script:RememberKeyCheck.IsChecked) { Save-NexusApiKey $apiKey }
                Write-UiLog (L 'LOG_MODE_AUTO')
            }
        }
        if ($mode -eq 'slow') { Write-UiLog (L 'LOG_MODE_SLOW') }
    }

    if ($Script:EssentialCheck.IsChecked) {
        $mod = Get-NexusModConfig 'essential-fixes'
        $zip = Join-Path $TempDir 'EssentialFixes.zip'
        if ($mode -eq 'auto' -and $apiKey) { $meta = Resolve-NexusArchive -Mod $mod -ApiKey $apiKey -DestinationZip $zip }
        else { $meta = Resolve-NexusArchiveManual -Mod $mod -DestinationZip $zip }
        $Script:ResolvedDownloads['essential-fixes'] = $zip
        $downloadManifest.Add($meta)
        if ($Script:DownloadMode -eq 'slow') { $mode = 'slow'; $apiKey = '' }
    }

    if ($Script:VisualCheck.IsChecked) {
        $mod = Get-NexusModConfig 'one-percent-better'
        $zip = Join-Path $TempDir 'OnePercentBetterMain.zip'
        try {
            if ($mode -eq 'auto' -and $apiKey) { $meta = Resolve-NexusArchive -Mod $mod -ApiKey $apiKey -DestinationZip $zip }
            else { $meta = Resolve-NexusArchiveManual -Mod $mod -DestinationZip $zip }
            $Script:ResolvedDownloads['one-percent-better'] = $zip
            $downloadManifest.Add($meta)
        } catch {
            $visualDownloadError = $_.Exception.Message
            Write-UiLog (LF 'LOG_VISUAL_SKIPPED' @($visualDownloadError))
            $continueWithoutVisual = Show-LocalizedQuestion -Text (LF 'VISUAL_DOWNLOAD_FAIL_CONTINUE' @($visualDownloadError)) -Title (L 'VISUAL_FAIL_TITLE')
            if (-not $continueWithoutVisual) { throw }
        }
    }

    $manifestPath = Join-Path $SettingsDir 'last-download-manifest.json'
    $downloadManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Write-UiLog (L 'LOG_DOWNLOADS_COMPLETE')
}

function Ensure-BackupRoot([string]$GamePath) {
    $root = Join-Path $GamePath 'Bully Starter Kit Backups'
    [System.IO.Directory]::CreateDirectory($root) | Out-Null
    return $root
}

function Backup-FileIfExists {
    param(
        [string]$GamePath,
        [string]$DestinationFile,
        [string]$BackupFolder
    )
    $DestinationFile = Get-SafePathWithinRoot -Root $GamePath -Path $DestinationFile
    if (!(Test-Path $DestinationFile)) { return }
    $relative = $DestinationFile.Substring([System.IO.Path]::GetFullPath($GamePath).TrimEnd('\','/').Length).TrimStart('\','/')
    $backupDest = Join-Path $BackupFolder $relative
    $parent = Split-Path -Parent $backupDest
    if ($parent) { [System.IO.Directory]::CreateDirectory($parent) | Out-Null }
    Copy-Item -LiteralPath $DestinationFile -Destination $backupDest -Force
}

function Copy-FileSafe {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$GamePath,
        [string]$BackupFolder
    )
    $Destination = Get-SafePathWithinRoot -Root $GamePath -Path $Destination
    $parent = Split-Path -Parent $Destination
    if ($parent) { [System.IO.Directory]::CreateDirectory($parent) | Out-Null }
    $existed = Test-Path $Destination
    Backup-FileIfExists -GamePath $GamePath -DestinationFile $Destination -BackupFolder $BackupFolder
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    if (-not $existed) {
        $relativeNew = $Destination.Substring([System.IO.Path]::GetFullPath($GamePath).TrimEnd('\','/').Length).TrimStart('\','/')
        if (-not $Script:NewFiles.Contains($relativeNew)) { $Script:NewFiles.Add($relativeNew) }
    }
}

function Copy-TreeSafe {
    param(
        [string]$SourceDir,
        [string]$DestinationDir,
        [string]$GamePath,
        [string]$BackupFolder,
        [string[]]$ExcludeNames = @()
    )
    $sourceRoot = (Get-Item $SourceDir).FullName.TrimEnd('\')
    Get-ChildItem -LiteralPath $SourceDir -Recurse -File | ForEach-Object {
        if ($ExcludeNames -contains $_.Name) { return }
        $rel = $_.FullName.Substring($sourceRoot.Length).TrimStart('\')
        $dest = Join-Path $DestinationDir $rel
        Copy-FileSafe -Source $_.FullName -Destination $dest -GamePath $GamePath -BackupFolder $BackupFolder
    }
}

function Get-SafeZipRelativePath {
    param([string]$EntryName)

    if ([string]::IsNullOrWhiteSpace($EntryName)) { return $null }

    # ZIP uses forward slashes, but some archives contain backslashes too.
    # Never normalize a rooted path into a relative one: block it first.
    if ($EntryName -match '^[\\/]' -or $EntryName -match '^[A-Za-z]:') {
        throw (LF 'ERR_UNSAFE_ZIP' @($EntryName))
    }

    $normalized = $EntryName.Replace('\','/')
    $parts = @($normalized.Split('/') | Where-Object { $_ -ne '' -and $_ -ne '.' })
    if ($parts.Count -eq 0) { return $null }

    foreach ($part in $parts) {
        if ($part -eq '..') { throw (LF 'ERR_UNSAFE_ZIP' @($EntryName)) }

        # These names cannot be created safely on Windows. They are not a
        # traversal attempt, so skip only this entry instead of aborting the
        # whole mod installation. Required mod files are validated later.
        if ($part.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
            Write-UiLog (LF 'LOG_ZIP_ENTRY_SKIPPED' @($EntryName))
            return $null
        }
        if ($part.EndsWith(' ') -or $part.EndsWith('.')) {
            Write-UiLog (LF 'LOG_ZIP_ENTRY_SKIPPED' @($EntryName))
            return $null
        }
        if ($part -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$') {
            Write-UiLog (LF 'LOG_ZIP_ENTRY_SKIPPED' @($EntryName))
            return $null
        }
    }

    return ($parts -join [System.IO.Path]::DirectorySeparatorChar)
}

function Copy-ZipEntryToGameSafe {
    param(
        [System.IO.Compression.ZipArchiveEntry]$Entry,
        [string]$RelativeDestination,
        [string]$GamePath,
        [string]$BackupFolder
    )

    if (!$Entry -or [string]::IsNullOrEmpty($Entry.Name)) { return $false }
    $safeRelative = Get-SafeZipRelativePath -EntryName $RelativeDestination
    if ([string]::IsNullOrWhiteSpace($safeRelative)) { return $false }

    $destination = Get-SafePathWithinRoot -Root $GamePath -Path (Join-Path $GamePath $safeRelative)
    $parent = Split-Path -Parent $destination
    if ($parent) { [System.IO.Directory]::CreateDirectory($parent) | Out-Null }

    $existed = Test-Path -LiteralPath $destination
    Backup-FileIfExists -GamePath $GamePath -DestinationFile $destination -BackupFolder $BackupFolder

    $input = $Entry.Open()
    try {
        $output = [System.IO.File]::Open($destination, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try { $input.CopyTo($output) } finally { $output.Dispose() }
    } finally { $input.Dispose() }

    if (-not $existed) {
        $rootFull = [System.IO.Path]::GetFullPath($GamePath).TrimEnd('\','/')
        $relativeNew = $destination.Substring($rootFull.Length).TrimStart('\','/')
        if (-not $Script:NewFiles.Contains($relativeNew)) { $Script:NewFiles.Add($relativeNew) }
    }
    return $true
}

function Expand-ZipFresh {
    param([string]$ZipPath,[string]$Destination)
    if (Test-Path $Destination) { Remove-Item -LiteralPath $Destination -Recurse -Force }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    $destinationRoot = [System.IO.Path]::GetFullPath($Destination).TrimEnd('\','/') + [System.IO.Path]::DirectorySeparatorChar
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        foreach ($entry in $archive.Entries) {
            $relative = Get-SafeZipRelativePath -EntryName $entry.FullName
            if ([string]::IsNullOrWhiteSpace($relative)) { continue }

            try {
                $candidate = [System.IO.Path]::Combine($Destination, $relative)
                $target = [System.IO.Path]::GetFullPath($candidate)
            } catch [System.ArgumentException] {
                Write-UiLog (LF 'LOG_ZIP_ENTRY_SKIPPED' @($entry.FullName))
                continue
            } catch [System.NotSupportedException] {
                Write-UiLog (LF 'LOG_ZIP_ENTRY_SKIPPED' @($entry.FullName))
                continue
            } catch [System.IO.PathTooLongException] {
                Write-UiLog (LF 'LOG_ZIP_ENTRY_SKIPPED' @($entry.FullName))
                continue
            }

            if (!$target.StartsWith($destinationRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw (LF 'ERR_UNSAFE_ZIP' @($entry.FullName))
            }
            if ([string]::IsNullOrEmpty($entry.Name)) {
                [System.IO.Directory]::CreateDirectory($target) | Out-Null
                continue
            }
            $parent = Split-Path -Parent $target
            if ($parent) { [System.IO.Directory]::CreateDirectory($parent) | Out-Null }
            $input = $entry.Open()
            try {
                $output = [System.IO.File]::Open($target, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
                try { $input.CopyTo($output) } finally { $output.Dispose() }
            } finally { $input.Dispose() }
        }
    } finally { $archive.Dispose() }
}

function Install-SilentPatch {
    param([string]$GamePath,[string]$BackupFolder,[int]$FpsLimit,[string]$ZipPath,[string]$TempDir)
    $extract = Join-Path $TempDir 'silentpatch-extract'
    Expand-ZipFresh -ZipPath $ZipPath -Destination $extract

    $wanted = @('dinput8.dll','MiniDumper.asi','modupdater.asi','SilentPatchBully.asi','SilentPatchBully.ini')
    foreach ($name in $wanted) {
        $src = Get-ChildItem -Path $extract -Recurse -File | Where-Object { $_.Name -ieq $name } | Select-Object -First 1
        if ($src) {
            Copy-FileSafe -Source $src.FullName -Destination (Join-Path $GamePath $name) -GamePath $GamePath -BackupFolder $BackupFolder
        }
    }

    $requiredInstalled = @('dinput8.dll','SilentPatchBully.asi','SilentPatchBully.ini')
    $missingInstalled = @($requiredInstalled | Where-Object { !(Test-Path (Join-Path $GamePath $_)) })
    if ($missingInstalled.Count -gt 0) {
        throw (LF 'ERR_SP_FILES_MISSING' @(($missingInstalled -join ', ')))
    }

    $ini = Join-Path $GamePath 'SilentPatchBully.ini'
    if (Test-Path $ini) {
        $content = Get-Content -LiteralPath $ini -Raw
        if ($content -match '(?m)^\s*FPSLimit\s*=') {
            $content = [regex]::Replace($content, '(?m)^\s*FPSLimit\s*=.*$', "FPSLimit = $FpsLimit")
        } else {
            $content += "`r`nFPSLimit = $FpsLimit`r`n"
        }
        Set-Content -LiteralPath $ini -Value $content -Encoding ASCII
    }
    Write-UiLog (LF 'LOG_SP_INSTALLED' @($FpsLimit))
}

function Install-EssentialFixes {
    param([string]$GamePath,[string]$BackupFolder,[string]$ZipPath,[string]$TempDir)

    # Official install method (Nexus mod 396):
    #   Main/To Scripts/* -> <game>/Scripts/*
    #   Optional/*        -> <game>/*, excluding default.idb
    #
    # Archives uploaded by third parties may rename or wrap folders. Do not
    # depend on one literal "To Scripts" path. We first identify that folder by
    # a normalized segment name, then fall back to loose .lur files while
    # explicitly excluding Compiled / Source / Optional copies.
    if (!(Test-ZipArchive $ZipPath)) { throw (L 'ERR_TO_SCRIPTS') }

    $archive = $null
    $coreCount = 0
    $optionalCount = 0
    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)

        $coreEntries = New-Object System.Collections.Generic.List[object]
        $optionalEntries = New-Object System.Collections.Generic.List[object]
        $seenCore = @{}
        $seenOptional = @{}

        foreach ($entry in $archive.Entries) {
            if ([string]::IsNullOrEmpty($entry.Name)) { continue }

            $name = $entry.FullName.Replace('\','/')
            $parts = @($name -split '/' | Where-Object { $_ -ne '' -and $_ -ne '.' })
            if ($parts.Count -eq 0) { continue }

            $normalizedParts = @($parts | ForEach-Object {
                [regex]::Replace(([string]$_).ToLowerInvariant(), '[^a-z0-9]', '')
            })

            $coreIndex = -1
            $optionalIndex = -1
            for ($i = 0; $i -lt $normalizedParts.Count; $i++) {
                $segment = [string]$normalizedParts[$i]

                # Covers: "To Scripts", "To_Scripts", "To-Scripts",
                # "Main - To Scripts", and labels such as "To Scripts (Recommended)".
                if ($coreIndex -lt 0 -and $segment -match 'toscripts') {
                    $coreIndex = $i
                }
                if ($optionalIndex -lt 0 -and $segment -match '^optional') {
                    $optionalIndex = $i
                }
            }

            if ($coreIndex -ge 0 -and $coreIndex -lt ($parts.Count - 1)) {
                $relParts = @($parts[($coreIndex + 1)..($parts.Count - 1)])
                $rel = ($relParts -join '/')
                if (![string]::IsNullOrWhiteSpace($rel)) {
                    $key = $rel.ToLowerInvariant()
                    if (!$seenCore.ContainsKey($key)) {
                        $seenCore[$key] = $true
                        $coreEntries.Add([pscustomobject]@{ Entry = $entry; Relative = $rel })
                    }
                }
                continue
            }

            if ($optionalIndex -ge 0 -and $optionalIndex -lt ($parts.Count - 1)) {
                $relParts = @($parts[($optionalIndex + 1)..($parts.Count - 1)])
                $rel = ($relParts -join '/')
                if (![string]::IsNullOrWhiteSpace($rel) -and [System.IO.Path]::GetFileName($rel) -ine 'default.idb') {
                    $key = $rel.ToLowerInvariant()
                    if (!$seenOptional.ContainsKey($key)) {
                        $seenOptional[$key] = $true
                        $optionalEntries.Add([pscustomobject]@{ Entry = $entry; Relative = $rel })
                    }
                }
            }
        }

        # Some preserved/repacked releases do not keep the documented folder
        # label at all. In that case find the actual compiled native script
        # files. Never take copies from Main/Compiled or source trees, because
        # those belong to the alternative IMG-editing installation method.
        if ($coreEntries.Count -eq 0) {
            foreach ($entry in $archive.Entries) {
                if ([string]::IsNullOrEmpty($entry.Name)) { continue }
                if ([System.IO.Path]::GetExtension($entry.Name) -ine '.lur') { continue }

                $name = $entry.FullName.Replace('\','/')
                $parts = @($name -split '/' | Where-Object { $_ -ne '' -and $_ -ne '.' })
                $normalizedParts = @($parts | ForEach-Object {
                    [regex]::Replace(([string]$_).ToLowerInvariant(), '[^a-z0-9]', '')
                })

                $excluded = $false
                foreach ($segment in $normalizedParts) {
                    if ($segment -match '^(compiled|source|sources|optional|optionalfiles)$') {
                        $excluded = $true
                        break
                    }
                }
                if ($excluded) { continue }

                $rel = $entry.Name
                if ([string]::IsNullOrWhiteSpace($rel)) { continue }
                $key = $rel.ToLowerInvariant()
                if (!$seenCore.ContainsKey($key)) {
                    $seenCore[$key] = $true
                    $coreEntries.Add([pscustomobject]@{ Entry = $entry; Relative = $rel })
                }
            }

            if ($coreEntries.Count -gt 0) {
                Write-UiLog (LF 'LOG_EF_LAYOUT_FALLBACK' @($coreEntries.Count))
            }
        }

        if ($coreEntries.Count -eq 0) {
            $sample = @($archive.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) } | Select-Object -First 30 -ExpandProperty FullName)
            if ($sample.Count -gt 0) { Write-UiLog ('Essential Fixes archive sample: ' + ($sample -join ' | ')) }
            throw (L 'ERR_TO_SCRIPTS')
        }

        foreach ($item in $coreEntries) {
            $destRel = 'Scripts/' + $item.Relative
            if (Copy-ZipEntryToGameSafe -Entry $item.Entry -RelativeDestination $destRel -GamePath $GamePath -BackupFolder $BackupFolder) {
                $coreCount++
            }
        }

        if ($coreCount -eq 0) { throw (L 'ERR_TO_SCRIPTS') }

        foreach ($item in $optionalEntries) {
            if (Copy-ZipEntryToGameSafe -Entry $item.Entry -RelativeDestination $item.Relative -GamePath $GamePath -BackupFolder $BackupFolder) {
                $optionalCount++
            }
        }

        Write-UiLog (LF 'LOG_EF_INSTALLED_COUNTS' @($coreCount,$optionalCount))
    } finally {
        if ($archive) { $archive.Dispose() }
    }
}

function Install-OnePercentBetter {
    param([string]$GamePath,[string]$BackupFolder,[string]$ZipPath,[string]$TempDir)

    # The author's Main archive only needs one file: gsa_info.dat -> Graphics.
    # Do not send this tiny graphics mod through the generic ZIP extractor.
    # Reading the exact entry directly is simpler and avoids archive-layout/path quirks.
    if (!(Test-ZipArchive $ZipPath)) { throw (L 'ERR_GSA') }

    $archive = $null
    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
        $matches = @($archive.Entries | Where-Object {
            -not [string]::IsNullOrEmpty($_.Name) -and $_.Name -ieq 'gsa_info.dat'
        })
        if ($matches.Count -lt 1) { throw (L 'ERR_GSA') }

        # Prefer a shallow entry if an archive contains more than one copy.
        $entry = $matches | Sort-Object @{ Expression = { ($_.FullName -replace '\\','/').Split('/').Count } }, FullName | Select-Object -First 1
        if (!$entry -or $entry.Length -le 0) { throw (L 'ERR_GSA') }

        $tempGsa = Join-Path $TempDir 'OnePercentBetter.gsa_info.dat'
        $input = $entry.Open()
        try {
            $output = [System.IO.File]::Open($tempGsa, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            try { $input.CopyTo($output) } finally { $output.Dispose() }
        } finally { $input.Dispose() }

        if (!(Test-Path $tempGsa) -or (Get-Item -LiteralPath $tempGsa).Length -le 0) { throw (L 'ERR_GSA') }
        $dest = Join-Path $GamePath 'Graphics\gsa_info.dat'
        Copy-FileSafe -Source $tempGsa -Destination $dest -GamePath $GamePath -BackupFolder $BackupFolder
        Write-UiLog (L 'LOG_OPB_INSTALLED')
        return $true
    } finally {
        if ($archive) { $archive.Dispose() }
    }
}

function Write-TextFileSafe {
    param([string]$GamePath,[string]$Path,[string]$Text,[string]$BackupFolder,[System.Text.Encoding]$Encoding)
    if (!$Encoding) { $Encoding = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false }
    $Path = Get-SafePathWithinRoot -Root $GamePath -Path $Path
    $parent = Split-Path -Parent $Path
    if ($parent) { [System.IO.Directory]::CreateDirectory($parent) | Out-Null }
    $existed = Test-Path $Path
    Backup-FileIfExists -GamePath $GamePath -DestinationFile $Path -BackupFolder $BackupFolder
    [System.IO.File]::WriteAllText($Path, $Text, $Encoding)
    if (-not $existed) {
        $relativeNew = $Path.Substring([System.IO.Path]::GetFullPath($GamePath).TrimEnd('\','/').Length).TrimStart('\','/')
        if (-not $Script:NewFiles.Contains($relativeNew)) { $Script:NewFiles.Add($relativeNew) }
    }
}

function Restore-BackupFolder {
    param([string]$GamePath,[string]$BackupFolder)
    if (!(Test-Path $BackupFolder)) { return }
    $addedList = Join-Path $BackupFolder 'added-files.txt'
    if (Test-Path $addedList) {
        Get-Content -LiteralPath $addedList | Where-Object { $_ -and $_.Trim() } | ForEach-Object {
            $addedPath = Get-SafePathWithinRoot -Root $GamePath -Path (Join-Path $GamePath $_)
            if (Test-Path $addedPath -PathType Leaf) { Remove-Item -LiteralPath $addedPath -Force -ErrorAction SilentlyContinue }
        }
    }
    Get-ChildItem -LiteralPath $BackupFolder -Recurse -File | Where-Object { $_.Name -notin @('backup-info.txt','added-files.txt') } | ForEach-Object {
        $rel = $_.FullName.Substring($BackupFolder.Length).TrimStart('\')
        $dest = Get-SafePathWithinRoot -Root $GamePath -Path (Join-Path $GamePath $rel)
        New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
    }
}

function Enable-BullyRussianLanguage {
    param([string]$GamePath,[string]$BackupFolder)
    $vdf = Join-Path $GamePath '12200_install.vdf'
    if (!(Test-Path $vdf)) {
        Show-Info (L 'GAME_RUS_UNSUPPORTED') (L 'GAME_RUS_TITLE')
        return $false
    }
    $content = [System.IO.File]::ReadAllText($vdf)
    $pattern = '(?si)("english"\s*\{\s*"Language"\s*")([0-9]+)(")'
    $m = [regex]::Match($content, $pattern)
    if (!$m.Success) {
        Show-Warn (L 'GAME_RUS_PATTERN_FAIL') (L 'GAME_RUS_TITLE')
        return $false
    }
    if ($m.Groups[2].Value -eq '1049') {
        Write-UiLog (L 'LOG_RUS_ALREADY')
        Show-Info (L 'GAME_RUS_ALREADY') (L 'GAME_RUS_TITLE')
        return $true
    }
    $updated = [regex]::Replace($content, $pattern, '${1}1049${3}', 1)
    Write-TextFileSafe -GamePath $GamePath -Path $vdf -Text $updated -BackupFolder $BackupFolder -Encoding ([System.Text.Encoding]::ASCII)
    Write-UiLog (L 'LOG_RUS_ENABLED')
    Show-Info (L 'GAME_RUS_ENABLED') (L 'GAME_RUS_TITLE')
    return $true
}

function Ask-BullyRussianLanguage {
    param([string]$GamePath,[string]$BackupFolder)
    $answer = Show-LocalizedQuestion -Text (L 'GAME_RUS_PROMPT') -Title (L 'GAME_RUS_TITLE')
    if ($answer) { return (Enable-BullyRussianLanguage -GamePath $GamePath -BackupFolder $BackupFolder) }
    return $false
}


function Show-InstallComplete {
    param([string]$GamePath,[string]$InstalledText)
    $doneXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Bully Starter Kit" Height="430" Width="650" WindowStartupLocation="CenterOwner"
        ResizeMode="NoResize" Background="#0A0C10" Foreground="#F8F8F9" FontFamily="Segoe UI" ShowInTaskbar="False" TextOptions.TextFormattingMode="Display" TextOptions.TextRenderingMode="ClearType">
    <Window.Resources>
        <SolidColorBrush x:Key="Accent" Color="#F6C945"/>
        <Style TargetType="Button">
            <Setter Property="Padding" Value="18,11"/><Setter Property="Margin" Value="5"/>
            <Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Foreground" Value="#F7F7F8"/><Setter Property="Background" Value="#1B1F27"/>
            <Setter Property="BorderBrush" Value="#343A46"/><Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
                <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                    <ContentPresenter HorizontalAlignment="Center"/>
                </Border>
                <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#272C36"/></Trigger></ControlTemplate.Triggers>
            </ControlTemplate></Setter.Value></Setter>
        </Style>
    </Window.Resources>
    <Grid Margin="30">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
        <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Border Width="72" Height="72" CornerRadius="36" Background="#183120" BorderBrush="#2F6840" BorderThickness="1">
                <TextBlock Text="✓" Foreground="#7EE787" FontSize="36" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <StackPanel Grid.Column="1" Margin="18,6,0,0">
                <TextBlock Text="{{COMPLETE_TITLE}}" FontSize="26" FontWeight="Bold"/>
                <TextBlock Text="{{COMPLETE_SUBTITLE}}" Foreground="#9BA2AE" FontSize="13" Margin="0,5,0,0"/>
            </StackPanel>
        </Grid>
        <Border Grid.Row="1" Margin="0,22,0,14" Padding="16" Background="#11151B" BorderBrush="#2A303A" BorderThickness="1" CornerRadius="12">
            <StackPanel><TextBlock Text="{{COMPLETE_INSTALLED}}" Foreground="#F6C945" FontWeight="Bold" FontSize="11"/><TextBlock x:Name="InstalledText" Margin="0,7,0,0" TextWrapping="Wrap" FontSize="14"/></StackPanel>
        </Border>
        <TextBlock Grid.Row="2" Text="{{COMPLETE_BODY}}" Foreground="#A7ADB7" TextWrapping="Wrap" LineHeight="20"/>
        <Grid Grid.Row="3" Margin="0,20,0,0">
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <TextBlock VerticalAlignment="Center" Foreground="#676E79" FontSize="11" Text="Bully Starter Kit • v0.4.0"/>
            <Button x:Name="CloseDone" Grid.Column="1" Content="{{COMPLETE_CLOSE}}" MinWidth="120"/>
            <Button x:Name="LaunchDone" Grid.Column="2" Content="{{COMPLETE_LAUNCH}}" MinWidth="155" Background="#F6C945" Foreground="#151515" BorderBrush="#F6C945" FontWeight="Bold"/>
        </Grid>
    </Grid>
</Window>
'@
    $doneXaml = Expand-LocTemplate $doneXaml
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$doneXaml)
    $done = [Windows.Markup.XamlReader]::Load($reader)
    if ($Script:Window) { $done.Owner = $Script:Window }
    $iconPath = Join-Path $RepoRoot 'assets\bully-starter-kit.ico'
    if (Test-Path $iconPath) { try { $done.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([Uri]$iconPath) } catch {} }
    $done.FindName('InstalledText').Text = $InstalledText
    $done.FindName('CloseDone').Add_Click({ $done.Close() })
    $done.FindName('LaunchDone').Add_Click({
        $exe = Join-Path $GamePath 'Bully.exe'
        if (Test-Path $exe) { try { Start-Process -FilePath $exe -WorkingDirectory $GamePath; $done.Close() } catch { Show-Warn $_.Exception.Message } }
        else { Show-Warn (L 'WARN_CHOOSE_GAME') }
    })
    [void]$done.ShowDialog()
}

function Install-Pack {
    $gamePath = $Script:GamePathBox.Text.Trim()
    if (!(Test-BullyPath $gamePath)) {
        Show-Warn (L 'WARN_CHOOSE_GAME')
        return
    }

    $fps = 60
    if (![int]::TryParse($Script:FpsBox.Text, [ref]$fps) -or $fps -lt 30 -or $fps -gt 60) {
        Show-Warn (L 'WARN_FPS')
        return
    }

    $backupRoot = Ensure-BackupRoot $gamePath
    $backupFolder = Join-Path $backupRoot (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')
    New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $backupFolder 'backup-info.txt') -Value "Bully Starter Kit $PackVersion`r`nCreated: $(Get-Date -Format o)`r`nGame: $gamePath" -Encoding UTF8

    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ('BullyStarterKit_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        if ($Script:InstallButton) { $Script:InstallButton.IsEnabled = $false }
        $Script:NewFiles.Clear()
        $Script:InstallProgress.Value = 10
        $Script:DownloadStatus.Text = L 'DOWNLOADING'
        $Script:DownloadStatus.Foreground = '#F6C945'
        Write-UiLog '---------------------------------------------'
        Write-UiLog (LF 'LOG_SETUP_START' @($backupFolder))
        Download-SelectedMods -TempDir $tempDir

        $Script:InstallProgress.Value = 55
        $Script:DownloadStatus.Text = L 'INSTALLING'
        if ($Script:SilentCheck.IsChecked) {
            Install-SilentPatch -GamePath $gamePath -BackupFolder $backupFolder -FpsLimit $fps -ZipPath $Script:ResolvedDownloads['silentpatch'] -TempDir $tempDir
        }
        if ($Script:EssentialCheck.IsChecked) {
            Install-EssentialFixes -GamePath $gamePath -BackupFolder $backupFolder -ZipPath $Script:ResolvedDownloads['essential-fixes'] -TempDir $tempDir
        }
        $visualInstalled = $false
        if ($Script:VisualCheck.IsChecked -and $Script:ResolvedDownloads.ContainsKey('one-percent-better')) {
            try {
                $visualInstalled = [bool](Install-OnePercentBetter -GamePath $gamePath -BackupFolder $backupFolder -ZipPath $Script:ResolvedDownloads['one-percent-better'] -TempDir $tempDir)
            } catch {
                $visualError = $_.Exception.Message
                Write-UiLog (LF 'LOG_VISUAL_SKIPPED' @($visualError))
                $continueWithoutVisual = Show-LocalizedQuestion -Text (LF 'VISUAL_FAIL_CONTINUE' @($visualError)) -Title (L 'VISUAL_FAIL_TITLE')
                if (-not $continueWithoutVisual) { throw }
                $visualInstalled = $false
            }
        }

        $russianEnabled = Ask-BullyRussianLanguage -GamePath $gamePath -BackupFolder $backupFolder

        $manifest = [ordered]@{
            installerVersion = $PackVersion
            installedAt = (Get-Date).ToString('o')
            gamePath = $gamePath
            gameExeVersion = (Get-BullyVersionText $gamePath)
            fpsLimit = $fps
            silentPatch = [bool]$Script:SilentCheck.IsChecked
            essentialFixes = [bool]$Script:EssentialCheck.IsChecked
            onePercentBetter = [bool]$visualInstalled
            russianLanguage = [bool]$russianEnabled
            uiLanguage = $Script:UiLanguage
            downloadMode = $Script:DownloadMode
            backup = $backupFolder
            sources = @(
                if ($Script:SilentCheck.IsChecked) { 'https://github.com/CookiePLMonster/SilentPatchBully' }
                if ($Script:EssentialCheck.IsChecked) { 'https://www.nexusmods.com/bullyscholarshipedition/mods/396' }
                if ($visualInstalled) { 'https://www.nexusmods.com/bullyscholarshipedition/mods/148' }
            )
        } | ConvertTo-Json -Depth 6
        Write-TextFileSafe -GamePath $gamePath -Path (Join-Path $gamePath 'BullyStarterKit.install.json') -Text $manifest -BackupFolder $backupFolder -Encoding (New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false)
        if ($Script:NewFiles.Count -gt 0) {
            Set-Content -LiteralPath (Join-Path $backupFolder 'added-files.txt') -Value ($Script:NewFiles -join "`r`n") -Encoding UTF8
        }

        $Script:InstallProgress.Value = 100
        $Script:DownloadStatus.Text = L 'DONE_STATUS'
        $Script:DownloadStatus.Foreground = '#7EE787'
        Write-UiLog (LF 'LOG_TRACKED_FILES' @($Script:NewFiles.Count))
        Write-UiLog (L 'LOG_DONE')
        $installedNames = New-Object System.Collections.Generic.List[string]
        if ($Script:SilentCheck.IsChecked) { $installedNames.Add((L 'SILENT_NAME')) }
        if ($Script:EssentialCheck.IsChecked) { $installedNames.Add((L 'ESSENTIAL_NAME')) }
        if ($visualInstalled) { $installedNames.Add((L 'VISUAL_NAME')) }
        if ($russianEnabled) { $installedNames.Add((L 'GAME_RUS_COMPONENT')) }
        if ($installedNames.Count -eq 0) { $installedNames.Add((L 'NO_COMPONENTS')) }
        Show-InstallComplete -GamePath $gamePath -InstalledText ($installedNames -join ', ')
    } catch {
        $installError = $_.Exception.Message
        $Script:InstallProgress.Value = 0
        $Script:DownloadStatus.Text = L 'FAILED_STATUS'
        $Script:DownloadStatus.Foreground = '#FF7B72'
        Write-UiLog (LF 'LOG_ERROR' @($installError))
        try {
            if ($Script:NewFiles.Count -gt 0) {
                Set-Content -LiteralPath (Join-Path $backupFolder 'added-files.txt') -Value ($Script:NewFiles -join "`r`n") -Encoding UTF8
            }
            Restore-BackupFolder -GamePath $gamePath -BackupFolder $backupFolder
            Write-UiLog (L 'LOG_ROLLBACK_DONE')
        } catch {
            Write-UiLog (LF 'LOG_ROLLBACK_WARN' @($_.Exception.Message))
        }
        Show-Warn (LF 'INSTALL_FAILED' @($installError, $backupFolder))
    } finally {
        if ($Script:InstallButton) { $Script:InstallButton.IsEnabled = $true }
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Restore-LatestBackup {
    $gamePath = $Script:GamePathBox.Text.Trim()
    if (!(Test-BullyPath $gamePath)) { Show-Warn (L 'WARN_CHOOSE_GAME'); return }
    $root = Join-Path $gamePath 'Bully Starter Kit Backups'
    if (!(Test-Path $root)) { Show-Warn (L 'NO_BACKUPS'); return }
    $latest = Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if (!$latest) { Show-Warn (L 'NO_BACKUPS'); return }

    $result = Show-LocalizedQuestion -Text (LF 'RESTORE_ASK' @($latest.FullName)) -Title (L 'RESTORE_TITLE')
    if (-not $result) { return }

    Restore-BackupFolder -GamePath $gamePath -BackupFolder $latest.FullName
    Write-UiLog (LF 'LOG_RESTORED' @($latest.Name))
    Show-Info (L 'RESTORE_DONE')
}

function Open-Credits {
    $aboutXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="{{ABOUT_TITLE}}" Height="575" Width="680" WindowStartupLocation="CenterOwner"
        Background="#090A0D" Foreground="#F7F7F8" FontFamily="Segoe UI" ResizeMode="NoResize" TextOptions.TextFormattingMode="Display" TextOptions.TextRenderingMode="ClearType">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#1D2027"/><Setter Property="Foreground" Value="#F7F7F8"/>
            <Setter Property="BorderBrush" Value="#343946"/><Setter Property="Padding" Value="13,8"/>
            <Setter Property="Margin" Value="3"/><Setter Property="Cursor" Value="Hand"/><Setter Property="FontWeight" Value="SemiBold"/>
        </Style>
    </Window.Resources>
    <Grid Margin="24">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
        <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Border Width="58" Height="58" CornerRadius="15" Background="#F6C945" Margin="0,0,14,0">
                <TextBlock Text="B" Foreground="#151515" FontSize="34" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                <TextBlock Text="BULLY STARTER KIT" FontSize="24" FontWeight="Bold"/>
                <TextBlock x:Name="AboutSubtitleText" Text="{{ABOUT_SUBTITLE}}" Foreground="#969CA8"/>
            </StackPanel>
        </Grid>
        <Border Grid.Row="1" Background="#121419" BorderBrush="#2A2E37" BorderThickness="1" CornerRadius="12" Padding="16" Margin="0,20,0,12">
            <TextBlock Text="{{ABOUT_BODY}}" TextWrapping="Wrap" Foreground="#C5C8CE" LineHeight="21"/>
        </Border>
        <StackPanel Grid.Row="2">
            <TextBlock Text="{{THIRD_PARTY_CREDITS}}" FontSize="11" FontWeight="Bold" Foreground="#F6C945" Margin="2,2,0,8"/>
            <Border Background="#121419" BorderBrush="#2A2E37" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,8">
                <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><StackPanel><TextBlock Text="SilentPatch for Bully" FontWeight="Bold"/><TextBlock Text="{{SILENT_CREDIT}}" Foreground="#969CA8" FontSize="12"/></StackPanel><Button x:Name="SilentSource" Grid.Column="1" Content="{{OFFICIAL_SOURCE}}"/></Grid>
            </Border>
            <Border Background="#121419" BorderBrush="#2A2E37" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,8">
                <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><StackPanel><TextBlock Text="Essential Fixes &amp; Improvements" FontWeight="Bold"/><TextBlock Text="{{ESSENTIAL_CREDIT}}" Foreground="#969CA8" FontSize="12"/></StackPanel><Button x:Name="EssentialSource" Grid.Column="1" Content="{{NEXUS_PAGE}}"/></Grid>
            </Border>
            <Border Background="#121419" BorderBrush="#2A2E37" BorderThickness="1" CornerRadius="10" Padding="14">
                <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><StackPanel><TextBlock Text="One Percent Better Project" FontWeight="Bold"/><TextBlock Text="{{VISUAL_CREDIT}}" Foreground="#969CA8" FontSize="12"/></StackPanel><Button x:Name="VisualSource" Grid.Column="1" Content="{{NEXUS_PAGE}}"/></Grid>
            </Border>
        </StackPanel>
        <Grid Grid.Row="3" Margin="0,18,0,0"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><TextBlock Text="{{LICENSE_NOTE}}" Foreground="#6F7682" VerticalAlignment="Center"/><Button x:Name="CreditsFile" Grid.Column="1" Content="{{FULL_CREDITS}}"/><Button x:Name="CloseAbout" Grid.Column="2" Content="{{CLOSE}}" Background="#F6C945" Foreground="#151515" BorderBrush="#F6C945"/></Grid>
    </Grid>
</Window>
'@
    $aboutXaml = Expand-LocTemplate $aboutXaml
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$aboutXaml)
    $about = [Windows.Markup.XamlReader]::Load($reader)
    if ($Script:Window) { $about.Owner = $Script:Window }
    $iconPath = Join-Path $RepoRoot 'assets\bully-starter-kit.ico'
    if (Test-Path $iconPath) { try { $about.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([Uri]$iconPath) } catch {} }
    $about.FindName('AboutSubtitleText').Text = (L 'ABOUT_SUBTITLE') + ' • v' + $PackVersion
    $about.FindName('SilentSource').Add_Click({ Start-Process 'https://github.com/CookiePLMonster/SilentPatchBully' })
    $about.FindName('EssentialSource').Add_Click({ Start-Process 'https://www.nexusmods.com/bullyscholarshipedition/mods/396' })
    $about.FindName('VisualSource').Add_Click({ Start-Process 'https://www.nexusmods.com/bullyscholarshipedition/mods/148' })
    $about.FindName('CreditsFile').Add_Click({ Start-Process (Join-Path $RepoRoot 'THIRD_PARTY.md') })
    $about.FindName('CloseAbout').Add_Click({ $about.Close() })
    $about.ShowDialog() | Out-Null
}


function New-UiDoubleAnimation {
    param([double]$From,[double]$To,[int]$Milliseconds = 180)
    $animation = New-Object System.Windows.Media.Animation.DoubleAnimation
    $animation.From = $From
    $animation.To = $To
    $animation.Duration = New-Object System.Windows.Duration -ArgumentList ([TimeSpan]::FromMilliseconds($Milliseconds))
    $ease = New-Object System.Windows.Media.Animation.CubicEase
    $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
    $animation.EasingFunction = $ease
    return $animation
}

function Set-DownloadMode {
    param([ValidateSet('auto','slow')][string]$Mode,[switch]$NoAnimation)
    $Script:DownloadMode = $Mode
    if (-not $Script:ModeSlider -or -not $Script:AutoModePanel -or -not $Script:SlowModePanel) { return }

    $isAuto = $Mode -eq 'auto'
    $targetX = if ($isAuto) { 0.0 } else { 168.0 }
    $autoOpacity = if ($isAuto) { 1.0 } else { 0.0 }
    $slowOpacity = if ($isAuto) { 0.0 } else { 1.0 }
    $transform = $Script:ModeSlider.RenderTransform
    if (-not ($transform -is [System.Windows.Media.TranslateTransform])) {
        $transform = New-Object System.Windows.Media.TranslateTransform
        $Script:ModeSlider.RenderTransform = $transform
    }

    if ($NoAnimation) {
        $transform.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, $null)
        $Script:AutoModePanel.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
        $Script:SlowModePanel.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
        $transform.X = $targetX
        $Script:AutoModePanel.Opacity = $autoOpacity
        $Script:SlowModePanel.Opacity = $slowOpacity
    } else {
        $transform.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, (New-UiDoubleAnimation -From $transform.X -To $targetX -Milliseconds 190))
        $Script:AutoModePanel.BeginAnimation([System.Windows.UIElement]::OpacityProperty, (New-UiDoubleAnimation -From $Script:AutoModePanel.Opacity -To $autoOpacity -Milliseconds 150))
        $Script:SlowModePanel.BeginAnimation([System.Windows.UIElement]::OpacityProperty, (New-UiDoubleAnimation -From $Script:SlowModePanel.Opacity -To $slowOpacity -Milliseconds 150))
    }

    $Script:AutoModePanel.IsHitTestVisible = $isAuto
    $Script:SlowModePanel.IsHitTestVisible = -not $isAuto
    $Script:AutoModeButton.Foreground = if ($isAuto) { '#111318' } else { '#AEB5C0' }
    $Script:SlowModeButton.Foreground = if ($isAuto) { '#AEB5C0' } else { '#111318' }
    if ($Script:DownloadStatus) {
        if ($isAuto) { $Script:DownloadStatus.Text = L 'DOWNLOAD_STATUS_AUTO'; $Script:DownloadStatus.Foreground = '#F6C945' }
        else { $Script:DownloadStatus.Text = L 'DOWNLOAD_STATUS_SLOW'; $Script:DownloadStatus.Foreground = '#8CE6A6' }
    }
}


$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Bully Starter Kit" Height="850" Width="1180" MinHeight="760" MinWidth="1040"
        WindowStartupLocation="CenterScreen" Background="#080A0E" Foreground="#F7F8FA"
        FontFamily="Segoe UI" ResizeMode="CanResize" UseLayoutRounding="True" SnapsToDevicePixels="True" TextOptions.TextFormattingMode="Display" TextOptions.TextRenderingMode="ClearType">
    <Window.Resources>
        <SolidColorBrush x:Key="Accent" Color="#F6C945"/>
        <SolidColorBrush x:Key="AccentSoft" Color="#2A2410"/>
        <SolidColorBrush x:Key="Surface" Color="#101319"/>
        <SolidColorBrush x:Key="Surface2" Color="#151922"/>
        <SolidColorBrush x:Key="Surface3" Color="#0D1015"/>
        <SolidColorBrush x:Key="Border" Color="#292F3A"/>
        <SolidColorBrush x:Key="Muted" Color="#99A1AE"/>
        <SolidColorBrush x:Key="Green" Color="#7EE787"/>
        <SolidColorBrush x:Key="Red" Color="#FF8383"/>
        <Style x:Key="Card" TargetType="Border">
            <Setter Property="Background" Value="{StaticResource Surface}"/><Setter Property="BorderBrush" Value="{StaticResource Border}"/>
            <Setter Property="BorderThickness" Value="1"/><Setter Property="CornerRadius" Value="16"/><Setter Property="Padding" Value="18"/>
        </Style>
        <Style x:Key="MiniCard" TargetType="Border">
            <Setter Property="Background" Value="{StaticResource Surface2}"/><Setter Property="BorderBrush" Value="#303744"/>
            <Setter Property="BorderThickness" Value="1"/><Setter Property="CornerRadius" Value="12"/><Setter Property="Padding" Value="14"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#191D25"/><Setter Property="Foreground" Value="#F7F8FA"/><Setter Property="BorderBrush" Value="#343B48"/>
            <Setter Property="BorderThickness" Value="1"/><Setter Property="Padding" Value="16,10"/><Setter Property="Margin" Value="4"/>
            <Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
                <Border x:Name="ButtonBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <ControlTemplate.Triggers>
                    <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ButtonBorder" Property="Background" Value="#252B35"/><Setter TargetName="ButtonBorder" Property="BorderBrush" Value="#4A5363"/></Trigger>
                    <Trigger Property="IsPressed" Value="True"><Setter TargetName="ButtonBorder" Property="Opacity" Value="0.78"/></Trigger>
                    <Trigger Property="IsEnabled" Value="False"><Setter TargetName="ButtonBorder" Property="Opacity" Value="0.42"/></Trigger>
                </ControlTemplate.Triggers>
            </ControlTemplate></Setter.Value></Setter>
        </Style>
        <Style x:Key="PrimaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{StaticResource Accent}"/><Setter Property="Foreground" Value="#111318"/><Setter Property="BorderBrush" Value="#F6C945"/>
            <Setter Property="FontWeight" Value="Bold"/>
        </Style>
        <Style x:Key="SegmentButton" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="0"/>
            <Setter Property="Margin" Value="0"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="10"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="Transparent" CornerRadius="10"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter Property="Opacity" Value="0.82"/></Trigger>
                            <Trigger Property="IsPressed" Value="True"><Setter Property="Opacity" Value="0.64"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="TextBox"><Setter Property="Background" Value="#090C11"/><Setter Property="Foreground" Value="#F7F8FA"/><Setter Property="BorderBrush" Value="#333B48"/><Setter Property="BorderThickness" Value="1"/><Setter Property="Padding" Value="11,8"/><Setter Property="CaretBrush" Value="{StaticResource Accent}"/></Style>
        <Style TargetType="PasswordBox"><Setter Property="Background" Value="#090C11"/><Setter Property="Foreground" Value="#F7F8FA"/><Setter Property="BorderBrush" Value="#333B48"/><Setter Property="BorderThickness" Value="1"/><Setter Property="Padding" Value="11,8"/><Setter Property="CaretBrush" Value="{StaticResource Accent}"/></Style>
        <Style TargetType="CheckBox"><Setter Property="Foreground" Value="#F7F8FA"/><Setter Property="FontSize" Value="14"/><Setter Property="Margin" Value="0,5"/></Style>
        <Style TargetType="Expander"><Setter Property="Foreground" Value="#D8DBE0"/></Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>

        <Border Grid.Row="0" Padding="26,20" BorderBrush="#262C35" BorderThickness="0,0,0,1">
            <Border.Background>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="#241B08" Offset="0"/><GradientStop Color="#11151C" Offset="0.43"/><GradientStop Color="#090B0F" Offset="1"/></LinearGradientBrush>
            </Border.Background>
            <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <Border Width="64" Height="64" CornerRadius="17" Background="{StaticResource Accent}" Margin="0,0,16,0">
                    <Grid><TextBlock Text="B" Foreground="#151515" FontSize="36" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="0,-3,0,0"/></Grid>
                </Border>
                <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <StackPanel Orientation="Horizontal"><TextBlock Text="BULLY STARTER KIT" FontSize="27" FontWeight="Bold"/><Border Background="#173421" BorderBrush="#2E7044" BorderThickness="1" CornerRadius="99" Padding="9,3" Margin="12,3,0,0"><TextBlock Text="{{STABLE_BADGE}}" Foreground="#8CF0A5" FontSize="10" FontWeight="Bold"/></Border></StackPanel>
                    <TextBlock Text="{{APP_TAGLINE}}" FontSize="13" Foreground="{StaticResource Muted}" Margin="0,4,0,0"/>
                </StackPanel>
                <StackPanel Grid.Column="2" HorizontalAlignment="Right" VerticalAlignment="Center">
                    <Button x:Name="LanguageButton" Content="{{LANG_SWITCH}}" ToolTip="{{LANG_SWITCH_HINT}}" HorizontalAlignment="Right" MinWidth="54" Padding="10,5" Margin="0,0,0,7"/>
                    <Border Background="#29220D" BorderBrush="#66541E" BorderThickness="1" CornerRadius="99" Padding="12,5" HorizontalAlignment="Right"><TextBlock x:Name="VersionBadge" Text="VANILLA+" Foreground="{StaticResource Accent}" FontWeight="Bold" FontSize="11"/></Border>
                    <TextBlock Text="{{WINDOWS_LABEL}}" Foreground="#777F8B" FontSize="10" HorizontalAlignment="Right" Margin="0,6,2,0"/>
                </StackPanel>
            </Grid>
        </Border>

        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
            <Grid Margin="24,22,24,26">
                <Grid.ColumnDefinitions><ColumnDefinition Width="1.55*"/><ColumnDefinition Width="1*"/></Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" Margin="0,0,12,0">
                    <Border Style="{StaticResource Card}" Margin="0,0,0,14">
                        <StackPanel>
                            <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border Width="34" Height="34" CornerRadius="17" Background="{StaticResource Accent}" Margin="0,0,12,0"><TextBlock Text="1" Foreground="#151515" FontWeight="Bold" FontSize="15" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                                <StackPanel Grid.Column="1"><TextBlock Text="{{STEP1_TITLE}}" FontSize="18" FontWeight="Bold"/><TextBlock Text="{{STEP1_DESC}}" Foreground="{StaticResource Muted}" FontSize="11" Margin="0,2,0,0"/></StackPanel>
                            </Grid>
                            <Grid Margin="0,15,0,0"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <TextBox x:Name="GamePath" Height="40" VerticalContentAlignment="Center" FontSize="12"/>
                                <Button x:Name="BrowseGame" Grid.Column="1" Content="{{BROWSE}}" MinWidth="122" Height="40" Margin="10,0,0,0"/>
                            </Grid>
                        </StackPanel>
                    </Border>

                    <Border Style="{StaticResource Card}" Margin="0,0,0,14">
                        <StackPanel>
                            <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border Width="34" Height="34" CornerRadius="17" Background="{StaticResource Accent}" Margin="0,0,12,0"><TextBlock Text="2" Foreground="#151515" FontWeight="Bold" FontSize="15" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                                <StackPanel Grid.Column="1"><TextBlock Text="{{STEP2_TITLE}}" FontSize="18" FontWeight="Bold"/><TextBlock Text="{{STEP2_DESC}}" Foreground="{StaticResource Muted}" FontSize="11" Margin="0,2,0,0"/></StackPanel>
                            </Grid>
                            <Grid Margin="0,15,0,0"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border Style="{StaticResource MiniCard}" Margin="0,0,6,7"><StackPanel><Border Background="#172A1E" CornerRadius="99" Padding="8,3" HorizontalAlignment="Left"><TextBlock Text="{{CORE}}" Foreground="#8CE6A6" FontSize="9" FontWeight="Bold"/></Border><CheckBox x:Name="SilentCheck" IsChecked="True" Content="{{SILENT_NAME}}" FontWeight="Bold" Margin="0,9,0,2"/><TextBlock Text="{{SILENT_DESC}}" Foreground="{StaticResource Muted}" TextWrapping="Wrap" FontSize="10"/><TextBlock Text="CookiePLMonster" Foreground="#69717E" FontSize="9" Margin="0,7,0,0"/></StackPanel></Border>
                                <Border Grid.Column="1" Style="{StaticResource MiniCard}" Margin="6,0,0,7"><StackPanel><Border Background="#172A1E" CornerRadius="99" Padding="8,3" HorizontalAlignment="Left"><TextBlock Text="{{CORE}}" Foreground="#8CE6A6" FontSize="9" FontWeight="Bold"/></Border><CheckBox x:Name="EssentialCheck" IsChecked="True" Content="{{ESSENTIAL_NAME}}" FontWeight="Bold" Margin="0,9,0,2"/><TextBlock Text="{{ESSENTIAL_DESC}}" Foreground="{StaticResource Muted}" TextWrapping="Wrap" FontSize="10"/><TextBlock Text="Razc01na" Foreground="#69717E" FontSize="9" Margin="0,7,0,0"/></StackPanel></Border>
                                <Border Grid.Row="1" Style="{StaticResource MiniCard}" Margin="0,6,6,0"><StackPanel><Border Background="#2B2513" CornerRadius="99" Padding="8,3" HorizontalAlignment="Left"><TextBlock Text="{{VISUAL}}" Foreground="#F6D56D" FontSize="9" FontWeight="Bold"/></Border><CheckBox x:Name="VisualCheck" IsChecked="True" Content="{{VISUAL_NAME}}" FontWeight="Bold" Margin="0,9,0,2"/><TextBlock Text="{{VISUAL_DESC}}" Foreground="{StaticResource Muted}" TextWrapping="Wrap" FontSize="10"/><TextBlock Text="SimonBestia" Foreground="#69717E" FontSize="9" Margin="0,7,0,0"/></StackPanel></Border>
                                <Border Grid.Row="1" Grid.Column="1" Style="{StaticResource MiniCard}" Margin="6,6,0,0"><StackPanel><TextBlock Text="{{FPS_LIMIT}}" FontSize="9" FontWeight="Bold" Foreground="#7D8490"/><Grid Margin="0,9,0,0"><Grid.ColumnDefinitions><ColumnDefinition Width="105"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><TextBox x:Name="FpsBox" Text="60" Height="44" FontSize="20" FontWeight="Bold" TextAlignment="Center" VerticalContentAlignment="Center"/><StackPanel Grid.Column="1" Margin="12,2,0,0"><TextBlock Text="{{FPS_RECOMMENDED}}" Foreground="{StaticResource Accent}" FontSize="11" FontWeight="SemiBold"/><TextBlock Text="30–60 FPS" Foreground="#727A87" FontSize="10" Margin="0,4,0,0"/></StackPanel></Grid></StackPanel></Border>
                            </Grid>
                        </StackPanel>
                    </Border>

                    <Expander IsExpanded="False" Margin="0,0,0,10">
                        <Expander.Header><TextBlock Text="{{INSTALL_LOG}}" FontWeight="SemiBold" Foreground="#B9BEC7"/></Expander.Header>
                        <Border Background="#05070A" BorderBrush="#262D37" BorderThickness="1" CornerRadius="12" Padding="10" Margin="0,8,0,0" Height="180"><TextBox x:Name="LogBox" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" BorderThickness="0" Background="Transparent" FontFamily="Consolas" FontSize="10"/></Border>
                    </Expander>
                </StackPanel>

                <StackPanel Grid.Column="1" Margin="12,0,0,0">
                    <Border Style="{StaticResource Card}" Margin="0,0,0,14">
                        <StackPanel>
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border Width="34" Height="34" CornerRadius="17" Background="{StaticResource Accent}" Margin="0,0,12,0">
                                    <TextBlock Text="3" Foreground="#151515" FontWeight="Bold" FontSize="15" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <StackPanel Grid.Column="1">
                                    <TextBlock Text="{{STEP3_TITLE}}" FontSize="18" FontWeight="Bold"/>
                                    <TextBlock Text="{{STEP3_DESC}}" Foreground="{StaticResource Muted}" FontSize="11" TextWrapping="Wrap" Margin="0,2,0,0"/>
                                </StackPanel>
                            </Grid>

                            <TextBlock Text="{{DOWNLOAD_MODE_TITLE}}" FontSize="10" FontWeight="Bold" Foreground="#7D8490" Margin="0,16,0,7"/>

                            <Grid Width="340" Height="44" HorizontalAlignment="Left">
                                <Border Background="#090C11" BorderBrush="#343B48" BorderThickness="1" CornerRadius="12"/>
                                <Border x:Name="ModeSlider" Width="168" Height="40" HorizontalAlignment="Left" VerticalAlignment="Center"
                                        Background="{StaticResource Accent}" CornerRadius="10" Margin="2,0,0,0">
                                    <Border.RenderTransform><TranslateTransform X="0"/></Border.RenderTransform>
                                </Border>
                                <Grid Margin="2">
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="168"/><ColumnDefinition Width="168"/></Grid.ColumnDefinitions>
                                    <Button x:Name="AutoModeButton" Grid.Column="0" Content="{{DOWNLOAD_MODE_AUTO}}" Style="{StaticResource SegmentButton}" Foreground="#111318"/>
                                    <Button x:Name="SlowModeButton" Grid.Column="1" Content="{{DOWNLOAD_MODE_SLOW}}" Style="{StaticResource SegmentButton}" Foreground="#AEB5C0"/>
                                </Grid>
                            </Grid>

                            <Grid Height="230" Margin="0,12,0,0">
                                <Border x:Name="AutoModePanel" Background="#19160B" BorderBrush="#66541E" BorderThickness="1" CornerRadius="12" Padding="13" Opacity="1">
                                    <StackPanel>
                                        <Grid>
                                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                            <StackPanel>
                                                <TextBlock Text="{{DOWNLOAD_AUTO_TITLE}}" Foreground="#F6D56D" FontWeight="Bold" FontSize="12"/>
                                                <TextBlock Text="{{DOWNLOAD_AUTO_DESC}}" Foreground="#B8B09A" TextWrapping="Wrap" FontSize="10" Margin="0,4,10,0"/>
                                            </StackPanel>
                                            <Border Grid.Column="1" Background="#30270C" BorderBrush="#6A581B" BorderThickness="1" CornerRadius="99" Padding="8,3" VerticalAlignment="Top">
                                                <TextBlock Text="API + PREMIUM" Foreground="#F6D56D" FontSize="10" FontWeight="Bold"/>
                                            </Border>
                                        </Grid>
                                        <TextBlock Text="{{NEXUS_API_KEY}}" FontSize="10" FontWeight="Bold" Foreground="#8C8270" Margin="0,12,0,5"/>
                                        <PasswordBox x:Name="NexusKey" Height="38"/>
                                        <CheckBox x:Name="RememberKey" IsChecked="True" Content="{{REMEMBER_KEY}}" FontSize="10" Margin="0,6,0,2"/>
                                        <Border Background="#111319" BorderBrush="#343B48" BorderThickness="1" CornerRadius="8" Padding="9,7" Margin="0,3,0,4">
                                            <TextBlock x:Name="NexusStatus" Text="{{NOT_CONNECTED}}" Foreground="#F6C945" FontSize="10" FontWeight="SemiBold"/>
                                        </Border>
                                        <WrapPanel>
                                            <Button x:Name="TestNexus" Content="{{TEST_CONNECTION}}" FontSize="10" Padding="10,7"/>
                                            <Button x:Name="OpenApiKeys" Content="{{GET_API_KEY}}" FontSize="10" Padding="10,7"/>
                                            <Button x:Name="ClearApiKey" Content="{{CLEAR_SAVED_KEY}}" FontSize="10" Padding="10,7"/>
                                        </WrapPanel>
                                    </StackPanel>
                                </Border>

                                <Border x:Name="SlowModePanel" Background="#0F1C14" BorderBrush="#285238" BorderThickness="1" CornerRadius="12" Padding="13" Opacity="0" IsHitTestVisible="False">
                                    <StackPanel>
                                        <Grid>
                                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                            <StackPanel>
                                                <TextBlock Text="{{DOWNLOAD_SLOW_TITLE}}" Foreground="#8CE6A6" FontWeight="Bold" FontSize="12"/>
                                                <TextBlock Text="{{DOWNLOAD_SLOW_DESC}}" Foreground="#A8B2AC" TextWrapping="Wrap" FontSize="10" Margin="0,4,10,0"/>
                                            </StackPanel>
                                            <Border Grid.Column="1" Background="#15321F" BorderBrush="#2E7044" BorderThickness="1" CornerRadius="99" Padding="8,3" VerticalAlignment="Top">
                                                <TextBlock Text="{{DOWNLOAD_SLOW_BADGE}}" Foreground="#8CF0A5" FontSize="10" FontWeight="Bold"/>
                                            </Border>
                                        </Grid>
                                        <Border Background="#0B1410" BorderBrush="#203F2C" BorderThickness="1" CornerRadius="9" Padding="11" Margin="0,14,0,0">
                                            <StackPanel>
                                                <TextBlock Text="{{DOWNLOAD_SLOW_STEP1}}" Foreground="#E0E6E2" FontSize="10" FontWeight="SemiBold"/>
                                                <TextBlock Text="{{DOWNLOAD_SLOW_STEP2}}" Foreground="#9BA59F" FontSize="10" Margin="0,7,0,0"/>
                                                <TextBlock Text="{{DOWNLOAD_SLOW_STEP3}}" Foreground="#9BA59F" FontSize="10" Margin="0,7,0,0"/>
                                            </StackPanel>
                                        </Border>
                                        <TextBlock Text="{{DOWNLOAD_SLOW_HINT}}" Foreground="#6F8B78" TextWrapping="Wrap" FontSize="10" Margin="0,12,0,0"/>
                                    </StackPanel>
                                </Border>
                            </Grid>
                        </StackPanel>
                    </Border>

                    <Border Style="{StaticResource Card}">
                        <StackPanel>
                            <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border Width="34" Height="34" CornerRadius="17" Background="{StaticResource Accent}" Margin="0,0,12,0"><TextBlock Text="4" Foreground="#151515" FontWeight="Bold" FontSize="15" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                                <StackPanel Grid.Column="1"><TextBlock Text="{{STEP4_TITLE}}" FontSize="18" FontWeight="Bold"/><TextBlock Text="{{STEP4_DESC}}" Foreground="{StaticResource Muted}" FontSize="11" TextWrapping="Wrap" Margin="0,2,0,0"/></StackPanel>
                            </Grid>
                            <Border Background="#19160B" BorderBrush="#51451A" BorderThickness="1" CornerRadius="10" Padding="11" Margin="0,14,0,12"><TextBlock Text="{{RUS_NOTE}}" Foreground="#EACB64" TextWrapping="Wrap" FontSize="10"/></Border>
                            <Button x:Name="InstallButton" Content="{{INSTALL}}" Style="{StaticResource PrimaryButton}" FontSize="14" Height="52" Margin="0,0,0,9"/>
                            <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><Button x:Name="RestoreButton" Content="{{RESTORE}}" Height="42" Margin="0,0,5,0"/><Button x:Name="CreditsButton" Grid.Column="1" Content="{{ABOUT}}" Height="42" Margin="5,0,0,0"/></Grid>
                            <ProgressBar x:Name="InstallProgress" Height="7" Minimum="0" Maximum="100" Value="0" Foreground="{StaticResource Accent}" Background="#20252D" BorderThickness="0" Margin="0,15,0,7"/>
                            <TextBlock x:Name="DownloadStatus" Text="{{READY}}" Foreground="{StaticResource Muted}" FontSize="11"/>
                            <Border Height="1" Background="#262D36" Margin="0,14,0,12"/>
                            <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><TextBlock Text="{{FOOTER_TRUST}}" Foreground="#656D79" FontSize="9" TextWrapping="Wrap"/><TextBlock Grid.Column="1" Text="v0.4.0 • MIT" Foreground="#656D79" FontSize="9" VerticalAlignment="Bottom"/></Grid>
                        </StackPanel>
                    </Border>
                </StackPanel>
            </Grid>
        </ScrollViewer>
    </Grid>
</Window>
'@

$xaml = Expand-LocTemplate $xaml
$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
$Script:Window = $window
$iconPath = Join-Path $RepoRoot 'assets\bully-starter-kit.ico'
if (Test-Path $iconPath) {
    try { $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([Uri]$iconPath) } catch {}
}

$Script:GamePathBox = $window.FindName('GamePath')
$Script:LogBox = $window.FindName('LogBox')
$Script:SilentCheck = $window.FindName('SilentCheck')
$Script:EssentialCheck = $window.FindName('EssentialCheck')
$Script:VisualCheck = $window.FindName('VisualCheck')
$Script:FpsBox = $window.FindName('FpsBox')
$Script:NexusKeyBox = $window.FindName('NexusKey')
$Script:RememberKeyCheck = $window.FindName('RememberKey')
$Script:NexusStatus = $window.FindName('NexusStatus')
$Script:DownloadStatus = $window.FindName('DownloadStatus')
$Script:InstallProgress = $window.FindName('InstallProgress')
$Script:InstallButton = $window.FindName('InstallButton')
$Script:ModeSlider = $window.FindName('ModeSlider')
$Script:AutoModeButton = $window.FindName('AutoModeButton')
$Script:SlowModeButton = $window.FindName('SlowModeButton')
$Script:AutoModePanel = $window.FindName('AutoModePanel')
$Script:SlowModePanel = $window.FindName('SlowModePanel')
$window.FindName('VersionBadge').Text = 'VANILLA+  •  v' + $PackVersion

$window.FindName('BrowseGame').Add_Click({ Select-GameFolder })
$window.FindName('LanguageButton').Add_Click({ Switch-UiLanguage })
$window.FindName('AutoModeButton').Add_Click({ Set-DownloadMode -Mode 'auto' })
$window.FindName('SlowModeButton').Add_Click({ Set-DownloadMode -Mode 'slow' })
$window.FindName('TestNexus').Add_Click({ [void](Test-NexusConnection) })
$window.FindName('OpenApiKeys').Add_Click({ Start-Process 'https://www.nexusmods.com/settings/api-keys' })
$window.FindName('ClearApiKey').Add_Click({ Clear-NexusApiKey })
$window.FindName('InstallButton').Add_Click({ Install-Pack })
$window.FindName('RestoreButton').Add_Click({ Restore-LatestBackup })
$window.FindName('CreditsButton').Add_Click({ Open-Credits })

Set-DownloadMode -Mode 'slow' -NoAnimation

$detected = Find-BullyInstall
if ($detected) {
    $Script:GamePathBox.Text = $detected
    Write-UiLog (LF 'LOG_DETECTED' @($detected))
    Write-UiLog (LF 'LOG_GAME_VERSION' @((Get-BullyVersionText $detected)))
} else {
    Write-UiLog (L 'LOG_NOT_DETECTED')
}

$saved = Load-NexusApiKey
if ($saved) {
    $Script:NexusStatus.Text = L 'NEXUS_SAVED_FOUND'
    $Script:NexusStatus.Foreground = '#F6C945'
    Write-UiLog (L 'LOG_CREDENTIALS_FOUND')
} else {
    Write-UiLog (L 'LOG_NO_CREDENTIALS')
}

Write-UiLog (L 'LOG_PRESET')
Write-UiLog (L 'LOG_CREDITS')
Write-UiLog (L 'LOG_PUBLIC_DOCS')
Write-UiLog (L 'PUBLIC_STABLE_NOTE')

$window.ShowDialog() | Out-Null
