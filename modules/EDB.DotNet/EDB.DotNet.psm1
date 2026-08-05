#Requires -Version 7.0

function Test-EdbDotNetInstalled {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $dotnet) {
        return [pscustomobject]@{
            Schema    = 'EDB.DotNetInstalled'
            Installed = $false
            Path      = $null
            Version   = $null
            Sdks      = @()
            Runtimes  = @()
        }
    }

    $version = $null
    $sdks = @()
    $runtimes = @()

    try {
        $version = (& dotnet --version 2>$null | Select-Object -First 1).ToString().Trim()
    }
    catch { $version = $null }

    try {
        $sdkOutput = & dotnet --list-sdks 2>$null
        if ($sdkOutput) { $sdks = @($sdkOutput | ForEach-Object { $_.ToString().Trim() }) }
    }
    catch { $sdks = @() }

    try {
        $runtimeOutput = & dotnet --list-runtimes 2>$null
        if ($runtimeOutput) { $runtimes = @($runtimeOutput | ForEach-Object { $_.ToString().Trim() }) }
    }
    catch { $runtimes = @() }

    [pscustomobject]@{
        Schema    = 'EDB.DotNetInstalled'
        Installed = $true
        Path      = $dotnet.Source
        Version   = $version
        Sdks      = $sdks
        Runtimes  = $runtimes
    }
}

Export-ModuleMember -Function @(
    'Test-EdbDotNetInstalled'
)
