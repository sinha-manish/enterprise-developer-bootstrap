# EDB.Reports
# HTML and JSON report writers for Enterprise Developer Bootstrap

@{
    RootModule           = 'EDB.Reports.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'f6a7b8c9-d0e1-2345-f012-456789012345'
    Author               = 'Enterprise Platform Engineering'
    CompanyName          = 'Enterprise'
    Copyright            = '(c) Enterprise. All rights reserved.'
    Description          = 'HTML and JSON report writers for Enterprise Developer Bootstrap.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'New-EdbJsonReportWriter',
        'New-EdbHtmlReportWriter',
        'Export-EdbReport',
        'New-EdbInstallationSummary'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Enterprise', 'Bootstrap', 'Reports', 'EDB')
            ReleaseNotes = 'Initial report writer release.'
        }
    }
}
