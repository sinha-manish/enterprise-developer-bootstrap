#Requires -Version 7.0
using module '..\EDB.Windows'

function Test-EdbJavaInstalled {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $java = Get-Command java -ErrorAction SilentlyContinue
    $version = $null

    if ($java) {
        try {
            $versionOutput = & java -version 2>&1 | Select-Object -First 1
            if ($versionOutput) {
                $version = $versionOutput.ToString().Trim()
            }
        }
        catch { $version = $null }
    }

    $javaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
    if ([string]::IsNullOrWhiteSpace($javaHome)) {
        $javaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine')
    }

    [pscustomobject]@{
        Schema    = 'EDB.JavaInstalled'
        Installed = [bool]$java
        Path      = $(if ($java) { $java.Source } else { $null })
        Version   = $version
        JavaHome  = $javaHome
    }
}

function Set-EdbJavaHome {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$JavaHome,
        [ValidateSet('User', 'Machine')]
        [string]$Scope = 'User',
        [switch]$UpdatePath
    )

    if (-not (Test-Path -LiteralPath $JavaHome)) {
        throw "JAVA_HOME path not found: $JavaHome"
    }

    $resolved = (Resolve-Path -LiteralPath $JavaHome).Path
    $binPath = Join-Path $resolved 'bin'

    $target = if ($Scope -eq 'Machine') {
        [EnvironmentVariableTarget]::Machine
    }
    else {
        [EnvironmentVariableTarget]::User
    }

    if ($PSCmdlet.ShouldProcess('JAVA_HOME', "Set $Scope JAVA_HOME")) {
        [Environment]::SetEnvironmentVariable('JAVA_HOME', $resolved, $target)
    }

    $pathAdded = @()
    if ($UpdatePath -and (Test-Path -LiteralPath $binPath)) {
        $pathResult = Set-EdbDeveloperPath -PathEntries @($binPath) -Scope $Scope
        $pathAdded = $pathResult.Added
    }

    [pscustomobject]@{
        Schema      = 'EDB.JavaHomeResult'
        JavaHome    = $resolved
        Scope       = $Scope
        AddedToPath = $pathAdded
    }
}

Export-ModuleMember -Function @(
    'Test-EdbJavaInstalled',
    'Set-EdbJavaHome'
)
