# EDB.System
# Host environment detection for Enterprise Developer Bootstrap

@{
    RootModule           = 'EDB.System.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'e5f6a7b8-c9d0-1234-ef01-345678901234'
    Author               = 'Enterprise Platform Engineering'
    CompanyName          = 'Enterprise'
    Copyright            = '(c) Enterprise. All rights reserved.'
    Description          = 'Windows host, proxy, internet, and privilege detection for EDB.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'Test-EdbIsAdministrator',
        'Get-EdbOperatingSystemInfo',
        'Test-EdbWindowsCompatible',
        'Test-EdbInternetAccess',
        'Get-EdbProxyConfiguration',
        'Get-EdbWingetStatus',
        'Invoke-EdbPreflightCheck'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Enterprise', 'Bootstrap', 'System', 'EDB')
            ReleaseNotes = 'Initial system detection release.'
        }
    }
}
