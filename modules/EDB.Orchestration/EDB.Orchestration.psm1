#Requires -Version 7.0
using module '..\EDB.Contracts'
using module '..\EDB.Models'
using module '..\EDB.Configuration'
using module '..\EDB.Profiles'
using module '..\EDB.InstallPipeline'
using module '..\EDB.Logging'
using module '..\EDB.System'
using module '..\EDB.Winget'
using module '..\EDB.Chocolatey'
using module '..\EDB.Health'
using module '..\EDB.Reports'
using module '..\EDB.Rollback'
using module '..\EDB.Retry'

<#
.SYNOPSIS
    End-to-end bootstrap orchestration for Enterprise Developer Bootstrap.
#>

. (Join-Path $PSScriptRoot 'EDB.Orchestration.Internal.ps1')
. (Join-Path $PSScriptRoot 'EDB.Orchestration.Reports.ps1')
. (Join-Path $PSScriptRoot 'EDB.Orchestration.PostConfigure.ps1')
. (Join-Path $PSScriptRoot 'EDB.Orchestration.Bootstrap.ps1')

Export-ModuleMember -Function @('Start-EdbBootstrap')
