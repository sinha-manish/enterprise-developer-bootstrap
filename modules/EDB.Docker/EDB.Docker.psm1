#Requires -Version 7.0

function Test-EdbDockerInstalled {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $command = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $command) {
        return [pscustomobject]@{
            Schema    = 'EDB.DockerInstalled'
            Installed = $false
            Path      = $null
            Version   = $null
        }
    }

    $version = $null
    try {
        $versionOutput = & docker --version 2>$null
        if ($versionOutput) {
            $version = ($versionOutput | Select-Object -First 1).ToString().Trim()
        }
    }
    catch {
        $version = $null
    }

    [pscustomobject]@{
        Schema    = 'EDB.DockerInstalled'
        Installed = $true
        Path      = $command.Source
        Version   = $version
    }
}

function Set-EdbDockerConfiguration {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [hashtable]$DaemonSettings,
        [string]$DaemonJsonPath = (Join-Path $env:USERPROFILE '.docker\daemon.json'),
        [string]$NotesPath = (Join-Path $env:USERPROFILE '.docker\edb-docker-notes.txt')
    )

    $notes = @(
        'Enterprise Developer Bootstrap - Docker configuration notes'
        "Updated: $([datetime]::UtcNow.ToString('o'))"
        ''
        'daemon.json is merged safely; existing keys are preserved unless overridden.'
        'Restart Docker Desktop after changing daemon.json.'
    )

    $merged = @{}
    $existingPath = $DaemonJsonPath

    if (Test-Path -LiteralPath $existingPath) {
        try {
            $raw = Get-Content -LiteralPath $existingPath -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                $existing = $raw | ConvertFrom-Json
                foreach ($prop in $existing.PSObject.Properties) {
                    $merged[$prop.Name] = $prop.Value
                }
            }
            $notes += "Existing daemon.json found at: $existingPath"
        }
        catch {
            throw "Existing daemon.json at '$existingPath' is invalid JSON: $($_.Exception.Message)"
        }
    }
    else {
        $notes += 'No existing daemon.json; a new file will be created.'
    }

    if ($DaemonSettings) {
        foreach ($key in $DaemonSettings.Keys) {
            $merged[$key] = $DaemonSettings[$key]
        }
    }

    if ($merged.Count -eq 0) {
        $notes += 'No daemon settings supplied; only notes were written.'
    }

    $directory = Split-Path -Parent $DaemonJsonPath
    if (-not (Test-Path -LiteralPath $directory)) {
        if ($PSCmdlet.ShouldProcess($directory, 'Create Docker config directory')) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
    }

    if ($merged.Count -gt 0 -and $PSCmdlet.ShouldProcess($DaemonJsonPath, 'Write merged daemon.json')) {
        ($merged | ConvertTo-Json -Depth 10) + [Environment]::NewLine |
            Set-Content -LiteralPath $DaemonJsonPath -Encoding UTF8 -NoNewline
        $notes += "Merged daemon.json written to: $DaemonJsonPath"
    }

    if ($PSCmdlet.ShouldProcess($NotesPath, 'Write Docker configuration notes')) {
        ($notes -join [Environment]::NewLine) + [Environment]::NewLine |
            Set-Content -LiteralPath $NotesPath -Encoding UTF8
    }

    [pscustomobject]@{
        Schema         = 'EDB.DockerConfigurationResult'
        DaemonJsonPath = $DaemonJsonPath
        NotesPath      = $NotesPath
        SettingCount   = $merged.Count
    }
}

Export-ModuleMember -Function @(
    'Test-EdbDockerInstalled',
    'Set-EdbDockerConfiguration'
)
