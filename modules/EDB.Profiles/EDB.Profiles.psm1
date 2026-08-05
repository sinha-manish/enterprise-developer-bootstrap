#Requires -Version 7.0
using module '..\EDB.Contracts'
using module '..\EDB.Models'
using module '..\EDB.Configuration'
using module '..\EDB.InstallPipeline'

<#
.SYNOPSIS
    Developer profile loading and package resolution for Enterprise Developer Bootstrap.
#>

. "$PSScriptRoot\EDB.Profiles.Internal.ps1"

Export-ModuleMember -Function @(
    'Get-EdbProfileList',
    'Get-EdbProfile',
    'Resolve-EdbProfilePackages'
)
