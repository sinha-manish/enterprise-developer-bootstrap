#Requires -Version 7.0

function New-EdbOrchestrationProviders {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [switch]$SkipWingetBootstrap
    )

    if (-not $SkipWingetBootstrap) {
        $wingetStatus = Get-EdbWingetStatus
        if (-not $wingetStatus.Available) {
            Install-EdbWingetIfMissing | Out-Null
        }
    }

    @{
        Winget     = New-EdbWingetProvider
        Chocolatey = New-EdbChocolateyProvider
    }
}

function Add-EdbOrchestrationRollbackActions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IList]$Journal,

        [Parameter(Mandatory)]
        [object[]]$Results,

        [Parameter(Mandatory)]
        [hashtable]$Providers,

        [Parameter(Mandatory)]
        [hashtable]$CatalogById
    )

    foreach ($result in @($Results)) {
        if ($null -eq $result -or $result.Status -ne [EdbInstallStatus]::Succeeded) {
            continue
        }

        $packageId = [string]$result.PackageId
        if (-not $CatalogById.ContainsKey($packageId)) {
            continue
        }

        $definition = $CatalogById[$packageId]
        $providerName = [string]$result.Provider
        $provider = if ($providerName) { $Providers[$providerName] } else { $null }
        $providerPackageId = if ($providerName -eq 'Winget') { [string]$definition.WingetId } else { [string]$definition.ChocolateyId }

        if ($null -eq $provider -or [string]::IsNullOrWhiteSpace($providerPackageId)) {
            continue
        }

        $capturedProvider = $provider
        $capturedProviderPackageId = $providerPackageId
        $capturedPackageId = $packageId
        $callback = {
            if ($capturedProvider -and $capturedProvider.IsAvailable()) {
                $capturedProvider.UninstallPackage($capturedProviderPackageId, @{ PackageId = $capturedPackageId }) | Out-Null
            }
            "Uninstalled $capturedPackageId"
        }.GetNewClosure()

        $action = [EdbUninstallRollbackAction]::new("uninstall:$packageId", $packageId, $callback)
        Add-EdbRollbackAction -Journal $Journal -Action $action | Out-Null
    }
}

function Get-EdbLatestPipelineStatePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$LogDirectory,

        [string]$SessionId
    )

    if (-not (Test-Path -LiteralPath $LogDirectory)) {
        return $null
    }

    $pattern = if ([string]::IsNullOrWhiteSpace($SessionId)) {
        'session-*.state.json'
    }
    else {
        "session-$SessionId.state.json"
    }

    $latest = Get-ChildItem -LiteralPath $LogDirectory -Filter $pattern -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1

    if ($null -eq $latest) {
        return $null
    }

    $latest.FullName
}

function Resolve-EdbOrchestrationPackages {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [object[]]$Catalog,
        [object]$Profile,
        [string[]]$Packages
    )

    if ($null -ne $Profile) {
        return Resolve-EdbProfilePackages -Profile $Profile -Catalog $Catalog -IncludeDependencies $true
    }

    if ($Packages -and $Packages.Count -gt 0) {
        $catalogById = @{}
        foreach ($package in $Catalog) {
            $catalogById[$package.Id] = $package
        }

        $selected = [System.Collections.Generic.List[object]]::new()
        foreach ($packageId in $Packages) {
            if (-not $catalogById.ContainsKey($packageId)) {
                throw "Unknown package id '$packageId'."
            }
            $selected.Add($catalogById[$packageId]) | Out-Null
        }

        return Resolve-EdbPackageOrder -Packages @($selected)
    }

    throw 'Either Profile or Packages must be specified.'
}

function ConvertTo-EdbLogLevelFromSettings {
    param([string]$LogLevel)

    switch ($LogLevel) {
        'Trace' { return [EdbLogLevel]::Trace }
        'Debug' { return [EdbLogLevel]::Debug }
        'Warning' { return [EdbLogLevel]::Warning }
        'Error' { return [EdbLogLevel]::Error }
        'Critical' { return [EdbLogLevel]::Critical }
        default { return [EdbLogLevel]::Information }
    }
}
