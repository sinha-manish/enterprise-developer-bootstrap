#Requires -Version 7.0
using module '..\EDB.Contracts'

<#
.SYNOPSIS
    Domain model factory cmdlets for Enterprise Developer Bootstrap.
#>

function Set-EdbObjectSchema {
    param(
        [Parameter(Mandatory)]
        [object]$Object,
        [Parameter(Mandatory)]
        [string]$Schema
    )
    $Object.PSObject.TypeNames.Insert(0, $Schema)
    $Object | Add-Member -NotePropertyName Schema -NotePropertyValue $Schema -Force
    $Object
}

function New-EdbPackageDefinition {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DisplayName,

        [string]$WingetId,
        [string]$ChocolateyId,

        [ValidateNotNullOrEmpty()]
        [string]$Category = 'General',

        [string[]]$Profiles = @(),
        [bool]$RequiresAdmin = $false,
        [string[]]$DependsOn = @(),
        [string]$ValidateCommand,
        [string]$PostInstallScript,
        [bool]$AllowParallel = $true,
        [hashtable]$Metadata = @{}
    )

    $metadataInstallType = if ($Metadata -and $Metadata.ContainsKey('installType')) {
        [string]$Metadata['installType']
    }
    else {
        ''
    }

    if ([string]::IsNullOrWhiteSpace($WingetId) -and [string]::IsNullOrWhiteSpace($ChocolateyId)) {
        $allowedMetadataInstall = @('vscodeExtension', 'pip', 'script')
        if ($allowedMetadataInstall -notcontains $metadataInstallType) {
            throw "Package '$Id' must define WingetId and/or ChocolateyId, or Metadata.installType of $($allowedMetadataInstall -join ', ')."
        }
    }

    Set-EdbObjectSchema -Schema 'EDB.PackageDefinition' -Object ([pscustomobject]@{
            Id                = $Id
            DisplayName       = $DisplayName
            WingetId          = $WingetId
            ChocolateyId      = $ChocolateyId
            Category          = $Category
            Profiles          = @($Profiles)
            RequiresAdmin     = $RequiresAdmin
            DependsOn         = @($DependsOn)
            ValidateCommand   = $ValidateCommand
            PostInstallScript = $PostInstallScript
            AllowParallel     = $AllowParallel
            Metadata          = $Metadata
        })
}

function New-EdbDeveloperProfile {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [string]$Description = '',

        [Parameter(Mandatory)]
        [string[]]$Packages,

        [hashtable]$Settings = @{}
    )

    if ($Packages.Count -eq 0) {
        throw "Profile '$Name' must include at least one package id."
    }

    Set-EdbObjectSchema -Schema 'EDB.DeveloperProfile' -Object ([pscustomobject]@{
            Name        = $Name
            Description = $Description
            Packages    = @($Packages | Select-Object -Unique)
            Settings    = $Settings
        })
}

function New-EdbInstallResult {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$PackageId,

        [Parameter(Mandatory)]
        [EdbInstallStatus]$Status,

        [string]$Provider = '',
        [string]$Message = '',
        [datetime]$StartedAt = ([datetime]::UtcNow),
        [datetime]$CompletedAt = ([datetime]::UtcNow),
        [int]$ExitCode = 0,
        [hashtable]$Details = @{}
    )

    Set-EdbObjectSchema -Schema 'EDB.InstallResult' -Object ([pscustomobject]@{
            PackageId   = $PackageId
            Status      = $Status
            Provider    = $Provider
            Message     = $Message
            StartedAt   = $StartedAt.ToUniversalTime()
            CompletedAt = $CompletedAt.ToUniversalTime()
            DurationMs  = [math]::Max(0, [int]($CompletedAt - $StartedAt).TotalMilliseconds)
            ExitCode    = $ExitCode
            Details     = $Details
        })
}

function New-EdbPackageInstallRecord {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$PackageId,

        [EdbInstallStatus]$Status = [EdbInstallStatus]::Pending,
        [string]$Provider = '',
        [string]$Message = ''
    )

    Set-EdbObjectSchema -Schema 'EDB.PackageInstallRecord' -Object ([pscustomobject]@{
            PackageId = $PackageId
            Status    = $Status
            Provider  = $Provider
            Message   = $Message
            UpdatedAt = [datetime]::UtcNow
        })
}

