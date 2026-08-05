#Requires -Version 7.0
using module '..\EDB.Contracts'

<#
.SYNOPSIS
    File and console logger implementing EdbLoggerBase.
#>

class EdbLogger : EdbLoggerBase {
    [string]$LogDirectory
    [string]$LogFilePath
    [EdbLogLevel]$MinimumLevel
    [bool]$WriteToConsole
    [System.Collections.Generic.HashSet[string]]$SensitivePropertyNames
    hidden [object]$SyncRoot
    hidden [System.IO.StreamWriter]$Writer

    EdbLogger([string]$LogDirectory, [EdbLogLevel]$MinimumLevel, [bool]$WriteToConsole, [string]$SessionId) {
        if ([string]::IsNullOrWhiteSpace($LogDirectory)) {
            throw 'LogDirectory is required.'
        }

        $this.LogDirectory = $LogDirectory
        $this.MinimumLevel = $MinimumLevel
        $this.WriteToConsole = $WriteToConsole
        $this.SyncRoot = [object]::new()
        $this.SensitivePropertyNames = [System.Collections.Generic.HashSet[string]]::new(
            [string[]]@('password', 'secret', 'token', 'apikey', 'api_key', 'authorization', 'privatekey', 'private_key'),
            [StringComparer]::OrdinalIgnoreCase
        )

        if (-not (Test-Path -LiteralPath $LogDirectory)) {
            New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
        }

        $safeSession = if ([string]::IsNullOrWhiteSpace($SessionId)) {
            [guid]::NewGuid().ToString('N')
        }
        else {
            ($SessionId -replace '[^a-zA-Z0-9_-]', '_')
        }

        $fileName = "edb-{0}-{1:yyyyMMdd-HHmmss}.log" -f $safeSession, [datetime]::UtcNow
        $this.LogFilePath = Join-Path $LogDirectory $fileName
        $this.Writer = [System.IO.StreamWriter]::new($this.LogFilePath, $true, [System.Text.UTF8Encoding]::new($false))
        $this.Writer.AutoFlush = $true
    }

    [void] Log([EdbLogLevel]$Level, [string]$Message, [hashtable]$Properties) {
        if ($Level -lt $this.MinimumLevel) {
            return
        }

        $safeProps = $this.Redact($Properties)
        $entry = [ordered]@{
            timestamp  = [datetime]::UtcNow.ToString('o')
            level      = $Level.ToString()
            message    = $Message
            properties = $safeProps
        }
        $line = ($entry | ConvertTo-Json -Compress -Depth 6)

        [System.Threading.Monitor]::Enter($this.SyncRoot)
        try {
            $this.Writer.WriteLine($line)
        }
        finally {
            [System.Threading.Monitor]::Exit($this.SyncRoot)
        }

        if ($this.WriteToConsole) {
            $color = switch ($Level) {
                ([EdbLogLevel]::Warning) { 'Yellow' }
                ([EdbLogLevel]::Error) { 'Red' }
                ([EdbLogLevel]::Critical) { 'Red' }
                default { 'Gray' }
            }
            Write-Host ("[{0}] {1}" -f $Level, $Message) -ForegroundColor $color
        }
    }

    [void] Flush() {
        [System.Threading.Monitor]::Enter($this.SyncRoot)
        try {
            if ($null -ne $this.Writer) {
                $this.Writer.Flush()
            }
        }
        finally {
            [System.Threading.Monitor]::Exit($this.SyncRoot)
        }
    }

    [string] GetLogDirectory() {
        return $this.LogDirectory
    }

    [hashtable] Redact([hashtable]$Properties) {
        $result = @{}
        if ($null -eq $Properties) {
            return $result
        }

        foreach ($key in $Properties.Keys) {
            if ($this.SensitivePropertyNames.Contains([string]$key)) {
                $result[$key] = '***REDACTED***'
            }
            else {
                $result[$key] = $Properties[$key]
            }
        }
        return $result
    }

    [void] Close() {
        [System.Threading.Monitor]::Enter($this.SyncRoot)
        try {
            if ($null -ne $this.Writer) {
                $this.Writer.Flush()
                $this.Writer.Dispose()
                $this.Writer = $null
            }
        }
        finally {
            [System.Threading.Monitor]::Exit($this.SyncRoot)
        }
    }
}

function Get-EdbDefaultLogDirectory {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$RepositoryRoot
    )

    if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
        $moduleRoot = Split-Path -Parent $PSScriptRoot
        $RepositoryRoot = Split-Path -Parent $moduleRoot
    }

    Join-Path $RepositoryRoot 'logs'
}

function Get-EdbLogDirectory {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [EdbLoggerBase]$Logger
    )

    $Logger.GetLogDirectory()
}

function New-EdbLogger {
    [CmdletBinding()]
    [OutputType([EdbLogger])]
    param(
        [string]$LogDirectory,
        [EdbLogLevel]$MinimumLevel = [EdbLogLevel]::Information,
        [bool]$WriteToConsole = $true,
        [string]$SessionId,
        [string]$RepositoryRoot
    )

    if ([string]::IsNullOrWhiteSpace($LogDirectory)) {
        $LogDirectory = Get-EdbDefaultLogDirectory -RepositoryRoot $RepositoryRoot
    }

    [EdbLogger]::new($LogDirectory, $MinimumLevel, $WriteToConsole, $SessionId)
}

function Write-EdbLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [EdbLoggerBase]$Logger,

        [Parameter(Mandatory)]
        [EdbLogLevel]$Level,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [hashtable]$Properties = @{}
    )

    $Logger.Log($Level, $Message, $Properties)
}

Export-ModuleMember -Function @(
    'New-EdbLogger',
    'Write-EdbLog',
    'Get-EdbLogDirectory',
    'Get-EdbDefaultLogDirectory'
)
