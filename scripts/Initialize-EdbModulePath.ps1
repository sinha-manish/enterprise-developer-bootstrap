#Requires -Version 7.0
<#
.SYNOPSIS
    Adds the repository modules path to PSModulePath for local development and tests.
#>
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$modulesPath = Join-Path $RepositoryRoot 'modules'
if (-not (Test-Path -LiteralPath $modulesPath)) {
    throw "Modules path not found: $modulesPath"
}

$parts = $env:PSModulePath -split [IO.Path]::PathSeparator
if ($parts -notcontains $modulesPath) {
    $env:PSModulePath = $modulesPath + [IO.Path]::PathSeparator + $env:PSModulePath
}

Write-Verbose "PSModulePath includes $modulesPath"
return $modulesPath
