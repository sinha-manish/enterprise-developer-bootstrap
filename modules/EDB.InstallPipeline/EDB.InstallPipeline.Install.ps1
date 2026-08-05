#Requires -Version 7.0

function Test-EdbInstallResultObject {
    param([object]$Result)

    return (
        $null -ne $Result -and
        $Result -is [pscustomobject] -and
        $null -ne $Result.PSObject.Properties['Status']
    )
}

function Resolve-EdbTrustedPostInstallScript {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$PostInstallScript,

        [Parameter(Mandatory)]
        [string]$RepositoryRoot
    )

    $trimmed = $PostInstallScript.Trim()
    if ($trimmed -match '[\r\n;|&$`]') {
        throw 'Inline PostInstallScript content is not permitted. Provide a repo-relative path under scripts/trusted/.'
    }

    if ($trimmed.Contains('..')) {
        throw 'PostInstallScript path must not contain parent-segment references (..).'
    }

    $normalized = $trimmed -replace '/', '\'
    if (-not $normalized.StartsWith('scripts\trusted\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "PostInstallScript must be a path under scripts/trusted/. Received: $trimmed"
    }

    if (-not $normalized.EndsWith('.ps1', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'PostInstallScript must reference a .ps1 file under scripts/trusted/.'
    }

    $fullPath = [IO.Path]::GetFullPath((Join-Path $RepositoryRoot $normalized))
    $trustedRoot = [IO.Path]::GetFullPath((Join-Path $RepositoryRoot 'scripts\trusted'))
    if (-not $fullPath.StartsWith($trustedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "PostInstallScript resolves outside scripts/trusted/: $trimmed"
    }

    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "Trusted PostInstallScript not found: $fullPath"
    }

    return $fullPath
}

function Invoke-EdbTrustedPostInstallScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [Parameter(Mandatory)]
        [string]$PackageId
    )

    $output = & pwsh -NoProfile -NonInteractive -File $ScriptPath 2>&1 | Out-String
    $exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
    if ($exitCode -ne 0) {
        throw "Trusted PostInstallScript failed for '$PackageId' with exit code $exitCode. $output"
    }

    return @{ ScriptPath = $ScriptPath; Output = $output.Trim() }
}

