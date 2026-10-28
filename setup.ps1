#requires -Version 5.1
<#
.SYNOPSIS
    Installs, repairs, inspects, or uninstalls PowerShell auto suggestions.

.DESCRIPTION
    Sets up PSReadLine history predictions, safer completion, and optional
    Terminal-Icons using a managed profile block. It never forces the working
    directory and never clears the screen.

    The script is safe to run both as a local file and through:

        irm https://raw.githubusercontent.com/AliHamza-Coder/powershell-auto-suggestions/main/setup.ps1 | iex

    Use -DryRun first to preview changes.

.PARAMETER Uninstall
    Removes the managed profile block and the managed snippet. Modules are not
    removed.

.PARAMETER Repair
    Reapplies the managed configuration, cleans legacy broken profile content,
    and installs missing modules.

.PARAMETER Status
    Shows module versions, profile paths, and whether legacy broken lines are
    still present.

.PARAMETER DryRun
    Prints what would change without writing files or installing modules.

.PARAMETER Purge
    Used with -Uninstall. Also removes backups and logs from the state directory.

.PARAMETER Scope
    Module installation scope. CurrentUser does not require Administrator.

.PARAMETER PredictionViewStyle
    InlineView shows ghost text. ListView shows a prediction list.

.PARAMETER Banner
    Adds a one-line banner when the profile loads.

.PARAMETER SkipModules
    Does not install or update PSReadLine or Terminal-Icons.

.PARAMETER SkipTerminalIcons
    Skips the optional Terminal-Icons module.

.PARAMETER AllHosts
    Configures both Windows PowerShell 5.1 and PowerShell 7 profiles, even if
    one host is not installed.

.PARAMETER ProfilePath
    Advanced/testing override. Writes only to the supplied profile path(s).

.PARAMETER StateDirectory
    Advanced/testing override for the state, snippet, backup, and log directory.

.PARAMETER SourceBase
    Base URL used to download src/AutoSuggestions.psm1 when running through iex.

.PARAMETER Ref
    Git ref used with SourceBase. Defaults to the v1.0.0 tag, then falls back to
    main if the tag is not available.

.PARAMETER ModuleHash
    Optional SHA256 hash of the downloaded module. Recommended for pinned
    installs.

.EXAMPLE
    irm https://raw.githubusercontent.com/AliHamza-Coder/powershell-auto-suggestions/main/setup.ps1 | iex

.EXAMPLE
    .\setup.ps1 -DryRun

.EXAMPLE
    .\setup.ps1 -Repair

.EXAMPLE
    .\setup.ps1 -Status

.EXAMPLE
    .\setup.ps1 -Uninstall -Purge
#>
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
    [string]$StateDirectory,

    [string]$SourceBase,
    [string]$Ref = 'v1.0.0',
    [string]$ModuleHash
)

$ErrorActionPreference = 'Stop'

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
catch {
}

$isFile = -not [string]::IsNullOrWhiteSpace($PSScriptRoot)
$isDotSourced = $MyInvocation.InvocationName -eq '.'
$modulePath = $null
$cacheDirectory = $null

if ($isFile) {
    $localModule = Join-Path $PSScriptRoot 'src\AutoSuggestions.psm1'
    if (Test-Path -LiteralPath $localModule) {
        $modulePath = $localModule
    }
}

if (-not $modulePath) {
    $cacheRoot = [IO.Path]::GetTempPath()
    $cacheDirectory = Join-Path $cacheRoot ('powershell-auto-suggestions-bootstrap-' + [guid]::NewGuid().ToString('N'))

    if (-not (Test-Path -LiteralPath $cacheDirectory)) {
        New-Item -ItemType Directory -Path $cacheDirectory -Force | Out-Null
    }

    # Best-effort cleanup of old bootstrap caches from earlier runs.
    Get-ChildItem -LiteralPath $cacheRoot -Directory -Filter 'powershell-auto-suggestions-bootstrap-*' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -ne $cacheDirectory -and $_.LastWriteTime -lt (Get-Date).AddHours(-1) } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    $modulePath = Join-Path $cacheDirectory 'AutoSuggestions.psm1'

    $explicitSource = -not [string]::IsNullOrWhiteSpace($SourceBase)
    $refsToTry = @($Ref)
    if ((-not $explicitSource) -and ($Ref -ne 'main')) {
        $refsToTry += 'main'
    }

    $downloaded = $false
    $lastError = $null
    foreach ($candidateRef in $refsToTry) {
        if ($explicitSource) {
            $base = $SourceBase.TrimEnd('/')
        }
        else {
            $base = "https://raw.githubusercontent.com/AliHamza-Coder/powershell-auto-suggestions/$candidateRef"
        }
        $url = "$base/src/AutoSuggestions.psm1"
        try {
            Write-Host "Downloading installer module ($candidateRef)..." -ForegroundColor Cyan
            Invoke-RestMethod -Uri $url -OutFile $modulePath -UseBasicParsing
            $downloaded = $true
            break
        }
        catch {
            $lastError = $_
        }
    }

    if (-not $downloaded) {
        if ($cacheDirectory) {
            Remove-Item -LiteralPath $cacheDirectory -Recurse -Force -ErrorAction SilentlyContinue
        }
        throw "Could not download AutoSuggestions.psm1. $($lastError.Exception.Message) Download setup.ps1 from the repository and run it locally instead."
    }

    if (-not [string]::IsNullOrWhiteSpace($ModuleHash)) {
        $actualHash = (Get-FileHash -LiteralPath $modulePath -Algorithm SHA256).Hash
        if ($actualHash -ne $ModuleHash.ToUpperInvariant()) {
            Remove-Item -LiteralPath $cacheDirectory -Recurse -Force -ErrorAction SilentlyContinue
            throw "Module hash mismatch. Expected $ModuleHash but got $actualHash."
        }
    }
}

try {
    Import-Module -Name $modulePath -Force
}
finally {
    if ($cacheDirectory) {
        try {
            Remove-Item -LiteralPath $cacheDirectory -Recurse -Force -ErrorAction Stop
        }
        catch {
            # The module is already loaded; a leftover temp file is harmless.
        }
    }
}

$parameters = @{
    Uninstall = $Uninstall
    Repair = $Repair
    Status = $Status
    DryRun = ($DryRun -or $WhatIfPreference)
    Force = $Force
    Purge = $Purge
    Scope = $Scope
    PredictionViewStyle = $PredictionViewStyle
    Banner = $Banner
    SkipModules = $SkipModules
    SkipTerminalIcons = $SkipTerminalIcons
    AllHosts = $AllHosts
}
if ($ProfilePath) {
    $parameters['ProfilePath'] = $ProfilePath
}
if ($StateDirectory) {
    $parameters['StateDirectory'] = $StateDirectory
}

try {
    Invoke-AutoSuggestionsSetup @parameters
}
catch {
    Write-Host ''
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($isFile -and (-not $isDotSourced)) {
        exit 1
    }
    throw
}
