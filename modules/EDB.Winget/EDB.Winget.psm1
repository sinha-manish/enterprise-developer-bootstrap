#Requires -Version 7.0
using module '..\EDB.Contracts'
using module '..\EDB.Models'

<#
.SYNOPSIS
    Winget package provider for Enterprise Developer Bootstrap.
#>

. "$PSScriptRoot\EDB.Winget.Bootstrap.ps1"

$script:EdbWingetInvokeCommand = $null

function Set-EdbWingetInvokeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Command
    )

    $script:EdbWingetInvokeCommand = $Command
}

function Reset-EdbWingetInvokeCommand {
    [CmdletBinding()]
    param()

    $script:EdbWingetInvokeCommand = $null
}

function Get-EdbWingetExecutable {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $command = Get-Command winget -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }
    return $null
}

function New-EdbWingetInvocationResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$ArgumentList,
        [Parameter(Mandatory)]
        [int]$ExitCode,
        [string]$Output = ''
    )

    [pscustomobject]@{
        Schema     = 'EDB.WingetInvocationResult'
        ExitCode   = $ExitCode
        Output     = $Output
        Arguments  = @($ArgumentList)
        Succeeded  = ($ExitCode -eq 0)
    }
}

function Invoke-EdbWinget {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    if ($null -ne $script:EdbWingetInvokeCommand) {
        return & $script:EdbWingetInvokeCommand $ArgumentList
    }

    $executable = Get-EdbWingetExecutable
    if (-not $executable) {
        throw 'Winget executable was not found on PATH.'
    }

    $output = & $executable @ArgumentList 2>&1
    $exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
    $text = if ($null -eq $output) { '' } else { ($output | Out-String).TrimEnd() }

    New-EdbWingetInvocationResult -ArgumentList $ArgumentList -ExitCode $exitCode -Output $text
}

function Get-EdbWingetDefaultArguments {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    @(
        '--disable-interactivity',
        '--accept-package-agreements',
        '--accept-source-agreements'
    )
}

function Test-EdbWingetPackageInstalled {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageId
    )

    if (-not (Get-EdbWingetExecutable) -and $null -eq $script:EdbWingetInvokeCommand) {
        return $false
    }

    $arguments = @(
        'list',
        '--id', $PackageId,
        '--exact'
    ) + (Get-EdbWingetDefaultArguments)

    $result = Invoke-EdbWinget -ArgumentList $arguments
    if ($result.ExitCode -ne 0) {
        return $false
    }

    return ($result.Output -match [regex]::Escape($PackageId))
}

function Install-EdbWingetPackage {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageId,

        [string]$Version,
        [ValidateSet('user', 'machine')]
        [string]$Scope,
        [hashtable]$Options = @{}
    )

    $startedAt = [datetime]::UtcNow

    if (Test-EdbWingetPackageInstalled -PackageId $PackageId) {
        return New-EdbInstallResult `
            -PackageId $PackageId `
            -Status ([EdbInstallStatus]::Skipped) `
            -Provider 'Winget' `
            -Message 'Package is already installed.' `
            -StartedAt $startedAt `
            -CompletedAt ([datetime]::UtcNow) `
            -ExitCode 0 `
            -Details @{ skipped = $true }
    }

    $arguments = @(
        'install',
        '--id', $PackageId,
        '--exact'
    ) + (Get-EdbWingetDefaultArguments)

    if (-not [string]::IsNullOrWhiteSpace($Version)) {
        $arguments += @('--version', $Version)
    }

    if (-not [string]::IsNullOrWhiteSpace($Scope)) {
        $arguments += @('--scope', $Scope)
    }

    if ($Options.ContainsKey('AdditionalArguments') -and $Options['AdditionalArguments']) {
        $arguments += @($Options['AdditionalArguments'])
    }

    $result = Invoke-EdbWinget -ArgumentList $arguments
    $completedAt = [datetime]::UtcNow

    if ($result.ExitCode -eq 0) {
        return New-EdbInstallResult `
            -PackageId $PackageId `
            -Status ([EdbInstallStatus]::Succeeded) `
            -Provider 'Winget' `
            -Message 'Package installed successfully via Winget.' `
            -StartedAt $startedAt `
            -CompletedAt $completedAt `
            -ExitCode $result.ExitCode `
            -Details @{ output = $result.Output; arguments = $result.Arguments }
    }

    return New-EdbInstallResult `
        -PackageId $PackageId `
        -Status ([EdbInstallStatus]::Failed) `
        -Provider 'Winget' `
        -Message ("Winget install failed with exit code {0}." -f $result.ExitCode) `
        -StartedAt $startedAt `
        -CompletedAt $completedAt `
        -ExitCode $result.ExitCode `
        -Details @{ output = $result.Output; arguments = $result.Arguments }
}

