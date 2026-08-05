#Requires -Version 7.0

function Test-EdbAwsCliInstalled {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $aws = Get-Command aws -ErrorAction SilentlyContinue
    $version = $null

    if ($aws) {
        try {
            $version = (& aws --version 2>&1 | Select-Object -First 1).ToString().Trim()
        }
        catch { $version = $null }
    }

    [pscustomobject]@{
        Schema    = 'EDB.AwsCliInstalled'
        Installed = [bool]$aws
        Path      = $(if ($aws) { $aws.Source } else { $null })
        Version   = $version
    }
}

function Set-EdbAwsConfiguration {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [string]$ProfileName = 'default',
        [string]$Region,
        [string]$OutputFormat = 'json',
        [string]$ConfigDirectory = (Join-Path $env:USERPROFILE '.aws')
    )

    if (-not (Test-EdbAwsCliInstalled).Installed) {
        throw 'AWS CLI is not installed or not available on PATH.'
    }

    if (-not (Test-Path -LiteralPath $ConfigDirectory)) {
        if ($PSCmdlet.ShouldProcess($ConfigDirectory, 'Create AWS config directory')) {
            New-Item -ItemType Directory -Path $ConfigDirectory -Force | Out-Null
        }
    }

    $configPath = Join-Path $ConfigDirectory 'config'
    $lines = [System.Collections.Generic.List[string]]::new()

    if (Test-Path -LiteralPath $configPath) {
        $lines.AddRange(@(Get-Content -LiteralPath $configPath -Encoding UTF8))
    }

    $profileHeader = "[profile $ProfileName]"
    $startIndex = $lines.IndexOf($profileHeader)
    if ($startIndex -lt 0) {
        if ($lines.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($lines[$lines.Count - 1])) {
            $lines.Add('')
        }
        $lines.Add($profileHeader)
        $startIndex = $lines.Count - 1
    }

    $endIndex = $lines.Count
    for ($i = $startIndex + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\[.+]\s*$') {
            $endIndex = $i
            break
        }
    }

    $settings = [ordered]@{}
    for ($i = $startIndex + 1; $i -lt $endIndex; $i++) {
        if ($lines[$i] -match '^\s*([^=]+?)\s*=\s*(.+)\s*$') {
            $settings[$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }

    if ($Region) { $settings['region'] = $Region }
    if ($OutputFormat) { $settings['output'] = $OutputFormat }

    $newSection = [System.Collections.Generic.List[string]]::new()
    $newSection.Add($profileHeader)
    foreach ($key in $settings.Keys) {
        $newSection.Add("$key = $($settings[$key])")
    }

    if ($startIndex -ge 0) {
        $before = if ($startIndex -gt 0) { $lines.GetRange(0, $startIndex) } else { [System.Collections.Generic.List[string]]::new() }
        $after = if ($endIndex -lt $lines.Count) { $lines.GetRange($endIndex, $lines.Count - $endIndex) } else { [System.Collections.Generic.List[string]]::new() }
        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.AddRange($before)
        $lines.AddRange($newSection)
        if ($after.Count -gt 0) {
            if ($lines.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($lines[$lines.Count - 1])) {
                $lines.Add('')
            }
            $lines.AddRange($after)
        }
    }

    if ($PSCmdlet.ShouldProcess($configPath, 'Update AWS config (no credentials written)')) {
        ($lines | Where-Object { $_ -ne $null }) -join [Environment]::NewLine |
            Set-Content -LiteralPath $configPath -Encoding UTF8
    }

    Write-Verbose "AWS config updated for profile '$ProfileName'. Credentials are never written or logged by EDB."

    [pscustomobject]@{
        Schema      = 'EDB.AwsConfigurationResult'
        ProfileName = $ProfileName
        ConfigPath  = $configPath
        Region      = $settings['region']
        Output      = $settings['output']
    }
}

Export-ModuleMember -Function @(
    'Test-EdbAwsCliInstalled',
    'Set-EdbAwsConfiguration'
)
