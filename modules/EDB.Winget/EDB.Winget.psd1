# EDB.Winget
# Winget package provider for Enterprise Developer Bootstrap

@{
    RootModule           = 'EDB.Winget.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'e5f6a7b8-c9d0-1234-ef01-345678901234'
    Author               = 'Enterprise Platform Engineering'
    CompanyName          = 'Enterprise'
    Copyright            = '(c) Enterprise. All rights reserved.'
    Description          = 'Winget package provider for Enterprise Developer Bootstrap.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'New-EdbWingetProvider',
        'Install-EdbWingetIfMissing',
        'Test-EdbWingetPackageInstalled',
        'Install-EdbWingetPackage',
        'Uninstall-EdbWingetPackage',
        'Invoke-EdbWinget',
        'Set-EdbWingetInvokeCommand',
        'Reset-EdbWingetInvokeCommand'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Enterprise', 'Bootstrap', 'Winget', 'EDB')
            ReleaseNotes = 'Initial Winget provider release.'
        }
    }
}
