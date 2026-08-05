#Requires -Version 7.0
using module '..\..\modules\EDB.Contracts'
using module '..\..\modules\EDB.Models'

Describe 'EDB.Orchestration' {
    BeforeAll {
        $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        $script:tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("edb-orchestration-tests-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
        . (Join-Path $script:repoRoot 'scripts\Initialize-EdbModulePath.ps1') -RepositoryRoot $script:repoRoot | Out-Null
        Import-Module EDB.Orchestration -Force
    }

    AfterAll {
        if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
            Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'runs WhatIf bootstrap without installing packages and without winget bootstrap (C2)' {
        Mock Invoke-EdbPreflightCheck -ModuleName EDB.Orchestration {
            New-EdbPreflightResult -IsWindows11OrCompatible:$true -OsCaption 'Test OS' -OsVersion '10.0.26200' `
                -IsAdministrator:$true -WingetAvailable:$true -WingetVersion '1.0' -InternetAvailable:$true
        }
        Mock Install-EdbWingetIfMissing -ModuleName EDB.Orchestration {
            throw 'Winget bootstrap must not run during WhatIf'
        }

        $result = Start-EdbBootstrap -Profile 'Frontend' -RepositoryRoot $script:repoRoot -WhatIf -SkipValidation
        $result.Schema | Should -Be 'EDB.BootstrapResult'
        $result.Session.ProfileName | Should -Be 'Frontend'
        ($result.Results | Where-Object { $_.Status -eq [EdbInstallStatus]::Skipped }).Count | Should -BeGreaterThan 0
        $result.PostConfigureActions | Should -Not -BeNullOrEmpty
        $result.PostConfigureActions[0].Status | Should -Be 'Skipped'
    }

    It 'generates report-only bootstrap output' {
        Mock Invoke-EdbPreflightCheck -ModuleName EDB.Orchestration {
            New-EdbPreflightResult -IsWindows11OrCompatible:$true -OsCaption 'Test OS' -OsVersion '10.0.26200' `
                -IsAdministrator:$false -WingetAvailable:$true -InternetAvailable:$true
        }

        $result = Start-EdbBootstrap -Profile 'Frontend' -RepositoryRoot $script:repoRoot -GenerateReportOnly -SkipValidation
        $result.Session.Status | Should -Be 'ReportOnly'
        $result.ReportPaths.Count | Should -BeGreaterThan 0
    }

    It 'marks session Failed when health checks are unhealthy (C7)' {
        Mock Install-EdbPackageSet -ModuleName EDB.Orchestration {
            @(New-EdbInstallResult -PackageId 'git' -Status ([EdbInstallStatus]::Succeeded) -Provider 'Winget')
        }
        Mock Invoke-EdbOrchestrationHealthChecks -ModuleName EDB.Orchestration {
            @(New-EdbHealthCheckResult -Name 'command:git' -Status ([EdbHealthStatus]::Unhealthy) -Message 'missing')
        }
        Mock Invoke-EdbPostConfigure -ModuleName EDB.Orchestration { @() }
        Mock Invoke-EdbPreflightCheck -ModuleName EDB.Orchestration {
            New-EdbPreflightResult -IsWindows11OrCompatible:$true -OsCaption 'Test OS' -OsVersion '10.0.26200' `
                -IsAdministrator:$true -WingetAvailable:$true -InternetAvailable:$true
        }
        Mock New-EdbOrchestrationProviders -ModuleName EDB.Orchestration { @{} }

        $result = Start-EdbBootstrap -Packages @('git') -RepositoryRoot $script:repoRoot
        $result.Session.Status | Should -Be 'Failed'
    }

    It 'resolves explicit package list through orchestration helpers' {
        . (Join-Path $script:repoRoot 'modules\EDB.Orchestration\EDB.Orchestration.Internal.ps1')
        $catalog = Get-EdbPackageCatalog -RepositoryRoot $script:repoRoot
        $resolved = Resolve-EdbOrchestrationPackages -Catalog $catalog -Packages @('git', 'gh')
        ($resolved | ForEach-Object { $_.Id }) | Should -Contain 'git'
        ($resolved | ForEach-Object { $_.Id }) | Should -Contain 'gh'
    }

    It 'throws when profile and packages are both omitted' {
        { Resolve-EdbOrchestrationPackages -Catalog @() -Profile $null -Packages @() } | Should -Throw
    }
}

Describe 'EDB.Orchestration catalog integration' {
    BeforeAll {
        $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        . (Join-Path $script:repoRoot 'scripts\Initialize-EdbModulePath.ps1') -RepositoryRoot $script:repoRoot | Out-Null
    }

    It 'loads the production catalog with expected package count' {
        $catalog = Get-EdbPackageCatalog -RepositoryRoot $script:repoRoot
        $catalog.Count | Should -Be 38
        ($catalog | Select-Object -First 1).Schema | Should -Be 'EDB.PackageDefinition'
    }

    It 'pins PostgreSQL to a versioned Winget id (C8)' {
        $catalog = Get-EdbPackageCatalog -RepositoryRoot $script:repoRoot
        $postgres = $catalog | Where-Object { $_.Id -eq 'postgres' }
        $postgres.WingetId | Should -Be 'PostgreSQL.PostgreSQL.16'
    }

    It 'loads default settings with parallel disabled' {
        $settings = Get-EdbSettings -RepositoryRoot $script:repoRoot
        $settings.Schema | Should -Be 'EDB.Settings'
        $settings.Parallel | Should -BeFalse
        $settings.RequireInternet | Should -BeTrue
    }
}
