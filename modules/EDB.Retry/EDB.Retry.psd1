# EDB.Retry
# Retry helpers for Enterprise Developer Bootstrap

@{
    RootModule           = 'EDB.Retry.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'd4e5f6a7-b8c9-0123-def0-234567890123'
    Author               = 'Enterprise Platform Engineering'
    CompanyName          = 'Enterprise'
    Copyright            = '(c) Enterprise. All rights reserved.'
    Description          = 'Retry and backoff utilities for Enterprise Developer Bootstrap.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'New-EdbRetryPolicy',
        'Invoke-EdbRetry'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Enterprise', 'Bootstrap', 'Retry', 'EDB')
            ReleaseNotes = 'Initial retry release.'
        }
    }
}
