#Requires -Version 7.0

function Get-EdbVSCodeRepositoryRoot {
    $moduleRoot = Split-Path -Parent $PSScriptRoot
    (Resolve-Path (Join-Path $moduleRoot '..')).Path
}

function Get-EdbVSCodePaths {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$RepositoryRoot
    )

    $root = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
        Get-EdbVSCodeRepositoryRoot
    }
    else {
        (Resolve-Path -LiteralPath $RepositoryRoot).Path
    }

    $appData = $env:APPDATA
    $userSettingsDir = Join-Path $appData 'Code\User'
    $userSettingsPath = Join-Path $userSettingsDir 'settings.json'
    $userExtensionsPath = Join-Path $userSettingsDir 'extensions.json'
    $defaultSettingsPath = Join-Path $root 'config\vscode\settings.json'
    $defaultExtensionsPath = Join-Path $root 'config\vscode\extensions.json'

    $codeCommand = Get-Command code -ErrorAction SilentlyContinue

    [pscustomobject]@{
        Schema                 = 'EDB.VSCodePaths'
        UserSettingsDirectory  = $userSettingsDir
        UserSettingsPath       = $userSettingsPath
        UserExtensionsPath     = $userExtensionsPath
        DefaultSettingsPath    = $defaultSettingsPath
        DefaultExtensionsPath  = $defaultExtensionsPath
        CodeCliPath            = $(if ($codeCommand) { $codeCommand.Source } else { $null })
        CodeCliAvailable       = [bool]$codeCommand
    }
}

function Merge-EdbJsonObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Base,
        [Parameter(Mandatory)]
        [hashtable]$Overlay
    )

    $merged = @{}
    foreach ($key in $Base.Keys) {
        $merged[$key] = $Base[$key]
    }

    foreach ($key in $Overlay.Keys) {
        $overlayValue = $Overlay[$key]
        $baseValue = $merged[$key]

        if ($baseValue -is [hashtable] -and $overlayValue -is [hashtable]) {
            $merged[$key] = Merge-EdbJsonObject -Base $baseValue -Overlay $overlayValue
        }
        else {
            $merged[$key] = $overlayValue
        }
    }

    return $merged
}

function ConvertTo-EdbJsonHashtable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        $InputObject
    )

    if ($null -eq $InputObject) { return @{} }
    if ($InputObject -is [hashtable]) { return $InputObject }

    if ($InputObject -is [pscustomobject]) {
        $table = @{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            $value = $prop.Value
            if ($value -is [pscustomobject]) {
                $table[$prop.Name] = ConvertTo-EdbJsonHashtable -InputObject $value
            }
            else {
                $table[$prop.Name] = $value
            }
        }
        return $table
    }

    return @{}
}

function Read-EdbJsonFileSafe {
    [CmdletBinding()]
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @{}
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return @{} }
        return ConvertTo-EdbJsonHashtable -InputObject ($raw | ConvertFrom-Json)
    }
    catch {
        throw "Failed to parse JSON at '$Path': $($_.Exception.Message)"
    }
}

function Write-EdbJsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [hashtable]$Content
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    ($Content | ConvertTo-Json -Depth 20) + [Environment]::NewLine |
        Set-Content -LiteralPath $Path -Encoding UTF8 -NoNewline
}

function Set-EdbVSCodeSettings {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [hashtable]$Settings,
        [string]$SettingsPath,
        [string]$RepositoryRoot,
        [switch]$UseRepositoryDefaults
    )

    $paths = Get-EdbVSCodePaths -RepositoryRoot $RepositoryRoot
    $targetPath = if ([string]::IsNullOrWhiteSpace($SettingsPath)) {
        $paths.UserSettingsPath
    }
    else {
        $SettingsPath
    }

    $existing = Read-EdbJsonFileSafe -Path $targetPath
    $merged = @{}

    if ($UseRepositoryDefaults -and (Test-Path -LiteralPath $paths.DefaultSettingsPath)) {
        $merged = Read-EdbJsonFileSafe -Path $paths.DefaultSettingsPath
    }

    $merged = Merge-EdbJsonObject -Base $merged -Overlay $existing

    if ($Settings) {
        $merged = Merge-EdbJsonObject -Base $merged -Overlay $Settings
    }

    if ($PSCmdlet.ShouldProcess($targetPath, 'Merge VS Code settings.json')) {
        Write-EdbJsonFile -Path $targetPath -Content $merged
    }

    [pscustomobject]@{
        Schema       = 'EDB.VSCodeSettingsResult'
        SettingsPath = $targetPath
        KeyCount     = $merged.Keys.Count
    }
}

function Install-EdbVSCodeExtension {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExtensionId,
        [switch]$Force
    )

    $code = Get-Command code -ErrorAction SilentlyContinue
    if (-not $code) {
        throw 'VS Code CLI (code) is not available on PATH.'
    }

    $args = @('--install-extension', $ExtensionId)
    if ($Force) { $args += '--force' }

    if ($PSCmdlet.ShouldProcess($ExtensionId, 'Install VS Code extension')) {
        & code @args 2>&1 | ForEach-Object { Write-Verbose $_ }
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install extension '$ExtensionId' (exit code $LASTEXITCODE)."
        }
    }

    [pscustomobject]@{
        Schema       = 'EDB.VSCodeExtensionResult'
        ExtensionId  = $ExtensionId
        Installed    = $true
    }
}

function Install-EdbDefaultVSCodeExtensions {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([object[]])]
    param(
        [string[]]$ExtensionIds,
        [string]$RepositoryRoot,
        [switch]$Force
    )

    $paths = Get-EdbVSCodePaths -RepositoryRoot $RepositoryRoot
    $ids = if ($ExtensionIds -and $ExtensionIds.Count -gt 0) {
        $ExtensionIds
    }
    elseif (Test-Path -LiteralPath $paths.DefaultExtensionsPath) {
        $doc = Get-Content -LiteralPath $paths.DefaultExtensionsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($doc.recommendations) { @($doc.recommendations) } else { @() }
    }
    else {
        @(
            'eamodio.gitlens',
            'esbenp.prettier-vscode',
            'dbaeumer.vscode-eslint',
            'ms-vscode.powershell',
            'ms-azuretools.vscode-docker',
            'ms-vscode-remote.remote-wsl',
            'ms-python.python'
        )
    }

    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($id in $ids) {
        if ([string]::IsNullOrWhiteSpace($id)) { continue }
        $result = Install-EdbVSCodeExtension -ExtensionId $id -Force:$Force
        $results.Add($result)
    }

    return $results.ToArray()
}

Export-ModuleMember -Function @(
    'Get-EdbVSCodePaths',
    'Set-EdbVSCodeSettings',
    'Install-EdbVSCodeExtension',
    'Install-EdbDefaultVSCodeExtensions'
)
