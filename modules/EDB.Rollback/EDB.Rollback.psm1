#Requires -Version 7.0
using module '..\EDB.Contracts'
using module '..\EDB.Models'

<#
.SYNOPSIS
    Rollback journal and best-effort uninstall actions for Enterprise Developer Bootstrap.
#>

class EdbUninstallRollbackAction : EdbRollbackActionBase {
    [scriptblock]$UninstallCallback

    EdbUninstallRollbackAction([string]$Name, [string]$PackageId, [scriptblock]$UninstallCallback) {
        $this.Name = $Name
        $this.PackageId = $PackageId
        $this.UninstallCallback = $UninstallCallback
    }

    [object] Invoke([hashtable]$Context) {
        $ctx = @{}
        if ($null -ne $Context) {
            foreach ($key in $Context.Keys) {
                $ctx[$key] = $Context[$key]
            }
        }
        $ctx['PackageId'] = $this.PackageId
        $ctx['ActionName'] = $this.Name

        if ($null -eq $this.UninstallCallback) {
            return [pscustomobject]@{
                Schema    = 'EDB.RollbackActionResult'
                Name      = $this.Name
                PackageId = $this.PackageId
                Success   = $false
                Message   = 'No uninstall callback defined.'
                Error     = $null
            }
        }

        try {
            $callbackResult = & $this.UninstallCallback @ctx
            return [pscustomobject]@{
                Schema    = 'EDB.RollbackActionResult'
                Name      = $this.Name
                PackageId = $this.PackageId
                Success   = $true
                Message   = if ($callbackResult) { [string]$callbackResult } else { 'Uninstall callback completed.' }
                Error     = $null
            }
        }
        catch {
            return [pscustomobject]@{
                Schema    = 'EDB.RollbackActionResult'
                Name      = $this.Name
                PackageId = $this.PackageId
                Success   = $false
                Message   = $_.Exception.Message
                Error     = $_.ToString()
            }
        }
    }
}

function New-EdbRollbackJournal {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[object]])]
    param(
        [object]$Session
    )

    if ($null -ne $Session) {
        if ($null -eq $Session.RollbackJournal) {
            $Session.RollbackJournal = [System.Collections.Generic.List[object]]::new()
        }
        return ,$Session.RollbackJournal
    }

    $journal = [System.Collections.Generic.List[object]]::new()
    return ,$journal
}

function Add-EdbRollbackAction {
    [CmdletBinding()]
    [OutputType([EdbRollbackActionBase])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IList]$Journal,

        [Parameter(Mandatory)]
        [EdbRollbackActionBase]$Action
    )

    if ($null -eq $Journal) {
        throw 'Journal cannot be null.'
    }

    $Journal.Add($Action) | Out-Null
    $Action
}

function Invoke-EdbRollback {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IList]$Journal,

        [hashtable]$Context = @{}
    )

    $results = [System.Collections.Generic.List[object]]::new()
    if ($null -eq $Journal -or $Journal.Count -eq 0) {
        return @()
    }

    for ($i = $Journal.Count - 1; $i -ge 0; $i--) {
        $action = $Journal[$i]
        if ($null -eq $action) {
            continue
        }

        try {
            $result = $action.Invoke($Context)
            $results.Add($result)
        }
        catch {
            $results.Add([pscustomobject]@{
                    Schema    = 'EDB.RollbackActionResult'
                    Name      = $action.Name
                    PackageId = $action.PackageId
                    Success   = $false
                    Message   = $_.Exception.Message
                    Error     = $_.ToString()
                })
        }
    }

    @($results)
}

function Clear-EdbRollbackJournal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IList]$Journal
    )

    if ($null -eq $Journal) {
        throw 'Journal cannot be null.'
    }

    $Journal.Clear()
}

Export-ModuleMember -Function @(
    'New-EdbRollbackJournal',
    'Add-EdbRollbackAction',
    'Invoke-EdbRollback',
    'Clear-EdbRollbackJournal'
)
