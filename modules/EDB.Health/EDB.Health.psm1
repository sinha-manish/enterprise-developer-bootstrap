#Requires -Version 7.0
using module '..\EDB.Contracts'
using module '..\EDB.Models'

<#
.SYNOPSIS
    Post-install health checks for Enterprise Developer Bootstrap packages.
.NOTES
    ValidateCommand must be a simple executable invocation (no scripts, pipes, or PowerShell metacharacters).
#>

function Test-EdbValidateCommandIsSafe {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$ValidateCommand
    )

    if ([string]::IsNullOrWhiteSpace($ValidateCommand)) {
        return $false
    }

    if ($ValidateCommand -match '[\r\n;|&$`<>]|@{|\(') {
        return $false
    }

    $tokens = @($ValidateCommand.Trim() -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($tokens.Count -eq 0) {
        return $false
    }

    $deniedFirst = @(
        'exit', 'return', 'throw', 'if', 'foreach', 'while', 'function', 'filter', 'iex',
        'invoke-expression', 'powershell'
    )
    if ($deniedFirst -contains $tokens[0].ToLowerInvariant()) {
        return $false
    }

    if ($tokens[0] -match '^(Get|Set|New|Remove|Invoke|Select|Where|ForEach)-') {
        return $false
    }

    foreach ($token in $tokens) {
        if ($token -notmatch '^[\w\.\-\\/:+]+$') {
            return $false
        }
        if ($token.Contains('..')) {
            return $false
        }
    }

    return $true
}

class EdbCommandHealthCheck : EdbHealthCheckBase {
    [string]$ValidateCommand
    [string]$PackageId

    EdbCommandHealthCheck([string]$Name, [string]$PackageId, [string]$ValidateCommand) {
        $this.Name = $Name
        $this.PackageId = $PackageId
        $this.ValidateCommand = $ValidateCommand
    }

    hidden [bool] IsSafeCommand([string]$CommandText) {
        if ([string]::IsNullOrWhiteSpace($CommandText)) {
            return $false
        }
        if ($CommandText -match '[\r\n;|&$`<>]|@{|\(') {
            return $false
        }
        $tokens = @($CommandText.Trim() -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($tokens.Count -eq 0) {
            return $false
        }
        $deniedFirst = @(
            'exit', 'return', 'throw', 'if', 'foreach', 'while', 'function', 'filter', 'iex',
            'invoke-expression', 'powershell'
        )
        if ($deniedFirst -contains $tokens[0].ToLowerInvariant()) {
            return $false
        }
        if ($tokens[0] -match '^(Get|Set|New|Remove|Invoke|Select|Where|ForEach)-') {
            return $false
        }
        foreach ($token in $tokens) {
            if ($token -notmatch '^[\w\.\-\\/:+]+$') {
                return $false
            }
            if ($token.Contains('..')) {
                return $false
            }
        }
        return $true
    }

    [object] Invoke([hashtable]$Context) {
        if ([string]::IsNullOrWhiteSpace($this.ValidateCommand)) {
            return New-EdbHealthCheckResult -Name $this.Name -Status ([EdbHealthStatus]::Unknown) `
                -Message 'No validate command configured.' -Data @{ PackageId = $this.PackageId }
        }

        if (-not $this.IsSafeCommand($this.ValidateCommand)) {
            return New-EdbHealthCheckResult -Name $this.Name -Status ([EdbHealthStatus]::Unhealthy) `
                -Message 'ValidateCommand rejected: only simple executable invocations are permitted (no scripts, pipes, or metacharacters).' `
                -Data @{ PackageId = $this.PackageId; ValidateCommand = $this.ValidateCommand }
        }

        $tokens = @($this.ValidateCommand.Trim() -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $commandName = $tokens[0]
        $arguments = @()
        if ($tokens.Count -gt 1) {
            $arguments = $tokens[1..($tokens.Count - 1)]
        }

        $resolved = Get-Command $commandName -ErrorAction SilentlyContinue
        if (-not $resolved) {
            return New-EdbHealthCheckResult -Name $this.Name -Status ([EdbHealthStatus]::Unhealthy) `
                -Message "Validation command '$commandName' was not found on PATH." `
                -Data @{ PackageId = $this.PackageId }
        }

        try {
            $output = & $resolved.Source @arguments 2>&1 | Out-String
            $exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }

            if ($exitCode -eq 0) {
                return New-EdbHealthCheckResult -Name $this.Name -Status ([EdbHealthStatus]::Healthy) `
                    -Message 'Validation command succeeded.' `
                    -Data @{ PackageId = $this.PackageId; ExitCode = $exitCode; Output = $output.Trim() }
            }

            return New-EdbHealthCheckResult -Name $this.Name -Status ([EdbHealthStatus]::Unhealthy) `
                -Message "Validation command failed with exit code $exitCode." `
                -Data @{ PackageId = $this.PackageId; ExitCode = $exitCode; Output = $output.Trim() }
        }
        catch {
            return New-EdbHealthCheckResult -Name $this.Name -Status ([EdbHealthStatus]::Unhealthy) `
                -Message $_.Exception.Message `
                -Data @{ PackageId = $this.PackageId; Error = $_.ToString() }
        }
    }
}

function Test-EdbCommandAvailable {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Command
    )

    $firstToken = ($Command -split '\s+', 2)[0]
    if ([string]::IsNullOrWhiteSpace($firstToken)) {
        return $false
    }

    $resolved = Get-Command $firstToken -ErrorAction SilentlyContinue
    return ($null -ne $resolved)
}

function New-EdbHealthCheck {
    [CmdletBinding()]
    [OutputType([EdbHealthCheckBase])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [string]$PackageId = '',
        [string]$ValidateCommand = '',

        [object]$PackageDefinition
    )

    if ($null -ne $PackageDefinition) {
        if ([string]::IsNullOrWhiteSpace($PackageId)) {
            $PackageId = [string]$PackageDefinition.Id
        }
        if ([string]::IsNullOrWhiteSpace($ValidateCommand) -and $PackageDefinition.ValidateCommand) {
            $ValidateCommand = [string]$PackageDefinition.ValidateCommand
        }
        if ($Name -eq '' -and $PackageId) {
            $Name = "command:$PackageId"
        }
    }

    [EdbCommandHealthCheck]::new($Name, $PackageId, $ValidateCommand)
}

function Invoke-EdbHealthCheck {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [EdbHealthCheckBase]$HealthCheck,

        [hashtable]$Context = @{}
    )

    $HealthCheck.Invoke($Context)
}

function Invoke-EdbHealthCheckSet {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [EdbHealthCheckBase[]]$HealthChecks,

        [hashtable]$Context = @{}
    )

    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($check in $HealthChecks) {
        if ($null -eq $check) {
            continue
        }
        $results.Add((Invoke-EdbHealthCheck -HealthCheck $check -Context $Context))
    }
    @($results)
}

Export-ModuleMember -Function @(
    'New-EdbHealthCheck',
    'Invoke-EdbHealthCheck',
    'Invoke-EdbHealthCheckSet',
    'Test-EdbCommandAvailable',
    'Test-EdbValidateCommandIsSafe'
)
