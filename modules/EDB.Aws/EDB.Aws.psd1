@{
    RootModule           = 'EDB.Aws.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'a1b2c3d4-e5f6-7890-abcd-ef1234567813'
    Author               = 'Enterprise Platform Engineering'
    CompanyName          = 'Enterprise'
    Copyright            = '(c) Enterprise. All rights reserved.'
    Description          = 'AWS CLI installation checks and non-secret config helpers for Enterprise Developer Bootstrap.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'Test-EdbAwsCliInstalled',
        'Set-EdbAwsConfiguration'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{ PSData = @{ Tags = @('Enterprise', 'Bootstrap', 'AWS', 'EDB') } }
}
