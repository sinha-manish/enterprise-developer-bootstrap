@{
    RootModule           = 'EDB.Git.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'a1b2c3d4-e5f6-7890-abcd-ef1234567801'
    Author               = 'Enterprise Platform Engineering'
    CompanyName          = 'Enterprise'
    Copyright            = '(c) Enterprise. All rights reserved.'
    Description          = 'Git configuration and SSH key management for Enterprise Developer Bootstrap.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'Test-EdbGitInstalled',
        'Set-EdbGitConfiguration',
        'New-EdbSshKey'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags = @('Enterprise', 'Bootstrap', 'Git', 'EDB')
        }
    }
}
