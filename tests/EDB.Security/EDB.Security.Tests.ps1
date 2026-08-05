#Requires -Version 7.0
using module '..\..\modules\EDB.Security'

Describe 'EDB.Security' {
    BeforeAll {
        $script:fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("edb-security-tests-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:fixtureRoot -Force | Out-Null
        $script:sensitiveFile = Join-Path $script:fixtureRoot 'secret.txt'
        'edb-secret-content' | Set-Content -LiteralPath $script:sensitiveFile -Encoding UTF8
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:fixtureRoot) {
            Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'reports security baseline without disabling defender or bitlocker' {
        Mock Get-Service {
            param($Name)
            if ($Name -eq 'WinDefend') {
                return [pscustomobject]@{
                    Name   = 'WinDefend'
                    Status = 'Running'
                }
            }
            return $null
        } -ModuleName EDB.Security

        Mock Get-CimInstance {
            return @(
                [pscustomobject]@{
                    DriveLetter      = 'C:'
                    ProtectionStatus = 1
                    ConversionStatus = 1
                }
            )
        } -ModuleName EDB.Security

        $result = Assert-EdbSecurityBaseline
        $result.Schema | Should -Be 'EDB.SecurityBaselineResult'
        $result.Passed | Should -BeTrue
        ($result.Checks | Where-Object { $_.Name -eq 'WindowsDefenderServicePresent' }).Passed | Should -BeTrue
        ($result.Checks | Where-Object { $_.Name -eq 'BitLockerStatusReadable' }).Passed | Should -BeTrue
        ($result.Checks | Where-Object { $_.Name -eq 'NoDefenderDisablePolicyDetected' }).Message |
            Should -Match 'must not attempt to disable'
    }

    It 'throws when baseline fails and ThrowOnFailure is set' {
        Mock Get-Service { return $null } -ModuleName EDB.Security
        Mock Get-CimInstance { throw 'cim unavailable' } -ModuleName EDB.Security

        { Assert-EdbSecurityBaseline -ThrowOnFailure } | Should -Throw '*Security baseline checks failed*'
    }

    It 'restricts sensitive file ACL to the current user' {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $result = Protect-EdbSensitiveFile -Path $script:sensitiveFile
        $result.Schema | Should -Be 'EDB.SensitiveFileProtectionResult'
        $result.AllowedAccounts | Should -Contain $currentUser

        $acl = Get-Acl -LiteralPath $script:sensitiveFile
        $acl.AreAccessRulesProtected | Should -BeTrue

        $explicitAllow = @($acl.Access | Where-Object {
            $_.AccessControlType -eq 'Allow' -and -not $_.IsInherited
        })
        $explicitAllow | Should -Not -BeNullOrEmpty
        $explicitAllow | Where-Object { $_.IdentityReference.Value -eq $currentUser } | Should -Not -BeNullOrEmpty
        @($acl.Access | Where-Object { $_.IsInherited }).Count | Should -Be 0
    }
}
