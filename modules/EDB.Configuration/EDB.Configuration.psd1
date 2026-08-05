# EDB.Configuration
# YAML and JSON configuration loading for Enterprise Developer Bootstrap

@{
    RootModule           = 'EDB.Configuration.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'd4e5f6a7-b8c9-0123-def4-234567890123'
    Author               = 'Enterprise Platform Engineering'
    CompanyName          = 'Enterprise'
    Copyright            = '(c) Enterprise. All rights reserved.'
    Description          = 'Loads YAML and JSON package catalogs and settings for Enterprise Developer Bootstrap.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'Get-EdbConfigRoot',
        'Import-EdbYamlFile',
        'Import-EdbJsonFile',
        'Get-EdbPackageCatalog',
        'Get-EdbSettings',
        'Test-EdbPackageDefinition'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Enterprise', 'Bootstrap', 'Configuration', 'EDB')
            ReleaseNotes = 'Initial configuration module release.'
        }
    }
}
