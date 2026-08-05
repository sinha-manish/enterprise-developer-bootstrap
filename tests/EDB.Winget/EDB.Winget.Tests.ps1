#Requires -Version 7.0
using module '..\..\modules\EDB.Contracts'
using module '..\..\modules\EDB.Models'
using module '..\..\modules\EDB.Winget'

Describe 'EDB.Winget' {
    BeforeEach {
        Reset-EdbWingetInvokeCommand
    }

    AfterAll {
        Reset-EdbWingetInvokeCommand
    }

    It 'creates a provider implementing EdbPackageProviderBase' {
        $provider = New-EdbWingetProvider
        $provider | Should -BeOfType ([EdbWingetProvider])
        ($provider -is [EdbPackageProviderBase]) | Should -BeTrue
        $provider.Name | Should -Be 'Winget'
    }

    It 'detects installed packages via mocked winget list' {
        Set-EdbWingetInvokeCommand {
            param([string[]]$ArgumentList)
            [pscustomobject]@{
                Schema    = 'EDB.WingetInvocationResult'
                ExitCode  = 0
                Output    = "Name Id`nGit Git.Git"
                Arguments = @($ArgumentList)
                Succeeded = $true
            }
        }

        Test-EdbWingetPackageInstalled -PackageId 'Git.Git' | Should -BeTrue
        Test-EdbWingetPackageInstalled -PackageId 'Contoso.Missing' | Should -BeFalse
    }

    It 'includes non-interactive agreement flags on install' {
        $capturedArgs = [System.Collections.Generic.List[string]]::new()
        Set-EdbWingetInvokeCommand {
            param([string[]]$ArgumentList)
            $capturedArgs.Clear()
            foreach ($argument in $ArgumentList) {
                $capturedArgs.Add($argument) | Out-Null
            }

            [pscustomobject]@{
                Schema    = 'EDB.WingetInvocationResult'
                ExitCode  = 0
                Output    = ''
                Arguments = @($ArgumentList)
                Succeeded = $true
            }
        }

        Install-EdbWingetPackage -PackageId 'Git.Git' | Out-Null
        $capturedArgs | Should -Contain '--accept-package-agreements'
        $capturedArgs | Should -Contain '--accept-source-agreements'
        $capturedArgs | Should -Contain '--disable-interactivity'
        $capturedArgs | Should -Contain 'install'
        $capturedArgs | Should -Contain '--id'
        $capturedArgs | Should -Contain 'Git.Git'
    }

    It 'skips install when package is already installed' {
        Set-EdbWingetInvokeCommand {
            param([string[]]$ArgumentList)
            if ($ArgumentList -contains 'list') {
                return [pscustomobject]@{
                    Schema    = 'EDB.WingetInvocationResult'
                    ExitCode  = 0
                    Output    = 'Git.Git'
                    Arguments = @($ArgumentList)
                    Succeeded = $true
                }
            }

            throw 'Install should not be invoked when package is already installed.'
        }

        $result = Install-EdbWingetPackage -PackageId 'Git.Git'
        $result.Status | Should -Be ([EdbInstallStatus]::Skipped)
        $result.Provider | Should -Be 'Winget'
    }

    It 'returns failed install result when winget exits non-zero' {
        Set-EdbWingetInvokeCommand {
            param([string[]]$ArgumentList)
            if ($ArgumentList -contains 'list') {
                return [pscustomobject]@{
                    Schema    = 'EDB.WingetInvocationResult'
                    ExitCode  = 0
                    Output    = ''
                    Arguments = @($ArgumentList)
                    Succeeded = $true
                }
            }

            [pscustomobject]@{
                Schema    = 'EDB.WingetInvocationResult'
                ExitCode  = 1603
                Output    = 'Install failed'
                Arguments = @($ArgumentList)
                Succeeded = $false
            }
        }

        $result = Install-EdbWingetPackage -PackageId 'Contoso.App'
        $result.Status | Should -Be ([EdbInstallStatus]::Failed)
        $result.ExitCode | Should -Be 1603
    }

    It 'uninstalls packages and skips when not installed' {
        $calls = [System.Collections.Generic.List[string]]::new()
        Set-EdbWingetInvokeCommand {
            param([string[]]$ArgumentList)
            $calls.Add(($ArgumentList -join ' ')) | Out-Null

            if ($ArgumentList -contains 'list') {
                $idIndex = [Array]::IndexOf($ArgumentList, '--id')
                $packageId = if ($idIndex -ge 0 -and ($idIndex + 1) -lt $ArgumentList.Count) {
                    $ArgumentList[$idIndex + 1]
                }
                else {
                    ''
                }

                return [pscustomobject]@{
                    Schema    = 'EDB.WingetInvocationResult'
                    ExitCode  = 0
                    Output    = if ($packageId -eq 'Git.Git') { 'Git.Git' } else { '' }
                    Arguments = @($ArgumentList)
                    Succeeded = $true
                }
            }

            [pscustomobject]@{
                Schema    = 'EDB.WingetInvocationResult'
                ExitCode  = 0
                Output    = 'Uninstalled'
                Arguments = @($ArgumentList)
                Succeeded = $true
            }
        }

        $missing = Uninstall-EdbWingetPackage -PackageId 'Contoso.Missing'
        $missing.Status | Should -Be ([EdbInstallStatus]::Skipped)

        $removed = Uninstall-EdbWingetPackage -PackageId 'Git.Git'
        $removed.Status | Should -Be ([EdbInstallStatus]::Succeeded)
        ($calls | Where-Object { $_ -match 'uninstall' }).Count | Should -Be 1
    }

    It 'reports already present for Install-EdbWingetIfMissing when winget exists' {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Set-ItResult -Inconclusive -Because 'winget is not available on this host.'
            return
        }

        $bootstrap = Install-EdbWingetIfMissing
        $bootstrap.Success | Should -BeTrue
        $bootstrap.AlreadyPresent | Should -BeTrue
        $bootstrap.Installed | Should -BeFalse
    }

    It 'delegates provider methods to package cmdlets' {
        Set-EdbWingetInvokeCommand {
            param([string[]]$ArgumentList)
            if ($ArgumentList -contains 'list') {
                return [pscustomobject]@{
                    Schema    = 'EDB.WingetInvocationResult'
                    ExitCode  = 0
                    Output    = ''
                    Arguments = @($ArgumentList)
                    Succeeded = $true
                }
            }

            [pscustomobject]@{
                Schema    = 'EDB.WingetInvocationResult'
                ExitCode  = 0
                Output    = 'Installed'
                Arguments = @($ArgumentList)
                Succeeded = $true
            }
        }

        $provider = New-EdbWingetProvider
        $provider.IsPackageInstalled('Git.Git') | Should -BeFalse
        $install = $provider.InstallPackage('Git.Git', @{ })
        $install.Status | Should -Be ([EdbInstallStatus]::Succeeded)
    }
}
