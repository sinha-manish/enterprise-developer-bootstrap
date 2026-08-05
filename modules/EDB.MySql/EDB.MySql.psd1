@{
    RootModule           = 'EDB.MySql.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'a1b2c3d4-e5f6-7890-abcd-ef1234567811'
    Author               = 'Enterprise Platform Engineering'
    CompanyName          = 'Enterprise'
    Copyright            = '(c) Enterprise. All rights reserved.'
    Description          = 'MySQL client installation checks for Enterprise Developer Bootstrap.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @('Test-EdbMySqlInstalled')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{ PSData = @{ Tags = @('Enterprise', 'Bootstrap', 'MySql', 'EDB') } }
}
