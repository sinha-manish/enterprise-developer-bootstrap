#Requires -Version 7.0
using module '..\..\modules\EDB.Windows'

Describe 'EDB.Windows' {
    BeforeAll {
        $script:fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("edb-windows-tests-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:fixtureRoot -Force | Out-Null
        $script:pathEntry = Join-Path $script:fixtureRoot 'tools'
        New-Item -ItemType Directory -Path $script:pathEntry -Force | Out-Null
        $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:fixtureRoot) {
            Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'sets process-scoped environment variables' {
        $name = 'EDB_TEST_VAR_' + [guid]::NewGuid().ToString('N')
        $result = Set-EdbEnvironmentVariable -Name $name -Value 'edb-value' -Scope Process
        $result.Schema | Should -Be 'EDB.EnvironmentVariableResult'
        [Environment]::GetEnvironmentVariable($name, 'Process') | Should -Be 'edb-value'
    }

    It 'appends unique developer PATH entries' {
        $original = [Environment]::GetEnvironmentVariable('Path', 'Process')
        try {
            $result = Set-EdbDeveloperPath -PathEntries @($script:pathEntry) -Scope Process
            $resolvedEntry = (Resolve-Path -LiteralPath $script:pathEntry).Path
            $result.Added | Should -Contain $resolvedEntry
            $result.PathValue.Split(';') | Should -Contain $resolvedEntry
        }
        finally {
            [Environment]::SetEnvironmentVariable('Path', $original, 'Process')
        }
    }

    It 'returns WSL status structure without requiring distros' {
        $status = Test-EdbWslStatus
        Write-Host ($status | Format-List * | Out-String)
        $status.Schema | Should -Be 'EDB.WslStatus'
        $status.Available | Should -BeOfType [bool]
        $status.Installed | Should -BeOfType [bool]
        $status.Status | Should -BeIn @('Installed', 'Unavailable')
        ($null -ne $status.Distributions) | Should -BeTrue
        $status.PSObject.Properties.Name | Should -Contain 'Distributions'
    }

    It 'appends EDB profile snippet once' {
        $profilePath = Join-Path $script:fixtureRoot 'profile.ps1'
        $marker = '# EDB Enterprise Developer Bootstrap'

        $first = Install-EdbPowerShellProfile -RepositoryRoot $script:repoRoot -ProfilePath $profilePath
        $first.Updated | Should -BeTrue
        (Get-Content -LiteralPath $profilePath -Raw) | Should -Match $marker

        $again = Install-EdbPowerShellProfile -RepositoryRoot $script:repoRoot -ProfilePath $profilePath
        $again.Updated | Should -BeFalse
    }
}
