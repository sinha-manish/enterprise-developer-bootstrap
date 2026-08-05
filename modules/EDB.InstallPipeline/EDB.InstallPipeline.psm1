#Requires -Version 7.0
using module '..\EDB.Contracts'
using module '..\EDB.Models'
using module '..\EDB.Logging'
using module '..\EDB.Retry'

<#
.SYNOPSIS
    Package install pipeline with dependency ordering, resume state, and optional parallelism.
#>

. (Join-Path $PSScriptRoot 'EDB.InstallPipeline.Install.ps1')

function New-EdbPipelineState {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object]$Session,

        [string]$LogDirectory,
        [string]$RepositoryRoot
    )

    if ([string]::IsNullOrWhiteSpace($LogDirectory)) {
        $LogDirectory = Get-EdbDefaultLogDirectory -RepositoryRoot $RepositoryRoot
    }

    if (-not (Test-Path -LiteralPath $LogDirectory)) {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
    }

    $statePath = Join-Path $LogDirectory ("session-{0}.state.json" -f $Session.SessionId)

    [pscustomobject]@{
        Schema             = 'EDB.PipelineState'
        SessionId          = $Session.SessionId
        ProfileName        = $Session.ProfileName
        StatePath          = $statePath
        CompletedPackages  = [System.Collections.Generic.List[string]]::new()
        FailedPackages     = [System.Collections.Generic.List[string]]::new()
        SkippedPackages    = [System.Collections.Generic.List[string]]::new()
        Results            = [System.Collections.Generic.List[object]]::new()
        UpdatedAt          = [datetime]::UtcNow
    }
}

function Save-EdbPipelineState {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$State
    )

    if ([string]::IsNullOrWhiteSpace($State.StatePath)) {
        throw 'Pipeline state does not define StatePath.'
    }

    $directory = Split-Path -Parent $State.StatePath
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $State.UpdatedAt = [datetime]::UtcNow
    $payload = [ordered]@{
        Schema            = $State.Schema
        SessionId         = $State.SessionId
        ProfileName       = $State.ProfileName
        CompletedPackages = @($State.CompletedPackages)
        FailedPackages    = @($State.FailedPackages)
        SkippedPackages   = @($State.SkippedPackages)
        Results           = @($State.Results)
        UpdatedAt         = $State.UpdatedAt.ToUniversalTime().ToString('o')
    }

    $json = $payload | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($State.StatePath, $json, [System.Text.UTF8Encoding]::new($false))
    return $State.StatePath
}

function Read-EdbPipelineState {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Pipeline state file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $data = $raw | ConvertFrom-Json

    $completed = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @($data.CompletedPackages)) {
        if ($null -ne $item -and -not [string]::IsNullOrWhiteSpace([string]$item)) {
            $completed.Add([string]$item) | Out-Null
        }
    }

    $failed = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @($data.FailedPackages)) {
        if ($null -ne $item -and -not [string]::IsNullOrWhiteSpace([string]$item)) {
            $failed.Add([string]$item) | Out-Null
        }
    }

    $skipped = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @($data.SkippedPackages)) {
        if ($null -ne $item -and -not [string]::IsNullOrWhiteSpace([string]$item)) {
            $skipped.Add([string]$item) | Out-Null
        }
    }

    $resultItems = [System.Collections.Generic.List[object]]::new()
    foreach ($item in @($data.Results)) {
        if ($null -ne $item) {
            $resultItems.Add($item) | Out-Null
        }
    }

    [pscustomobject]@{
        Schema            = if ($data.Schema) { [string]$data.Schema } else { 'EDB.PipelineState' }
        SessionId         = [string]$data.SessionId
        ProfileName       = [string]$data.ProfileName
        StatePath         = $Path
        CompletedPackages = $completed
        FailedPackages    = $failed
        SkippedPackages   = $skipped
        Results           = $resultItems
        UpdatedAt         = if ($data.UpdatedAt) { [datetime]::Parse($data.UpdatedAt).ToUniversalTime() } else { [datetime]::UtcNow }
    }
}

function Resolve-EdbPackageOrder {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object[]]$Packages
    )

    if ($Packages.Count -eq 0) {
        return @()
    }

    $byId = @{}
    foreach ($pkg in $Packages) {
        if ($null -eq $pkg -or [string]::IsNullOrWhiteSpace($pkg.Id)) {
            throw 'Each package definition must include a non-empty Id.'
        }
        if ($byId.ContainsKey($pkg.Id)) {
            throw "Duplicate package id '$($pkg.Id)' in dependency resolution input."
        }
        $byId[$pkg.Id] = $pkg
    }

    $inDegree = @{}
    $dependents = @{}
    foreach ($id in $byId.Keys) {
        $inDegree[$id] = 0
        $dependents[$id] = [System.Collections.Generic.List[string]]::new()
    }

    foreach ($pkg in $Packages) {
        foreach ($dep in @($pkg.DependsOn)) {
            if ([string]::IsNullOrWhiteSpace($dep)) { continue }
            if (-not $byId.ContainsKey($dep)) {
                throw "Package '$($pkg.Id)' depends on unknown package '$dep'."
            }
            $inDegree[$pkg.Id]++
            $dependents[$dep].Add($pkg.Id) | Out-Null
        }
    }

    $queue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($entry in $inDegree.GetEnumerator() | Sort-Object Name) {
        if ($entry.Value -eq 0) {
            $queue.Enqueue($entry.Key)
        }
    }

    $ordered = [System.Collections.Generic.List[object]]::new()
    while ($queue.Count -gt 0) {
        $currentId = $queue.Dequeue()
        $ordered.Add($byId[$currentId]) | Out-Null

        foreach ($nextId in $dependents[$currentId]) {
            $inDegree[$nextId]--
            if ($inDegree[$nextId] -eq 0) {
                $queue.Enqueue($nextId)
            }
        }
    }

    if ($ordered.Count -ne $Packages.Count) {
        throw 'Circular dependency detected in package definitions.'
    }

    @($ordered)
}

