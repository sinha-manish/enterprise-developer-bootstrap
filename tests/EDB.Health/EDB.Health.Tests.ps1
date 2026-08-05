#Requires -Version 7.0
using module '..\..\modules\EDB.Contracts'
using module '..\..\modules\EDB.Models'
using module '..\..\modules\EDB.Health'

Describe 'EDB.Health' {
    Context 'Test-EdbCommandAvailable' {
        It 'returns true for built-in commands' {
            Test-EdbCommandAvailable -Command 'Get-Command' | Should -BeTrue
        }

        It 'returns false for unknown commands' {
            Test-EdbCommandAvailable -Command 'edb-fake-command-not-real' | Should -BeFalse
        }
    }

    Context 'Test-EdbValidateCommandIsSafe' {
        It 'allows simple CLI invocations' {
            Test-EdbValidateCommandIsSafe -ValidateCommand 'git --version' | Should -BeTrue
            Test-EdbValidateCommandIsSafe -ValidateCommand 'notepad++ --version' | Should -BeTrue
        }

        It 'rejects scripts pipes and metacharacters' {
            Test-EdbValidateCommandIsSafe -ValidateCommand 'exit 0' | Should -BeFalse
            Test-EdbValidateCommandIsSafe -ValidateCommand 'code --list-extensions | Select-String x' | Should -BeFalse
            Test-EdbValidateCommandIsSafe -ValidateCommand 'Get-Process ChatGPT' | Should -BeFalse
        }
    }

    Context 'New-EdbHealthCheck' {
        It 'builds a check from a package definition validate command' {
            $pkg = New-EdbPackageDefinition -Id 'git' -DisplayName 'Git' -WingetId 'Git.Git' `
                -ValidateCommand 'git --version'
            $check = New-EdbHealthCheck -Name 'git-check' -PackageDefinition $pkg
            $check.Name | Should -Be 'git-check'
            $check.PackageId | Should -Be 'git'
            $check.ValidateCommand | Should -Be 'git --version'
        }
    }

    Context 'Invoke-EdbHealthCheck' {
        It 'marks healthy when validate command exits zero' {
            $check = New-EdbHealthCheck -Name 'ok-check' -PackageId 'demo' -ValidateCommand 'pwsh -v'
            $result = Invoke-EdbHealthCheck -HealthCheck $check
            $result.Status | Should -Be ([EdbHealthStatus]::Healthy)
            $result.Schema | Should -Be 'EDB.HealthCheckResult'
        }

        It 'marks unhealthy when command is missing' {
            $check = New-EdbHealthCheck -Name 'bad-check' -PackageId 'demo' -ValidateCommand 'edb-missing-health-bin --version'
            $result = Invoke-EdbHealthCheck -HealthCheck $check
            $result.Status | Should -Be ([EdbHealthStatus]::Unhealthy)
        }

        It 'marks unhealthy when validate command is unsafe inline script' {
            $check = New-EdbHealthCheck -Name 'unsafe' -PackageId 'demo' -ValidateCommand 'exit 0'
            $result = Invoke-EdbHealthCheck -HealthCheck $check
            $result.Status | Should -Be ([EdbHealthStatus]::Unhealthy)
            $result.Message | Should -Match 'rejected'
        }
    }

    Context 'Invoke-EdbHealthCheckSet' {
        It 'runs multiple checks and returns all results' {
            $checks = @(
                (New-EdbHealthCheck -Name 'one' -ValidateCommand 'pwsh -v')
                (New-EdbHealthCheck -Name 'two' -ValidateCommand 'edb-missing-health-bin')
            )
            $results = Invoke-EdbHealthCheckSet -HealthChecks $checks
            $results.Count | Should -Be 2
            $results[0].Status | Should -Be ([EdbHealthStatus]::Healthy)
            $results[1].Status | Should -Be ([EdbHealthStatus]::Unhealthy)
        }
    }
}
