#requires -Version 5.1

$script:AutoSuggestionsVersion = '1.0.0'
$script:BeginMarker = '# >>> powershell-auto-suggestions >>>'
$script:EndMarker = '# <<< powershell-auto-suggestions <<<'
$script:MinimumPSReadLine = [version]'2.2.6'

function Write-AutoSuggestionsMessage {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message,

        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Step')]
        [string]$Level = 'Info'
    )

    $color = switch ($Level) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Step' { 'Cyan' }
        default { 'Gray' }
    }

    Write-Host $Message -ForegroundColor $color
}

function Add-AutoSuggestionsLog {
    param(
        [Parameter(Mandatory = $true)]
        $Paths,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    try {
        if (-not (Test-Path -LiteralPath $Paths.State)) {
            New-Item -ItemType Directory -Path $Paths.State -Force | Out-Null
        }
        $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
        Add-Content -LiteralPath $Paths.Log -Value $line -Encoding UTF8
    }
    catch {
        # Logging must never break the installer.
    }
}

function Get-AutoSuggestionsPaths {
    param(
        [string]$StateDirectory
    )

    if ([string]::IsNullOrWhiteSpace($StateDirectory)) {
        $base = $env:LOCALAPPDATA
        if ([string]::IsNullOrWhiteSpace($base)) {
            $base = [Environment]::GetFolderPath('LocalApplicationData')
        }
        if ([string]::IsNullOrWhiteSpace($base)) {
            $base = [IO.Path]::GetTempPath()
        }
        $StateDirectory = Join-Path $base 'powershell-auto-suggestions'
    }

    [pscustomobject]@{
        State = $StateDirectory
        Snippet = Join-Path $StateDirectory 'auto-suggestions.ps1'
        StateFile = Join-Path $StateDirectory 'state.json'
        Log = Join-Path $StateDirectory 'install.log'
        Backups = Join-Path $StateDirectory 'backups'
        Module = Join-Path $StateDirectory 'AutoSuggestions.psm1'
    }
}

function Get-AutoSuggestionsDocumentsPath {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    if ([string]::IsNullOrWhiteSpace($docs)) {
        $docs = Join-Path $HOME 'Documents'
    }
    return $docs
}

function Test-AutoSuggestionsCommandExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Get-AutoSuggestionsTargetProfiles {
    param(
        [string[]]$ProfilePath,
        [switch]$AllHosts
    )

    if ($ProfilePath -and $ProfilePath.Count -gt 0) {
        $paths = $ProfilePath
    }
    else {
        $docs = Get-AutoSuggestionsDocumentsPath
        $ps5Profile = Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
        $ps7Profile = Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'

        $paths = New-Object System.Collections.Generic.List[string]
        if (-not [string]::IsNullOrWhiteSpace($PROFILE)) {
            $paths.Add($PROFILE)
        }
        if ($AllHosts -or (Test-AutoSuggestionsCommandExists -Name 'powershell')) {
            $paths.Add($ps5Profile)
        }
        if ($AllHosts -or (Test-AutoSuggestionsCommandExists -Name 'pwsh') -or (Test-Path -LiteralPath $ps7Profile)) {
            $paths.Add($ps7Profile)
        }
        if ($paths.Count -eq 0) {
            $paths.Add($ps5Profile)
        }
    }

    $seen = @{}
    $result = New-Object System.Collections.Generic.List[object]
    foreach ($path in $paths) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }
        $fullPath = [IO.Path]::GetFullPath($path)
        $key = $fullPath.ToLowerInvariant()
        if ($seen.ContainsKey($key)) {
            continue
        }
        $seen[$key] = $true
        $result.Add([pscustomobject]@{
            Path = $fullPath
            Existed = (Test-Path -LiteralPath $fullPath)
        })
    }

    return $result
}

