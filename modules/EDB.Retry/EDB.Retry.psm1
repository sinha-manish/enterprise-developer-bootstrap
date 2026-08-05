#Requires -Version 7.0
<#
.SYNOPSIS
    Retry with exponential backoff for transient failures.
#>

function New-EdbRetryPolicy {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [ValidateRange(1, 20)]
        [int]$MaxAttempts = 3,

        [ValidateRange(0, 600000)]
        [int]$InitialDelayMs = 1000,

        [ValidateRange(1.0, 10.0)]
        [double]$BackoffMultiplier = 2.0,

        [ValidateRange(0, 600000)]
        [int]$MaxDelayMs = 30000,

        [int[]]$RetryableExitCodes = @(1618, 0x80070005, -2147024891),

        [string[]]$RetryableMessagePatterns = @(
            'timeout',
            'timed out',
            'temporar',
            'network',
            'connection',
            'unavailable',
            'busy',
            'locked'
        )
    )

    [pscustomobject]@{
        PSTypeName               = 'EDB.RetryPolicy'
        MaxAttempts              = $MaxAttempts
        InitialDelayMs           = $InitialDelayMs
        BackoffMultiplier        = $BackoffMultiplier
        MaxDelayMs               = $MaxDelayMs
        RetryableExitCodes       = @($RetryableExitCodes)
        RetryableMessagePatterns = @($RetryableMessagePatterns)
    }
}

function Test-EdbShouldRetry {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object]$Policy,

        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [nullable[int]]$ExitCode
    )

    if ($null -ne $ExitCode -and $Policy.RetryableExitCodes -contains [int]$ExitCode) {
        return $true
    }

    if ($null -eq $ErrorRecord) {
        return $false
    }

    $text = @($ErrorRecord.Exception.Message, $ErrorRecord.ToString()) -join ' '
    foreach ($pattern in $Policy.RetryableMessagePatterns) {
        if ($text -match $pattern) {
            return $true
        }
    }

    return $false
}

function Get-EdbRetryDelayMs {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [object]$Policy,

        [Parameter(Mandatory)]
        [ValidateRange(1, 100)]
        [int]$Attempt
    )

    $delay = [math]::Floor($Policy.InitialDelayMs * [math]::Pow($Policy.BackoffMultiplier, ($Attempt - 1)))
    [int][math]::Min($delay, $Policy.MaxDelayMs)
}

function Invoke-EdbRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [object]$Policy = (New-EdbRetryPolicy),

        [hashtable]$ArgumentList = @{},

        [scriptblock]$OnRetry,

        [switch]$RetryOnAnyError
    )

    $attempt = 0
    $lastError = $null

    while ($attempt -lt $Policy.MaxAttempts) {
        $attempt++
        try {
            return & $ScriptBlock @ArgumentList
        }
        catch {
            $lastError = $_
            $exitCode = $null
            if ($null -ne $_.Exception -and $_.Exception.PSObject.Properties['ExitCode']) {
                $exitCode = $_.Exception.ExitCode
            }

            $shouldRetry = $RetryOnAnyError -or (Test-EdbShouldRetry -Policy $Policy -ErrorRecord $_ -ExitCode $exitCode)
            $hasAttemptsRemaining = $attempt -lt $Policy.MaxAttempts

            if (-not $shouldRetry -or -not $hasAttemptsRemaining) {
                throw
            }

            $delay = Get-EdbRetryDelayMs -Policy $Policy -Attempt $attempt
            if ($OnRetry) {
                & $OnRetry @{
                    Attempt     = $attempt
                    DelayMs     = $delay
                    ErrorRecord = $_
                }
            }

            Start-Sleep -Milliseconds $delay
        }
    }

    throw $lastError
}

Export-ModuleMember -Function @(
    'New-EdbRetryPolicy',
    'Invoke-EdbRetry'
)
