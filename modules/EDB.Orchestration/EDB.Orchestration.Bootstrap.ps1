#Requires -Version 7.0

function Start-EdbBootstrap {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [string]$Profile,
        [string[]]$Packages,
        [switch]$Resume,
        [switch]$Parallel,
        [string]$RepositoryRoot,
        [string]$ConfigRoot,
        [switch]$SkipValidation,
        [switch]$GenerateReportOnly,
        [switch]$RollbackOnFailure,
        [string]$SessionId
    )

    $repoRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
        (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    }
    else {
        (Resolve-Path -LiteralPath $RepositoryRoot).Path
    }

    $initScript = Join-Path $repoRoot 'scripts\Initialize-EdbModulePath.ps1'
    if (-not (Test-Path -LiteralPath $initScript)) {
        throw "Initialize-EdbModulePath.ps1 was not found at $initScript"
    }
    . $initScript -RepositoryRoot $repoRoot | Out-Null

    $settings = Get-EdbSettings -RepositoryRoot $repoRoot -ConfigRoot $ConfigRoot
    $catalog = @(Get-EdbPackageCatalog -RepositoryRoot $repoRoot -ConfigRoot $ConfigRoot)
    $logDirectory = Get-EdbDefaultLogDirectory -RepositoryRoot $repoRoot

    $profileObject = $null
    $profileName = ''
    if (-not [string]::IsNullOrWhiteSpace($Profile)) {
        $profileObject = Get-EdbProfile -Name $Profile -RepositoryRoot $repoRoot -ConfigRoot $ConfigRoot
        $profileName = $profileObject.Name
    }

    $packageSet = @(Resolve-EdbOrchestrationPackages -Catalog $catalog -Profile $profileObject -Packages $Packages)
    $requiresAdmin = @($packageSet | Where-Object { $_.RequiresAdmin }).Count -gt 0

    $session = New-EdbInstallSession -SessionId $SessionId -ProfileName $profileName `
        -RequestedPackages @($packageSet | ForEach-Object { $_.Id }) `
        -Options @{
            WhatIf             = [bool]$WhatIfPreference
            Parallel           = [bool]$Parallel
            GenerateReportOnly = [bool]$GenerateReportOnly
            RollbackOnFailure  = [bool]$RollbackOnFailure
        }

    $logger = New-EdbLogger -RepositoryRoot $repoRoot -SessionId $session.SessionId `
        -MinimumLevel (ConvertTo-EdbLogLevelFromSettings -LogLevel $settings.LogLevel) `
        -WriteToConsole ([bool]$settings.WriteToConsole)

    Write-EdbLog -Logger $logger -Level ([EdbLogLevel]::Information) `
        -Message 'Starting Enterprise Developer Bootstrap.' `
        -Properties @{ Profile = $profileName; PackageCount = $packageSet.Count; SessionId = $session.SessionId }

    $enforceAdmin = $requiresAdmin -and -not $WhatIfPreference -and -not $GenerateReportOnly
    $enforceInternet = [bool]$settings.RequireInternet -and -not $WhatIfPreference -and -not $GenerateReportOnly

    $preflight = Invoke-EdbPreflightCheck `
        -RequireAdministrator:($enforceAdmin) `
        -RequireInternet:($enforceInternet)

    if (-not $preflight.Passed -and $settings.RequirePreflight -and -not $WhatIfPreference -and -not $GenerateReportOnly) {
        throw ("Preflight checks failed: {0}" -f ($preflight.Errors -join '; '))
    }

    if (-not $preflight.Passed -and ($WhatIfPreference -or $GenerateReportOnly)) {
        Write-EdbLog -Logger $logger -Level ([EdbLogLevel]::Warning) `
            -Message 'Preflight reported issues; continuing because this is a dry-run or report-only session.' `
            -Properties @{ Errors = ($preflight.Errors -join '; ') }
    }

    $pipelineState = $null
    if ($Resume) {
        $statePath = Get-EdbLatestPipelineStatePath -LogDirectory $logDirectory -SessionId $session.SessionId
        if ($statePath) {
            $pipelineState = Read-EdbPipelineState -Path $statePath
            $session.SessionId = $pipelineState.SessionId
        }
    }

    if (-not $pipelineState) {
        $pipelineState = New-EdbPipelineState -Session $session -LogDirectory $logDirectory -RepositoryRoot $repoRoot
    }

    $installResults = @()
    $providers = @{}
    $catalogById = @{}
    foreach ($package in $catalog) {
        $catalogById[$package.Id] = $package
    }

    $postConfigureActions = @()

    if (-not $GenerateReportOnly) {
        $providers = New-EdbOrchestrationProviders -SkipWingetBootstrap:$WhatIfPreference
        $useParallel = if ($PSBoundParameters.ContainsKey('Parallel')) { [bool]$Parallel } else { [bool]$settings.Parallel }
        $retryPolicy = New-EdbRetryPolicy -MaxAttempts ([math]::Max(1, [int]$settings.RetryCount))

        $installResults = Install-EdbPackageSet -Packages $packageSet -Providers $providers `
            -Logger $logger -RetryPolicy $retryPolicy -State $pipelineState `
            -Parallel:$useParallel -ThrottleLimit ([math]::Max(1, [int]$settings.ParallelInstalls)) `
            -RepositoryRoot $repoRoot -WhatIf:$WhatIfPreference

        $failedCount = @($installResults | Where-Object { $_.Status -eq [EdbInstallStatus]::Failed }).Count
        if ($failedCount -gt 0 -and $RollbackOnFailure) {
            Add-EdbOrchestrationRollbackActions -Journal (New-EdbRollbackJournal -Session $session) `
                -Results $installResults -Providers $providers -CatalogById $catalogById
            Invoke-EdbRollback -Journal $session.RollbackJournal -Context @{ Providers = $providers } | Out-Null
            Complete-EdbOrchestrationSession -Session $session -Results $installResults -FinalStatus 'Failed' | Out-Null
            $logger.Flush()
            $logger.Close()
            throw ("Bootstrap completed with $failedCount failed package(s). Rollback attempted.")
        }

        if ($failedCount -eq 0) {
            $postConfigureActions = @(Invoke-EdbPostConfigure -RepositoryRoot $repoRoot `
                    -PackageIds @($packageSet | ForEach-Object { $_.Id }) `
                    -ProfileName $profileName -Logger $logger -WhatIf:$WhatIfPreference)
        }
    }

    $skipHealth = $SkipValidation -or $WhatIfPreference -or $GenerateReportOnly
    $healthResults = @(Invoke-EdbOrchestrationHealthChecks -Packages $packageSet -SkipValidation:$skipHealth)

    $failedInstalls = @($installResults | Where-Object { $_.Status -eq [EdbInstallStatus]::Failed }).Count
    $unhealthy = @($healthResults | Where-Object { $_.Status -eq [EdbHealthStatus]::Unhealthy }).Count

    $finalStatus = if ($failedInstalls -gt 0 -or $unhealthy -gt 0) {
        'Failed'
    }
    elseif ($GenerateReportOnly) {
        'ReportOnly'
    }
    else {
        'Completed'
    }

    Complete-EdbOrchestrationSession -Session $session -Results $installResults -FinalStatus $finalStatus | Out-Null
    $reportPaths = Export-EdbOrchestrationReports -Session $session -Preflight $preflight `
        -HealthResults $healthResults -Settings $settings -LogDirectory $logDirectory `
        -RepositoryRoot $repoRoot

    $logger.Flush()
    $logger.Close()

    [pscustomobject]@{
        Schema               = 'EDB.BootstrapResult'
        Session              = $session
        Preflight            = $preflight
        HealthResults        = @($healthResults)
        PostConfigureActions = @($postConfigureActions)
        ReportPaths          = $reportPaths
        PackageCount         = $packageSet.Count
        Results              = @($installResults)
    }
}
