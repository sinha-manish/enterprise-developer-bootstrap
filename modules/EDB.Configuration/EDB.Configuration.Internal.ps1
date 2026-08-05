#Requires -Version 7.0

function Import-EdbConfigFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $extension = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($extension) {
        { $_ -in @('.yaml', '.yml') } { return Import-EdbYamlFile -Path $Path }
        '.json' { return Import-EdbJsonFile -Path $Path }
        default { throw "Unsupported configuration file extension '$extension' for path: $Path" }
    }
}

function ConvertTo-EdbHashtable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return @{}
    }

    if ($InputObject -is [hashtable]) {
        return $InputObject
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $table = @{}
        foreach ($key in $InputObject.Keys) {
            $table[[string]$key] = ConvertTo-EdbHashtable -InputObject $InputObject[$key]
        }
        return $table
    }

    if ($InputObject -is [System.Array]) {
        $converted = foreach ($item in $InputObject) {
            ConvertTo-EdbHashtable -InputObject $item
        }
        return @($converted)
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $converted = foreach ($item in $InputObject) {
            ConvertTo-EdbHashtable -InputObject $item
        }
        return @($converted)
    }

    if ($InputObject -is [pscustomobject]) {
        $table = @{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            $table[$prop.Name] = ConvertTo-EdbHashtable -InputObject $prop.Value
        }
        return $table
    }

    return $InputObject
}

function Get-EdbPackageDefinitionEntries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Document,
        [Parameter(Mandatory)]
        [string]$SourcePath
    )

    if ($null -eq $Document) {
        return @()
    }

    if ($Document -is [System.Collections.IEnumerable] -and $Document -isnot [string] -and $Document -isnot [hashtable] -and $Document -isnot [pscustomobject]) {
        return @($Document)
    }

    $asTable = ConvertTo-EdbHashtable -InputObject $Document
    if ($asTable.Contains('packages') -and $null -ne $asTable['packages']) {
        return @($asTable['packages'])
    }

    if ($asTable.Contains('Packages') -and $null -ne $asTable['Packages']) {
        return @($asTable['Packages'])
    }

    if ($asTable.Contains('Id')) {
        return @($Document)
    }

    throw "Configuration file '$SourcePath' does not contain package definitions. Expected a package object or a 'packages' collection."
}

function ConvertTo-EdbPackageDefinitionParameters {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Entry
    )

    $table = ConvertTo-EdbHashtable -InputObject $Entry
    @{
        Id                = [string]$table['Id']
        DisplayName       = [string]$table['DisplayName']
        WingetId          = if ($null -ne $table['WingetId']) { [string]$table['WingetId'] } else { '' }
        ChocolateyId      = if ($null -ne $table['ChocolateyId']) { [string]$table['ChocolateyId'] } else { '' }
        Category          = if ($null -ne $table['Category']) { [string]$table['Category'] } else { 'General' }
        Profiles          = @($(if ($null -ne $table['Profiles']) { $table['Profiles'] } else { @() }))
        RequiresAdmin     = [bool]($table['RequiresAdmin'])
        DependsOn         = @($(if ($null -ne $table['DependsOn']) { $table['DependsOn'] } else { @() }))
        ValidateCommand   = if ($null -ne $table['ValidateCommand']) { [string]$table['ValidateCommand'] } else { '' }
        PostInstallScript = if ($null -ne $table['PostInstallScript']) { [string]$table['PostInstallScript'] } else { '' }
        AllowParallel     = if ($null -ne $table['AllowParallel']) { [bool]$table['AllowParallel'] } else { $true }
        Metadata          = ConvertTo-EdbHashtable -InputObject $(if ($null -ne $table['Metadata']) { $table['Metadata'] } else { @{} })
    }
}

function Merge-EdbSettingsHashtable {
    [CmdletBinding()]
    param(
        [hashtable]$Base,
        [hashtable]$Overlay
    )

    $merged = @{}
    foreach ($key in $Base.Keys) {
        $merged[$key] = $Base[$key]
    }

    foreach ($key in $Overlay.Keys) {
        $overlayValue = $Overlay[$key]
        if ($merged.ContainsKey($key) -and $merged[$key] -is [hashtable] -and $overlayValue -is [hashtable]) {
            $merged[$key] = Merge-EdbSettingsHashtable -Base $merged[$key] -Overlay $overlayValue
        }
        else {
            $merged[$key] = $overlayValue
        }
    }

    return $merged
}

function Get-EdbDefaultSettings {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    @{
        LogLevel          = 'Information'
        WriteToConsole    = $true
        Parallel          = $false
        ParallelInstalls  = 2
        DefaultProvider   = 'Winget'
        RetryCount        = 3
        RequirePreflight  = $true
        RequireInternet   = $true
        GenerateReports   = $true
        ReportFormats     = @('Json', 'Html')
    }
}
