#Requires -Version 7.0

function Get-EdbGitRepositoryRoot {
    $moduleRoot = Split-Path -Parent $PSScriptRoot
    (Resolve-Path (Join-Path $moduleRoot '..')).Path
}

function Test-EdbGitInstalled {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $command = Get-Command git -ErrorAction SilentlyContinue
    if (-not $command) {
        return [pscustomobject]@{
            Schema    = 'EDB.GitInstalled'
            Installed = $false
            Path      = $null
            Version   = $null
        }
    }

    $version = $null
    try {
        $versionOutput = & git --version 2>$null
        if ($versionOutput) {
            $version = ($versionOutput | Select-Object -First 1).ToString().Trim()
        }
    }
    catch {
        $version = $null
    }

    [pscustomobject]@{
        Schema    = 'EDB.GitInstalled'
        Installed = $true
        Path      = $command.Source
        Version   = $version
    }
}

function Invoke-EdbGitNative {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    & git @Arguments 2>&1 | Out-Null
    return $LASTEXITCODE
}

function Set-EdbGitConfiguration {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [string]$UserName,
        [string]$UserEmail,
        [bool]$CoreLongPaths = $true,
        [string]$InitDefaultBranch = 'main',
        [ValidateSet('Global', 'Local', 'System')]
        [string]$Scope = 'Global'
    )

    if (-not (Test-EdbGitInstalled).Installed) {
        throw 'Git is not installed or not available on PATH.'
    }

    $applied = [System.Collections.Generic.List[string]]::new()
    $scopeArg = switch ($Scope) {
        'Global' { '--global' }
        'Local'  { '--local' }
        'System' { '--system' }
    }

    $settings = [ordered]@{}
    if (-not [string]::IsNullOrWhiteSpace($UserName)) { $settings['user.name'] = $UserName }
    if (-not [string]::IsNullOrWhiteSpace($UserEmail)) { $settings['user.email'] = $UserEmail }
    $settings['core.longpaths'] = $(if ($CoreLongPaths) { 'true' } else { 'false' })
    $settings['init.defaultBranch'] = $InitDefaultBranch

    foreach ($entry in $settings.GetEnumerator()) {
        if (-not $PSCmdlet.ShouldProcess($entry.Key, "Set git config $Scope $($entry.Key)")) {
            continue
        }

        $exitCode = Invoke-EdbGitNative -Arguments @('config', $scopeArg, $entry.Key, [string]$entry.Value)
        if ($exitCode -ne 0) {
            throw "Failed to set git config '$($entry.Key)' (exit code $exitCode)."
        }
        $applied.Add($entry.Key)
    }

    [pscustomobject]@{
        Schema  = 'EDB.GitConfigurationResult'
        Scope   = $Scope
        Applied = $applied.ToArray()
    }
}

function New-EdbSshKey {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [string]$Comment = "$env:USERNAME@$env:COMPUTERNAME",
        [string]$Directory = (Join-Path $env:USERPROFILE '.ssh'),
        [string]$FileName = 'id_ed25519_edb',
        [switch]$Force
    )

    $sshKeygen = Get-Command ssh-keygen -ErrorAction SilentlyContinue
    if (-not $sshKeygen) {
        throw 'ssh-keygen was not found. Install OpenSSH Client via Windows Optional Features or Git for Windows.'
    }

    if (-not (Test-Path -LiteralPath $Directory)) {
        if ($PSCmdlet.ShouldProcess($Directory, 'Create SSH directory')) {
            New-Item -ItemType Directory -Path $Directory -Force | Out-Null
        }
    }

    $privatePath = Join-Path $Directory $FileName
    $publicPath = "$privatePath.pub"

    if ((Test-Path -LiteralPath $privatePath) -and -not $Force) {
        throw "SSH private key already exists at '$privatePath'. Use -Force to overwrite."
    }

    $args = @(
        '-t', 'ed25519',
        '-C', $Comment,
        '-f', $privatePath,
        '-N', ''
    )
    if ($Force) {
        $args += '-y'
    }

    if ($PSCmdlet.ShouldProcess($privatePath, 'Generate ed25519 SSH key pair')) {
        & ssh-keygen @args 2>&1 | ForEach-Object { Write-Verbose $_ }
        if ($LASTEXITCODE -ne 0) {
            throw "ssh-keygen failed with exit code $LASTEXITCODE."
        }

        Protect-EdbSshPrivateKeyAcl -Path $privatePath
    }

    $publicKey = $null
    if (Test-Path -LiteralPath $publicPath) {
        $publicKey = (Get-Content -LiteralPath $publicPath -Raw -Encoding UTF8).Trim()
    }

    Write-Verbose "SSH key pair created. Private key: $privatePath (contents not logged)."

    [pscustomobject]@{
        Schema         = 'EDB.SshKeyResult'
        PrivateKeyPath = $privatePath
        PublicKeyPath  = $publicPath
        PublicKey      = $publicKey
        Algorithm      = 'ed25519'
    }
}

function Protect-EdbSshPrivateKeyAcl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Private key file not found: $Path"
    }

    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name

    $icacls = Get-Command icacls -ErrorAction SilentlyContinue
    if ($icacls) {
        & icacls $Path /inheritance:r /grant:r "${currentUser}:(F)" 2>&1 | ForEach-Object { Write-Verbose $_ }
        if ($LASTEXITCODE -ne 0) {
            throw "icacls failed to restrict ACL on '$Path' (exit code $LASTEXITCODE)."
        }
        return
    }

    $acl = Get-Acl -LiteralPath $Path
    try {
        $acl.SetAccessRuleProtection($true, $false)
        $acl.Access | ForEach-Object { $null = $acl.RemoveAccessRule($_) }
    }
    catch {
        Write-Verbose "Could not disable ACL inheritance on '$Path': $($_.Exception.Message)"
        $acl = Get-Acl -LiteralPath $Path
    }

    $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
        $currentUser,
        [System.Security.AccessControl.FileSystemRights]::FullControl,
        [System.Security.AccessControl.InheritanceFlags]::None,
        [System.Security.AccessControl.PropagationFlags]::None,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
    $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $Path -AclObject $acl
}

Export-ModuleMember -Function @(
    'Test-EdbGitInstalled',
    'Set-EdbGitConfiguration',
    'New-EdbSshKey'
)
