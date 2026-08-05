#Requires -Version 7.0

function Install-EdbWingetIfMissing {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param()

    $existing = Get-EdbWingetExecutable
    if ($existing) {
        return [pscustomobject]@{
            Schema         = 'EDB.WingetBootstrapResult'
            Success        = $true
            AlreadyPresent = $true
            Installed      = $false
            Message        = 'Winget is already available.'
            Path           = $existing
        }
    }

    $bundleUri = 'https://cdn.winget.microsoft.com/cache/installers/appinstaller/latest/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
    $tempFile = Join-Path ([IO.Path]::GetTempPath()) ("edb-appinstaller-{0}.msixbundle" -f [guid]::NewGuid().ToString('N'))

    if (-not $PSCmdlet.ShouldProcess('Microsoft.DesktopAppInstaller', 'Download and install Winget / App Installer')) {
        return [pscustomobject]@{
            Schema         = 'EDB.WingetBootstrapResult'
            Success        = $true
            AlreadyPresent = $false
            Installed      = $false
            Message        = 'Winget bootstrap skipped by ShouldProcess/WhatIf.'
            Path           = $null
        }
    }

    try {
        Invoke-WebRequest -Uri $bundleUri -OutFile $tempFile -UseBasicParsing -ErrorAction Stop
        Add-AppxPackage -Path $tempFile -ErrorAction Stop | Out-Null
    }
    catch {
        return [pscustomobject]@{
            Schema         = 'EDB.WingetBootstrapResult'
            Success        = $false
            AlreadyPresent = $false
            Installed      = $false
            Message        = "Failed to install App Installer / Winget: $($_.Exception.Message)"
            Path           = $null
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempFile) {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    $resolved = Get-EdbWingetExecutable
    if ($resolved) {
        return [pscustomobject]@{
            Schema         = 'EDB.WingetBootstrapResult'
            Success        = $true
            AlreadyPresent = $false
            Installed      = $true
            Message        = 'Winget was installed via Microsoft Desktop App Installer.'
            Path           = $resolved
        }
    }

    return [pscustomobject]@{
        Schema         = 'EDB.WingetBootstrapResult'
        Success        = $false
        AlreadyPresent = $false
        Installed      = $false
        Message        = 'App Installer package was deployed but winget is still unavailable. Open a new shell and retry.'
        Path           = $null
    }
}
