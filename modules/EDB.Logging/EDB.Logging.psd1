# EDB.Logging
# Structured logging for Enterprise Developer Bootstrap

@{
    RootModule           = 'EDB.Logging.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'c3d4e5f6-a7b8-9012-cdef-123456789012'
    Author               = 'Enterprise Platform Engineering'
    CompanyName          = 'Enterprise'
    Copyright            = '(c) Enterprise. All rights reserved.'
    Description          = 'Structured file and console logging for Enterprise Developer Bootstrap.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'New-EdbLogger',
        'Write-EdbLog',
        'Get-EdbLogDirectory',
        'Get-EdbDefaultLogDirectory'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Enterprise', 'Bootstrap', 'Logging', 'EDB')
            ReleaseNotes = 'Initial logging release.'
        }
    }
}