function Read-AutoSuggestionsState {
    param(
        [Parameter(Mandatory = $true)]
        $Paths
    )

    if (-not (Test-Path -LiteralPath $Paths.StateFile)) {
        return $null
    }

    try {
        return (Get-Content -LiteralPath $Paths.StateFile -Raw -Encoding UTF8 | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

function Read-AutoSuggestionsTextFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -eq 0) {
        return ''
    }

    if (($bytes.Length -ge 3) -and ($bytes[0] -eq 0xEF) -and ($bytes[1] -eq 0xBB) -and ($bytes[2] -eq 0xBF)) {
        return [Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
    }
    if (($bytes.Length -ge 4) -and ($bytes[0] -eq 0xFF) -and ($bytes[1] -eq 0xFE) -and ($bytes[2] -eq 0x00) -and ($bytes[3] -eq 0x00)) {
        return [Text.Encoding]::UTF32.GetString($bytes, 4, $bytes.Length - 4)
    }
    if (($bytes.Length -ge 4) -and ($bytes[0] -eq 0x00) -and ($bytes[1] -eq 0x00) -and ($bytes[2] -eq 0xFE) -and ($bytes[3] -eq 0xFF)) {
        $utf32BigEndian = New-Object System.Text.UTF32Encoding($true, $true)
        return $utf32BigEndian.GetString($bytes, 4, $bytes.Length - 4)
    }
    if (($bytes.Length -ge 2) -and ($bytes[0] -eq 0xFF) -and ($bytes[1] -eq 0xFE)) {
        return [Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2)
    }
    if (($bytes.Length -ge 2) -and ($bytes[0] -eq 0xFE) -and ($bytes[1] -eq 0xFF)) {
        return [Text.Encoding]::BigEndianUnicode.GetString($bytes, 2, $bytes.Length - 2)
    }

    try {
        $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
        return $strictUtf8.GetString($bytes)
    }
    catch {
        return [Text.Encoding]::Default.GetString($bytes)
    }
}

function Write-AutoSuggestionsTextFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [AllowEmptyString()]
        [string]$Text
    )

    $directory = Split-Path -Parent $Path
    if ([string]::IsNullOrWhiteSpace($directory)) {
        $directory = (Get-Location).Path
    }
    if ($null -eq $Text) {
        $Text = ''
    }
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    if (-not $Text.EndsWith("`n")) {
        $Text += "`n"
    }

    $temp = Join-Path $directory ('.psas-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $encoding = New-Object System.Text.UTF8Encoding($true)
        [IO.File]::WriteAllText($temp, $Text, $encoding)
        Move-Item -LiteralPath $temp -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $temp) {
            Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        }
    }
}

function Backup-AutoSuggestionsProfile {
    param(
        [Parameter(Mandatory = $true)]
        $Paths,

        [Parameter(Mandatory = $true)]
        [string]$ProfilePath
    )

    if (-not (Test-Path -LiteralPath $ProfilePath)) {
        return $null
    }
    if (-not (Test-Path -LiteralPath $Paths.Backups)) {
        New-Item -ItemType Directory -Path $Paths.Backups -Force | Out-Null
    }

    $name = [IO.Path]::GetFileName($ProfilePath)
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
    $destination = Join-Path $Paths.Backups ('{0}.{1}.bak' -f $name, $stamp)
    Copy-Item -LiteralPath $ProfilePath -Destination $destination -Force

    $oldBackups = Get-ChildItem -LiteralPath $Paths.Backups -Filter ('{0}.*.bak' -f $name) -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 5
    foreach ($old in $oldBackups) {
        Remove-Item -LiteralPath $old.FullName -Force -ErrorAction SilentlyContinue
    }

    return $destination
}

function Test-AutoSuggestionsLegacyProfile {
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }
    if ($Text -match 'PowerShell Ultimate Setup Loaded') {
        return $true
    }
    if (($Text -match '(?m)^\s*Set-Location\s+\$HOME\s*$') -and
        ($Text -match 'Set-PSReadLineOption\s+-PredictionSource\s+History')) {
        return $true
    }

    return $false
}

function Remove-AutoSuggestionsManagedBlock {
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    $pattern = '(?ms)^[ \t]*# >>> powershell-auto-suggestions >>>[ \t]*\r?\n.*?^[ \t]*# <<< powershell-auto-suggestions <<<[ \t]*(?:\r?\n)?'
    return ([regex]::Replace($Text, $pattern, '')).Trim()
}

