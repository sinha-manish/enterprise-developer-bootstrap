# EDB.Health
# Post-install health checks for Enterprise Developer Bootstrap

@{
    RootModule           = 'EDB.Health.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'e5f6a7b8-c9d0-1234-ef01-345678901234'
    Author               = 'Enterprise Platform Engineering'
    CompanyName          = 'Enterprise'
    Copyright            = '(c) Enterprise. All rights reserved.'
    Description          = 'Post-install health checks for Enterprise Developer Bootstrap packages.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'New-EdbHealthCheck',
        'Invoke-EdbHealthCheck',
        'Invoke-EdbHealthCheckSet',
        'Test-EdbCommandAvailable',
        'Test-EdbValidateCommandIsSafe'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Enterprise', 'Bootstrap', 'Health', 'EDB')
            ReleaseNotes = 'Initial health check release.'
        }
    }
}
