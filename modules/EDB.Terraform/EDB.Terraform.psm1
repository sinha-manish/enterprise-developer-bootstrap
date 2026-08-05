#Requires -Version 7.0

function Test-EdbTerraformInstalled {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $terraform = Get-Command terraform -ErrorAction SilentlyContinue
    $version = $null

    if ($terraform) {
        try {
            $version = (& terraform version -json 2>$null | ConvertFrom-Json).terraform_version
            if (-not $version) {
                $version = (& terraform version 2>$null | Select-Object -First 1).ToString().Trim()
            }
        }
        catch { $version = $null }
    }

    [pscustomobject]@{
        Schema    = 'EDB.TerraformInstalled'
        Installed = [bool]$terraform
        Path      = $(if ($terraform) { $terraform.Source } else { $null })
        Version   = $version
    }
}

Export-ModuleMember -Function @(
    'Test-EdbTerraformInstalled'
)
