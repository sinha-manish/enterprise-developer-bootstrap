# EDB.Profiles
# Developer profile loading for Enterprise Developer Bootstrap

@{
    RootModule           = 'EDB.Profiles.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'b1c2d3e4-f5a6-7890-bcde-f12345678901'
    Author               = 'Enterprise Platform Engineering'
    CompanyName          = 'Enterprise'
    Copyright            = '(c) Enterprise. All rights reserved.'
    Description          = 'Loads developer profiles and resolves catalog packages for bootstrap sessions.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules      = @(
        @{ ModuleName = 'EDB.Configuration'; ModuleVersion = '1.0.0' }
        @{ ModuleName = 'EDB.InstallPipeline'; ModuleVersion = '1.0.0' }
    )
    FunctionsToExport    = @(
        'Get-EdbProfileList',
        'Get-EdbProfile',
        'Resolve-EdbProfilePackages'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Enterprise', 'Bootstrap', 'Profiles', 'EDB')
            ReleaseNotes = 'Initial profiles module release.'
        }
    }
}
