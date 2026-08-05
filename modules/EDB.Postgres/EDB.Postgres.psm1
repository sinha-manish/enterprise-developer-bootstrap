#Requires -Version 7.0

function Test-EdbPostgresInstalled {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string[]]$CommandNames = @('psql', 'pg_isready')
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
    if ($found | Where-Object { $_.Name -eq 'psql' }) {
        try {
            $version = (& psql --version 2>$null | Select-Object -First 1).ToString().Trim()
        }
        catch { $version = $null }
    }

    [pscustomobject]@{
        Schema    = 'EDB.PostgresInstalled'
        Installed = ($found.Count -gt 0)
        Commands  = $found
        Version   = $version
    }
}

Export-ModuleMember -Function @(
    'Test-EdbPostgresInstalled'
)