function Remove-AutoSuggestionsLegacyContent {
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($Text -split "`r?`n")) {
        $lines.Add($line)
    }

    $banner = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'PowerShell Ultimate Setup Loaded') {
            $banner = $i
            break
        }
    }

    if ($banner -ge 0) {
        $start = -1
        for ($i = $banner; $i -ge 0; $i--) {
            if ($lines[$i] -match '^\s*Import-Module\s+PSReadLine\s*$') {
                $start = $i
                break
            }
        }

        if ($start -ge 0) {
            $end = $banner
            for ($i = $banner + 1; $i -lt $lines.Count; $i++) {
                if (($lines[$i] -match '^\s*$') -or ($lines[$i] -match '^\s*Write-Host\b')) {
                    $end = $i
                }
                else {
                    break
                }
            }
            $lines.RemoveRange($start, $end - $start + 1)
        }
    }

    $clean = New-Object System.Collections.Generic.List[string]
    $inLegacyColors = $false
    foreach ($line in $lines) {
        if ($line -match '^\s*Set-PSReadLineOption\s+-Colors\s+@\{') {
            $inLegacyColors = $true
            continue
        }
        if ($inLegacyColors) {
            if ($line -match '^\s*\}') {
                $inLegacyColors = $false
            }
            continue
        }
        if ($line -match '^\s*Set-Location\s+\$HOME\s*$') { continue }
        if ($line -match '^\s*Clear-Host\s*$') { continue }
        if ($line -match '^\s*Import-Module\s+(PSReadLine|Terminal-Icons)\s*$') { continue }
        if ($line -match '^\s*Set-PSReadLineOption\s+-PredictionSource\s+History\s*$') { continue }
        if ($line -match '^\s*Set-PSReadLineOption\s+-PredictionViewStyle\s+InlineView\s*$') { continue }
        if ($line -match '^\s*Set-PSReadLineKeyHandler\s+-Key\s+Tab\s+-Function\s+Complete\s*$') { continue }
        if ($line -match '^\s*Set-PSReadLineOption\s+-MaximumHistoryCount\s+10000\s*$') { continue }
        if ($line -match '^\s*Write-Host\s+"=+"') { continue }
        if ($line -match '^\s*Write-Host\s+"\s*PowerShell Ultimate Setup Loaded\s*"') { continue }
        if ($line -match '^\s*Write-Host\s+""\s*$') { continue }
        $clean.Add($line)
    }

    return (($clean -join "`r`n").Trim())
}

function Get-AutoSuggestionsManagedBlock {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SnippetPath
    )

    $escaped = $SnippetPath.Replace("'", "''")
    return @"
$script:BeginMarker
# Managed by powershell-auto-suggestions v$script:AutoSuggestionsVersion. Do not edit this block.
. '$escaped'
$script:EndMarker
"@
}

function Get-AutoSuggestionsSnippet {
    param(
        [ValidateSet('InlineView', 'ListView')]
        [string]$PredictionViewStyle = 'InlineView',

        [switch]$Banner,
        [switch]$SkipTerminalIcons
    )

    $bannerLine = ''
    if ($Banner) {
        $bannerLine = '        Write-Host "powershell-auto-suggestions loaded" -ForegroundColor DarkGray'
    }

    $terminalIconsBlock = ''
    if (-not $SkipTerminalIcons) {
        $terminalIconsBlock = @'
        try {
            Import-Module Terminal-Icons -ErrorAction Stop
        }
        catch {
            # Terminal-Icons is optional.
        }
'@
    }

    $template = @'
# Managed by powershell-auto-suggestions v__VERSION__
# Do not edit this file. Run setup.ps1 -Repair to regenerate it.

try {
    $__psasInteractive = $Host.Name -eq 'ConsoleHost' -and -not [Console]::IsOutputRedirected
}
catch {
    $__psasInteractive = $Host.Name -eq 'ConsoleHost'
}

if ($__psasInteractive) {
    try {
        Import-Module PSReadLine -MinimumVersion 2.2.6 -ErrorAction Stop

        # Plugin predictions require PowerShell 7.2+. Windows PowerShell 5.1
        # and PowerShell 7.0/7.1 must use history-only predictions.
        $__psasSource = 'History'
        if (($PSVersionTable.PSEdition -eq 'Core') -and
            (($PSVersionTable.PSVersion.Major -gt 7) -or
             (($PSVersionTable.PSVersion.Major -eq 7) -and ($PSVersionTable.PSVersion.Minor -ge 2)))) {
            $__psasSource = 'HistoryAndPlugin'
        }

        Set-PSReadLineOption -PredictionSource $__psasSource
        Set-PSReadLineOption -PredictionViewStyle __STYLE__
        Set-PSReadLineOption -HistoryNoDuplicates
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd
        Set-PSReadLineOption -BellStyle None
        Set-PSReadLineOption -MaximumHistoryCount 10000

        $global:MaximumHistoryCount = 10000

        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

__TERMINAL_ICONS__
__BANNER__
    }
    catch {
        Write-Warning "powershell-auto-suggestions: $($_.Exception.Message)"
    }
}

Remove-Variable __psasInteractive, __psasSource -ErrorAction SilentlyContinue
'@

    $template = $template.Replace('__VERSION__', $script:AutoSuggestionsVersion)
    $template = $template.Replace('__STYLE__', $PredictionViewStyle)
    $template = $template.Replace('__BANNER__', $bannerLine)
    $template = $template.Replace('__TERMINAL_ICONS__', $terminalIconsBlock)
    return $template.Trim()
}

