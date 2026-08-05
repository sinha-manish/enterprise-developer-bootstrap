#Requires -Version 7.0

function Export-EdbOrchestrationReports {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [object]$Session,

        [object]$Preflight,
        [object[]]$HealthResults,
        [object]$Settings,
        [string]$LogDirectory,
        [string]$ReportDirectory,
        [string]$RepositoryRoot
    )

    $reportPaths = @{}
    if (-not $Settings.GenerateReports) {
        return $reportPaths
    }

    if ([string]::IsNullOrWhiteSpace($ReportDirectory)) {
        if (-not [string]::IsNullOrWhiteSpace($RepositoryRoot)) {
            $ReportDirectory = Join-Path $RepositoryRoot 'reports'
        }
        elseif (-not [string]::IsNullOrWhiteSpace($LogDirectory)) {
            $ReportDirectory = Join-Path (Split-Path -Parent $LogDirectory) 'reports'
        }
        else {
            throw 'ReportDirectory or RepositoryRoot is required to export reports.'
        }
    }

    if (-not (Test-Path -LiteralPath $ReportDirectory)) {
        New-Item -ItemType Directory -Path $ReportDirectory -Force | Out-Null
    }

    $document = New-EdbReportDocument -Session $Session -Preflight $Preflight -HealthResults $HealthResults
    $formats = @($Settings.ReportFormats)
    if ($formats.Count -eq 0) {
        $formats = @('Json', 'Html')
    }

    foreach ($format in $formats) {
        switch ($format.ToString()) {
            'Json' {
                $writer = New-EdbJsonReportWriter
                $path = Join-Path $ReportDirectory ("edb-report-{0}.json" -f $Session.SessionId)
                $reportPaths['Json'] = Export-EdbReport -Writer $writer -ReportDocument $document -OutputPath $path
            }
            'Html' {
                $writer = New-EdbHtmlReportWriter
                $path = Join-Path $ReportDirectory ("edb-report-{0}.html" -f $Session.SessionId)
                $reportPaths['Html'] = Export-EdbReport -Writer $writer -ReportDocument $document -OutputPath $path
            }
        }
    }

    $reportPaths
}

function Invoke-EdbOrchestrationHealthChecks {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object[]]$Packages,

        [switch]$SkipValidation
    )

    if ($SkipValidation) {
        return @()
    }

    $checks = [System.Collections.Generic.List[EdbHealthCheckBase]]::new()
    foreach ($package in $Packages) {
        if ([string]::IsNullOrWhiteSpace($package.ValidateCommand)) {
            continue
        }
        $checks.Add((New-EdbHealthCheck -Name ("command:$($package.Id)") -PackageDefinition $package))
    }

    if ($checks.Count -eq 0) {
        return @()
    }

    Invoke-EdbHealthCheckSet -HealthChecks @($checks)
}

function Complete-EdbOrchestrationSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Session,

        [object[]]$Results = @(),

        [string]$FinalStatus = 'Completed'
    )

    foreach ($result in @($Results)) {
        if ($null -eq $result) { continue }
        $Session.Results.Add($result) | Out-Null
        switch ($result.Status) {
            ([EdbInstallStatus]::Succeeded) { $Session.CompletedPackages.Add($result.PackageId) | Out-Null }
            ([EdbInstallStatus]::Failed) { $Session.FailedPackages.Add($result.PackageId) | Out-Null }
            ([EdbInstallStatus]::Skipped) { $Session.SkippedPackages.Add($result.PackageId) | Out-Null }
        }
    }

    $Session.Status = $FinalStatus
    $Session.CompletedAt = [datetime]::UtcNow
    $Session
}