function Install-EdbSinglePackage {
    param(
        [object]$Package,
        [hashtable]$Providers,
        [EdbLoggerBase]$Logger,
        [object]$RetryPolicy,
        [switch]$WhatIf,
        [string]$RepositoryRoot
    )

    $startedAt = [datetime]::UtcNow
    $providerUsed = ''
    $packageId = $Package.Id

    if ($WhatIf) {
        return New-EdbInstallResult -PackageId $packageId -Status ([EdbInstallStatus]::Skipped) `
            -Provider 'WhatIf' -Message 'Dry run; install skipped.' -StartedAt $startedAt -CompletedAt ([datetime]::UtcNow)
    }

    $winget = $Providers['Winget']
    $choco = $Providers['Chocolatey']

    $installScript = {
        param($Pkg, $Winget, $Choco, [ref]$ProviderName)

        $installType = if ($Pkg.Metadata -and $Pkg.Metadata.installType) {
            [string]$Pkg.Metadata.installType
        }
        else {
            ''
        }

        if ($installType -eq 'vscodeExtension') {
            $extensionId = if ($Pkg.Metadata.extensionId) { [string]$Pkg.Metadata.extensionId } else { '' }
            if ([string]::IsNullOrWhiteSpace($extensionId)) {
                throw "Package '$($Pkg.Id)' requires Metadata.extensionId for vscodeExtension installs."
            }
            $code = (Get-Command code -ErrorAction SilentlyContinue).Source
            if (-not $code) {
                throw "VS Code CLI 'code' was not found for extension install '$extensionId'."
            }
            $ProviderName.Value = 'VscodeExtension'
            $output = & $code --install-extension $extensionId --force 2>&1 | Out-String
            $exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
            if ($exitCode -ne 0) {
                throw "VS Code extension install failed for '$extensionId' with exit code $exitCode. $output"
            }
            return New-EdbInstallResult -PackageId $Pkg.Id -Status ([EdbInstallStatus]::Succeeded) `
                -Provider 'VscodeExtension' -Message 'VS Code extension installed.' `
                -Details @{ ExtensionId = $extensionId; Output = $output.Trim() }
        }

        $providerResult = $null

        if ($Winget -and -not [string]::IsNullOrWhiteSpace($Pkg.WingetId) -and $Winget.IsAvailable()) {
            $ProviderName.Value = 'Winget'
            $providerResult = $Winget.InstallPackage($Pkg.WingetId, @{ PackageId = $Pkg.Id })
            if (Test-EdbInstallResultObject -Result $providerResult) {
                if ($providerResult.Status -eq [EdbInstallStatus]::Succeeded -or
                    $providerResult.Status -eq [EdbInstallStatus]::Skipped) {
                    return $providerResult
                }
            }
            else {
                return New-EdbInstallResult -PackageId $Pkg.Id -Status ([EdbInstallStatus]::Succeeded) `
                    -Provider 'Winget' -Message 'Install succeeded.' -Details @{ Raw = $providerResult }
            }

            if ($Choco -and -not [string]::IsNullOrWhiteSpace($Pkg.ChocolateyId) -and $Choco.IsAvailable()) {
                $ProviderName.Value = 'Chocolatey'
                $providerResult = $Choco.InstallPackage($Pkg.ChocolateyId, @{ PackageId = $Pkg.Id })
                if (Test-EdbInstallResultObject -Result $providerResult) {
                    if ($providerResult.Status -eq [EdbInstallStatus]::Succeeded -or
                        $providerResult.Status -eq [EdbInstallStatus]::Skipped) {
                        return $providerResult
                    }
                    throw $providerResult.Message
                }
                return New-EdbInstallResult -PackageId $Pkg.Id -Status ([EdbInstallStatus]::Succeeded) `
                    -Provider 'Chocolatey' -Message 'Install succeeded.' -Details @{ Raw = $providerResult }
            }

            if (Test-EdbInstallResultObject -Result $providerResult) {
                throw $providerResult.Message
            }
            throw "Winget install failed for package '$($Pkg.Id)'."
        }

        if ($Choco -and -not [string]::IsNullOrWhiteSpace($Pkg.ChocolateyId) -and $Choco.IsAvailable()) {
            $ProviderName.Value = 'Chocolatey'
            $providerResult = $Choco.InstallPackage($Pkg.ChocolateyId, @{ PackageId = $Pkg.Id })
            if (Test-EdbInstallResultObject -Result $providerResult) {
                if ($providerResult.Status -eq [EdbInstallStatus]::Failed) {
                    throw $providerResult.Message
                }
                return $providerResult
            }
            return New-EdbInstallResult -PackageId $Pkg.Id -Status ([EdbInstallStatus]::Succeeded) `
                -Provider 'Chocolatey' -Message 'Install succeeded.' -Details @{ Raw = $providerResult }
        }

        throw "No available provider for package '$($Pkg.Id)'."
    }

    try {
        $providerRef = [ref]''
        $installResult = Invoke-EdbRetry -Policy $RetryPolicy -ScriptBlock $installScript `
            -ArgumentList @{ Pkg = $Package; Winget = $winget; Choco = $choco; ProviderName = $providerRef }

        $providerUsed = $providerRef.Value

        if (Test-EdbInstallResultObject -Result $installResult) {
            if ($installResult.Status -eq [EdbInstallStatus]::Failed) {
                throw $installResult.Message
            }

            if ($installResult.Status -eq [EdbInstallStatus]::Skipped) {
                return $installResult
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($Package.PostInstallScript)) {
            if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
                throw "Package '$packageId' defines PostInstallScript but RepositoryRoot was not supplied to the installer."
            }
            $trustedScript = Resolve-EdbTrustedPostInstallScript -PostInstallScript $Package.PostInstallScript -RepositoryRoot $RepositoryRoot
            $postDetails = Invoke-EdbTrustedPostInstallScript -ScriptPath $trustedScript -PackageId $packageId
            if (Test-EdbInstallResultObject -Result $installResult) {
                $details = @{}
                if ($installResult.Details -is [hashtable]) {
                    $details = @{}.Clone()
                    foreach ($key in $installResult.Details.Keys) { $details[$key] = $installResult.Details[$key] }
                }
                $details['PostInstall'] = $postDetails
                $installResult | Add-Member -NotePropertyName Details -NotePropertyValue $details -Force
            }
        }

        if ($Logger) {
            Write-EdbLog -Logger $Logger -Level ([EdbLogLevel]::Information) `
                -Message "Installed package '$packageId' via $providerUsed." `
                -Properties @{ PackageId = $packageId; Provider = $providerUsed }
        }

        if (Test-EdbInstallResultObject -Result $installResult) {
            return $installResult
        }

        New-EdbInstallResult -PackageId $packageId -Status ([EdbInstallStatus]::Succeeded) `
            -Provider $providerUsed -Message 'Install succeeded.' `
            -StartedAt $startedAt -CompletedAt ([datetime]::UtcNow) `
            -Details @{ Raw = $installResult }
    }
    catch {
        if ($Logger) {
            Write-EdbLog -Logger $Logger -Level ([EdbLogLevel]::Error) `
                -Message "Install failed for '$packageId': $($_.Exception.Message)" `
                -Properties @{ PackageId = $packageId }
        }

        New-EdbInstallResult -PackageId $packageId -Status ([EdbInstallStatus]::Failed) `
            -Provider $providerUsed -Message $_.Exception.Message `
            -StartedAt $startedAt -CompletedAt ([datetime]::UtcNow) -ExitCode 1
    }
}

