#Requires -Version 7.0

function Get-EdbAiRepositoryRoot {
    $moduleRoot = Split-Path -Parent $PSScriptRoot
    (Resolve-Path (Join-Path $moduleRoot '..')).Path
}

function Get-EdbCursorPaths {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $localAppData = $env:LOCALAPPDATA
    $appData = $env:APPDATA

    $cursorLocal = if (-not [string]::IsNullOrWhiteSpace($localAppData)) {
        Join-Path $localAppData 'Programs\cursor\Cursor.exe'
    }
    else {
        $null
    }

    $cursorUserData = if (-not [string]::IsNullOrWhiteSpace($appData)) {
        Join-Path $appData 'Cursor'
    }
    else {
        $null
    }

    $cursorMcpPath = if ($cursorUserData) {
        Join-Path $cursorUserData 'mcp.json'
    }
    else {
        $null
    }

    $command = Get-Command cursor -ErrorAction SilentlyContinue

    [pscustomobject]@{
        Schema           = 'EDB.CursorPaths'
        ExecutablePath   = $(if (Test-Path -LiteralPath $cursorLocal) { $cursorLocal } else { $null })
        UserDataPath     = $cursorUserData
        McpConfigPath    = $cursorMcpPath
        CliAvailable     = [bool]$command
        CliPath          = $(if ($command) { $command.Source } else { $null })
    }
}

function Test-EdbCursorInstalled {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $paths = Get-EdbCursorPaths
    $installed = $paths.CliAvailable -or ($paths.ExecutablePath -and (Test-Path -LiteralPath $paths.ExecutablePath))
    $version = $null
    $status = if ($installed) { 'Installed' } else { 'Unavailable' }
    $resolvedPath = if ($paths.CliPath) { $paths.CliPath } elseif ($paths.ExecutablePath) { $paths.ExecutablePath } else { $null }

    if ($resolvedPath) {
        try {
            $versionOutput = & $resolvedPath --version 2>$null
            if ($versionOutput) {
                $version = ($versionOutput | Select-Object -First 1).ToString().Trim()
            }
        }
        catch {
            $version = $null
        }
    }

    [pscustomobject]@{
        Schema       = 'EDB.CursorInstalled'
        Installed    = $installed
        CliAvailable = $paths.CliAvailable
        Path         = $resolvedPath
        Version      = $version
        Status       = $status
    }
}

function Remove-EdbSecretValuesFromHashtable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$InputTable
    )

    $secretPattern = '(?i)(secret|password|token|api[_-]?key|authorization|credential|private[_-]?key)'
    $clean = @{}

    foreach ($key in $InputTable.Keys) {
        $value = $InputTable[$key]
        if ($key -match $secretPattern) {
            $clean[$key] = '${ENV:' + ($key.ToUpperInvariant() -replace '[^A-Z0-9_]', '_') + '}'
            continue
        }

        if ($value -is [hashtable]) {
            $clean[$key] = Remove-EdbSecretValuesFromHashtable -InputTable $value
        }
        elseif ($value -is [string] -and $value -match $secretPattern) {
            $clean[$key] = '${REDACTED}'
        }
        else {
            $clean[$key] = $value
        }
    }

    return $clean
}

