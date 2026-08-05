#Requires -Version 7.0

function Test-EdbNodeInstalled {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $node = Get-Command node -ErrorAction SilentlyContinue
    $npm = Get-Command npm -ErrorAction SilentlyContinue

    $nodeVersion = $null
    $npmVersion = $null

    if ($node) {
        try {
            $nodeVersion = (& node --version 2>$null | Select-Object -First 1).ToString().Trim()
        }
        catch { $nodeVersion = $null }
    }

    if ($npm) {
        try {
            $npmVersion = (& npm --version 2>$null | Select-Object -First 1).ToString().Trim()
        }
        catch { $npmVersion = $null }
    }

    [pscustomobject]@{
        Schema       = 'EDB.NodeInstalled'
        Installed    = [bool]$node
        NodePath     = $(if ($node) { $node.Source } else { $null })
        NodeVersion  = $nodeVersion
        NpmAvailable = [bool]$npm
        NpmVersion   = $npmVersion
    }
}

function Set-EdbNpmConfiguration {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [string]$Prefix,
        [string]$Registry = 'https://registry.npmjs.org/',
        [bool]$Fund = $false,
        [bool]$Audit = $true,
        [hashtable]$AdditionalSettings
    )

    if (-not (Test-EdbNodeInstalled).NpmAvailable) {
        throw 'npm is not installed or not available on PATH.'
    }

    $applied = [System.Collections.Generic.List[string]]::new()

    $setNpm = {
        param([string]$Key, [string]$Value)
        if ($PSCmdlet.ShouldProcess($Key, "Set npm config $Key")) {
            & npm config set $Key $Value --location=user 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to set npm config '$Key' (exit code $LASTEXITCODE)."
            }
            $applied.Add($Key)
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Prefix)) {
        & $setNpm 'prefix' $Prefix
    }
    if (-not [string]::IsNullOrWhiteSpace($Registry)) {
        & $setNpm 'registry' $Registry
    }
    & $setNpm 'fund' ($(if ($Fund) { 'true' } else { 'false' }))
    & $setNpm 'audit' ($(if ($Audit) { 'true' } else { 'false' }))

    if ($AdditionalSettings) {
        foreach ($key in $AdditionalSettings.Keys) {
            & $setNpm $key ([string]$AdditionalSettings[$key])
        }
    }

    [pscustomobject]@{
        Schema  = 'EDB.NpmConfigurationResult'
        Applied = $applied.ToArray()
    }
}

Export-ModuleMember -Function @(
    'Test-EdbNodeInstalled',
    'Set-EdbNpmConfiguration'
)