function Resolve-EdbPackageWaves {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object[]]$OrderedPackages,

        [System.Collections.Generic.HashSet[string]]$CompletedSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    )

    $remaining = [System.Collections.Generic.List[object]]::new()
    foreach ($pkg in $OrderedPackages) {
        if (-not $CompletedSet.Contains($pkg.Id)) {
            $remaining.Add($pkg) | Out-Null
        }
    }

    $waves = [System.Collections.Generic.List[object]]::new()
    $satisfied = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($id in $CompletedSet) { [void]$satisfied.Add($id) }

    while ($remaining.Count -gt 0) {
        $ready = [System.Collections.Generic.List[object]]::new()
        foreach ($pkg in @($remaining)) {
            $unmet = @($pkg.DependsOn | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not $satisfied.Contains($_) })
            if ($unmet.Count -eq 0) {
                $ready.Add($pkg) | Out-Null
            }
        }

        if ($ready.Count -eq 0) {
            $ids = @($remaining | ForEach-Object { $_.Id }) -join ', '
            throw "Unable to build install waves; remaining packages have unmet dependencies: $ids"
        }

        $waves.Add([pscustomobject]@{
                Schema           = 'EDB.InstallWave'
                Packages         = @($ready)
                Parallelizable   = @($ready | Where-Object { $_.AllowParallel })
                SerialPackages   = @($ready | Where-Object { -not $_.AllowParallel })
            }) | Out-Null

        $readyIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($pkg in $ready) {
            [void]$readyIds.Add($pkg.Id)
            [void]$satisfied.Add($pkg.Id)
        }

        for ($i = $remaining.Count - 1; $i -ge 0; $i--) {
            if ($readyIds.Contains($remaining[$i].Id)) {
                $remaining.RemoveAt($i)
            }
        }
    }

    @($waves)
}

function Update-EdbPipelineResultCollections {
    param(
        [object]$Result,
        [System.Collections.Generic.HashSet[string]]$CompletedSet,
        [System.Collections.Generic.List[object]]$Results,
        [object]$State
    )

    $Results.Add($Result) | Out-Null
    switch ($Result.Status) {
        ([EdbInstallStatus]::Succeeded) {
            [void]$CompletedSet.Add($Result.PackageId)
            if ($State) { $State.CompletedPackages.Add($Result.PackageId) | Out-Null }
        }
        ([EdbInstallStatus]::Failed) {
            if ($State) { $State.FailedPackages.Add($Result.PackageId) | Out-Null }
        }
        ([EdbInstallStatus]::Skipped) {
            [void]$CompletedSet.Add($Result.PackageId)
            if ($State) { $State.SkippedPackages.Add($Result.PackageId) | Out-Null }
        }
    }

    if ($State) {
        $State.Results.Add($Result) | Out-Null
        Save-EdbPipelineState -State $State | Out-Null
    }
}

