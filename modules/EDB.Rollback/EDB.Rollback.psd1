# EDB.Rollback
# Rollback journal and best-effort uninstall for Enterprise Developer Bootstrap

@{
    RootModule           = 'EDB.Rollback.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'd4e5f6a7-b8c9-0123-def0-234567890123'
    Author               = 'Enterprise Platform Engineering'
    CompanyName          = 'Enterprise'
    Copyright            = '(c) Enterprise. All rights reserved.'
    Description          = 'Rollback journal and best-effort uninstall actions for Enterprise Developer Bootstrap.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'New-EdbRollbackJournal',
        'Add-EdbRollbackAction',
        'Invoke-EdbRollback',
        'Clear-EdbRollbackJournal'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Enterprise', 'Bootstrap', 'Rollback', 'EDB')
            ReleaseNotes = 'Initial rollback journal release.'
        }
    }
}
