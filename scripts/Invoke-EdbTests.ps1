#Requires -Version 7.0
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Path = @('./tests')
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot
. (Join-Path $PSScriptRoot 'Initialize-EdbModulePath.ps1')

if (-not (Get-Module -ListAvailable Pester | Where-Object { $_.Version -ge [version]'5.0.0' })) {
    Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force -SkipPublisherCheck
}

Import-Module Pester -MinimumVersion 5.0.0

$resolved = foreach ($p in $Path) {
    if ([IO.Path]::IsPathRooted($p)) { $p } else { Join-Path $repoRoot $p }
}

$config = New-PesterConfiguration
$config.Run.Path = @($resolved)
$config.Filter.ExcludeTag = @('Integration')
$config.Output.Verbosity = 'Detailed'
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = Join-Path $repoRoot 'PesterResults.xml'
$config.TestResult.OutputFormat = 'NUnitXml'

$result = Invoke-Pester -Configuration $config
Write-Host ("PASSED={0} FAILED={1} TOTAL={2}" -f $result.PassedCount, $result.FailedCount, $result.TotalCount)
if ($result.FailedCount -gt 0) {
    $result.Failed | ForEach-Object {
        Write-Host $_.ExpandedName -ForegroundColor Red
        Write-Host ($_.ErrorRecord | Out-String)
    }
    exit 1
}

exit 0
