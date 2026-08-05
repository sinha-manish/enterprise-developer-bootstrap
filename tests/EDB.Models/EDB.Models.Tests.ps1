#Requires -Version 7.0
using module '..\..\modules\EDB.Contracts'
using module '..\..\modules\EDB.Models'

Describe 'EDB.Models' {
    Context 'New-EdbPackageDefinition' {
        It 'creates a valid package definition' {
            $pkg = New-EdbPackageDefinition -Id 'git' -DisplayName 'Git' -WingetId 'Git.Git' -Category 'Vcs'
            $pkg.Id | Should -Be 'git'
            $pkg.WingetId | Should -Be 'Git.Git'
            $pkg.Schema | Should -Be 'EDB.PackageDefinition'
        }

        It 'throws when no provider ids are supplied' {
            { New-EdbPackageDefinition -Id 'x' -DisplayName 'X' } | Should -Throw -ExpectedMessage '*WingetId*'
        }
    }

    Context 'New-EdbDeveloperProfile' {
        It 'deduplicates package ids' {
            $profile = New-EdbDeveloperProfile -Name 'Backend' -Packages @('git', 'git', 'node')
            $profile.Packages.Count | Should -Be 2
        }

        It 'throws when packages are empty' {
            { New-EdbDeveloperProfile -Name 'Empty' -Packages @() } | Should -Throw
        }
    }

    Context 'New-EdbInstallResult' {
        It 'computes duration' {
            $start = [datetime]::UtcNow.AddSeconds(-2)
            $end = [datetime]::UtcNow
            $result = New-EdbInstallResult -PackageId 'git' -Status Succeeded -StartedAt $start -CompletedAt $end
            $result.DurationMs | Should -BeGreaterOrEqual 0
            $result.Status | Should -Be ([EdbInstallStatus]::Succeeded)
        }
    }

    Context 'New-EdbInstallSession' {
        It 'initializes tracking collections' {
            $session = New-EdbInstallSession -ProfileName 'DevOps' -RequestedPackages @('git', 'docker')
            $session.SessionId | Should -Not -BeNullOrEmpty
            $session.CompletedPackages.Count | Should -Be 0
            $session.Status | Should -Be 'Running'
        }
    }

    Context 'New-EdbPreflightResult' {
        It 'passes when there are no errors' {
            $pf = New-EdbPreflightResult -IsWindows11OrCompatible:$true -IsAdministrator:$true -WingetAvailable:$true -InternetAvailable:$true
            $pf.Passed | Should -BeTrue
        }

        It 'fails when errors are present' {
            $pf = New-EdbPreflightResult -Errors @('Winget missing')
            $pf.Passed | Should -BeFalse
        }
    }

    Context 'New-EdbReportDocument' {
        It 'aggregates result counts' {
            $session = New-EdbInstallSession -ProfileName 'Frontend'
            $session.Results.Add((New-EdbInstallResult -PackageId 'a' -Status Succeeded))
            $session.Results.Add((New-EdbInstallResult -PackageId 'b' -Status Failed))
            $session.Results.Add((New-EdbInstallResult -PackageId 'c' -Status Skipped))
            $session.Status = 'CompletedWithErrors'
            $doc = New-EdbReportDocument -Session $session -Summary 'test'
            $doc.Counts.Succeeded | Should -Be 1
            $doc.Counts.Failed | Should -Be 1
            $doc.Counts.Skipped | Should -Be 1
            $doc.Counts.Total | Should -Be 3
        }
    }
}
