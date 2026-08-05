#Requires -Version 7.0
using module '..\EDB.Contracts'
using module '..\EDB.Models'

<#
.SYNOPSIS
    Host environment detection and preflight checks.
.NOTES
    Does not bypass UAC, Defender, or BitLocker. Elevation is detected only.
#>

function Test-EdbIsAdministrator {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-EdbOperatingSystemInfo {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $version = [version]$os.Version
    $build = [int]$os.BuildNumber
    $caption = [string]$os.Caption

    [pscustomobject]@{
        Schema         = 'EDB.OperatingSystemInfo'
        Caption        = $caption
        Version        = $version.ToString()
        Build          = $build
        ProductType    = [int]$os.ProductType
        OsArchitecture = [string]$os.OSArchitecture
    }
}

function Test-EdbWindowsCompatible {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object]$OsInfo
    )

    # Windows 10 1903+ (build 18362) and Windows 11 (build 22000+) are accepted for enterprise bootstrap.
    return ($OsInfo.Build -ge 18362)
}

function Test-EdbInternetAccess {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string[]]$Uris = @(
            'https://www.microsoft.com',
            'https://cdn.winget.microsoft.com'
        ),
        [int]$TimeoutSec = 8
    )

    foreach ($uri in $Uris) {
        try {
            $request = [System.Net.HttpWebRequest]::Create($uri)
            $request.Method = 'HEAD'
            $request.Timeout = $TimeoutSec * 1000
            $request.AllowAutoRedirect = $true
            $response = $request.GetResponse()
            $response.Close()
            return $true
        }
        catch {
            try {
                $response = Invoke-WebRequest -Uri $uri -Method Head -TimeoutSec $TimeoutSec -UseBasicParsing -ErrorAction Stop
                if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
                    return $true
                }
            }
            catch {
                continue
            }
        }
    }

    return $false
}

function Get-EdbProxyConfiguration {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $systemProxy = [System.Net.WebRequest]::DefaultWebProxy
    $envHttp = $env:HTTP_PROXY
    $envHttps = $env:HTTPS_PROXY
    $winHttpProxy = $null

    try {
        $netsh = & netsh winhttp show proxy 2>$null | Out-String
        if ($netsh -match 'Proxy Server\(s\)\s*:\s*(.+)') {
            $winHttpProxy = $Matches[1].Trim()
            if ($winHttpProxy -eq 'Direct access (no proxy server).') {
                $winHttpProxy = $null
            }
        }
    }
    catch {
        $winHttpProxy = $null
    }

    $address = $null
    if (-not [string]::IsNullOrWhiteSpace($envHttps)) {
        $address = $envHttps
    }
    elseif (-not [string]::IsNullOrWhiteSpace($envHttp)) {
        $address = $envHttp
    }
    elseif (-not [string]::IsNullOrWhiteSpace($winHttpProxy)) {
        $address = $winHttpProxy
    }
    elseif ($null -ne $systemProxy -and $null -ne $systemProxy.GetProxy([uri]'https://example.com')) {
        $proxyUri = $systemProxy.GetProxy([uri]'https://example.com')
        if ($proxyUri.AbsoluteUri -ne 'https://example.com/') {
            $address = $proxyUri.AbsoluteUri
        }
    }

    [pscustomobject]@{
        Schema        = 'EDB.ProxyConfiguration'
        Detected      = -not [string]::IsNullOrWhiteSpace($address)
        Address       = $address
        HttpProxyEnv  = $envHttp
        HttpsProxyEnv = $envHttps
        WinHttpProxy  = $winHttpProxy
    }
}

function Get-EdbWingetStatus {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $command = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $command) {
        return [pscustomobject]@{
            Schema    = 'EDB.WingetStatus'
            Available = $false
            Path      = $null
            Version   = $null
        }
    }

    $version = $null
    try {
        $versionOutput = & winget --version 2>$null
        if ($versionOutput) {
            $version = ($versionOutput | Select-Object -First 1).ToString().Trim()
        }
    }
    catch {
        $version = $null
    }

    [pscustomobject]@{
        Schema    = 'EDB.WingetStatus'
        Available = $true
        Path      = $command.Source
        Version   = $version
    }
}

function Invoke-EdbPreflightCheck {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [switch]$RequireAdministrator,
        [switch]$RequireInternet,
        [switch]$SkipInternetCheck
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    $osInfo = Get-EdbOperatingSystemInfo
    $compatible = Test-EdbWindowsCompatible -OsInfo $osInfo
    if (-not $compatible) {
        $errors.Add("Unsupported Windows build $($osInfo.Build). Windows 10 1903+ or Windows 11 is required.")
    }

    $isAdmin = Test-EdbIsAdministrator
    if ($RequireAdministrator -and -not $isAdmin) {
        $errors.Add('Administrator rights are required for this profile. Re-run from an elevated PowerShell 7 session granted by IT (Developer OU / Intune / SCCM / Local Admin). UAC will not be bypassed.')
    }
    elseif (-not $isAdmin) {
        $warnings.Add('Session is not elevated. Packages marked RequiresAdmin will fail until elevation is granted by IT.')
    }

    $winget = Get-EdbWingetStatus
    if (-not $winget.Available) {
        $warnings.Add('Winget was not detected. The bootstrap will attempt to install App Installer / Winget when permitted.')
    }

    $proxy = Get-EdbProxyConfiguration
    if ($proxy.Detected) {
        $warnings.Add("Corporate proxy detected: $($proxy.Address)")
    }

    $internet = $false
    if (-not $SkipInternetCheck) {
        $internet = Test-EdbInternetAccess
        if ($RequireInternet -and -not $internet) {
            $errors.Add('Internet access check failed. Configure proxy environment variables (HTTPS_PROXY/HTTP_PROXY) or WinHTTP proxy, then retry.')
        }
        elseif (-not $internet) {
            $warnings.Add('Internet access check failed. Online package installs may fail.')
        }
    }

    New-EdbPreflightResult `
        -IsWindows11OrCompatible:$compatible `
        -OsCaption $osInfo.Caption `
        -OsVersion $osInfo.Version `
        -IsAdministrator:$isAdmin `
        -WingetAvailable:$winget.Available `
        -WingetVersion $(if ($winget.Version) { $winget.Version } else { '' }) `
        -InternetAvailable:$internet `
        -ProxyDetected:$proxy.Detected `
        -ProxyAddress $(if ($proxy.Address) { $proxy.Address } else { '' }) `
        -Errors $errors.ToArray() `
        -Warnings $warnings.ToArray()
}

Export-ModuleMember -Function @(
    'Test-EdbIsAdministrator',
    'Get-EdbOperatingSystemInfo',
    'Test-EdbWindowsCompatible',
    'Test-EdbInternetAccess',
    'Get-EdbProxyConfiguration',
    'Get-EdbWingetStatus',
    'Invoke-EdbPreflightCheck'
)
