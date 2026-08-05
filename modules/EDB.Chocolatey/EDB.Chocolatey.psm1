#Requires -Version 7.0
using module '..\EDB.Contracts'
using module '..\EDB.Models'

<#
.SYNOPSIS
    Optional Chocolatey package provider for Enterprise Developer Bootstrap.
#>

. "$PSScriptRoot\EDB.Chocolatey.Bootstrap.ps1"

$script:EdbChocolateyInvokeCommand = $null

function Set-EdbChocolateyInvokeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Command
    )

    $script:EdbChocolateyInvokeCommand = $Command
}

function Reset-EdbChocolateyInvokeCommand {
    [CmdletBinding()]
    param()

    $script:EdbChocolateyInvokeCommand = $null
}

function Get-EdbChocolateyExecutable {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $command = Get-Command choco -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }
    return $null
}

function New-EdbChocolateyInvocationResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$ArgumentList,
        [Parameter(Mandatory)]
        [int]$ExitCode,
        [string]$Output = ''
    )

    [pscustomobject]@{
        Schema     = 'EDB.ChocolateyInvocationResult'
        ExitCode   = $ExitCode
        Output     = $Output
        Arguments  = @($ArgumentList)
        Succeeded  = ($ExitCode -eq 0)
    }
}

function Invoke-EdbChocolatey {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    if ($null -ne $script:EdbChocolateyInvokeCommand) {
        return & $script:EdbChocolateyInvokeCommand $ArgumentList
    }

    $executable = Get-EdbChocolateyExecutable
    if (-not $executable) {
        throw 'Chocolatey executable (choco) was not found on PATH.'
    }

    $output = & $executable @ArgumentList 2>&1
    $exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
    $text = if ($null -eq $output) { '' } else { ($output | Out-String).TrimEnd() }

    New-EdbChocolateyInvocationResult -ArgumentList $ArgumentList -ExitCode $exitCode -Output $text
}

function Test-EdbChocolateyPackageInstalled {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageId
    )

    if (-not (Get-EdbChocolateyExecutable) -and $null -eq $script:EdbChocolateyInvokeCommand) {
        return $false
    }

    $arguments = @('list', '--local-only', '--exact', $PackageId)
    $result = Invoke-EdbChocolatey -ArgumentList $arguments

    if ($result.ExitCode -ne 0) {
        return $false
    }

    return ($result.Output -match ("(?m)^{0}\s" -f [regex]::Escape($PackageId)))
}

function Install-EdbChocolateyPackage {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageId,

        [string]$Version,
        [hashtable]$Options = @{}
    )

    $startedAt = [datetime]::UtcNow

    if (Test-EdbChocolateyPackageInstalled -PackageId $PackageId) {
        return New-EdbInstallResult `
            -PackageId $PackageId `
            -Status ([EdbInstallStatus]::Skipped) `
            -Provider 'Chocolatey' `
            -Message 'Package is already installed.' `
            -StartedAt $startedAt `
            -CompletedAt ([datetime]::UtcNow) `
            -ExitCode 0 `
            -Details @{ skipped = $true }
    }

    $arguments = @('install', $PackageId, '-y', '--no-progress')

    if (-not [string]::IsNullOrWhiteSpace($Version)) {
        $arguments += @('--version', $Version)
    }

    if ($Options.ContainsKey('AdditionalArguments') -and $Options['AdditionalArguments']) {
        $arguments += @($Options['AdditionalArguments'])
    }

    $result = Invoke-EdbChocolatey -ArgumentList $arguments
    $completedAt = [datetime]::UtcNow

    if ($result.ExitCode -eq 0) {
        return New-EdbInstallResult `
            -PackageId $PackageId `
            -Status ([EdbInstallStatus]::Succeeded) `
            -Provider 'Chocolatey' `
            -Message 'Package installed successfully via Chocolatey.' `
            -StartedAt $startedAt `
            -CompletedAt $completedAt `
            -ExitCode $result.ExitCode `
            -Details @{ output = $result.Output; arguments = $result.Arguments }
    }

    return New-EdbInstallResult `
        -PackageId $PackageId `
        -Status ([EdbInstallStatus]::Failed) `
        -Provider 'Chocolatey' `
        -Message ("Chocolatey install failed with exit code {0}." -f $result.ExitCode) `
        -StartedAt $startedAt `
        -CompletedAt $completedAt `
        -ExitCode $result.ExitCode `
        -Details @{ output = $result.Output; arguments = $result.Arguments }
}

