#Requires -Version 7.0

function Test-EdbRedisInstalled {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string[]]$CommandNames = @('redis-cli', 'redis-server')
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

    $version = $null
    if ($found | Where-Object { $_.Name -eq 'redis-cli' }) {
        try {
            $version = (& redis-cli --version 2>$null | Select-Object -First 1).ToString().Trim()
        }
        catch { $version = $null }
    }

    [pscustomobject]@{
        Schema    = 'EDB.RedisInstalled'
        Installed = ($found.Count -gt 0)
        Commands  = $found
        Version   = $version
    }
}

Export-ModuleMember -Function @(
    'Test-EdbRedisInstalled'
)
