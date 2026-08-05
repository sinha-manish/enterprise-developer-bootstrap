#Requires -Version 7.0
using module '..\EDB.Windows'

function Test-EdbPythonInstalled {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) {
        $python = Get-Command py -ErrorAction SilentlyContinue
    }

    $version = $null
    if ($python) {
        try {
            if ($python.Name -eq 'py') {
                $version = (& py -3 --version 2>$null | Select-Object -First 1).ToString().Trim()
            }
            else {
                $version = (& python --version 2>$null | Select-Object -First 1).ToString().Trim()
            }
        }
        catch { $version = $null }
    }

    [pscustomobject]@{
        Schema    = 'EDB.PythonInstalled'
        Installed = [bool]$python
        Path      = $(if ($python) { $python.Source } else { $null })
        Version   = $version
    }
}

function Set-EdbPythonPath {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [string]$PythonHome,
        [string[]]$AdditionalPaths,
        [ValidateSet('User', 'Machine')]
        [string]$Scope = 'User'
    )

    $pathsToAdd = [System.Collections.Generic.List[string]]::new()

    if (-not [string]::IsNullOrWhiteSpace($PythonHome)) {
        if (-not (Test-Path -LiteralPath $PythonHome)) {
            throw "PythonHome path not found: $PythonHome"
        }
        $resolved = (Resolve-Path -LiteralPath $PythonHome).Path
        $pathsToAdd.Add($resolved)
        $scripts = Join-Path $resolved 'Scripts'
        if (Test-Path -LiteralPath $scripts) {
            $pathsToAdd.Add((Resolve-Path -LiteralPath $scripts).Path)
        }
    }

    if ($AdditionalPaths) {
        foreach ($p in $AdditionalPaths) {
            if (Test-Path -LiteralPath $p) {
                $pathsToAdd.Add((Resolve-Path -LiteralPath $p).Path)
            }
            else {
                Write-Verbose "Skipping missing Python path entry: $p"
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($PythonHome)) {
        if ($PSCmdlet.ShouldProcess('PYTHONHOME', "Set $Scope PYTHONHOME")) {
            $target = if ($Scope -eq 'Machine') {
                [EnvironmentVariableTarget]::Machine
            }
            else {
                [EnvironmentVariableTarget]::User
            }
            [Environment]::SetEnvironmentVariable('PYTHONHOME', (Resolve-Path -LiteralPath $PythonHome).Path, $target)
        }
    }

    $added = @()
    if ($pathsToAdd.Count -gt 0) {
        $pathResult = Set-EdbDeveloperPath -PathEntries $pathsToAdd.ToArray() -Scope $Scope
        $added = $pathResult.Added
    }

    [pscustomobject]@{
        Schema      = 'EDB.PythonPathResult'
        PythonHome  = $PythonHome
        AddedToPath = $added
        Scope       = $Scope
    }
}

Export-ModuleMember -Function @(
    'Test-EdbPythonInstalled',
    'Set-EdbPythonPath'
)