function Test-AutoSuggestionsAdmin {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Get-AutoSuggestionsModuleVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $module = Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending |
        Select-Object -First 1
    if ($module) {
        return $module.Version
    }
    return $null
}

function Install-AutoSuggestionsModule {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [version]$MinimumVersion,

        [Parameter(Mandatory = $true)]
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope
    )

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
    catch {
    }

    $repository = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if (-not $repository) {
        throw "PSGallery is not registered. Register it or install $Name manually, then rerun setup.ps1."
    }

    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        $nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
        if (-not $nuget) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -Confirm:$false | Out-Null
        }
    }

    $oldPolicy = $repository.InstallationPolicy
    $trustChanged = $false
    try {
        if ($oldPolicy -ne 'Trusted') {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
            $trustChanged = $true
        }

        $parameters = @{
            Name = $Name
            Scope = $Scope
            Force = $true
            Repository = 'PSGallery'
            ErrorAction = 'Stop'
        }
        if ($MinimumVersion) {
            $parameters['MinimumVersion'] = $MinimumVersion
        }

        try {
            Install-Module @parameters
        }
        catch {
            $parameters['SkipPublisherCheck'] = $true
            Install-Module @parameters
        }
    }
    finally {
        if ($trustChanged) {
            try {
                Set-PSRepository -Name PSGallery -InstallationPolicy $oldPolicy -ErrorAction Stop
            }
            catch {
            }
        }
    }
}

function Install-AutoSuggestionsModules {
    param(
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope = 'CurrentUser',

        [switch]$SkipModules,
        [switch]$SkipTerminalIcons,
        [switch]$DryRun
    )

    $psReadLine = Get-AutoSuggestionsModuleVersion -Name 'PSReadLine'
    $terminalIcons = Get-AutoSuggestionsModuleVersion -Name 'Terminal-Icons'

    if ($SkipModules) {
        Write-AutoSuggestionsMessage "Module installation skipped (-SkipModules)." 'Warning'
        if (-not $psReadLine -or $psReadLine -lt $script:MinimumPSReadLine) {
            Write-AutoSuggestionsMessage "PSReadLine $($script:MinimumPSReadLine) or newer is required for the managed profile." 'Warning'
        }
        return
    }

    if ($Scope -eq 'AllUsers' -and -not (Test-AutoSuggestionsAdmin)) {
        throw "Scope 'AllUsers' requires an elevated PowerShell session. Use -Scope CurrentUser or run as Administrator."
    }

    if ($psReadLine -and $psReadLine -ge $script:MinimumPSReadLine) {
        Write-AutoSuggestionsMessage "PSReadLine $psReadLine is already installed." 'Success'
    }
    else {
        if ($DryRun) {
            Write-AutoSuggestionsMessage "[dry-run] Would install PSReadLine $($script:MinimumPSReadLine)+ (scope: $Scope)." 'Step'
        }
        else {
            Write-AutoSuggestionsMessage "Installing PSReadLine $($script:MinimumPSReadLine)+ (scope: $Scope)..." 'Step'
            Install-AutoSuggestionsModule -Name 'PSReadLine' -MinimumVersion $script:MinimumPSReadLine -Scope $Scope
            $psReadLine = Get-AutoSuggestionsModuleVersion -Name 'PSReadLine'
            if (-not $psReadLine -or $psReadLine -lt $script:MinimumPSReadLine) {
                throw "PSReadLine installation did not produce a usable version $($script:MinimumPSReadLine) or newer."
            }
            Write-AutoSuggestionsMessage "PSReadLine $psReadLine installed." 'Success'
        }
    }

    if ($SkipTerminalIcons) {
        Write-AutoSuggestionsMessage "Terminal-Icons skipped (-SkipTerminalIcons)." 'Info'
        return
    }

    if ($terminalIcons) {
        Write-AutoSuggestionsMessage "Terminal-Icons $terminalIcons is already installed." 'Success'
    }
    elseif ($DryRun) {
        Write-AutoSuggestionsMessage "[dry-run] Would install Terminal-Icons (optional)." 'Step'
    }
    else {
        try {
            Write-AutoSuggestionsMessage "Installing Terminal-Icons (optional)..." 'Step'
            Install-AutoSuggestionsModule -Name 'Terminal-Icons' -Scope $Scope
            $terminalIcons = Get-AutoSuggestionsModuleVersion -Name 'Terminal-Icons'
            if ($terminalIcons) {
                Write-AutoSuggestionsMessage "Terminal-Icons $terminalIcons installed." 'Success'
            }
        }
        catch {
            Write-AutoSuggestionsMessage "Terminal-Icons could not be installed (optional): $($_.Exception.Message)" 'Warning'
        }
    }
}

