#Requires -Version 7.0

function Test-EdbKubernetesInstalled {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string[]]$CommandNames = @('kubectl', 'helm')
    )

    $found = @()
    foreach ($name in $CommandNames) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) {
            $found += [pscustomobject]@{
                Name = $name
                Path = $cmd.Source
            }
        }
    }

    $kubectlVersion = $null
    if ($found | Where-Object { $_.Name -eq 'kubectl' }) {
        try {
            $client = (& kubectl version --client -o json 2>$null | ConvertFrom-Json).clientVersion
            if ($client) {
                $kubectlVersion = '{0}.{1}.{2}' -f $client.major, $client.minor, $client.gitVersion
            }
        }
        catch {
            try {
                $kubectlVersion = (& kubectl version --client 2>$null | Select-Object -First 1).ToString().Trim()
            }
            catch { $kubectlVersion = $null }
        }
    }

    [pscustomobject]@{
        Schema         = 'EDB.KubernetesInstalled'
        Installed      = ($found | Where-Object { $_.Name -eq 'kubectl' }).Count -gt 0
        Commands       = $found
        KubectlVersion = $kubectlVersion
    }
}

Export-ModuleMember -Function @(
    'Test-EdbKubernetesInstalled'
)
