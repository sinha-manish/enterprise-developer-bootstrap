#Requires -Version 7.0
using module '..\EDB.System'

function Test-EdbWslStatus {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    # List[string] (not @()): PowerShell treats `$null -eq @()` as $true, which breaks
    # Pester `-Not -Be $null` for an empty Distributions value.
    $distributions = [System.Collections.Generic.List[string]]::new()

    $wsl = Get-Command wsl -ErrorAction SilentlyContinue
    if (-not $wsl) {
        return [pscustomobject]@{
            Schema        = 'EDB.WslStatus'
            Installed     = $false
            Available     = $false
            Status        = 'Unavailable'
            Path          = $null
            Version       = $null
            Distributions = $distributions
        }
    }

    $version = $null
    try {
        $versionOutput = & wsl --version 2>$null
        if ($versionOutput) {
            $version = ($versionOutput | Select-Object -First 1).ToString().Trim()
        }
    }
    catch {
        $version = $null
    }

    try {
        # wsl.exe emits UTF-16LE; strip NULs so names parse cleanly on Windows.
        $listOutput = & wsl -l -q 2>$null
        foreach ($line in @($listOutput)) {
            if ($null -eq $line) { continue }
            $name = ($line.ToString() -replace "`0", '').Trim()
            if (-not [string]::IsNullOrWhiteSpace($name)) {
                $distributions.Add($name)
            }
        }
    }
    catch {
        $distributions.Clear()
    }

    [pscustomobject]@{
        Schema        = 'EDB.WslStatus'
        Installed     = $true
        Available     = $true
        Status        = 'Installed'
        Path          = $wsl.Source
        Version       = $version
        Distributions = $distributions
    }
}

function Set-EdbEnvironmentVariable {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [AllowNull()]
        [string]$Value,
        [ValidateSet('User', 'Machine', 'Process')]
        [string]$Scope = 'User',
        [switch]$Append,
        [string]$Separator = ';'
    )

    if ($Scope -eq 'Machine' -and -not (Test-EdbIsAdministrator)) {
        throw 'Machine-scoped environment variables require an elevated session.'
    }

    $target = switch ($Scope) {
        'User'    { [EnvironmentVariableTarget]::User }
        'Machine' { [EnvironmentVariableTarget]::Machine }
        'Process' { [EnvironmentVariableTarget]::Process }
    }

    $finalValue = $Value
    if ($Append) {
        $existing = [Environment]::GetEnvironmentVariable($Name, $target)
        if (-not [string]::IsNullOrWhiteSpace($existing)) {
            $parts = $existing -split [regex]::Escape($Separator) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            if ($parts -notcontains $Value) {
                $finalValue = ($parts + $Value) -join $Separator
            }
            else {
                $finalValue = $existing
            }
        }
    }

    if ($PSCmdlet.ShouldProcess($Name, "Set $Scope environment variable")) {
        [Environment]::SetEnvironmentVariable($Name, $finalValue, $target)
        if ($Scope -eq 'Process') {
            Set-Item -Path "Env:$Name" -Value $finalValue
        }
    }

    [pscustomobject]@{
        Schema = 'EDB.EnvironmentVariableResult'
        Name   = $Name
        Value  = $finalValue
        Scope  = $Scope
    }
}

function Set-EdbDeveloperPath {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$PathEntries,
        [ValidateSet('User', 'Machine', 'Process')]
        [string]$Scope = 'User'
    )

    if ($Scope -eq 'Machine' -and -not (Test-EdbIsAdministrator)) {
        throw 'Machine-scoped PATH updates require an elevated session.'
    }

    $target = switch ($Scope) {
        'User'    { [EnvironmentVariableTarget]::User }
        'Machine' { [EnvironmentVariableTarget]::Machine }
        'Process' { [EnvironmentVariableTarget]::Process }
    }

    $current = [Environment]::GetEnvironmentVariable('Path', $target)
    $parts = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($current)) {
        foreach ($part in ($current -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
            $parts.Add($part)
        }
    }

    $added = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $PathEntries) {
        $resolved = $entry
        if (-not [IO.Path]::IsPathRooted($entry)) {
            continue
        }
        if (-not (Test-Path -LiteralPath $resolved)) {
            Write-Verbose "Skipping PATH entry that does not exist: $resolved"
            continue
        }
        $normalized = (Resolve-Path -LiteralPath $resolved).Path
        if ($parts -notcontains $normalized) {
            $parts.Add($normalized)
            $added.Add($normalized)
        }
    }

    $newPath = ($parts | Select-Object -Unique) -join ';'
    if ($PSCmdlet.ShouldProcess('Path', "Append developer PATH entries ($Scope)")) {
        [Environment]::SetEnvironmentVariable('Path', $newPath, $target)
        if ($Scope -eq 'Process') {
            Set-Item -Path 'Env:Path' -Value $newPath
        }
    }

    [pscustomobject]@{
        Schema      = 'EDB.DeveloperPathResult'
        Scope       = $Scope
        Added       = $added.ToArray()
        PathValue   = $newPath
    }
}

function Install-EdbPowerShellProfile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [string]$RepositoryRoot,
        [string]$ProfilePath,
        [string]$Marker = '# EDB Enterprise Developer Bootstrap'
    )

    $moduleRoot = Split-Path -Parent $PSScriptRoot
    $root = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
        (Resolve-Path (Join-Path $moduleRoot '..')).Path
    }
    else {
        (Resolve-Path -LiteralPath $RepositoryRoot).Path
    }

    $initScript = Join-Path $root 'scripts\Initialize-EdbModulePath.ps1'
    $snippet = @(
        $Marker
        "if (Test-Path -LiteralPath '$initScript') {"
        "    . '$initScript' | Out-Null"
        '}'
        '# End EDB'
    ) -join [Environment]::NewLine

    $profilePath = if ([string]::IsNullOrWhiteSpace($ProfilePath)) {
        $PROFILE.CurrentUserAllHosts
    }
    else {
        $ProfilePath
    }
    $profileDir = Split-Path -Parent $profilePath
    if (-not (Test-Path -LiteralPath $profileDir)) {
        if ($PSCmdlet.ShouldProcess($profileDir, 'Create PowerShell profile directory')) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }
    }

    $existing = if (Test-Path -LiteralPath $profilePath) {
        Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8
    }
    else {
        ''
    }

    if ($existing -match [regex]::Escape($Marker)) {
        return [pscustomobject]@{
            Schema      = 'EDB.PowerShellProfileResult'
            ProfilePath = $profilePath
            Updated     = $false
            Message     = 'EDB profile snippet already present.'
        }
    }

    if ($PSCmdlet.ShouldProcess($profilePath, 'Append EDB profile snippet')) {
        $content = if ([string]::IsNullOrWhiteSpace($existing)) {
            $snippet + [Environment]::NewLine
        }
        else {
            $existing.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $snippet + [Environment]::NewLine
        }
        Set-Content -LiteralPath $profilePath -Value $content -Encoding UTF8
    }

    [pscustomobject]@{
        Schema      = 'EDB.PowerShellProfileResult'
        ProfilePath = $profilePath
        Updated     = $true
        Message     = 'EDB profile snippet appended.'
    }
}

Export-ModuleMember -Function @(
    'Test-EdbWslStatus',
    'Set-EdbEnvironmentVariable',
    'Set-EdbDeveloperPath',
    'Install-EdbPowerShellProfile'
)