function Install-AutoSuggestions {
    [CmdletBinding()]
    param(
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope = 'CurrentUser',

        [ValidateSet('InlineView', 'ListView')]
        [string]$PredictionViewStyle = 'InlineView',

        [switch]$Banner,
        [switch]$SkipModules,
        [switch]$SkipTerminalIcons,
        [switch]$DryRun,
        [switch]$Force,
        [switch]$AllHosts,
        [string[]]$ProfilePath,
        [string]$StateDirectory
    )

    $paths = Get-AutoSuggestionsPaths -StateDirectory $StateDirectory
    $profiles = @(Get-AutoSuggestionsTargetProfiles -ProfilePath $ProfilePath -AllHosts:$AllHosts)
    $previousState = Read-AutoSuggestionsState -Paths $paths

    Write-AutoSuggestionsMessage "powershell-auto-suggestions v$script:AutoSuggestionsVersion" 'Info'
    if ($DryRun) {
        Write-AutoSuggestionsMessage "Dry run: no changes will be made." 'Warning'
    }

    if (-not $DryRun) {
        foreach ($directory in @($paths.State, $paths.Backups)) {
            if (-not (Test-Path -LiteralPath $directory)) {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
            }
        }
    }

    Install-AutoSuggestionsModules -Scope $Scope -SkipModules:$SkipModules -SkipTerminalIcons:$SkipTerminalIcons -DryRun:$DryRun

    $snippet = Get-AutoSuggestionsSnippet -PredictionViewStyle $PredictionViewStyle -Banner:$Banner -SkipTerminalIcons:$SkipTerminalIcons
    $existingSnippet = Read-AutoSuggestionsTextFile -Path $paths.Snippet
    $snippetChanged = $true
    if ($null -ne $existingSnippet) {
        $normalizedExisting = $existingSnippet.Replace("`r`n", "`n").Trim()
        $normalizedNew = $snippet.Replace("`r`n", "`n").Trim()
        $snippetChanged = $normalizedExisting -ne $normalizedNew
    }

    if ($DryRun) {
        if ($snippetChanged) {
            Write-AutoSuggestionsMessage "[dry-run] Would write managed snippet: $($paths.Snippet)" 'Step'
        }
        else {
            Write-AutoSuggestionsMessage "[dry-run] Managed snippet is already up to date: $($paths.Snippet)" 'Success'
        }
    }
    else {
        if ($snippetChanged) {
            Write-AutoSuggestionsTextFile -Path $paths.Snippet -Text $snippet
            Add-AutoSuggestionsLog -Paths $paths -Message "Wrote snippet $($paths.Snippet)"
            Write-AutoSuggestionsMessage "Managed snippet: $($paths.Snippet)" 'Success'
        }
        else {
            Write-AutoSuggestionsMessage "Managed snippet is already up to date: $($paths.Snippet)" 'Success'
        }
    }

    $block = Get-AutoSuggestionsManagedBlock -SnippetPath $paths.Snippet
    $stateProfiles = New-Object System.Collections.Generic.List[object]

    foreach ($profile in $profiles) {
        $path = $profile.Path
        $oldText = Read-AutoSuggestionsTextFile -Path $path
        if ($null -eq $oldText) {
            $oldText = ''
        }
        $existed = Test-Path -LiteralPath $path
        $existedBefore = $existed
        if ($previousState -and $previousState.Profiles) {
            $priorEntry = @($previousState.Profiles) | Where-Object { $_.Path -eq $path } | Select-Object -First 1
            if ($priorEntry) {
                $existedBefore = [bool]$priorEntry.Existed
            }
        }
        $legacy = Test-AutoSuggestionsLegacyProfile -Text $oldText

        $clean = Remove-AutoSuggestionsManagedBlock -Text $oldText
        if ($legacy) {
            $clean = Remove-AutoSuggestionsLegacyContent -Text $clean
        }
        $clean = $clean.Trim()

        if ([string]::IsNullOrWhiteSpace($clean)) {
            $newText = $block
        }
        else {
            $newText = $clean.TrimEnd() + "`r`n`r`n" + $block
        }

        if ((-not $Force) -and ($oldText.Trim() -eq $newText.Trim())) {
            Write-AutoSuggestionsMessage "Profile is already up to date: $path" 'Success'
            $stateProfiles.Add([pscustomobject]@{
                Path = $path
                Existed = $existedBefore
                Legacy = $legacy
                Backup = $null
                Changed = $false
            })
            continue
        }

        if ($DryRun) {
            $reason = 'update managed block'
            if ($legacy) {
                $reason = 'replace legacy/broken profile content'
            }
            Write-AutoSuggestionsMessage "[dry-run] Would ${reason}: $path" 'Step'
            $stateProfiles.Add([pscustomobject]@{
                Path = $path
                Existed = $existedBefore
                Legacy = $legacy
                Backup = $null
                Changed = $true
            })
            continue
        }

        $backup = $null
        if ($existed) {
            $backup = Backup-AutoSuggestionsProfile -Paths $paths -ProfilePath $path
            if ($backup) {
                Write-AutoSuggestionsMessage "Backup: $backup" 'Info'
            }
        }

        Write-AutoSuggestionsTextFile -Path $path -Text $newText
        if ($legacy) {
            Write-AutoSuggestionsMessage "Removed legacy/broken profile content: $path" 'Success'
        }
        Write-AutoSuggestionsMessage "Profile configured: $path" 'Success'
        Add-AutoSuggestionsLog -Paths $paths -Message "Configured profile $path (legacy=$legacy, backup=$backup)"

        $stateProfiles.Add([pscustomobject]@{
            Path = $path
            Existed = $existedBefore
            Legacy = $legacy
            Backup = $backup
            Changed = $true
        })
    }

    if (-not $DryRun) {
        $state = [pscustomobject]@{
            Version = $script:AutoSuggestionsVersion
            InstalledAt = (Get-Date).ToString('o')
            ModuleScope = $Scope
            PredictionViewStyle = $PredictionViewStyle
            Banner = [bool]$Banner
            SkipTerminalIcons = [bool]$SkipTerminalIcons
            Profiles = $stateProfiles.ToArray()
        }
        Write-AutoSuggestionsTextFile -Path $paths.StateFile -Text ($state | ConvertTo-Json -Depth 6)
        Add-AutoSuggestionsLog -Paths $paths -Message "Install complete (scope=$Scope, style=$PredictionViewStyle)"
    }

    Write-AutoSuggestionsMessage '' 'Info'
    if ($DryRun) {
        Write-AutoSuggestionsMessage "Dry run complete. Run setup.ps1 without -DryRun to apply." 'Success'
    }
    else {
        Write-AutoSuggestionsMessage "Installation complete." 'Success'
        Write-AutoSuggestionsMessage "Open a new terminal (or run . `$PROFILE) to load the new settings." 'Info'
        Write-AutoSuggestionsMessage "If PSReadLine was upgraded, restart PowerShell before the new version is active." 'Info'
    }
}

