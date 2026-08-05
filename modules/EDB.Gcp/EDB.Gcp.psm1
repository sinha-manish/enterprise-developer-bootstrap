#Requires -Version 7.0

function Test-EdbGcpCliInstalled {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $gcloud = Get-Command gcloud -ErrorAction SilentlyContinue
    $version = $null

    if ($gcloud) {
        try {
            $version = (& gcloud --version 2>$null | Select-Object -First 1).ToString().Trim()
        }
        catch { $version = $null }
    }

    [pscustomobject]@{
        Schema    = 'EDB.GcpCliInstalled'
        Installed = [bool]$gcloud
        Path      = $(if ($gcloud) { $gcloud.Source } else { $null })
        Version   = $version
    }
}

function Set-EdbGcpConfiguration {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [string]$ProjectId,
        [string]$Region,
        [string]$NotesPath = (Join-Path $env:USERPROFILE '.config\gcloud\edb-gcp-notes.txt')
    )

    if (-not (Test-EdbGcpCliInstalled).Installed) {
        throw 'Google Cloud CLI (gcloud) is not installed or not available on PATH.'
    }

    $applied = [System.Collections.Generic.List[string]]::new()

    if (-not [string]::IsNullOrWhiteSpace($ProjectId)) {
        if ($PSCmdlet.ShouldProcess($ProjectId, 'Set gcloud core/project')) {
            & gcloud config set project $ProjectId 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to set gcloud project (exit code $LASTEXITCODE)."
            }
            $applied.Add('project')
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Region)) {
        if ($PSCmdlet.ShouldProcess($Region, 'Set gcloud compute/region')) {
            & gcloud config set compute/region $Region 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to set gcloud compute/region (exit code $LASTEXITCODE)."
            }
            $applied.Add('compute/region')
        }
    }

    $notes = @(
        'Enterprise Developer Bootstrap - GCP configuration notes'
        "Updated: $([datetime]::UtcNow.ToString('o'))"
        ''
        'Authenticate with `gcloud auth login` or application-default credentials from IT.'
        'EDB never stores or logs service account keys or OAuth tokens.'
    )
    if ($ProjectId) { $notes += "Project: $ProjectId" }
    if ($Region) { $notes += "Region: $Region" }

    $notesDir = Split-Path -Parent $NotesPath
    if (-not (Test-Path -LiteralPath $notesDir)) {
        New-Item -ItemType Directory -Path $notesDir -Force | Out-Null
    }

    if ($PSCmdlet.ShouldProcess($NotesPath, 'Write GCP configuration notes')) {
        ($notes -join [Environment]::NewLine) + [Environment]::NewLine |
            Set-Content -LiteralPath $NotesPath -Encoding UTF8
    }

    [pscustomobject]@{
        Schema    = 'EDB.GcpConfigurationResult'
        Applied   = $applied.ToArray()
        NotesPath = $NotesPath
        ProjectId = $ProjectId
        Region    = $Region
    }
}

Export-ModuleMember -Function @(
    'Test-EdbGcpCliInstalled',
    'Set-EdbGcpConfiguration'
)
