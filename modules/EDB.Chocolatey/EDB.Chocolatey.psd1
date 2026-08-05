# EDB.Chocolatey
# Optional Chocolatey package provider for Enterprise Developer Bootstrap

@{
    RootModule           = 'EDB.Chocolatey.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'f6a7b8c9-d0e1-2345-f012-456789012345'
    Author               = 'Enterprise Platform Engineering'
    CompanyName          = 'Enterprise'
    Copyright            = '(c) Enterprise. All rights reserved.'
    Description          = 'Optional Chocolatey package provider for Enterprise Developer Bootstrap.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'New-EdbChocolateyProvider',
        'Install-EdbChocolateyIfMissing',
        'Test-EdbChocolateyPackageInstalled',
        'Install-EdbChocolateyPackage',
        'Uninstall-EdbChocolateyPackage',
        'Invoke-EdbChocolatey',
        'Set-EdbChocolateyInvokeCommand',
        'Reset-EdbChocolateyInvokeCommand'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Enterprise', 'Bootstrap', 'Chocolatey', 'EDB')
            ReleaseNotes = 'Initial Chocolatey provider release.'
        }
    }
}
