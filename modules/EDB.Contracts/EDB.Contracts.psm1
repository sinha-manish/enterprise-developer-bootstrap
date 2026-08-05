#Requires -Version 7.0
<#
.SYNOPSIS
    Domain contracts for Enterprise Developer Bootstrap.
.DESCRIPTION
    Defines shared enums and abstract base classes used as contracts across layers.
    PowerShell does not ship first-class custom interfaces; abstract bases provide
    the same architectural boundary for dependency inversion.
#>

enum EdbLogLevel {
    Trace = 0
    Debug = 1
    Information = 2
    Warning = 3
    Error = 4
    Critical = 5
}

enum EdbInstallStatus {
    Pending = 0
    Skipped = 1
    Succeeded = 2
    Failed = 3
    RolledBack = 4
}

enum EdbHealthStatus {
    Unknown = 0
    Healthy = 1
    Degraded = 2
    Unhealthy = 3
}

class EdbLoggerBase {
    [void] Log([EdbLogLevel]$Level, [string]$Message, [hashtable]$Properties) {
        throw [System.NotImplementedException]::new('Log must be overridden by a concrete logger.')
    }

    [void] Flush() {
        throw [System.NotImplementedException]::new('Flush must be overridden by a concrete logger.')
    }

    [string] GetLogDirectory() {
        throw [System.NotImplementedException]::new('GetLogDirectory must be overridden by a concrete logger.')
    }
}

class EdbPackageProviderBase {
    [string] $Name

    [bool] IsAvailable() {
        throw [System.NotImplementedException]::new('IsAvailable must be overridden.')
    }

    [bool] IsPackageInstalled([string]$PackageId) {
        throw [System.NotImplementedException]::new('IsPackageInstalled must be overridden.')
    }

    [object] InstallPackage([string]$PackageId, [hashtable]$Options) {
        throw [System.NotImplementedException]::new('InstallPackage must be overridden.')
    }

    [object] UninstallPackage([string]$PackageId, [hashtable]$Options) {
        throw [System.NotImplementedException]::new('UninstallPackage must be overridden.')
    }
}

class EdbPackageInstallerBase {
    [string] $PackageId

    [object] Test() {
        throw [System.NotImplementedException]::new('Test must be overridden.')
    }

    [object] Install([hashtable]$Context) {
        throw [System.NotImplementedException]::new('Install must be overridden.')
    }

    [object] Uninstall([hashtable]$Context) {
        throw [System.NotImplementedException]::new('Uninstall must be overridden.')
    }
}

class EdbRollbackActionBase {
    [string] $Name
    [string] $PackageId

    [object] Invoke([hashtable]$Context) {
        throw [System.NotImplementedException]::new('Invoke must be overridden.')
    }
}

class EdbHealthCheckBase {
    [string] $Name

    [object] Invoke([hashtable]$Context) {
        throw [System.NotImplementedException]::new('Invoke must be overridden.')
    }
}

class EdbReportWriterBase {
    [string] $Format

    [string] WriteReport([object]$ReportDocument, [string]$OutputPath) {
        throw [System.NotImplementedException]::new('WriteReport must be overridden.')
    }
}

class EdbContractsMarker {
    static [string] GetVersion() { return '1.0.0' }
}

Export-ModuleMember -Function @()
