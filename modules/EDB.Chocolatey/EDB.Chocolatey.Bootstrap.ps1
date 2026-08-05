#Requires -Version 7.0

function Install-EdbChocolateyIfMissing {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $existing = Get-EdbChocolateyExecutable
    if ($existing) {
        return [pscustomobject]@{
            Schema         = 'EDB.ChocolateyBootstrapResult'
            Success        = $true
            AlreadyPresent = $true
            Installed      = $false
            Message        = 'Chocolatey is already available.'
            Path           = $existing
        }
    }

    $installScript = Join-Path ([IO.Path]::GetTempPath()) ("edb-choco-install-{0}.ps1" -f [guid]::NewGuid().ToString('N'))

    try {
        Invoke-WebRequest -Uri 'https://community.chocolatey.org/install.ps1' -OutFile $installScript -UseBasicParsing -ErrorAction Stop
        & $PSHOME\pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $installScript | Out-Null
    }
    catch {
        return [pscustomobject]@{
            Schema         = 'EDB.ChocolateyBootstrapResult'
            Success        = $false
            AlreadyPresent = $false
            Installed      = $false
            Message        = "Failed to install Chocolatey: $($_.Exception.Message)"
            Path           = $null
        }
    }
    finally {
        if (Test-Path -LiteralPath $installScript) {
            Remove-Item -LiteralPath $installScript -Force -ErrorAction SilentlyContinue
        }
    }

    $resolved = Get-EdbChocolateyExecutable
    if ($resolved) {
        return [pscustomobject]@{
            Schema         = 'EDB.ChocolateyBootstrapResult'
            Success        = $true
            AlreadyPresent = $false
            Installed      = $true
            Message        = 'Chocolatey was installed successfully.'
            Path           = $resolved
        }
    }

    return [pscustomobject]@{
        Schema         = 'EDB.ChocolateyBootstrapResult'
        Success        = $false
        AlreadyPresent = $false
        Installed      = $false
        Message        = 'Chocolatey install script completed but choco is still unavailable. Open a new shell and retry.'
        Path           = $null
    }
}
