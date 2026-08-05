#Requires -Version 7.0
using module '..\..\modules\EDB.Contracts'
using module '..\..\modules\EDB.Models'
using module '..\..\modules\EDB.Rollback'

Describe 'EDB.Rollback' {
    Context 'New-EdbRollbackJournal' {
        It 'creates a standalone journal list' {
            $journal = New-EdbRollbackJournal
            $null -eq $journal | Should -BeFalse
            $journal.Count | Should -Be 0
        }

        It 'returns the session rollback journal when a session is supplied' {
            $session = New-EdbInstallSession -ProfileName 'Test'
            $journal = New-EdbRollbackJournal -Session $session
            $journal | Should -Be $session.RollbackJournal
        }
    }

    Context 'Add-EdbRollbackAction and Invoke-EdbRollback' {
        It 'executes rollback actions in reverse order with best effort' {
            $journal = New-EdbRollbackJournal
            $script:order = @()

            $actionA = [EdbUninstallRollbackAction]::new('a', 'pkg-a', {
                    $script:order += 'a'
                    'removed-a'
                })
            $actionB = [EdbUninstallRollbackAction]::new('b', 'pkg-b', {
                    $script:order += 'b'
                    'removed-b'
                })

            Add-EdbRollbackAction -Journal $journal -Action $actionA
            Add-EdbRollbackAction -Journal $journal -Action $actionB

            $results = Invoke-EdbRollback -Journal $journal
            $results.Count | Should -Be 2
            $results[0].PackageId | Should -Be 'pkg-b'
            $results[0].Success | Should -BeTrue
            $results[1].PackageId | Should -Be 'pkg-a'
            $script:order | Should -Be @('b', 'a')
        }

        It 'continues after a failed uninstall callback' {
            $journal = New-EdbRollbackJournal
            $fail = [EdbUninstallRollbackAction]::new('fail', 'pkg-f', { throw 'uninstall failed' })
            $ok = [EdbUninstallRollbackAction]::new('ok', 'pkg-o', { 'done' })

            Add-EdbRollbackAction -Journal $journal -Action $fail
            Add-EdbRollbackAction -Journal $journal -Action $ok

            $results = Invoke-EdbRollback -Journal $journal
            $results.Count | Should -Be 2
            $results[0].Success | Should -BeTrue
            $results[1].Success | Should -BeFalse
        }
    }

    Context 'Clear-EdbRollbackJournal' {
        It 'removes all journal entries' {
            $journal = New-EdbRollbackJournal
            Add-EdbRollbackAction -Journal $journal -Action ([EdbUninstallRollbackAction]::new('x', 'pkg-x', { 'x' }))
            Clear-EdbRollbackJournal -Journal $journal
            $journal.Count | Should -Be 0
        }
    }
}
