# EDB.Models
# Domain models for Enterprise Developer Bootstrap

@{
    RootModule           = 'EDB.Models.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'b2c3d4e5-f6a7-8901-bcde-f12345678901'
    Author               = 'Enterprise Platform Engineering'
    CompanyName          = 'Enterprise'
    Copyright            = '(c) Enterprise. All rights reserved.'
    Description          = 'Domain models for the Enterprise Developer Bootstrap framework.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'New-EdbPackageDefinition',
        'New-EdbDeveloperProfile',
        'New-EdbInstallResult',
        'New-EdbInstallSession',
        'New-EdbPreflightResult',
        'New-EdbHealthCheckResult',
        'New-EdbLogEntry',
        'New-EdbReportDocument',
        'New-EdbPackageInstallRecord'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Enterprise', 'Bootstrap', 'Models', 'EDB')
            ReleaseNotes = 'Initial models release.'
        }
    }
}
