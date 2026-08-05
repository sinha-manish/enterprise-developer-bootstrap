# EDB.InstallPipeline
# Package install pipeline for Enterprise Developer Bootstrap

@{
    RootModule           = 'EDB.InstallPipeline.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'a7b8c9d0-e1f2-3456-0123-567890123456'
    Author               = 'Enterprise Platform Engineering'
    CompanyName          = 'Enterprise'
    Copyright            = '(c) Enterprise. All rights reserved.'
    Description          = 'Package install pipeline with dependency ordering and resume state.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'New-EdbPipelineState',
        'Save-EdbPipelineState',
        'Read-EdbPipelineState',
        'Resolve-EdbPackageOrder',
        'Resolve-EdbPackageWaves',
        'Resolve-EdbTrustedPostInstallScript',
        'Install-EdbPackageSet',
        'Show-EdbProgress'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Enterprise', 'Bootstrap', 'Pipeline', 'EDB')
            ReleaseNotes = 'Initial install pipeline release.'
        }
    }
}