function Uninstall-EdbWingetPackage {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageId,

        [hashtable]$Options = @{}
    )

    $startedAt = [datetime]::UtcNow

    if (-not (Test-EdbWingetPackageInstalled -PackageId $PackageId)) {
        return New-EdbInstallResult `
            -PackageId $PackageId `
            -Status ([EdbInstallStatus]::Skipped) `
            -Provider 'Winget' `
            -Message 'Package is not installed.' `
            -StartedAt $startedAt `
            -CompletedAt ([datetime]::UtcNow) `
            -ExitCode 0 `
            -Details @{ skipped = $true }
    }

    $arguments = @(
        'uninstall',
        '--id', $PackageId,
        '--exact'
    ) + (Get-EdbWingetDefaultArguments)

    if ($Options.ContainsKey('AdditionalArguments') -and $Options['AdditionalArguments']) {
        $arguments += @($Options['AdditionalArguments'])
    }

    $result = Invoke-EdbWinget -ArgumentList $arguments
    $completedAt = [datetime]::UtcNow

    if ($result.ExitCode -eq 0) {
        return New-EdbInstallResult `
            -PackageId $PackageId `
            -Status ([EdbInstallStatus]::Succeeded) `
            -Provider 'Winget' `
            -Message 'Package uninstalled successfully via Winget.' `
            -StartedAt $startedAt `
            -CompletedAt $completedAt `
            -ExitCode $result.ExitCode `
            -Details @{ output = $result.Output; arguments = $result.Arguments }
    }

    return New-EdbInstallResult `
        -PackageId $PackageId `
        -Status ([EdbInstallStatus]::Failed) `
        -Provider 'Winget' `
        -Message ("Winget uninstall failed with exit code {0}." -f $result.ExitCode) `
        -StartedAt $startedAt `
        -CompletedAt $completedAt `
        -ExitCode $result.ExitCode `
        -Details @{ output = $result.Output; arguments = $result.Arguments }
}

class EdbWingetProvider : EdbPackageProviderBase {
    EdbWingetProvider() {
        $this.Name = 'Winget'
    }

    [bool] IsAvailable() {
        return $null -ne (Get-EdbWingetExecutable)
    }

    [bool] IsPackageInstalled([string]$PackageId) {
        return [bool](Test-EdbWingetPackageInstalled -PackageId $PackageId)
    }

    [object] InstallPackage([string]$PackageId, [hashtable]$Options) {
        $optionsTable = if ($null -eq $Options) { @{} } else { $Options }
        return Install-EdbWingetPackage -PackageId $PackageId -Options $optionsTable
    }

    [object] UninstallPackage([string]$PackageId, [hashtable]$Options) {
        $optionsTable = if ($null -eq $Options) { @{} } else { $Options }
        return Uninstall-EdbWingetPackage -PackageId $PackageId -Options $optionsTable
    }
}

function New-EdbWingetProvider {
    [CmdletBinding()]
    [OutputType([EdbWingetProvider])]
    param()

    [EdbWingetProvider]::new()
}

Export-ModuleMember -Function @(
    'New-EdbWingetProvider',
    'Install-EdbWingetIfMissing',
    'Test-EdbWingetPackageInstalled',
    'Install-EdbWingetPackage',
    'Uninstall-EdbWingetPackage',
    'Invoke-EdbWinget',
    'Set-EdbWingetInvokeCommand',
    'Reset-EdbWingetInvokeCommand'
)
