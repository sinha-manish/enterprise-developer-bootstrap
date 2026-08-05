#Requires -Version 7.0

function Test-EdbAzureCliInstalled {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $az = Get-Command az -ErrorAction SilentlyContinue
    $version = $null

    if ($az) {
        try {
            $json = & az version 2>$null | ConvertFrom-Json
            if ($json.'azure-cli') {
                $version = [string]$json.'azure-cli'
            }
        }
        catch { $version = $null }
    }

    [pscustomobject]@{
        Schema    = 'EDB.AzureCliInstalled'
        Installed = [bool]$az
        Path      = $(if ($az) { $az.Source } else { $null })
        Version   = $version
    }
}

function Set-EdbAzureConfiguration {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [string]$DefaultLocation,
        [string]$NotesPath = (Join-Path $env:USERPROFILE '.azure\edb-azure-notes.txt')
    )

    if (-not (Test-EdbAzureCliInstalled).Installed) {
        throw 'Azure CLI is not installed or not available on PATH.'
    }

    $applied = [System.Collections.Generic.List[string]]::new()

    if (-not [string]::IsNullOrWhiteSpace($DefaultLocation)) {
        if ($PSCmdlet.ShouldProcess('defaults.location', 'Set Azure CLI default location')) {
            & az configure --defaults location=$DefaultLocation 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to set Azure default location (exit code $LASTEXITCODE)."
            }
            $applied.Add('location')
        }
    }

    $notes = @(
        'Enterprise Developer Bootstrap - Azure configuration notes'
        "Updated: $([datetime]::UtcNow.ToString('o'))"
        ''
        'Use `az login` interactively or federated credentials configured by IT.'
        'EDB never stores or logs secrets, tokens, or client secrets.'
    )
    if ($DefaultLocation) {
        $notes += "Default location: $DefaultLocation"
    }

    $notesDir = Split-Path -Parent $NotesPath
    if (-not (Test-Path -LiteralPath $notesDir)) {
        New-Item -ItemType Directory -Path $notesDir -Force | Out-Null
    }

    if ($PSCmdlet.ShouldProcess($NotesPath, 'Write Azure configuration notes')) {
        ($notes -join [Environment]::NewLine) + [Environment]::NewLine |
            Set-Content -LiteralPath $NotesPath -Encoding UTF8
    }

    [pscustomobject]@{
        Schema       = 'EDB.AzureConfigurationResult'
        Applied      = $applied.ToArray()
        NotesPath    = $NotesPath
        Location     = $DefaultLocation
    }
}

Export-ModuleMember -Function @(
    'Test-EdbAzureCliInstalled',
    'Set-EdbAzureConfiguration'
)