function Show-EdbProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Current,

        [Parameter(Mandatory)]
        [int]$Total,

        [Parameter(Mandatory)]
        [string]$PackageId,

        [string]$Status = 'Running'
    )

    $percent = if ($Total -gt 0) { [math]::Round(($Current / $Total) * 100, 1) } else { 0 }
    Write-Host ("[{0}/{1} {2}%] {3}: {4}" -f $Current, $Total, $percent, $PackageId, $Status)
}

function Install-EdbPackageSet {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object[]]$Packages,

        [hashtable]$Providers = @{},

        [EdbLoggerBase]$Logger,

        [object]$RetryPolicy = (New-EdbRetryPolicy -MaxAttempts 1),

        [object]$State,

        [switch]$Parallel,

        [ValidateRange(1, 16)]
        [int]$ThrottleLimit = 4,

        [string]$RepositoryRoot
    )

    $ordered = Resolve-EdbPackageOrder -Packages $Packages
    $results = [System.Collections.Generic.List[object]]::new()
    $completedSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    if ($State -and $State.CompletedPackages) {
        foreach ($id in @($State.CompletedPackages)) {
            if (-not [string]::IsNullOrWhiteSpace($id)) {
                [void]$completedSet.Add($id)
            }
        }
    }

    $total = $ordered.Count

    if ($Parallel) {
        $modulesPath = Split-Path -Parent $PSScriptRoot
        Invoke-EdbWavePackageSet -Ordered $ordered -Providers $Providers -Logger $Logger `
            -RetryPolicy $RetryPolicy -State $State -CompletedSet $completedSet -Results $results `
            -Total $total -ThrottleLimit $ThrottleLimit -WhatIf:[bool]$WhatIfPreference `
            -ModulesPath $modulesPath -RepositoryRoot $RepositoryRoot
        return @($results)
    }

    $index = 0
    foreach ($pkg in $ordered) {
        $index++

        if ($completedSet.Contains($pkg.Id)) {
            $skipped = New-EdbInstallResult -PackageId $pkg.Id -Status ([EdbInstallStatus]::Skipped) `
                -Message 'Already completed in pipeline state.'
            $results.Add($skipped) | Out-Null
            Show-EdbProgress -Current $index -Total $total -PackageId $pkg.Id -Status 'Skipped'
            continue
        }

        $unmet = @($pkg.DependsOn | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not $completedSet.Contains($_) })
        if ($unmet.Count -gt 0) {
            $failed = New-EdbInstallResult -PackageId $pkg.Id -Status ([EdbInstallStatus]::Failed) `
                -Message ("Unmet dependencies: {0}" -f ($unmet -join ', '))
            Update-EdbPipelineResultCollections -Result $failed -CompletedSet $completedSet -Results $results -State $State
            Show-EdbProgress -Current $index -Total $total -PackageId $pkg.Id -Status 'Failed'
            continue
        }

        if ($WhatIfPreference) {
            $result = Install-EdbSinglePackage -Package $pkg -Providers $Providers `
                -Logger $Logger -RetryPolicy $RetryPolicy -WhatIf -RepositoryRoot $RepositoryRoot
        }
        elseif ($PSCmdlet.ShouldProcess($pkg.Id, 'Install package')) {
            $result = Install-EdbSinglePackage -Package $pkg -Providers $Providers `
                -Logger $Logger -RetryPolicy $RetryPolicy -RepositoryRoot $RepositoryRoot
        }
        else {
            $result = New-EdbInstallResult -PackageId $pkg.Id -Status ([EdbInstallStatus]::Skipped) `
                -Message 'Operation was not confirmed.' -Provider 'ShouldProcess'
        }

        Update-EdbPipelineResultCollections -Result $result -CompletedSet $completedSet -Results $results -State $State
        Show-EdbProgress -Current $index -Total $total -PackageId $pkg.Id -Status ($result.Status.ToString())
    }

    @($results)
}

Export-ModuleMember -Function @(
    'New-EdbPipelineState',
    'Save-EdbPipelineState',
    'Read-EdbPipelineState',
    'Resolve-EdbPackageOrder',
    'Resolve-EdbPackageWaves',
    'Resolve-EdbTrustedPostInstallScript',
    'Install-EdbPackageSet',
    'Show-EdbProgress'
)