function Uninstall-AutoSuggestions {
    [CmdletBinding()]
    param(
        [switch]$DryRun,
        [switch]$Purge,
        [switch]$AllHosts,
        [string[]]$ProfilePath,
        [string]$StateDirectory
    )

    $paths = Get-AutoSuggestionsPaths -StateDirectory $StateDirectory
    $state = Read-AutoSuggestionsState -Paths $paths

    $targets = New-Object System.Collections.Generic.List[object]
    if ($ProfilePath -and $ProfilePath.Count -gt 0) {
        foreach ($target in (Get-AutoSuggestionsTargetProfiles -ProfilePath $ProfilePath)) {
            $targets.Add($target)
        }
    }
    elseif ($state -and $state.Profiles) {
        foreach ($saved in @($state.Profiles)) {
            $targets.Add([pscustomobject]@{
                Path = $saved.Path
                Existed = [bool]$saved.Existed
            })
        }
    }
    else {
        foreach ($target in (Get-AutoSuggestionsTargetProfiles -AllHosts:$AllHosts)) {
            $targets.Add($target)
        }
    }

    Write-AutoSuggestionsMessage "powershell-auto-suggestions uninstall" 'Info'
    if ($DryRun) {
        Write-AutoSuggestionsMessage "Dry run: no changes will be made." 'Warning'
    }

    foreach ($target in $targets) {
        $path = $target.Path
        $oldText = Read-AutoSuggestionsTextFile -Path $path
        if ($null -eq $oldText) {
            Write-AutoSuggestionsMessage "Profile not found, skipping: $path" 'Info'
            continue
        }

        $hadMarker = $oldText -match [regex]::Escape($script:BeginMarker)
        $legacy = Test-AutoSuggestionsLegacyProfile -Text $oldText
        if ((-not $hadMarker) -and (-not $legacy)) {
            Write-AutoSuggestionsMessage "No managed content found: $path" 'Info'
            continue
        }

        $clean = Remove-AutoSuggestionsManagedBlock -Text $oldText
        if ($legacy) {
            $clean = Remove-AutoSuggestionsLegacyContent -Text $clean
        }
        $clean = $clean.Trim()

        if ($DryRun) {
            Write-AutoSuggestionsMessage "[dry-run] Would clean profile: $path" 'Step'
            continue
        }

        $backup = Backup-AutoSuggestionsProfile -Paths $paths -ProfilePath $path
        if ($backup) {
            Write-AutoSuggestionsMessage "Backup: $backup" 'Info'
        }

        $existedBefore = $true
        if ($state -and $state.Profiles) {
            $entry = @($state.Profiles) | Where-Object { $_.Path -eq $path } | Select-Object -First 1
            if ($entry) {
                $existedBefore = [bool]$entry.Existed
            }
        }
        elseif ($legacy) {
            $existedBefore = $false
        }

        if ([string]::IsNullOrWhiteSpace($clean) -and (-not $existedBefore)) {
            Remove-Item -LiteralPath $path -Force
            Write-AutoSuggestionsMessage "Removed generated profile: $path" 'Success'
        }
        else {
            Write-AutoSuggestionsTextFile -Path $path -Text $clean
            Write-AutoSuggestionsMessage "Cleaned profile: $path" 'Success'
        }
        Add-AutoSuggestionsLog -Paths $paths -Message "Uninstalled from $path (legacy=$legacy)"
    }

    if ($DryRun) {
        Write-AutoSuggestionsMessage "[dry-run] Would remove managed snippet and state file." 'Step'
        Write-AutoSuggestionsMessage "Dry run complete." 'Success'
        return
    }

    foreach ($file in @($paths.Snippet, $paths.StateFile)) {
        if (Test-Path -LiteralPath $file) {
            Remove-Item -LiteralPath $file -Force
            Write-AutoSuggestionsMessage "Removed: $file" 'Info'
        }
    }

    if ($Purge) {
        if (Test-Path -LiteralPath $paths.State) {
            try {
                Remove-Item -LiteralPath $paths.State -Recurse -Force -ErrorAction Stop
                Write-AutoSuggestionsMessage "Purged state directory: $($paths.State)" 'Info'
            }
            catch {
                Write-AutoSuggestionsMessage "Could not fully purge $($paths.State): $($_.Exception.Message)" 'Warning'
            }
        }
    }
    else {
        Write-AutoSuggestionsMessage "Backups/log kept in: $($paths.State)" 'Info'
        Write-AutoSuggestionsMessage "Use -Purge to remove them." 'Info'
    }

    Write-AutoSuggestionsMessage "Uninstall complete. Open a new terminal to apply." 'Success'
}