function Invoke-EdbParallelPackageBatch {
    param(
        [object[]]$Packages,
        [hashtable]$Providers,
        [EdbLoggerBase]$Logger,
        [object]$RetryPolicy,
        [object]$State,
        [System.Collections.Generic.HashSet[string]]$CompletedSet,
        [System.Collections.Generic.List[object]]$Results,
        [int]$Total,
        [int]$ThrottleLimit,
        [bool]$WhatIf,
        [string]$ModulesPath,
        [string]$RepositoryRoot,
        [ref]$Index
    )

    if ($Packages.Count -eq 0) {
        return
    }

    $sync = [hashtable]::Synchronized(@{
            Results      = $Results
            CompletedSet = $CompletedSet
            State        = $State
            Index        = $Index.Value
        })

    $Packages | ForEach-Object -Parallel {
        $modulesPath = $using:ModulesPath
        if ($modulesPath -and ($env:PSModulePath -split [IO.Path]::PathSeparator -notcontains $modulesPath)) {
            $env:PSModulePath = $modulesPath + [IO.Path]::PathSeparator + $env:PSModulePath
        }
        Import-Module EDB.InstallPipeline -Force -ErrorAction Stop | Out-Null

        $pkg = $_
        $result = Install-EdbSinglePackage -Package $pkg -Providers $using:Providers `
            -Logger $using:Logger -RetryPolicy $using:RetryPolicy -WhatIf:$using:WhatIf `
            -RepositoryRoot $using:RepositoryRoot

        $usingSync = $using:sync
        [System.Threading.Monitor]::Enter($usingSync)
        try {
            $usingSync.Index++
            Update-EdbPipelineResultCollections -Result $result -CompletedSet $usingSync.CompletedSet `
                -Results $usingSync.Results -State $usingSync.State
            Show-EdbProgress -Current $usingSync.Index -Total $using:Total -PackageId $pkg.Id -Status ($result.Status.ToString())
        }
        finally {
            [System.Threading.Monitor]::Exit($usingSync)
        }
    } -ThrottleLimit ([math]::Max(1, $ThrottleLimit))

    $Index.Value = $sync.Index
}

function Invoke-EdbWavePackageSet {
    param(
        [object[]]$Ordered,
        [hashtable]$Providers,
        [EdbLoggerBase]$Logger,
        [object]$RetryPolicy,
        [object]$State,
        [System.Collections.Generic.HashSet[string]]$CompletedSet,
        [System.Collections.Generic.List[object]]$Results,
        [int]$Total,
        [int]$ThrottleLimit,
        [bool]$WhatIf,
        [string]$ModulesPath,
        [string]$RepositoryRoot
    )

    $waves = Resolve-EdbPackageWaves -OrderedPackages $Ordered -CompletedSet $CompletedSet
    $index = 0

    foreach ($wave in $waves) {
        foreach ($pkg in @($wave.SerialPackages)) {
            $index++
            if ($CompletedSet.Contains($pkg.Id)) {
                $skipped = New-EdbInstallResult -PackageId $pkg.Id -Status ([EdbInstallStatus]::Skipped) `
                    -Message 'Already completed in pipeline state.'
                Update-EdbPipelineResultCollections -Result $skipped -CompletedSet $CompletedSet -Results $Results -State $State
                Show-EdbProgress -Current $index -Total $Total -PackageId $pkg.Id -Status 'Skipped'
                continue
            }

            $result = Install-EdbSinglePackage -Package $pkg -Providers $Providers `
                -Logger $Logger -RetryPolicy $RetryPolicy -WhatIf:$WhatIf -RepositoryRoot $RepositoryRoot
            Update-EdbPipelineResultCollections -Result $result -CompletedSet $CompletedSet -Results $Results -State $State
            Show-EdbProgress -Current $index -Total $Total -PackageId $pkg.Id -Status ($result.Status.ToString())
        }

        $parallelPkgs = @($wave.Parallelizable | Where-Object { -not $CompletedSet.Contains($_.Id) })
        if ($parallelPkgs.Count -eq 1) {
            $index++
            $result = Install-EdbSinglePackage -Package $parallelPkgs[0] -Providers $Providers `
                -Logger $Logger -RetryPolicy $RetryPolicy -WhatIf:$WhatIf -RepositoryRoot $RepositoryRoot
            Update-EdbPipelineResultCollections -Result $result -CompletedSet $CompletedSet -Results $Results -State $State
            Show-EdbProgress -Current $index -Total $Total -PackageId $parallelPkgs[0].Id -Status ($result.Status.ToString())
        }
        elseif ($parallelPkgs.Count -gt 1) {
            $indexRef = [ref]$index
            Invoke-EdbParallelPackageBatch -Packages $parallelPkgs -Providers $Providers -Logger $Logger `
                -RetryPolicy $RetryPolicy -State $State -CompletedSet $CompletedSet -Results $Results `
                -Total $Total -ThrottleLimit $ThrottleLimit -WhatIf:$WhatIf -ModulesPath $ModulesPath `
                -RepositoryRoot $RepositoryRoot -Index $indexRef
            $index = $indexRef.Value
        }
    }
}
