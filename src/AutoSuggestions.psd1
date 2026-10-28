@{
    RootModule        = 'AutoSuggestions.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '23e12653-fdf5-419d-9ef0-7dd2c2175006'
    Author            = 'Ali Hamza'
    CompanyName       = 'Community'
    Copyright         = '(c) Ali Hamza. MIT License.'
    Description       = 'Safe installer, repair, status, and uninstall tooling for PowerShell auto suggestions.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Invoke-AutoSuggestionsSetup',
        'Show-AutoSuggestionsStatus',
        'Get-AutoSuggestionsPaths',
        'Get-AutoSuggestionsTargetProfiles',
        'Get-AutoSuggestionsVersion'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('PSReadLine', 'Productivity', 'Terminal', 'AutoSuggestions')
            LicenseUri = 'https://github.com/AliHamza-Coder/powershell-auto-suggestions/blob/main/LICENSE'
            ProjectUri = 'https://github.com/AliHamza-Coder/powershell-auto-suggestions'
        }
    }
}
