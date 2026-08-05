#Requires -Version 7.0
using module '..\..\modules\EDB.Contracts'
using module '..\..\modules\EDB.Models'
using module '..\..\modules\EDB.Chocolatey'

Describe 'EDB.Chocolatey' {
    BeforeEach {
        Reset-EdbChocolateyInvokeCommand
    }

    AfterAll {
        Reset-EdbChocolateyInvokeCommand
    }

    It 'creates a provider implementing EdbPackageProviderBase' {
        $provider = New-EdbChocolateyProvider
        $provider | Should -BeOfType ([EdbChocolateyProvider])
        ($provider -is [EdbPackageProviderBase]) | Should -BeTrue
        $provider.Name | Should -Be 'Chocolatey'
    }

    It 'detects installed packages via mocked choco list' {
        Set-EdbChocolateyInvokeCommand {
            param([string[]]$ArgumentList)
            [pscustomobject]@{
                Schema    = 'EDB.ChocolateyInvocationResult'
                ExitCode  = 0
                Output    = "git 2.44.0`n"
                Arguments = @($ArgumentList)
                Succeeded = $true
            }
        }

        Test-EdbChocolateyPackageInstalled -PackageId 'git' | Should -BeTrue
        Test-EdbChocolateyPackageInstalled -PackageId 'missing' | Should -BeFalse
    }

    It 'installs packages with non-interactive flags' {
        $capturedArgs = [System.Collections.Generic.List[string]]::new()
        Set-EdbChocolateyInvokeCommand {
            param([string[]]$ArgumentList)
            $capturedArgs.Clear()
            foreach ($argument in $ArgumentList) {
                $capturedArgs.Add($argument) | Out-Null
            }

            if ($ArgumentList -contains 'list') {
                return [pscustomobject]@{
                    Schema    = 'EDB.ChocolateyInvocationResult'
                    ExitCode  = 0
                    Output    = ''
                    Arguments = @($ArgumentList)
                    Succeeded = $true
                }
            }

            [pscustomobject]@{
                Schema    = 'EDB.ChocolateyInvocationResult'
                ExitCode  = 0
                Output    = 'Installed'
                Arguments = @($ArgumentList)
                Succeeded = $true
            }
        }

        $result = Install-EdbChocolateyPackage -PackageId 'git'
        $result.Status | Should -Be ([EdbInstallStatus]::Succeeded)
        $capturedArgs | Should -Contain 'install'
        $capturedArgs | Should -Contain '-y'
        $capturedArgs | Should -Contain '--no-progress'
        $capturedArgs | Should -Contain 'git'
    }

    It 'skips install when package is already installed' {
        Set-EdbChocolateyInvokeCommand {
            param([string[]]$ArgumentList)
            if ($ArgumentList -contains 'list') {
                return [pscustomobject]@{
                    Schema    = 'EDB.ChocolateyInvocationResult'
                    ExitCode  = 0
                    Output    = "git 2.44.0`n"
                    Arguments = @($ArgumentList)
                    Succeeded = $true
                }
            }

            throw 'Install should not be invoked when package is already installed.'
        }

        $result = Install-EdbChocolateyPackage -PackageId 'git'
        $result.Status | Should -Be ([EdbInstallStatus]::Skipped)
        $result.Provider | Should -Be 'Chocolatey'
    }

    It 'returns failed install result when choco exits non-zero' {
        Set-EdbChocolateyInvokeCommand {
            param([string[]]$ArgumentList)
            if ($ArgumentList -contains 'list') {
                return [pscustomobject]@{
                    Schema    = 'EDB.ChocolateyInvocationResult'
                    ExitCode  = 0
                    Output    = ''
                    Arguments = @($ArgumentList)
                    Succeeded = $true
                }
            }

            [pscustomobject]@{
                Schema    = 'EDB.ChocolateyInvocationResult'
                ExitCode  = 1
                Output    = 'Install failed'
                Arguments = @($ArgumentList)
                Succeeded = $false
            }
        }

        $result = Install-EdbChocolateyPackage -PackageId 'broken'
        $result.Status | Should -Be ([EdbInstallStatus]::Failed)
        $result.ExitCode | Should -Be 1
    }

    It 'uninstalls packages and skips when not installed' {
        $calls = [System.Collections.Generic.List[string]]::new()
        Set-EdbChocolateyInvokeCommand {
            param([string[]]$ArgumentList)
            $calls.Add(($ArgumentList -join ' ')) | Out-Null

            if ($ArgumentList -contains 'list') {
                $packageId = $ArgumentList[-1]
                return [pscustomobject]@{
                    Schema    = 'EDB.ChocolateyInvocationResult'
                    ExitCode  = 0
                    Output    = if ($packageId -eq 'git') { "git 2.44.0`n" } else { '' }
                    Arguments = @($ArgumentList)
                    Succeeded = $true
                }
            }

            [pscustomobject]@{
                Schema    = 'EDB.ChocolateyInvocationResult'
                ExitCode  = 0
                Output    = 'Uninstalled'
                Arguments = @($ArgumentList)
                Succeeded = $true
            }
        }

        $missing = Uninstall-EdbChocolateyPackage -PackageId 'missing'
        $missing.Status | Should -Be ([EdbInstallStatus]::Skipped)

        $removed = Uninstall-EdbChocolateyPackage -PackageId 'git'
        $removed.Status | Should -Be ([EdbInstallStatus]::Succeeded)
        ($calls | Where-Object { $_ -match 'uninstall' }).Count | Should -Be 1
    }

    It 'reports already present for Install-EdbChocolateyIfMissing when choco exists' {
        if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
            Set-ItResult -Inconclusive -Because 'Chocolatey is not available on this host.'
            return
        }

        $bootstrap = Install-EdbChocolateyIfMissing
        $bootstrap.Success | Should -BeTrue
        $bootstrap.AlreadyPresent | Should -BeTrue
        $bootstrap.Installed | Should -BeFalse
    }

    It 'delegates provider methods to package cmdlets' {
        Set-EdbChocolateyInvokeCommand {
            param([string[]]$ArgumentList)
            if ($ArgumentList -contains 'list') {
                return [pscustomobject]@{
                    Schema    = 'EDB.ChocolateyInvocationResult'
                    ExitCode  = 0
                    Output    = ''
                    Arguments = @($ArgumentList)
                    Succeeded = $true
                }
            }

            [pscustomobject]@{
                Schema    = 'EDB.ChocolateyInvocationResult'
                ExitCode  = 0
                Output    = 'Installed'
                Arguments = @($ArgumentList)
                Succeeded = $true
            }
        }

        $provider = New-EdbChocolateyProvider
        $provider.IsPackageInstalled('git') | Should -BeFalse
        $install = $provider.InstallPackage('git', @{ })
        $install.Status | Should -Be ([EdbInstallStatus]::Succeeded)
    }
}
