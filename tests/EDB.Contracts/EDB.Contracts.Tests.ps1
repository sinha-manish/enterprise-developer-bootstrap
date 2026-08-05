#Requires -Version 7.0
using module '..\..\modules\EDB.Contracts'

Describe 'EDB.Contracts' {
    It 'exports contract marker version' {
        [EdbContractsMarker]::GetVersion() | Should -Be '1.0.0'
    }

    It 'defines EdbLogLevel members' {
        [EdbLogLevel]::Information | Should -Be 2
        [EdbLogLevel]::Error | Should -Be 4
    }

    It 'defines EdbInstallStatus members' {
        [EdbInstallStatus]::Succeeded | Should -Be 2
        [EdbInstallStatus]::Failed | Should -Be 3
    }

    It 'defines EdbHealthStatus members' {
        [EdbHealthStatus]::Healthy | Should -Be 1
        [EdbHealthStatus]::Unhealthy | Should -Be 3
    }

    It 'loads abstract contract base types' {
        { [EdbLoggerBase] } | Should -Not -Throw
        { [EdbPackageProviderBase] } | Should -Not -Throw
        { [EdbPackageInstallerBase] } | Should -Not -Throw
        { [EdbRollbackActionBase] } | Should -Not -Throw
        { [EdbHealthCheckBase] } | Should -Not -Throw
        { [EdbReportWriterBase] } | Should -Not -Throw
    }

    It 'abstract logger requires override' {
        $base = [EdbLoggerBase]::new()
        { $base.Log([EdbLogLevel]::Information, 'x', @{}) } | Should -Throw -ExceptionType ([System.NotImplementedException])
    }
}
