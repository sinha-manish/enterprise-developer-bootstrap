#Requires -Version 7.0

function Invoke-EdbPostConfigure {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot,

        [string[]]$PackageIds = @(),

        [string]$ProfileName = '',

        [EdbLoggerBase]$Logger,

        [switch]$WhatIf
    )

    $actions = [System.Collections.Generic.List[object]]::new()
    $idSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($id in @($PackageIds)) {
        if (-not [string]::IsNullOrWhiteSpace($id)) {
            [void]$idSet.Add($id)
        }
    }

    if ($WhatIf) {
        $actions.Add([pscustomobject]@{
                Schema  = 'EDB.PostConfigureAction'
                Name    = 'PostConfigure'
                Status  = 'Skipped'
                Message = 'Post-configure skipped during WhatIf.'
            }) | Out-Null
        return @($actions)
    }

    function Add-EdbPostConfigureAction {
        param([string]$Name, [string]$Status, [string]$Message)
        $actions.Add([pscustomobject]@{
                Schema  = 'EDB.PostConfigureAction'
                Name    = $Name
                Status  = $Status
                Message = $Message
            }) | Out-Null
        if ($Logger) {
            $level = if ($Status -eq 'Failed') { [EdbLogLevel]::Warning } else { [EdbLogLevel]::Information }
            Write-EdbLog -Logger $Logger -Level $level -Message ("Post-configure {0}: {1}" -f $Name, $Message) `
                -Properties @{ Action = $Name; Status = $Status }
        }
    }

    try {
        Import-Module EDB.Security -Force -ErrorAction Stop
        $baseline = Assert-EdbSecurityBaseline
        if ($baseline.Passed) {
            Add-EdbPostConfigureAction -Name 'SecurityBaseline' -Status 'Succeeded' `
                -Message ("Baseline completed with {0} check(s)." -f @($baseline.Checks).Count)
        }
        else {
            Add-EdbPostConfigureAction -Name 'SecurityBaseline' -Status 'Failed' `
                -Message 'One or more security baseline checks did not pass (informational; Defender/BitLocker are never disabled).'
        }
    }
    catch {
        Add-EdbPostConfigureAction -Name 'SecurityBaseline' -Status 'Failed' -Message $_.Exception.Message
    }

    try {
        Import-Module EDB.Windows -Force -ErrorAction Stop
        Install-EdbPowerShellProfile | Out-Null
        Add-EdbPostConfigureAction -Name 'PowerShellProfile' -Status 'Succeeded' -Message 'EDB profile snippet ensured.'
    }
    catch {
        Add-EdbPostConfigureAction -Name 'PowerShellProfile' -Status 'Failed' -Message $_.Exception.Message
    }

    if ($idSet.Contains('vscode')) {
        try {
            Import-Module EDB.VSCode -Force -ErrorAction Stop
            Set-EdbVSCodeSettings -UseRepositoryDefaults -RepositoryRoot $RepositoryRoot | Out-Null
            Install-EdbDefaultVSCodeExtensions -RepositoryRoot $RepositoryRoot -ErrorAction SilentlyContinue | Out-Null
            Add-EdbPostConfigureAction -Name 'VSCode' -Status 'Succeeded' -Message 'VS Code settings/extensions applied when CLI available.'
        }
        catch {
            Add-EdbPostConfigureAction -Name 'VSCode' -Status 'Failed' -Message $_.Exception.Message
        }
    }

    if ($idSet.Contains('git')) {
        try {
            Import-Module EDB.Git -Force -ErrorAction Stop
            $gitStatus = Test-EdbGitInstalled
            Add-EdbPostConfigureAction -Name 'Git' -Status 'Succeeded' `
                -Message ("Git detected={0}. Identity/SSH remain opt-in via EDB.Git cmdlets." -f $gitStatus.Installed)
        }
        catch {
            Add-EdbPostConfigureAction -Name 'Git' -Status 'Failed' -Message $_.Exception.Message
        }
    }

    if ($ProfileName -eq 'AIEngineer' -or $idSet.Contains('cursor') -or $idSet.Contains('githubcopilot')) {
        try {
            Import-Module EDB.AI -Force -ErrorAction Stop
            $template = Join-Path $RepositoryRoot 'config\ai\mcp.template.json'
            if (Test-Path -LiteralPath $template) {
                Set-EdbMcpConfiguration -RepositoryRoot $RepositoryRoot -UseTemplate | Out-Null
            }
            Install-EdbAiToolingNotes -RepositoryRoot $RepositoryRoot | Out-Null
            Add-EdbPostConfigureAction -Name 'AI' -Status 'Succeeded' -Message 'MCP template and AI tooling notes applied.'
        }
        catch {
            Add-EdbPostConfigureAction -Name 'AI' -Status 'Failed' -Message $_.Exception.Message
        }
    }

    @($actions)
}