function Set-EdbMcpConfiguration {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [string]$McpConfigPath,
        [string]$RepositoryRoot,
        [hashtable]$ServerDefinitions,
        [switch]$UseTemplate
    )

    $root = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
        Get-EdbAiRepositoryRoot
    }
    else {
        (Resolve-Path -LiteralPath $RepositoryRoot).Path
    }

    $paths = Get-EdbCursorPaths
    $targetPath = if ([string]::IsNullOrWhiteSpace($McpConfigPath)) {
        $paths.McpConfigPath
    }
    else {
        $McpConfigPath
    }

    $content = @{}
    if ($UseTemplate) {
        $templatePath = Join-Path $root 'config\ai\mcp.template.json'
        if (-not (Test-Path -LiteralPath $templatePath)) {
            throw "MCP template not found: $templatePath"
        }
        $raw = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
        $template = $raw | ConvertFrom-Json
        foreach ($prop in $template.PSObject.Properties) {
            if ($prop.Value -is [pscustomobject]) {
                $nested = @{}
                foreach ($nestedProp in $prop.Value.PSObject.Properties) {
                    $nested[$nestedProp.Name] = $nestedProp.Value
                }
                $content[$prop.Name] = $nested
            }
            else {
                $content[$prop.Name] = $prop.Value
            }
        }
    }

    if ($ServerDefinitions) {
        if (-not $content.ContainsKey('mcpServers')) {
            $content['mcpServers'] = @{}
        }
        foreach ($serverName in $ServerDefinitions.Keys) {
            $serverDef = $ServerDefinitions[$serverName]
            if ($serverDef -is [hashtable]) {
                $content['mcpServers'][$serverName] = Remove-EdbSecretValuesFromHashtable -InputTable $serverDef
            }
            else {
                $content['mcpServers'][$serverName] = $serverDef
            }
        }
    }

    $sanitized = Remove-EdbSecretValuesFromHashtable -InputTable $content
    $directory = Split-Path -Parent $targetPath
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    if ($PSCmdlet.ShouldProcess($targetPath, 'Write MCP configuration template without secrets')) {
        ($sanitized | ConvertTo-Json -Depth 20) + [Environment]::NewLine |
            Set-Content -LiteralPath $targetPath -Encoding UTF8 -NoNewline
    }

    Write-Verbose "MCP configuration written to $targetPath (secrets replaced with environment placeholders)."

    [pscustomobject]@{
        Schema        = 'EDB.McpConfigurationResult'
        McpConfigPath = $targetPath
        ServerCount   = $(if ($sanitized['mcpServers']) { $sanitized['mcpServers'].Keys.Count } else { 0 })
    }
}

function Install-EdbAiToolingNotes {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [string]$OutputDirectory = (Join-Path $env:USERPROFILE '.edb\ai'),
        [string]$RepositoryRoot
    )

    $root = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
        Get-EdbAiRepositoryRoot
    }
    else {
        (Resolve-Path -LiteralPath $RepositoryRoot).Path
    }

    $paths = Get-EdbCursorPaths
    $cursorNotesPath = Join-Path $OutputDirectory 'cursor-paths.json'
    $copilotNotesPath = Join-Path $OutputDirectory 'copilot-paths.json'
    $readmePath = Join-Path $OutputDirectory 'README.txt'

    if (-not (Test-Path -LiteralPath $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    $cursorDoc = [ordered]@{
        schema          = 'EDB.AiToolingNotes.Cursor'
        executablePath  = $paths.ExecutablePath
        userDataPath    = $paths.UserDataPath
        mcpConfigPath   = $paths.McpConfigPath
        templatePath    = Join-Path $root 'config\ai\mcp.template.json'
        cliAvailable    = $paths.CliAvailable
    }

    $copilotDoc = [ordered]@{
        schema       = 'EDB.AiToolingNotes.Copilot'
        vscodePath   = Join-Path $env:APPDATA 'Code\User'
        settingsHint = 'Configure github.copilot.* settings via VS Code settings merge (EDB.VSCode).'
    }

    $readme = @(
        'Enterprise Developer Bootstrap - AI tooling notes'
        "Generated: $([datetime]::UtcNow.ToString('o'))"
        ''
        'Cursor MCP config: use Set-EdbMcpConfiguration with -UseTemplate.'
        'Never commit API keys; use environment variables or OS secret stores.'
    ) -join [Environment]::NewLine

    if ($PSCmdlet.ShouldProcess($OutputDirectory, 'Write AI tooling configuration notes')) {
        ($cursorDoc | ConvertTo-Json -Depth 5) + [Environment]::NewLine |
            Set-Content -LiteralPath $cursorNotesPath -Encoding UTF8 -NoNewline
        ($copilotDoc | ConvertTo-Json -Depth 5) + [Environment]::NewLine |
            Set-Content -LiteralPath $copilotNotesPath -Encoding UTF8 -NoNewline
        $readme + [Environment]::NewLine | Set-Content -LiteralPath $readmePath -Encoding UTF8
    }

    [pscustomobject]@{
        Schema           = 'EDB.AiToolingNotesResult'
        OutputDirectory  = $OutputDirectory
        CursorNotesPath  = $cursorNotesPath
        CopilotNotesPath = $copilotNotesPath
        ReadmePath       = $readmePath
    }
}

Export-ModuleMember -Function @(
    'Test-EdbCursorInstalled',
    'Set-EdbMcpConfiguration',
    'Install-EdbAiToolingNotes'
)
