@{
    RootModule           = 'EDB.VSCode.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'a1b2c3d4-e5f6-7890-abcd-ef1234567802'
    Author               = 'Enterprise Platform Engineering'
    CompanyName          = 'Enterprise'
    Copyright            = '(c) Enterprise. All rights reserved.'
    Description          = 'Visual Studio Code settings and extension management for Enterprise Developer Bootstrap.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'Get-EdbVSCodePaths',
        'Set-EdbVSCodeSettings',
        'Install-EdbVSCodeExtension',
        'Install-EdbDefaultVSCodeExtensions'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags = @('Enterprise', 'Bootstrap', 'VSCode', 'EDB')
        }
    }
}
