#Requires -Version 7.0
using module '..\EDB.Contracts'
using module '..\EDB.Models'

<#
.SYNOPSIS
    Loads YAML/JSON package catalogs and settings for Enterprise Developer Bootstrap.
#>

. "$PSScriptRoot\EDB.Configuration.Internal.ps1"

function Get-EdbRepositoryRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$RepositoryRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($RepositoryRoot)) {
        return (Resolve-Path -LiteralPath $RepositoryRoot).Path
    }

    $moduleRoot = Split-Path -Parent $PSScriptRoot
    (Resolve-Path (Join-Path $moduleRoot '..')).Path
}

function Get-EdbConfigRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$RepositoryRoot,
        [string]$ConfigRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($ConfigRoot)) {
        return (Resolve-Path -LiteralPath $ConfigRoot).Path
    }

    Join-Path (Get-EdbRepositoryRoot -RepositoryRoot $RepositoryRoot) 'config'
}

function Test-EdbYamlModuleAvailable {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $null -ne (Get-Module -ListAvailable -Name powershell-yaml | Select-Object -First 1)
}

function Import-EdbJsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON file not found: $Path"
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $null
        }
        return ($raw | ConvertFrom-Json)
    }
    catch {
        throw "Failed to parse JSON file '$Path': $($_.Exception.Message)"
    }
}

function Import-EdbYamlFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "YAML file not found: $Path"
    }

    $extension = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($extension -notin @('.yaml', '.yml')) {
        throw "Import-EdbYamlFile expects a .yaml or .yml file. Received: $Path"
    }

    if (-not (Test-EdbYamlModuleAvailable)) {
        throw @"
Cannot load YAML file '$Path' because the 'powershell-yaml' module is not installed.
Install it with: Install-Module powershell-yaml -Scope CurrentUser -Force
Alternatively, provide a JSON configuration file and use Import-EdbJsonFile.
"@
    }

    Import-Module powershell-yaml -ErrorAction Stop
    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $null
        }
        return (ConvertFrom-Yaml -Yaml $raw)
    }
    catch {
        throw "Failed to parse YAML file '$Path': $($_.Exception.Message)"
    }
}

function Test-EdbPackageDefinition {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        $Definition,

        [switch]$ThrowOnFailure
    )

    try {
        $params = ConvertTo-EdbPackageDefinitionParameters -Entry $Definition
        $null = New-EdbPackageDefinition @params
        return $true
    }
    catch {
        if ($ThrowOnFailure) {
            throw
        }
        return $false
    }
}

function Get-EdbPackageCatalog {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [string]$RepositoryRoot,
        [string]$ConfigRoot,
        [string]$PackagesDirectory
    )

    $root = Get-EdbConfigRoot -RepositoryRoot $RepositoryRoot -ConfigRoot $ConfigRoot
    $packagesPath = if ([string]::IsNullOrWhiteSpace($PackagesDirectory)) {
        Join-Path $root 'packages'
    }
    else {
        $PackagesDirectory
    }

    if (-not (Test-Path -LiteralPath $packagesPath)) {
        throw "Package catalog directory not found: $packagesPath"
    }

    $catalogJson = Join-Path $packagesPath 'catalog.json'
    $catalogYaml = Join-Path $packagesPath 'catalog.yaml'
    $catalogYml = Join-Path $packagesPath 'catalog.yml'

    if (Test-Path -LiteralPath $catalogJson) {
        $files = @(Get-Item -LiteralPath $catalogJson)
    }
    elseif (Test-Path -LiteralPath $catalogYaml) {
        $files = @(Get-Item -LiteralPath $catalogYaml)
    }
    elseif (Test-Path -LiteralPath $catalogYml) {
        $files = @(Get-Item -LiteralPath $catalogYml)
    }
    else {
        $files = @(Get-ChildItem -LiteralPath $packagesPath -File -ErrorAction Stop |
            Where-Object { $_.Extension.ToLowerInvariant() -in @('.yaml', '.yml', '.json') } |
            Sort-Object Name)
    }

    if ($files.Count -eq 0) {
        throw "No package catalog files found in: $packagesPath"
    }

    $catalog = [System.Collections.Generic.List[object]]::new()
    $seenIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($file in $files) {
        $document = Import-EdbConfigFile -Path $file.FullName
        $entries = Get-EdbPackageDefinitionEntries -Document $document -SourcePath $file.FullName

        foreach ($entry in $entries) {
            $params = ConvertTo-EdbPackageDefinitionParameters -Entry $entry
            $package = New-EdbPackageDefinition @params

            if (-not $seenIds.Add($package.Id)) {
                throw "Duplicate package id '$($package.Id)' found in catalog file '$($file.Name)'."
            }

            $catalog.Add($package)
        }
    }

    return $catalog.ToArray()
}

function Get-EdbSettings {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$RepositoryRoot,
        [string]$ConfigRoot,
        [switch]$IncludeLocalOverrides
    )

    $root = Get-EdbConfigRoot -RepositoryRoot $RepositoryRoot -ConfigRoot $ConfigRoot
    $settingsDir = Join-Path $root 'settings'

    if (-not (Test-Path -LiteralPath $settingsDir)) {
        throw "Settings directory not found: $settingsDir"
    }

    $defaults = Get-EdbDefaultSettings
    $merged = $defaults

    $baseCandidates = @(
        (Join-Path $settingsDir 'default.yaml'),
        (Join-Path $settingsDir 'default.yml'),
        (Join-Path $settingsDir 'default.json'),
        (Join-Path $settingsDir 'settings.yaml'),
        (Join-Path $settingsDir 'settings.yml'),
        (Join-Path $settingsDir 'settings.json')
    )

    $loadedBase = $false
    foreach ($candidate in $baseCandidates) {
        if (-not (Test-Path -LiteralPath $candidate)) {
            continue
        }

        $document = Import-EdbConfigFile -Path $candidate
        $table = ConvertTo-EdbHashtable -InputObject $document
        $merged = Merge-EdbSettingsHashtable -Base $merged -Overlay $table
        $loadedBase = $true
        break
    }

    if (-not $loadedBase) {
        throw "No settings file found in '$settingsDir'. Expected default.yaml, default.json, or settings.yaml."
    }

    if ($IncludeLocalOverrides) {
        $localCandidates = @(
            (Join-Path $settingsDir 'local.yaml'),
            (Join-Path $settingsDir 'local.yml'),
            (Join-Path $settingsDir 'local.json')
        )

        foreach ($candidate in $localCandidates) {
            if (-not (Test-Path -LiteralPath $candidate)) {
                continue
            }

            $document = Import-EdbConfigFile -Path $candidate
            $table = ConvertTo-EdbHashtable -InputObject $document
            $merged = Merge-EdbSettingsHashtable -Base $merged -Overlay $table
            break
        }
    }

    $settings = [pscustomobject]$merged
    $settings | Add-Member -NotePropertyName Schema -NotePropertyValue 'EDB.Settings' -Force
    return $settings
}

Export-ModuleMember -Function @(
    'Get-EdbConfigRoot',
    'Import-EdbYamlFile',
    'Import-EdbJsonFile',
    'Get-EdbPackageCatalog',
    'Get-EdbSettings',
    'Test-EdbPackageDefinition'
)