function New-EdbInstallSession {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$SessionId = ([guid]::NewGuid().ToString('N')),
        [string]$ProfileName = '',
        [string[]]$RequestedPackages = @(),
        [string]$HostName = $env:COMPUTERNAME,
        [string]$UserName = $env:USERNAME,
        [hashtable]$Options = @{}
    )

    if ([string]::IsNullOrWhiteSpace($SessionId)) {
        $SessionId = [guid]::NewGuid().ToString('N')
    }

    Set-EdbObjectSchema -Schema 'EDB.InstallSession' -Object ([pscustomobject]@{
            SessionId         = $SessionId
            ProfileName       = $ProfileName
            RequestedPackages = @($RequestedPackages)
            CompletedPackages = [System.Collections.Generic.List[string]]::new()
            FailedPackages    = [System.Collections.Generic.List[string]]::new()
            SkippedPackages   = [System.Collections.Generic.List[string]]::new()
            Results           = [System.Collections.Generic.List[object]]::new()
            RollbackJournal   = [System.Collections.Generic.List[object]]::new()
            HostName          = $HostName
            UserName          = $UserName
            Options           = $Options
            StartedAt         = [datetime]::UtcNow
            CompletedAt       = $null
            Status            = 'Running'
        })
}

function New-EdbPreflightResult {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [bool]$IsWindows11OrCompatible = $false,
        [string]$OsCaption = '',
        [string]$OsVersion = '',
        [bool]$IsAdministrator = $false,
        [bool]$WingetAvailable = $false,
        [string]$WingetVersion = '',
        [bool]$InternetAvailable = $false,
        [bool]$ProxyDetected = $false,
        [string]$ProxyAddress = '',
        [string[]]$Errors = @(),
        [string[]]$Warnings = @()
    )

    $passed = ($Errors.Count -eq 0)

    Set-EdbObjectSchema -Schema 'EDB.PreflightResult' -Object ([pscustomobject]@{
            Passed                  = $passed
            IsWindows11OrCompatible = $IsWindows11OrCompatible
            OsCaption               = $OsCaption
            OsVersion               = $OsVersion
            IsAdministrator         = $IsAdministrator
            WingetAvailable         = $WingetAvailable
            WingetVersion           = $WingetVersion
            InternetAvailable       = $InternetAvailable
            ProxyDetected           = $ProxyDetected
            ProxyAddress            = $ProxyAddress
            Errors                  = @($Errors)
            Warnings                = @($Warnings)
            CheckedAt               = [datetime]::UtcNow
        })
}

function New-EdbHealthCheckResult {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [EdbHealthStatus]$Status,

        [string]$Message = '',
        [hashtable]$Data = @{}
    )

    Set-EdbObjectSchema -Schema 'EDB.HealthCheckResult' -Object ([pscustomobject]@{
            Name      = $Name
            Status    = $Status
            Message   = $Message
            Data      = $Data
            CheckedAt = [datetime]::UtcNow
        })
}

function New-EdbLogEntry {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [EdbLogLevel]$Level,

        [Parameter(Mandatory)]
        [string]$Message,

        [hashtable]$Properties = @{},
        [string]$Source = 'EDB'
    )

    Set-EdbObjectSchema -Schema 'EDB.LogEntry' -Object ([pscustomobject]@{
            Timestamp  = [datetime]::UtcNow
            Level      = $Level
            Message    = $Message
            Source     = $Source
            Properties = $Properties
        })
}

function New-EdbReportDocument {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object]$Session,

        [object]$Preflight = $null,
        [object[]]$HealthResults = @(),
        [string]$Summary = ''
    )

    $succeeded = @($Session.Results | Where-Object { $_.Status -eq [EdbInstallStatus]::Succeeded }).Count
    $failed = @($Session.Results | Where-Object { $_.Status -eq [EdbInstallStatus]::Failed }).Count
    $skipped = @($Session.Results | Where-Object { $_.Status -eq [EdbInstallStatus]::Skipped }).Count

    Set-EdbObjectSchema -Schema 'EDB.ReportDocument' -Object ([pscustomobject]@{
            GeneratedAt   = [datetime]::UtcNow
            SessionId     = $Session.SessionId
            ProfileName   = $Session.ProfileName
            HostName      = $Session.HostName
            UserName      = $Session.UserName
            Status        = $Session.Status
            StartedAt     = $Session.StartedAt
            CompletedAt   = $Session.CompletedAt
            Summary       = $Summary
            Counts        = [pscustomobject]@{
                Succeeded = $succeeded
                Failed    = $failed
                Skipped   = $skipped
                Total     = @($Session.Results).Count
            }
            Preflight     = $Preflight
            Results       = @($Session.Results)
            HealthResults = @($HealthResults)
            Options       = $Session.Options
        })
}

Export-ModuleMember -Function @(
    'New-EdbPackageDefinition',
    'New-EdbDeveloperProfile',
    'New-EdbInstallResult',
    'New-EdbInstallSession',
    'New-EdbPreflightResult',
    'New-EdbHealthCheckResult',
    'New-EdbLogEntry',
    'New-EdbReportDocument',
    'New-EdbPackageInstallRecord'
)
