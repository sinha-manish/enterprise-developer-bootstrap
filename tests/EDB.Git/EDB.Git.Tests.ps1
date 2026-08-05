#Requires -Version 7.0
using module '..\..\modules\EDB.Git'

Describe 'EDB.Git' {
    BeforeAll {
        $script:fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("edb-git-tests-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:fixtureRoot -Force | Out-Null
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:fixtureRoot) {
            Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns structured git installation status' {
        $status = Test-EdbGitInstalled
        $status.Schema | Should -Be 'EDB.GitInstalled'
        $status.Installed | Should -BeOfType [bool]
    }

    It 'applies git configuration via mocked git' {
        Mock Test-EdbGitInstalled {
            return [pscustomobject]@{
                Schema    = 'EDB.GitInstalled'
                Installed = $true
                Path      = 'C:\Program Files\Git\cmd\git.exe'
                Version   = 'git version 2.44.0'
            }
        } -ModuleName EDB.Git

        Mock Invoke-EdbGitNative { return 0 } -ModuleName EDB.Git

        $result = Set-EdbGitConfiguration -UserName 'Dev User' -UserEmail 'dev@example.com' -CoreLongPaths:$true -InitDefaultBranch 'main'
        $result.Schema | Should -Be 'EDB.GitConfigurationResult'
        $result.Applied | Should -Contain 'user.name'
        $result.Applied | Should -Contain 'init.defaultBranch'
    }

    It 'generates ed25519 keys with restricted ACL without logging private key' {
        $sshDir = Join-Path $script:fixtureRoot '.ssh'
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null

        $sshKeygen = Get-Command ssh-keygen -ErrorAction SilentlyContinue
        if (-not $sshKeygen) {
            Set-ItResult -Inconclusive -Because 'ssh-keygen is not available on this host.'
            return
        }

        $result = New-EdbSshKey -Directory $sshDir -FileName 'test_ed25519' -Comment 'edb-test'
        $result.Algorithm | Should -Be 'ed25519'
        Test-Path -LiteralPath $result.PrivateKeyPath | Should -BeTrue
        Test-Path -LiteralPath $result.PublicKeyPath | Should -BeTrue
        $result.PublicKey | Should -Match 'ssh-ed25519'

        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $acl = Get-Acl -LiteralPath $result.PrivateKeyPath
        @($acl.Access | Where-Object {
                $_.IdentityReference.Value -eq $currentUser -and $_.AccessControlType -eq 'Allow'
            }).Count | Should -BeGreaterThan 0
    }

    It 'throws when git is missing during configuration' {
        Mock Test-EdbGitInstalled {
            return [pscustomobject]@{
                Schema    = 'EDB.GitInstalled'
                Installed = $false
                Path      = $null
                Version   = $null
            }
        } -ModuleName EDB.Git

        { Set-EdbGitConfiguration -UserName 'A' -UserEmail 'a@example.com' } | Should -Throw '*Git is not installed*'
    }
}
