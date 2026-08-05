@{
    RootModule           = 'EDB.AI.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'a1b2c3d4-e5f6-7890-abcd-ef1234567818'
    Author               = 'Enterprise Platform Engineering'
    CompanyName          = 'Enterprise'
    Copyright            = '(c) Enterprise. All rights reserved.'
    Description          = 'Cursor/MCP AI tooling configuration for Enterprise Developer Bootstrap.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'Test-EdbCursorInstalled',
        'Set-EdbMcpConfiguration',
        'Install-EdbAiToolingNotes'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags = @('Enterprise', 'Bootstrap', 'AI', 'Cursor', 'MCP', 'EDB')
        }
    }
}