function Show-AutoSuggestionsStatus {
    param(
        [string]$StateDirectory
    )

    $paths = Get-AutoSuggestionsPaths -StateDirectory $StateDirectory
    $state = Read-AutoSuggestionsState -Paths $paths

    Write-AutoSuggestionsMessage "powershell-auto-suggestions status" 'Info'
    Write-AutoSuggestionsMessage "Installer version : $script:AutoSuggestionsVersion" 'Info'
    Write-AutoSuggestionsMessage "State directory   : $($paths.State)" 'Info'

    if ($state) {
        Write-AutoSuggestionsMessage "Installed at      : $($state.InstalledAt)" 'Info'
        Write-AutoSuggestionsMessage "Module scope      : $($state.ModuleScope)" 'Info'
        Write-AutoSuggestionsMessage "Prediction style  : $($state.PredictionViewStyle)" 'Info'
    }
    else {
        Write-AutoSuggestionsMessage "Installed at      : not installed (no state.json)" 'Warning'
    }

    $psReadLine = Get-AutoSuggestionsModuleVersion -Name 'PSReadLine'
    $terminalIcons = Get-AutoSuggestionsModuleVersion -Name 'Terminal-Icons'
    $psReadLineText = 'not found'
    if ($psReadLine) {
        $psReadLineText = [string]$psReadLine
    }
    $terminalIconsText = 'not found (optional)'
    if ($terminalIcons) {
        $terminalIconsText = [string]$terminalIcons
    }
    Write-AutoSuggestionsMessage "PSReadLine        : $psReadLineText" 'Info'
    Write-AutoSuggestionsMessage "Terminal-Icons    : $terminalIconsText" 'Info'

    $targets = @()
    if ($state -and $state.Profiles) {
        $targets = @($state.Profiles | ForEach-Object {
            [pscustomobject]@{
                Path = $_.Path
                Existed = [bool]$_.Existed
            }
        })
    }
    else {
        $targets = @(Get-AutoSuggestionsTargetProfiles -AllHosts)
    }

    foreach ($target in $targets) {
        $path = $target.Path
        if (-not (Test-Path -LiteralPath $path)) {
            Write-AutoSuggestionsMessage "Profile           : $path (missing)" 'Warning'
            continue
        }

        $text = Read-AutoSuggestionsTextFile -Path $path
        $managed = $text -match [regex]::Escape($script:BeginMarker)
        $legacy = Test-AutoSuggestionsLegacyProfile -Text $text
        $badLocation = $text -match '(?m)^\s*Set-Location\s+\$HOME\s*$'
        $badClear = $text -match '(?m)^\s*Clear-Host\s*$'

        $parts = New-Object System.Collections.Generic.List[string]
        if ($managed) { $parts.Add('managed block present') } else { $parts.Add('no managed block') }
        if ($legacy) { $parts.Add('legacy broken content') }
        if ($badLocation) { $parts.Add('WARNING: Set-Location $HOME') }
        if ($badClear) { $parts.Add('WARNING: Clear-Host') }

        $level = 'Warning'
        if ($managed -and (-not $legacy) -and (-not $badLocation) -and (-not $badClear)) {
            $level = 'Success'
        }
        Write-AutoSuggestionsMessage "Profile           : $path ($($parts -join ', '))" $level

        $profileDirectory = Split-Path -Parent $path
        $profileName = Split-Path -Leaf $path
        $legacyBackups = @(Get-ChildItem -LiteralPath $profileDirectory -Filter ('{0}.backup_*' -f $profileName) -File -ErrorAction SilentlyContinue)
        if ($legacyBackups.Count -gt 0) {
            Write-AutoSuggestionsMessage "Legacy backups    : $($legacyBackups.Count) file(s) in $profileDirectory (from the old installer; safe to delete)" 'Info'
        }
    }

    $loaded = Get-Module -Name PSReadLine -ErrorAction SilentlyContinue
    if ($loaded) {
        Write-AutoSuggestionsMessage "Loaded PSReadLine : $($loaded.Version)" 'Info'
        try {
            Write-AutoSuggestionsMessage "Prediction source : $((Get-PSReadLineOption).PredictionSource)" 'Info'
            Write-AutoSuggestionsMessage "Prediction view   : $((Get-PSReadLineOption).PredictionViewStyle)" 'Info'
        }
        catch {
        }
    }
    else {
        Write-AutoSuggestionsMessage "Loaded PSReadLine : not loaded in this session" 'Info'
    }
}

