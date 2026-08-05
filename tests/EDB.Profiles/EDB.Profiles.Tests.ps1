#Requires -Version 7.0
using module '..\..\modules\EDB.Contracts'
using module '..\..\modules\EDB.Models'
using module '..\..\modules\EDB.Configuration'
using module '..\..\modules\EDB.Profiles'

Describe 'EDB.Profiles' {
    BeforeAll {
        $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        . (Join-Path $script:repoRoot 'scripts\Initialize-EdbModulePath.ps1') -RepositoryRoot $script:repoRoot | Out-Null
    }

    It 'lists configured developer profiles' {
        $names = Get-EdbProfileList -RepositoryRoot $script:repoRoot
        $names | Should -Contain 'Backend'
        $names | Should -Contain 'DevOps'
        $names | Should -Contain 'AIEngineer'
        ($names | Measure-Object).Count | Should -BeGreaterOrEqual 7
    }

    It 'loads a profile with schema metadata' {
        $profile = Get-EdbProfile -Name 'Backend' -RepositoryRoot $script:repoRoot
        $profile.Schema | Should -Be 'EDB.DeveloperProfile'
        $profile.Name | Should -Be 'Backend'
        $profile.Packages | Should -Contain 'git'
        $profile.Packages | Should -Contain 'postgres'
    }

    It 'resolves profile packages from catalog with dependencies' {
        $catalog = Get-EdbPackageCatalog -RepositoryRoot $script:repoRoot
        $profile = Get-EdbProfile -Name 'DevOps' -RepositoryRoot $script:repoRoot
        $resolved = Resolve-EdbProfilePackages -Profile $profile -Catalog $catalog
        ($resolved | ForEach-Object { $_.Id }) | Should -Contain 'wsl'
        ($resolved | ForEach-Object { $_.Id }) | Should -Contain 'ubuntu'
        $wslIndex = [array]::IndexOf(($resolved | ForEach-Object { $_.Id }), 'wsl')
        $ubuntuIndex = [array]::IndexOf(($resolved | ForEach-Object { $_.Id }), 'ubuntu')
        $wslIndex | Should -BeLessThan $ubuntuIndex
    }

    It 'resolves AI profile packages including vscode extension metadata' {
        $catalog = Get-EdbPackageCatalog -RepositoryRoot $script:repoRoot
        $profile = Get-EdbProfile -Name 'AIEngineer' -RepositoryRoot $script:repoRoot
        $resolved = Resolve-EdbProfilePackages -Profile $profile -Catalog $catalog
        $copilot = $resolved | Where-Object { $_.Id -eq 'githubcopilot' } | Select-Object -First 1
        $copilot.Metadata.installType | Should -Be 'vscodeExtension'
        $copilot.Metadata.extensionId | Should -Be 'GitHub.copilot'
    }

    It 'throws when profile references unknown package ids' {
        $catalog = Get-EdbPackageCatalog -RepositoryRoot $script:repoRoot
        $badProfile = New-EdbDeveloperProfile -Name 'Broken' -Packages @('does-not-exist')
        { Resolve-EdbProfilePackages -Profile $badProfile -Catalog $catalog } | Should -Throw "*unknown package*"
    }
}
