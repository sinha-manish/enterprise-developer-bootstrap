@{
    RootModule           = 'EDB.Azure.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'a1b2c3d4-e5f6-7890-abcd-ef1234567814'
    Author               = 'Enterprise Platform Engineering'
    CompanyName          = 'Enterprise'
    Copyright            = '(c) Enterprise. All rights reserved.'
    Description          = 'Azure CLI installation checks and non-secret config helpers for Enterprise Developer Bootstrap.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'Test-EdbAzureCliInstalled',
        'Set-EdbAzureConfiguration'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{ PSData = @{ Tags = @('Enterprise', 'Bootstrap', 'Azure', 'EDB') } }
}
