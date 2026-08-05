#Requires -Version 7.0

. (Join-Path (Split-Path -Parent $PSScriptRoot) 'EDB.Configuration\EDB.Configuration.Internal.ps1')

function Get-EdbProfilesDirectory {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$RepositoryRoot,
        [string]$ConfigRoot
    )

    Join-Path (Get-EdbConfigRoot -RepositoryRoot $RepositoryRoot -ConfigRoot $ConfigRoot) 'profiles'
}

function Import-EdbProfileDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $document = Import-EdbConfigFile -Path $Path
    if ($null -eq $document) {
        throw "Profile document is empty: $Path"
    }

    if ($document -is [pscustomobject]) {
        $name = if ($document.Name) { [string]$document.Name } else { [IO.Path]::GetFileNameWithoutExtension($Path) }
        $description = if ($document.Description) { [string]$document.Description } else { '' }
        $packages = @($document.Packages | ForEach-Object { [string]$_ })
        $settings = ConvertTo-EdbHashtable -InputObject $(if ($document.Settings) { $document.Settings } else { @{} })
        return New-EdbDeveloperProfile -Name $name -Description $description -Packages $packages -Settings $settings
    }

    $table = ConvertTo-EdbHashtable -InputObject $document
    $name = if ($table.ContainsKey('Name')) { [string]$table['Name'] } else { [IO.Path]::GetFileNameWithoutExtension($Path) }
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = [IO.Path]::GetFileNameWithoutExtension($Path)
    }

    $rawPackages = if ($table.ContainsKey('Packages')) { @($table['Packages']) } else { @() }
    $packages = @($rawPackages | ForEach-Object {
            if ($_ -is [string]) { $_ }
            elseif ($null -eq $_) { $null }
            else { [string]$_ }
        } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    $description = if ($table.ContainsKey('Description')) { [string]$table['Description'] } else { '' }
    $settings = ConvertTo-EdbHashtable -InputObject $(if ($table.ContainsKey('Settings')) { $table['Settings'] } else { @{} })

    New-EdbDeveloperProfile -Name $name -Description $description -Packages $packages -Settings $settings
}

function Resolve-EdbProfileConfigFile {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$ProfilesDirectory,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfileName
    )

    $jsonPath = Join-Path $ProfilesDirectory ($ProfileName + '.json')
    if (Test-Path -LiteralPath $jsonPath) {
        return $jsonPath
    }

    foreach ($extension in @('.yaml', '.yml')) {
        $candidate = Join-Path $ProfilesDirectory ($ProfileName + $extension)
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    throw "Profile '$ProfileName' was not found in '$ProfilesDirectory'."
}

function Get-EdbProfileList {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [string]$RepositoryRoot,
        [string]$ConfigRoot,
        [string]$ProfilesDirectory
    )

    $directory = if ([string]::IsNullOrWhiteSpace($ProfilesDirectory)) {
        Get-EdbProfilesDirectory -RepositoryRoot $RepositoryRoot -ConfigRoot $ConfigRoot
    }
    else {
        $ProfilesDirectory
    }

    if (-not (Test-Path -LiteralPath $directory)) {
        throw "Profiles directory not found: $directory"
    }

    $names = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in Get-ChildItem -LiteralPath $directory -File |
        Where-Object { $_.Extension.ToLowerInvariant() -in @('.json', '.yaml', '.yml') }) {
        [void]$names.Add($file.BaseName)
    }

    @($names | Sort-Object)
}

function Get-EdbProfile {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [string]$RepositoryRoot,
        [string]$ConfigRoot,
        [string]$ProfilesDirectory
    )

    $directory = if ([string]::IsNullOrWhiteSpace($ProfilesDirectory)) {
        Get-EdbProfilesDirectory -RepositoryRoot $RepositoryRoot -ConfigRoot $ConfigRoot
    }
    else {
        $ProfilesDirectory
    }

    $path = Resolve-EdbProfileConfigFile -ProfilesDirectory $directory -ProfileName $Name
    Import-EdbProfileDocument -Path $path
}

function Resolve-EdbProfilePackages {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object]$Profile,

        [Parameter(Mandatory)]
        [object[]]$Catalog,

        [bool]$IncludeDependencies = $true
    )

    if ($Profile.Schema -ne 'EDB.DeveloperProfile') {
        throw 'Profile object must use schema EDB.DeveloperProfile.'
    }

    $catalogById = @{}
    foreach ($package in $Catalog) {
        if ($null -eq $package -or [string]::IsNullOrWhiteSpace($package.Id)) {
            continue
        }
        $catalogById[$package.Id] = $package
    }

    $selectedIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $queue = [System.Collections.Generic.Queue[string]]::new()

    foreach ($packageId in @($Profile.Packages)) {
        if (-not [string]::IsNullOrWhiteSpace($packageId)) {
            $queue.Enqueue([string]$packageId)
        }
    }

    while ($queue.Count -gt 0) {
        $currentId = $queue.Dequeue()
        if (-not $selectedIds.Add($currentId)) {
            continue
        }

        if (-not $catalogById.ContainsKey($currentId)) {
            throw "Profile '$($Profile.Name)' references unknown package id '$currentId'."
        }

        if ($IncludeDependencies) {
            foreach ($dep in @($catalogById[$currentId].DependsOn)) {
                if (-not [string]::IsNullOrWhiteSpace($dep) -and -not $selectedIds.Contains($dep)) {
                    $queue.Enqueue([string]$dep)
                }
            }
        }
    }

    $selected = @($selectedIds | ForEach-Object { $catalogById[$_] })
    if (Get-Command Resolve-EdbPackageOrder -ErrorAction SilentlyContinue) {
        return Resolve-EdbPackageOrder -Packages $selected
    }

    @($selected)
}
