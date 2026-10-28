#requires -Version 5.1

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $repoRoot 'src\AutoSuggestions.psm1'
Import-Module -Name $modulePath -Force

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('powershell-auto-suggestions-tests-' + [guid]::NewGuid().ToString('N'))
$stateDirectory = Join-Path $testRoot 'state'
$legacyStateDirectory = Join-Path $testRoot 'legacy-state'
$userStateDirectory = Join-Path $testRoot 'user-state'
$profilePath = Join-Path $testRoot 'profile\Microsoft.PowerShell_profile.ps1'
$legacyProfilePath = Join-Path $testRoot 'legacy\Microsoft.PowerShell_profile.ps1'
$userProfilePath = Join-Path $testRoot 'user\Microsoft.PowerShell_profile.ps1'
$dryProfilePath = Join-Path $testRoot 'dry\Microsoft.PowerShell_profile.ps1'
$dryStateDirectory = Join-Path $testRoot 'dry-state'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERT FAILED: $Message" }
}

function Assert-False {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { throw "ASSERT FAILED: $Message" }
}

function Assert-Match {
    param([string]$Text, [string]$Pattern, [string]$Message)
    if ($Text -notmatch $Pattern) { throw "ASSERT FAILED: $Message" }
}

function Assert-NotMatch {
    param([string]$Text, [string]$Pattern, [string]$Message)
    if ($Text -match $Pattern) { throw "ASSERT FAILED: $Message" }
}

try {
    New-Item -ItemType Directory -Path (Split-Path -Parent $profilePath) -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $legacyProfilePath) -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $userProfilePath) -Force | Out-Null

    $legacyContent = @'
# user-before
$env:PSAS_TEST = 'before'
Import-Module PSReadLine
Import-Module Terminal-Icons
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle InlineView
Set-PSReadLineKeyHandler -Key Tab -Function Complete
Set-PSReadLineOption -Colors @{
    Command = 'Cyan'
    Variable = 'White'
}
Set-PSReadLineOption -MaximumHistoryCount 10000
Set-Location $HOME
Clear-Host
Write-Host "=========================================" -ForegroundColor Green
Write-Host " PowerShell Ultimate Setup Loaded "
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
# user-after
$env:PSAS_TEST = 'after'
'@
    Set-Content -LiteralPath $legacyProfilePath -Value $legacyContent -Encoding UTF8

    Write-Host 'Test 1: install creates a managed profile without directory hijacking' -ForegroundColor Cyan
    Invoke-AutoSuggestionsSetup -ProfilePath $profilePath -StateDirectory $stateDirectory -SkipModules -SkipTerminalIcons -PredictionViewStyle InlineView -Force
    $installedText = Get-Content -LiteralPath $profilePath -Raw
    Assert-Match $installedText '# >>> powershell-auto-suggestions >>>' 'managed block is missing'
    Assert-NotMatch $installedText 'Set-Location\s+\$HOME' 'Set-Location $HOME must not be present'
    Assert-NotMatch $installedText 'Clear-Host' 'Clear-Host must not be present'
    [void][ScriptBlock]::Create($installedText)

    $snippetPath = Join-Path $stateDirectory 'auto-suggestions.ps1'
    Assert-True (Test-Path -LiteralPath $snippetPath) 'managed snippet was not created'
    $snippetText = Get-Content -LiteralPath $snippetPath -Raw
    Assert-Match $snippetText 'PSEdition -eq ''Core''' 'PowerShell edition capability check is missing'
    Assert-Match $snippetText 'PSVersion\.Major -gt 7' 'major version capability check is missing'
    Assert-Match $snippetText 'PSVersion\.Minor -ge 2' 'minor version capability check is missing'
    Assert-Match $snippetText 'PredictionSource \$__psasSource' 'dynamic prediction source is missing'
    Assert-NotMatch $snippetText 'Set-PSReadLineOption\s+-PredictionSource\s+HistoryAndPlugin' 'plugin predictions must not be set unconditionally'
    Assert-Match $snippetText 'PredictionViewStyle InlineView' 'prediction view style was not configured'
    Assert-Match $snippetText 'MenuComplete' 'tab completion was not configured'
    Assert-NotMatch $snippetText 'Import-Module Terminal-Icons' 'Terminal-Icons must not load when it is skipped'
    Assert-NotMatch $snippetText 'Set-Location\s+\$HOME' 'snippet must not change directory'
    Assert-NotMatch $snippetText 'Clear-Host' 'snippet must not clear the screen'
    [void][ScriptBlock]::Create($snippetText)

    Write-Host 'Test 2: reinstalling is idempotent' -ForegroundColor Cyan
    Invoke-AutoSuggestionsSetup -ProfilePath $profilePath -StateDirectory $stateDirectory -SkipModules -SkipTerminalIcons -PredictionViewStyle InlineView -Force
    $reinstalledText = Get-Content -LiteralPath $profilePath -Raw
    $markerCount = ([regex]::Matches($reinstalledText, [regex]::Escape('# >>> powershell-auto-suggestions >>>'))).Count
    Assert-True ($markerCount -eq 1) "expected exactly one managed block, found $markerCount"

    Write-Host 'Test 3: legacy broken profile is cleaned' -ForegroundColor Cyan
    Invoke-AutoSuggestionsSetup -ProfilePath $legacyProfilePath -StateDirectory $legacyStateDirectory -SkipModules -SkipTerminalIcons -Force
    $legacyText = Get-Content -LiteralPath $legacyProfilePath -Raw
    Assert-NotMatch $legacyText 'PowerShell Ultimate Setup Loaded' 'legacy banner should be removed'
    Assert-NotMatch $legacyText 'Set-Location\s+\$HOME' 'legacy Set-Location should be removed'
    Assert-NotMatch $legacyText 'Clear-Host' 'legacy Clear-Host should be removed'
    Assert-NotMatch $legacyText "Variable\s*=\s*'White'" 'legacy hardcoded colors should be removed'
    Assert-Match $legacyText '# >>> powershell-auto-suggestions >>>' 'managed block was not added to the legacy profile'
    Assert-Match $legacyText 'user-before' 'content before the legacy block should be preserved'
    Assert-Match $legacyText 'user-after' 'content after the legacy block should be preserved'
    Assert-NotMatch $legacyText 'PredictionSource\s+History\b' 'legacy prediction source should be removed'
    [void][ScriptBlock]::Create($legacyText)

    Write-Host 'Test 4: dry run writes nothing' -ForegroundColor Cyan
    Invoke-AutoSuggestionsSetup -ProfilePath $dryProfilePath -StateDirectory $dryStateDirectory -SkipModules -SkipTerminalIcons -DryRun
    Assert-False (Test-Path -LiteralPath $dryProfilePath) 'dry run must not create a profile'
    Assert-False (Test-Path -LiteralPath $dryStateDirectory) 'dry run must not create a state directory'

    Write-Host 'Test 5: uninstall removes the managed block and state' -ForegroundColor Cyan
    Invoke-AutoSuggestionsSetup -Uninstall -ProfilePath $profilePath -StateDirectory $stateDirectory
    Assert-False (Test-Path -LiteralPath $profilePath) 'a profile created by the installer should be removed on uninstall'
    Assert-False (Test-Path -LiteralPath (Join-Path $stateDirectory 'state.json')) 'state.json should be removed'
    Assert-False (Test-Path -LiteralPath (Join-Path $stateDirectory 'auto-suggestions.ps1')) 'managed snippet should be removed'

    Write-Host 'Test 6: user profile content is preserved' -ForegroundColor Cyan
    $userContent = @'
