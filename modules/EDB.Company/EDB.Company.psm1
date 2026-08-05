#Requires -Version 7.0

function Get-EdbCompanyRepositoryRoot {
    $moduleRoot = Split-Path -Parent $PSScriptRoot
    (Resolve-Path (Join-Path $moduleRoot '..')).Path
}

function Get-EdbCompanyConfig {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$RepositoryRoot,
        [string]$ConfigDirectory
    )

    $root = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
        Get-EdbCompanyRepositoryRoot
    }
    else {
        (Resolve-Path -LiteralPath $RepositoryRoot).Path
    }

    $companyDir = if ([string]::IsNullOrWhiteSpace($ConfigDirectory)) {
        Join-Path $root 'config\company'
    }
    else {
        $ConfigDirectory
    }

    $candidates = @(
        (Join-Path $companyDir 'company.json'),
        (Join-Path $companyDir 'company.yaml'),
        (Join-Path $companyDir 'company.yml'),
        (Join-Path $companyDir 'company.template.json')
    )

    foreach ($candidate in $candidates) {
        if (-not (Test-Path -LiteralPath $candidate)) {
            continue
        }

        $extension = [IO.Path]::GetExtension($candidate).ToLowerInvariant()
        if ($extension -eq '.json') {
            $doc = Get-Content -LiteralPath $candidate -Raw -Encoding UTF8 | ConvertFrom-Json
            $doc | Add-Member -NotePropertyName Schema -NotePropertyValue 'EDB.CompanyConfig' -Force
            $doc | Add-Member -NotePropertyName SourcePath -NotePropertyValue $candidate -Force
            return $doc
        }
    }

    return [pscustomobject]@{
        Schema          = 'EDB.CompanyConfig'
        SourcePath      = $null
        CompanyName     = 'Enterprise'
        SupportEmail    = 'platform-engineering@example.com'
        DocumentationUrl = 'https://docs.example.com/developer-bootstrap'
        Branding        = [pscustomobject]@{
            PrimaryColor = '#0078D4'
            LogoPath     = ''
        }
    }
}

function Set-EdbCompanyBranding {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [string]$RepositoryRoot,
        [string]$OutputDirectory = (Join-Path $env:USERPROFILE '.edb\company'),
        [hashtable]$Overrides
    )

    $config = Get-EdbCompanyConfig -RepositoryRoot $RepositoryRoot
    $branding = @{
        CompanyName      = [string]$config.CompanyName
        SupportEmail     = [string]$config.SupportEmail
        DocumentationUrl = [string]$config.DocumentationUrl
        Branding         = @{}
    }

    if ($config.Branding) {
        foreach ($prop in $config.Branding.PSObject.Properties) {
            $branding.Branding[$prop.Name] = $prop.Value
        }
    }

    if ($Overrides) {
        foreach ($key in $Overrides.Keys) {
            if ($key -eq 'Branding' -and $Overrides[$key] -is [hashtable]) {
                foreach ($brandKey in $Overrides[$key].Keys) {
                    $branding.Branding[$brandKey] = $Overrides[$key][$brandKey]
                }
            }
            else {
                $branding[$key] = $Overrides[$key]
            }
        }
    }

    if (-not (Test-Path -LiteralPath $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    $outputPath = Join-Path $OutputDirectory 'branding.json'
    if ($PSCmdlet.ShouldProcess($outputPath, 'Write company branding placeholders')) {
        ($branding | ConvertTo-Json -Depth 10) + [Environment]::NewLine |
            Set-Content -LiteralPath $outputPath -Encoding UTF8 -NoNewline
    }

    [pscustomobject]@{
        Schema      = 'EDB.CompanyBrandingResult'
        OutputPath  = $outputPath
        CompanyName = $branding.CompanyName
    }
}

Export-ModuleMember -Function @(
    'Get-EdbCompanyConfig',
    'Set-EdbCompanyBranding'
)
