#Requires -Version 7.0
using module '..\..\modules\EDB.Contracts'
using module '..\..\modules\EDB.Models'
using module '..\..\modules\EDB.System'

Describe 'EDB.System' {
    It 'returns OS info with build number' {
        $os = Get-EdbOperatingSystemInfo
        $os.Build | Should -BeGreaterThan 0
        $os.Caption | Should -Not -BeNullOrEmpty
    }

    It 'evaluates Windows compatibility from build' {
        $ok = [pscustomobject]@{ Build = 22621 }
        $bad = [pscustomobject]@{ Build = 14393 }
        Test-EdbWindowsCompatible -OsInfo $ok | Should -BeTrue
        Test-EdbWindowsCompatible -OsInfo $bad | Should -BeFalse
    }

    It 'detects administrator as boolean' {
        $isAdmin = Test-EdbIsAdministrator
        $isAdmin | Should -BeOfType ([bool])
    }

    It 'returns proxy configuration object' {
        $proxy = Get-EdbProxyConfiguration
        $proxy.Schema | Should -Be 'EDB.ProxyConfiguration'
        $proxy.Detected | Should -BeOfType ([bool])
    }

    It 'returns winget status object' {
        $status = Get-EdbWingetStatus
        $status.Available | Should -BeOfType ([bool])
    }

    It 'produces a preflight result' {
        $pf = Invoke-EdbPreflightCheck -SkipInternetCheck
        $pf.Schema | Should -Be 'EDB.PreflightResult'
        $pf.OsCaption | Should -Not -BeNullOrEmpty
    }
}