# user setting
$env:PSAS_USER = 'keep'
'@
    Set-Content -LiteralPath $userProfilePath -Value $userContent -Encoding UTF8
    Invoke-AutoSuggestionsSetup -ProfilePath $userProfilePath -StateDirectory $userStateDirectory -SkipModules -SkipTerminalIcons -Force
    $userInstalledText = Get-Content -LiteralPath $userProfilePath -Raw
    Assert-Match $userInstalledText 'user setting' 'user content should survive install'
    Assert-Match $userInstalledText 'PSAS_USER' 'user variable should survive install'
    Assert-Match $userInstalledText '# >>> powershell-auto-suggestions >>>' 'managed block should be added to an existing profile'

    Invoke-AutoSuggestionsSetup -Uninstall -ProfilePath $userProfilePath -StateDirectory $userStateDirectory
    Assert-True (Test-Path -LiteralPath $userProfilePath) 'an existing profile should not be deleted on uninstall'
    $userAfterText = Get-Content -LiteralPath $userProfilePath -Raw
    Assert-Match $userAfterText 'user setting' 'user content should survive uninstall'
    Assert-Match $userAfterText 'PSAS_USER' 'user variable should survive uninstall'
    Assert-NotMatch $userAfterText '# >>> powershell-auto-suggestions >>>' 'managed block should be removed from an existing profile'

    Write-Host 'Test 7: Terminal-Icons can be included or skipped' -ForegroundColor Cyan
    $tiStateDirectory = Join-Path $testRoot 'ti-state'
    $tiProfilePath = Join-Path $testRoot 'ti\Microsoft.PowerShell_profile.ps1'
    $tiSnippetPath = Join-Path $tiStateDirectory 'auto-suggestions.ps1'
    Invoke-AutoSuggestionsSetup -ProfilePath $tiProfilePath -StateDirectory $tiStateDirectory -SkipModules -Force
    $tiSnippetText = Get-Content -LiteralPath $tiSnippetPath -Raw
    Assert-Match $tiSnippetText 'Import-Module Terminal-Icons' 'Terminal-Icons import should be included by default'

    Invoke-AutoSuggestionsSetup -ProfilePath $tiProfilePath -StateDirectory $tiStateDirectory -SkipModules -SkipTerminalIcons -Force
    $tiSnippetText = Get-Content -LiteralPath $tiSnippetPath -Raw
    Assert-NotMatch $tiSnippetText 'Import-Module Terminal-Icons' 'Terminal-Icons import should be removed when skipped'

    Write-Host ''
    Write-Host 'All smoke tests passed.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