function Get-AutoSuggestionsVersion {
    return $script:AutoSuggestionsVersion
}

function Invoke-AutoSuggestionsSetup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [switch]$Uninstall,
        [switch]$Repair,
        [switch]$Status,
        [switch]$DryRun,
        [switch]$Force,
        [switch]$Purge,

        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope = 'CurrentUser',

        [ValidateSet('InlineView', 'ListView')]
        [string]$PredictionViewStyle = 'InlineView',

        [switch]$Banner,
        [switch]$SkipModules,
        [switch]$SkipTerminalIcons,
        [switch]$AllHosts,
        [string[]]$ProfilePath,
        [string]$StateDirectory
    )

    if ($Status) {
        Show-AutoSuggestionsStatus -StateDirectory $StateDirectory
        return
    }

    if ($Uninstall -and $Repair) {
        throw "Use either -Uninstall or -Repair, not both."
    }

    if ($WhatIfPreference) {
        $DryRun = $true
    }

    $action = 'Install'
    if ($Uninstall) {
        $action = 'Uninstall'
    }
    elseif ($Repair) {
        $action = 'Repair'
    }

    if ((-not $DryRun) -and (-not $PSCmdlet.ShouldProcess('PowerShell profiles', "$action powershell-auto-suggestions"))) {
        return
    }

    if ($Uninstall) {
        Uninstall-AutoSuggestions -DryRun:$DryRun -Purge:$Purge -AllHosts:$AllHosts -ProfilePath $ProfilePath -StateDirectory $StateDirectory
    }
    else {
        Install-AutoSuggestions -Scope $Scope -PredictionViewStyle $PredictionViewStyle -Banner:$Banner -SkipModules:$SkipModules -SkipTerminalIcons:$SkipTerminalIcons -DryRun:$DryRun -Force:($Force -or $Repair) -AllHosts:$AllHosts -ProfilePath $ProfilePath -StateDirectory $StateDirectory
    }
}

Export-ModuleMember -Function Invoke-AutoSuggestionsSetup, Show-AutoSuggestionsStatus, Get-AutoSuggestionsPaths, Get-AutoSuggestionsTargetProfiles, Get-AutoSuggestionsVersion
