#Requires -Version 7.0
using module '..\..\modules\EDB.Contracts'
using module '..\..\modules\EDB.Models'
using module '..\..\modules\EDB.Reports'

Describe 'EDB.Reports' {
    BeforeAll {
        $script:TempReportDir = Join-Path ([System.IO.Path]::GetTempPath()) ("edb-report-tests-{0}" -f [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:TempReportDir -Force | Out-Null
    }

    AfterAll {
        if ($script:TempReportDir -and (Test-Path -LiteralPath $script:TempReportDir)) {
            Remove-Item -LiteralPath $script:TempReportDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'New-EdbInstallationSummary' {
        It 'describes failed installs' {
            $session = New-EdbInstallSession -ProfileName 'Backend'
            $session.Results.Add((New-EdbInstallResult -PackageId 'git' -Status Succeeded)) | Out-Null
            $session.Results.Add((New-EdbInstallResult -PackageId 'node' -Status Failed)) | Out-Null
            $session.Status = 'CompletedWithErrors'
            $doc = New-EdbReportDocument -Session $session -Summary 'test run'

            $summary = New-EdbInstallationSummary -ReportDocument $doc
            $summary | Should -Match 'completed with errors'
            $summary | Should -Match 'Backend'
        }
    }

    Context 'Export-EdbReport JSON' {
        It 'writes JSON report to disk' {
            $session = New-EdbInstallSession -ProfileName 'Backend'
            $session.Results.Add((New-EdbInstallResult -PackageId 'git' -Status Succeeded)) | Out-Null
            $session.Results.Add((New-EdbInstallResult -PackageId 'node' -Status Failed)) | Out-Null
            $doc = New-EdbReportDocument -Session $session -Summary 'test run'

            $writer = New-EdbJsonReportWriter
            $path = Join-Path $script:TempReportDir 'report.json'
            Export-EdbReport -Writer $writer -ReportDocument $doc -OutputPath $path | Should -Be $path
            Test-Path -LiteralPath $path | Should -BeTrue
            $raw = Get-Content -LiteralPath $path -Raw
            $raw | Should -Match '"SessionId"'
            ($raw | ConvertFrom-Json).Counts.Failed | Should -Be 1
        }
    }

    Context 'Export-EdbReport HTML' {
        It 'writes a complete HTML report with escaped content and tables' {
            $session = New-EdbInstallSession -ProfileName 'Backend'
            $session.Results.Add((New-EdbInstallResult -PackageId 'git' -Status Succeeded)) | Out-Null
            $session.Results.Add((New-EdbInstallResult -PackageId 'node' -Status Failed -Message 'timeout')) | Out-Null
            $preflight = New-EdbPreflightResult -IsWindows11OrCompatible:$true -IsAdministrator:$true `
                -WingetAvailable:$true -InternetAvailable:$true
            $health = @((New-EdbHealthCheckResult -Name 'git' -Status Healthy))
            $doc = New-EdbReportDocument -Session $session -Preflight $preflight -HealthResults $health -Summary '<script>alert("x")</script>'

            $writer = New-EdbHtmlReportWriter
            $path = Join-Path $script:TempReportDir 'report.html'
            Export-EdbReport -Writer $writer -ReportDocument $doc -OutputPath $path | Should -Be $path

            $html = Get-Content -LiteralPath $path -Raw
            $html | Should -Match '<!DOCTYPE html>'
            $html | Should -Match '<table>'
            $html | Should -Match 'Install Results'
            $html | Should -Match 'Preflight'
            $html | Should -Match 'Health Checks'
            $html | Should -Not -Match '<script>alert'
            $html | Should -Match '&lt;script&gt;'
        }
    }
}
