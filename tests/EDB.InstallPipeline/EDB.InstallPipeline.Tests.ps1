#Requires -Version 7.0
using module '..\..\modules\EDB.Contracts'
using module '..\..\modules\EDB.Models'
using module '..\..\modules\EDB.Logging'
using module '..\..\modules\EDB.Retry'
using module '..\..\modules\EDB.InstallPipeline'

Describe 'EDB.InstallPipeline' {
    BeforeAll {
        $script:TempLogDir = Join-Path ([System.IO.Path]::GetTempPath()) ("edb-pipeline-tests-{0}" -f [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:TempLogDir -Force | Out-Null
        $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
    }

    AfterAll {
        if ($script:TempLogDir -and (Test-Path -LiteralPath $script:TempLogDir)) {
            Remove-Item -LiteralPath $script:TempLogDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Resolve-EdbPackageOrder' {
        It 'topologically sorts dependencies' {
            $packages = @(
                (New-EdbPackageDefinition -Id 'app' -DisplayName 'app' -WingetId 'Test.app' -DependsOn @('runtime'))
                (New-EdbPackageDefinition -Id 'runtime' -DisplayName 'runtime' -WingetId 'Test.runtime')
                (New-EdbPackageDefinition -Id 'sdk' -DisplayName 'sdk' -WingetId 'Test.sdk' -DependsOn @('runtime'))
            )
            $ordered = Resolve-EdbPackageOrder -Packages $packages
            ($ordered | ForEach-Object { $_.Id }) | Should -Be @('runtime', 'app', 'sdk')
        }

        It 'throws on circular dependencies' {
            $packages = @(
                (New-EdbPackageDefinition -Id 'a' -DisplayName 'a' -WingetId 'Test.a' -DependsOn @('b'))
                (New-EdbPackageDefinition -Id 'b' -DisplayName 'b' -WingetId 'Test.b' -DependsOn @('a'))
            )
            { Resolve-EdbPackageOrder -Packages $packages } | Should -Throw -ExpectedMessage '*Circular*'
        }
    }

    Context 'Resolve-EdbPackageWaves' {
        It 'builds dependency waves and separates AllowParallel' {
            $packages = @(
                (New-EdbPackageDefinition -Id 'wsl' -DisplayName 'wsl' -WingetId 'Test.wsl' -AllowParallel:$false)
                (New-EdbPackageDefinition -Id 'ubuntu' -DisplayName 'ubuntu' -WingetId 'Test.ubuntu' -DependsOn @('wsl') -AllowParallel:$true)
                (New-EdbPackageDefinition -Id 'git' -DisplayName 'git' -WingetId 'Test.git' -AllowParallel:$true)
            )
            $ordered = Resolve-EdbPackageOrder -Packages $packages
            $waves = Resolve-EdbPackageWaves -OrderedPackages $ordered
            $waves.Count | Should -Be 2
            ($waves[0].Packages | ForEach-Object { $_.Id }) | Should -Contain 'wsl'
            ($waves[0].Packages | ForEach-Object { $_.Id }) | Should -Contain 'git'
            ($waves[0].SerialPackages | ForEach-Object { $_.Id }) | Should -Contain 'wsl'
            ($waves[1].Packages | ForEach-Object { $_.Id }) | Should -Be @('ubuntu')
        }
    }

    Context 'Resolve-EdbTrustedPostInstallScript' {
        It 'rejects inline script content' {
            {
                Resolve-EdbTrustedPostInstallScript -PostInstallScript "Write-Host 'hi'`nexit 1" -RepositoryRoot $script:RepoRoot
            } | Should -Throw -ExpectedMessage '*Inline*'
        }

        It 'rejects paths outside scripts/trusted' {
            {
                Resolve-EdbTrustedPostInstallScript -PostInstallScript 'scripts/Invoke-EdbTests.ps1' -RepositoryRoot $script:RepoRoot
            } | Should -Throw -ExpectedMessage '*scripts/trusted*'
        }

        It 'accepts scripts under scripts/trusted' {
            $path = Resolve-EdbTrustedPostInstallScript -PostInstallScript 'scripts/trusted/example-noop.ps1' -RepositoryRoot $script:RepoRoot
            $path | Should -Match 'example-noop\.ps1$'
        }
    }

    Context 'Pipeline state' {
        It 'saves and reads state from logs directory' {
            $session = New-EdbInstallSession -ProfileName 'StateTest'
            $state = New-EdbPipelineState -Session $session -LogDirectory $script:TempLogDir
            $state.CompletedPackages.Add('git') | Out-Null
            Save-EdbPipelineState -State $state | Should -Be $state.StatePath
            Test-Path -LiteralPath $state.StatePath | Should -BeTrue

            $loaded = Read-EdbPipelineState -Path $state.StatePath
            $loaded.SessionId | Should -Be $session.SessionId
            $loaded.CompletedPackages | Should -Be @('git')
            $loaded.Schema | Should -Be 'EDB.PipelineState'
        }
    }

    Context 'Install-EdbPackageSet' {
        It 'skips packages already completed in state' {
            $packages = @(
                (New-EdbPackageDefinition -Id 'git' -DisplayName 'git' -WingetId 'Test.git')
                (New-EdbPackageDefinition -Id 'node' -DisplayName 'node' -WingetId 'Test.node')
            )
            $session = New-EdbInstallSession -ProfileName 'SkipTest'
            $state = New-EdbPipelineState -Session $session -LogDirectory $script:TempLogDir
            $state.CompletedPackages.Add('git') | Out-Null

            $winget = [PSCustomObject]@{ Name = 'Winget' }
            $winget | Add-Member -MemberType ScriptMethod -Name IsAvailable -Value { $true }
            $winget | Add-Member -MemberType ScriptMethod -Name IsPackageInstalled -Value { param([string]$PackageId) $false }
            $winget | Add-Member -MemberType ScriptMethod -Name InstallPackage -Value {
                param([string]$PackageId, [hashtable]$Options)
                New-EdbInstallResult -PackageId $Options.PackageId -Status ([EdbInstallStatus]::Succeeded) -Provider 'Winget'
            }
            $winget | Add-Member -MemberType ScriptMethod -Name UninstallPackage -Value {
                param([string]$PackageId, [hashtable]$Options)
                @{ Removed = $PackageId }
            }

            $results = Install-EdbPackageSet -Packages $packages -Providers @{ Winget = $winget } -State $state

            ($results | Where-Object { $_.PackageId -eq 'git' }).Status | Should -Be ([EdbInstallStatus]::Skipped)
            ($results | Where-Object { $_.PackageId -eq 'node' }).Status | Should -Be ([EdbInstallStatus]::Succeeded)
        }

        It 'propagates provider Failed status instead of Succeeded (C1)' {
            $packages = @(New-EdbPackageDefinition -Id 'broken' -DisplayName 'broken' -WingetId 'Test.broken')
            $winget = [PSCustomObject]@{ Name = 'Winget' }
            $winget | Add-Member -MemberType ScriptMethod -Name IsAvailable -Value { $true }
            $winget | Add-Member -MemberType ScriptMethod -Name IsPackageInstalled -Value { param([string]$PackageId) $false }
            $winget | Add-Member -MemberType ScriptMethod -Name InstallPackage -Value {
                param([string]$PackageId, [hashtable]$Options)
                New-EdbInstallResult -PackageId $Options.PackageId -Status ([EdbInstallStatus]::Failed) `
                    -Provider 'Winget' -Message 'Winget install failed with exit code 1.' -ExitCode 1
            }
            $winget | Add-Member -MemberType ScriptMethod -Name UninstallPackage -Value {
                param([string]$PackageId, [hashtable]$Options)
                @{ Removed = $PackageId }
            }

            $results = Install-EdbPackageSet -Packages $packages -Providers @{ Winget = $winget } `
                -RetryPolicy (New-EdbRetryPolicy -MaxAttempts 1)
            $results[0].Status | Should -Be ([EdbInstallStatus]::Failed)
            $results[0].Message | Should -Match 'failed'
        }

        It 'runs provider install before trusted PostInstallScript (C6)' {
            $packages = @(New-EdbPackageDefinition -Id 'withpost' -DisplayName 'withpost' -WingetId 'Test.withpost' `
                    -PostInstallScript 'scripts/trusted/example-noop.ps1')
            $script:providerCalled = $false
            $winget = [PSCustomObject]@{ Name = 'Winget' }
            $winget | Add-Member -MemberType ScriptMethod -Name IsAvailable -Value { $true }
            $winget | Add-Member -MemberType ScriptMethod -Name IsPackageInstalled -Value { param([string]$PackageId) $false }
            $winget | Add-Member -MemberType ScriptMethod -Name InstallPackage -Value {
                param([string]$PackageId, [hashtable]$Options)
                $script:providerCalled = $true
                New-EdbInstallResult -PackageId $Options.PackageId -Status ([EdbInstallStatus]::Succeeded) -Provider 'Winget'
            }
            $winget | Add-Member -MemberType ScriptMethod -Name UninstallPackage -Value {
                param([string]$PackageId, [hashtable]$Options)
                @{ Removed = $PackageId }
            }

            $results = Install-EdbPackageSet -Packages $packages -Providers @{ Winget = $winget } `
                -RepositoryRoot $script:RepoRoot -RetryPolicy (New-EdbRetryPolicy -MaxAttempts 1)
            $script:providerCalled | Should -BeTrue
            $results[0].Status | Should -Be ([EdbInstallStatus]::Succeeded)
        }

        It 'supports WhatIf dry run without installing' {
            $packages = @(New-EdbPackageDefinition -Id 'dryrun' -DisplayName 'dryrun' -WingetId 'Test.dryrun')
            $winget = [PSCustomObject]@{ Name = 'Winget' }
            $winget | Add-Member -MemberType ScriptMethod -Name IsAvailable -Value { $true }
            $winget | Add-Member -MemberType ScriptMethod -Name IsPackageInstalled -Value { param([string]$PackageId) $false }
            $winget | Add-Member -MemberType ScriptMethod -Name InstallPackage -Value {
                param([string]$PackageId, [hashtable]$Options)
                throw 'should not install'
            }
            $winget | Add-Member -MemberType ScriptMethod -Name UninstallPackage -Value {
                param([string]$PackageId, [hashtable]$Options)
                @{ Removed = $PackageId }
            }

            $results = Install-EdbPackageSet -Packages $packages -Providers @{ Winget = $winget } -WhatIf
            $results.Count | Should -Be 1
            $results[0].Status | Should -Be ([EdbInstallStatus]::Skipped)
            $results[0].Provider | Should -Be 'WhatIf'
        }
    }
}
