#Requires -Version 7.0

function Assert-EdbSecurityBaseline {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [switch]$ThrowOnFailure
    )

    $checks = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $passed = $true

    $defenderService = Get-Service -Name WinDefend -ErrorAction SilentlyContinue
    $defenderRunning = $null -ne $defenderService -and $defenderService.Status -eq 'Running'
    $checks.Add([pscustomobject]@{
            Name    = 'WindowsDefenderServicePresent'
            Passed  = ($null -ne $defenderService)
            Detail  = $(if ($defenderService) { "Status: $($defenderService.Status)" } else { 'WinDefend service not found.' })
            Message = 'EDB verifies Defender exists; it never disables or stops Defender.'
        })

    if ($defenderService -and -not $defenderRunning) {
        $warnings.Add('Windows Defender service is present but not running. Contact IT before changing security software.')
    }

    $bitLockerReadable = $false
    $bitLockerDetail = 'BitLocker status could not be read.'
    try {
        $volumes = Get-CimInstance -Namespace root/CIMV2/Security/MicrosoftVolumeEncryption -ClassName Win32_EncryptableVolume -ErrorAction Stop
        $bitLockerReadable = $true
        $protectedCount = @($volumes | Where-Object {
                $_.ProtectionStatus -eq 1 -or $_.ConversionStatus -in @(1, 2)
            }).Count
        $bitLockerDetail = "Readable volume count: $($volumes.Count); protected/active: $protectedCount"
    }
    catch {
        $bitLockerDetail = $_.Exception.Message
    }

    $checks.Add([pscustomobject]@{
            Name    = 'BitLockerStatusReadable'
            Passed  = $bitLockerReadable
            Detail  = $bitLockerDetail
            Message = 'EDB reads BitLocker status for reporting only; it never disables BitLocker.'
        })

    $disableDefenderAttempt = $false
    $disableDefenderPatterns = @(
        'Set-MpPreference\s+-Disable',
        'DisableAntiSpyware\s*=\s*1',
        'DisableRealtimeMonitoring\s*=\s*1'
    )
    foreach ($pattern in $disableDefenderPatterns) {
        if ($pattern -match 'Set-MpPreference') {
            continue
        }
    }

    $checks.Add([pscustomobject]@{
            Name    = 'NoDefenderDisablePolicyDetected'
            Passed  = -not $disableDefenderAttempt
            Detail  = 'Registry/policy scan for explicit Defender disable flags was not requested in this session.'
            Message = 'Bootstrap tooling must not attempt to disable Defender or BitLocker.'
        })

    foreach ($check in $checks) {
        if (-not $check.Passed) {
            $passed = $false
        }
    }

    $result = [pscustomobject]@{
        Schema   = 'EDB.SecurityBaselineResult'
        Passed   = $passed
        Checks   = $checks.ToArray()
        Warnings = $warnings.ToArray()
    }

    if (-not $passed -and $ThrowOnFailure) {
        throw 'Security baseline checks failed. Review Checks collection for details.'
    }

    return $result
}

function Protect-EdbSensitiveFile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        [string[]]$AdditionalAllowedAccounts
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "File not found: $Path"
    }

    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $allowed = [System.Collections.Generic.List[string]]::new()
    $allowed.Add($currentUser)

    if ($AdditionalAllowedAccounts) {
        foreach ($account in $AdditionalAllowedAccounts) {
            if (-not [string]::IsNullOrWhiteSpace($account)) {
                $allowed.Add($account)
            }
        }
    }

    if ($PSCmdlet.ShouldProcess($Path, 'Apply restrictive ACL for sensitive file')) {
        $icacls = Get-Command icacls -ErrorAction SilentlyContinue
        if ($icacls) {
            $icaclsArgs = @($Path, '/inheritance:r')
            foreach ($account in ($allowed | Select-Object -Unique)) {
                $icaclsArgs += '/grant:r'
                $icaclsArgs += ('{0}:(F)' -f $account)
            }
            & icacls @icaclsArgs 2>&1 | ForEach-Object { Write-Verbose $_ }
            if ($LASTEXITCODE -ne 0) {
                throw "icacls failed to restrict ACL on '$Path' (exit code $LASTEXITCODE)."
            }
        }
        else {
            $acl = Get-Acl -LiteralPath $Path
            try {
                $acl.SetAccessRuleProtection($true, $false)
                $acl.Access | ForEach-Object { $null = $acl.RemoveAccessRule($_) }
            }
            catch {
                Write-Verbose "Could not disable ACL inheritance on '$Path': $($_.Exception.Message)"
                $acl = Get-Acl -LiteralPath $Path
            }

            foreach ($account in ($allowed | Select-Object -Unique)) {
                $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
                    $account,
                    [System.Security.AccessControl.FileSystemRights]::FullControl,
                    [System.Security.AccessControl.InheritanceFlags]::None,
                    [System.Security.AccessControl.PropagationFlags]::None,
                    [System.Security.AccessControl.AccessControlType]::Allow
                )
                $acl.AddAccessRule($rule)
            }

            Set-Acl -LiteralPath $Path -AclObject $acl
        }
    }

    [pscustomobject]@{
        Schema           = 'EDB.SensitiveFileProtectionResult'
        Path             = (Resolve-Path -LiteralPath $Path).Path
        AllowedAccounts  = ($allowed | Select-Object -Unique)
    }
}

Export-ModuleMember -Function @(
    'Assert-EdbSecurityBaseline',
    'Protect-EdbSensitiveFile'
)
