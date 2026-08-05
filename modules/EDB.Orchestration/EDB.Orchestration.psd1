# EDB.Orchestration
# Bootstrap orchestration for Enterprise Developer Bootstrap

@{
    RootModule           = 'EDB.Orchestration.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'c2d3e4f5-a6b7-8901-cdef-123456789012'
    Author               = 'Enterprise Platform Engineering'
    CompanyName          = 'Enterprise'
    Copyright            = '(c) Enterprise. All rights reserved.'
    Description          = 'End-to-end bootstrap orchestration for developer environment installation.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules      = @(
        @{ ModuleName = 'EDB.Configuration'; ModuleVersion = '1.0.0' }
        @{ ModuleName = 'EDB.Profiles'; ModuleVersion = '1.0.0' }
        @{ ModuleName = 'EDB.InstallPipeline'; ModuleVersion = '1.0.0' }
        @{ ModuleName = 'EDB.Logging'; ModuleVersion = '1.0.0' }
        @{ ModuleName = 'EDB.System'; ModuleVersion = '1.0.0' }
        @{ ModuleName = 'EDB.Winget'; ModuleVersion = '1.0.0' }
        @{ ModuleName = 'EDB.Chocolatey'; ModuleVersion = '1.0.0' }
        @{ ModuleName = 'EDB.Health'; ModuleVersion = '1.0.0' }
        @{ ModuleName = 'EDB.Reports'; ModuleVersion = '1.0.0' }
        @{ ModuleName = 'EDB.Rollback'; ModuleVersion = '1.0.0' }
        @{ ModuleName = 'EDB.Retry'; ModuleVersion = '1.0.0' }
    )
    FunctionsToExport    = @('Start-EdbBootstrap')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Enterprise', 'Bootstrap', 'Orchestration', 'EDB')
            ReleaseNotes = 'Initial orchestration module release.'
        }
    }
}