function Uninstall-EdbChocolateyPackage {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageId,

        [hashtable]$Options = @{}
    )

    $startedAt = [datetime]::UtcNow

    if (-not (Test-EdbChocolateyPackageInstalled -PackageId $PackageId)) {
        return New-EdbInstallResult `
            -PackageId $PackageId `
            -Status ([EdbInstallStatus]::Skipped) `
            -Provider 'Chocolatey' `
            -Message 'Package is not installed.' `
            -StartedAt $startedAt `
            -CompletedAt ([datetime]::UtcNow) `
            -ExitCode 0 `
            -Details @{ skipped = $true }
    }

    $arguments = @('uninstall', $PackageId, '-y', '--no-progress')

    if ($Options.ContainsKey('AdditionalArguments') -and $Options['AdditionalArguments']) {
        $arguments += @($Options['AdditionalArguments'])
    }

    $result = Invoke-EdbChocolatey -ArgumentList $arguments
    $completedAt = [datetime]::UtcNow

    if ($result.ExitCode -eq 0) {
        return New-EdbInstallResult `
            -PackageId $PackageId `
            -Status ([EdbInstallStatus]::Succeeded) `
            -Provider 'Chocolatey' `
            -Message 'Package uninstalled successfully via Chocolatey.' `
            -StartedAt $startedAt `
            -CompletedAt $completedAt `
            -ExitCode $result.ExitCode `
            -Details @{ output = $result.Output; arguments = $result.Arguments }
    }

    return New-EdbInstallResult `
        -PackageId $PackageId `
        -Status ([EdbInstallStatus]::Failed) `
        -Provider 'Chocolatey' `
        -Message ("Chocolatey uninstall failed with exit code {0}." -f $result.ExitCode) `
        -StartedAt $startedAt `
        -CompletedAt $completedAt `
        -ExitCode $result.ExitCode `
        -Details @{ output = $result.Output; arguments = $result.Arguments }
}

class EdbChocolateyProvider : EdbPackageProviderBase {
    EdbChocolateyProvider() {
        $this.Name = 'Chocolatey'
    }

    [bool] IsAvailable() {
        return $null -ne (Get-EdbChocolateyExecutable)
    }

    [bool] IsPackageInstalled([string]$PackageId) {
        return [bool](Test-EdbChocolateyPackageInstalled -PackageId $PackageId)
    }

    [object] InstallPackage([string]$PackageId, [hashtable]$Options) {
        $optionsTable = if ($null -eq $Options) { @{} } else { $Options }
        return Install-EdbChocolateyPackage -PackageId $PackageId -Options $optionsTable
    }

    [object] UninstallPackage([string]$PackageId, [hashtable]$Options) {
        $optionsTable = if ($null -eq $Options) { @{} } else { $Options }
        return Uninstall-EdbChocolateyPackage -PackageId $PackageId -Options $optionsTable
    }
}

function New-EdbChocolateyProvider {
    [CmdletBinding()]
    [OutputType([EdbChocolateyProvider])]
    param()

    [EdbChocolateyProvider]::new()
}

Export-ModuleMember -Function @(
    'New-EdbChocolateyProvider',
    'Install-EdbChocolateyIfMissing',
    'Test-EdbChocolateyPackageInstalled',
    'Install-EdbChocolateyPackage',
    'Uninstall-EdbChocolateyPackage',
    'Invoke-EdbChocolatey',
    'Set-EdbChocolateyInvokeCommand',
    'Reset-EdbChocolateyInvokeCommand'
)
