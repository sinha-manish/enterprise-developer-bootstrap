#Requires -Version 7.0
<#
.SYNOPSIS
    One-command entry point for Enterprise Developer Bootstrap.
.DESCRIPTION
    Installs a developer toolchain profile or explicit package set using Winget and Chocolatey providers.
.EXAMPLE
    .\Install-DeveloperEnvironment.ps1 -Profile Backend
.EXAMPLE
    .\Install-DeveloperEnvironment.ps1 -Profile DevOps -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Profile,
    [string[]]$Packages,
    [switch]$Resume,
    [switch]$Parallel,
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$ConfigRoot,
    [switch]$SkipValidation,
    [switch]$GenerateReportOnly,
    [switch]$RollbackOnFailure,
    [string]$SessionId
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Profile) -and (-not $Packages -or $Packages.Count -eq 0)) {
    throw 'Specify -Profile or -Packages.'
}

$initScript = Join-Path $RepositoryRoot 'scripts\Initialize-EdbModulePath.ps1'
if (-not (Test-Path -LiteralPath $initScript)) {
    throw "Initialize-EdbModulePath.ps1 was not found at $initScript"
}

. $initScript -RepositoryRoot $RepositoryRoot | Out-Null
Import-Module EDB.Orchestration -Force

$bootstrapParams = @{
    Profile            = $Profile
    Packages           = $Packages
    Resume             = $Resume
    Parallel           = $Parallel
    RepositoryRoot     = $RepositoryRoot
    ConfigRoot         = $ConfigRoot
    SkipValidation     = $SkipValidation
    GenerateReportOnly = $GenerateReportOnly
    RollbackOnFailure  = $RollbackOnFailure
    WhatIf             = $WhatIfPreference
}

if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
    $bootstrapParams['SessionId'] = $SessionId
}

$result = Start-EdbBootstrap @bootstrapParams
$result

if ($result.Session.Status -eq 'Failed') {
    exit 1
}
