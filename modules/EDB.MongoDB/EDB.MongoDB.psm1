#Requires -Version 7.0

function Test-EdbMongoDbInstalled {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string[]]$CommandNames = @('mongosh', 'mongo')
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
    $primary = $found | Select-Object -First 1
    if ($primary) {
        try {
            $version = (& $primary.Name --version 2>$null | Select-Object -First 1).ToString().Trim()
        }
        catch { $version = $null }
    }

    [pscustomobject]@{
        Schema    = 'EDB.MongoDbInstalled'
        Installed = ($found.Count -gt 0)
        Commands  = $found
        Version   = $version
    }
}

Export-ModuleMember -Function @(
    'Test-EdbMongoDbInstalled'
)
