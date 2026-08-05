#Requires -Version 7.0
using module '..\EDB.Contracts'
using module '..\EDB.Models'

<#
.SYNOPSIS
    HTML and JSON report writers for Enterprise Developer Bootstrap.
#>

function ConvertTo-EdbHtmlEncoded {
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) {
        return ''
    }

    [System.Net.WebUtility]::HtmlEncode($Text)
}

function ConvertTo-EdbHtmlStatusClass {
    param([string]$Status)

    switch -Regex ($Status) {
        'Succeeded|Healthy|Passed|true' { 'status-ok' }
        'Failed|Unhealthy|false' { 'status-bad' }
        'Skipped|Degraded|Warning' { 'status-warn' }
        default { 'status-neutral' }
    }
}

function Get-EdbHtmlReportStyles {
    return @'
<style>
  :root { color-scheme: light; font-family: "Segoe UI", system-ui, sans-serif; }
  body { margin: 0; background: #f4f6f8; color: #1f2933; }
  .container { max-width: 1100px; margin: 0 auto; padding: 24px; }
  header { background: #0f4c81; color: #fff; padding: 24px; border-radius: 8px 8px 0 0; }
  header h1 { margin: 0 0 8px; font-size: 1.6rem; }
  header p { margin: 4px 0; opacity: 0.92; }
  section { background: #fff; margin-top: 16px; padding: 20px; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
  h2 { margin-top: 0; font-size: 1.15rem; border-bottom: 2px solid #e5e7eb; padding-bottom: 8px; }
  table { width: 100%; border-collapse: collapse; font-size: 0.92rem; }
  th, td { border: 1px solid #e5e7eb; padding: 8px 10px; text-align: left; vertical-align: top; }
  th { background: #f8fafc; font-weight: 600; }
  tr:nth-child(even) td { background: #fafbfc; }
  .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 12px; }
  .metric { background: #f8fafc; border: 1px solid #e5e7eb; border-radius: 6px; padding: 12px; text-align: center; }
  .metric .value { font-size: 1.4rem; font-weight: 700; }
  .metric .label { font-size: 0.8rem; color: #52606d; text-transform: uppercase; letter-spacing: 0.04em; }
  .status-ok { color: #0f7b3a; font-weight: 600; }
  .status-bad { color: #b42318; font-weight: 600; }
  .status-warn { color: #b45309; font-weight: 600; }
  .status-neutral { color: #52606d; font-weight: 600; }
  footer { margin-top: 20px; font-size: 0.82rem; color: #52606d; text-align: center; }
</style>
'@
}

function ConvertTo-EdbHtmlTable {
    param(
        [string[]]$Headers,
        [object[][]]$Rows
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<table><thead><tr>')
    foreach ($header in $Headers) {
        [void]$sb.Append('<th>')
        [void]$sb.Append((ConvertTo-EdbHtmlEncoded -Text $header))
        [void]$sb.AppendLine('</th>')
    }
    [void]$sb.AppendLine('</tr></thead><tbody>')

    foreach ($row in $Rows) {
        [void]$sb.AppendLine('<tr>')
        foreach ($cell in $row) {
            $text = if ($null -eq $cell) { '' } else { [string]$cell }
            $class = ConvertTo-EdbHtmlStatusClass -Status $text
            [void]$sb.Append('<td class="')
            [void]$sb.Append($class)
            [void]$sb.Append('">')
            [void]$sb.Append((ConvertTo-EdbHtmlEncoded -Text $text))
            [void]$sb.AppendLine('</td>')
        }
        [void]$sb.AppendLine('</tr>')
    }

    [void]$sb.AppendLine('</tbody></table>')
    $sb.ToString()
}

class EdbJsonReportWriter : EdbReportWriterBase {
    EdbJsonReportWriter() {
        $this.Format = 'json'
    }

    [string] WriteReport([object]$ReportDocument, [string]$OutputPath) {
        if ($null -eq $ReportDocument) {
            throw 'ReportDocument is required.'
        }
        if ([string]::IsNullOrWhiteSpace($OutputPath)) {
            throw 'OutputPath is required.'
        }

        $directory = Split-Path -Parent $OutputPath
        if (-not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }

        $json = $ReportDocument | ConvertTo-Json -Depth 8
        [System.IO.File]::WriteAllText($OutputPath, $json, [System.Text.UTF8Encoding]::new($false))
        return $OutputPath
    }
}

class EdbHtmlReportWriter : EdbReportWriterBase {
    EdbHtmlReportWriter() {
        $this.Format = 'html'
    }

    [string] WriteReport([object]$ReportDocument, [string]$OutputPath) {
        if ($null -eq $ReportDocument) {
            throw 'ReportDocument is required.'
        }
        if ([string]::IsNullOrWhiteSpace($OutputPath)) {
            throw 'OutputPath is required.'
        }

        $directory = Split-Path -Parent $OutputPath
        if (-not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }

        $html = New-EdbHtmlReportContent -ReportDocument $ReportDocument
        [System.IO.File]::WriteAllText($OutputPath, $html, [System.Text.UTF8Encoding]::new($false))
        return $OutputPath
    }
}

function New-EdbHtmlReportContent {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$ReportDocument
    )

    $summaryText = if (-not [string]::IsNullOrWhiteSpace($ReportDocument.Summary)) {
        [string]$ReportDocument.Summary
    }
    else {
        New-EdbInstallationSummary -ReportDocument $ReportDocument
    }
    $counts = $ReportDocument.Counts
    $generatedAt = if ($ReportDocument.GeneratedAt) { $ReportDocument.GeneratedAt.ToUniversalTime().ToString('u') } else { [datetime]::UtcNow.ToString('u') }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<!DOCTYPE html>')
    [void]$sb.AppendLine('<html lang="en"><head><meta charset="utf-8" />')
    [void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1" />')
    [void]$sb.AppendLine('<title>Enterprise Developer Bootstrap Report</title>')
    [void]$sb.AppendLine((Get-EdbHtmlReportStyles))
    [void]$sb.AppendLine('</head><body><div class="container">')
    [void]$sb.AppendLine('<header>')
    [void]$sb.AppendLine('<h1>Enterprise Developer Bootstrap Report</h1>')
    [void]$sb.Append("<p>Session: $(ConvertTo-EdbHtmlEncoded -Text $ReportDocument.SessionId)</p>")
    [void]$sb.Append("<p>Profile: $(ConvertTo-EdbHtmlEncoded -Text $ReportDocument.ProfileName)</p>")
    [void]$sb.Append("<p>Host: $(ConvertTo-EdbHtmlEncoded -Text $ReportDocument.HostName) | User: $(ConvertTo-EdbHtmlEncoded -Text $ReportDocument.UserName)</p>")
    [void]$sb.Append("<p>Generated: $(ConvertTo-EdbHtmlEncoded -Text $generatedAt)</p>")
    [void]$sb.AppendLine('</header>')

    [void]$sb.AppendLine('<section><h2>Summary</h2>')
    [void]$sb.Append("<p>$(ConvertTo-EdbHtmlEncoded -Text $summaryText)</p>")
    [void]$sb.AppendLine('<div class="summary-grid">')
    foreach ($metric in @(
            @{ Label = 'Succeeded'; Value = $counts.Succeeded }
            @{ Label = 'Failed'; Value = $counts.Failed }
            @{ Label = 'Skipped'; Value = $counts.Skipped }
            @{ Label = 'Total'; Value = $counts.Total }
        )) {
        [void]$sb.AppendLine('<div class="metric">')
        [void]$sb.Append("<div class=""value"">$(ConvertTo-EdbHtmlEncoded -Text ([string]$metric.Value))</div>")
        [void]$sb.Append("<div class=""label"">$(ConvertTo-EdbHtmlEncoded -Text $metric.Label)</div>")
        [void]$sb.AppendLine('</div>')
    }
    [void]$sb.AppendLine('</div></section>')

    $resultRows = [System.Collections.Generic.List[object[]]]::new()
    foreach ($item in @($ReportDocument.Results)) {
        if ($null -eq $item) { continue }
        $resultRows.Add(@(
                [string]$item.PackageId
                [string]$item.Status
                [string]$item.Provider
                [string]$item.Message
                [string]$item.DurationMs
            ))
    }
    [void]$sb.AppendLine('<section><h2>Install Results</h2>')
    [void]$sb.Append((ConvertTo-EdbHtmlTable -Headers @('Package', 'Status', 'Provider', 'Message', 'Duration (ms)') -Rows $resultRows))
    [void]$sb.AppendLine('</section>')

    if ($null -ne $ReportDocument.Preflight) {
        $pf = $ReportDocument.Preflight
        $preflightRows = [System.Collections.Generic.List[object[]]]::new()
        foreach ($row in @(
                @('Passed', [string]$pf.Passed)
                @('OS Caption', [string]$pf.OsCaption)
                @('OS Version', [string]$pf.OsVersion)
                @('Administrator', [string]$pf.IsAdministrator)
                @('Winget Available', [string]$pf.WingetAvailable)
                @('Winget Version', [string]$pf.WingetVersion)
                @('Internet Available', [string]$pf.InternetAvailable)
                @('Proxy Detected', [string]$pf.ProxyDetected)
                @('Proxy Address', [string]$pf.ProxyAddress)
                @('Errors', ($pf.Errors -join '; '))
                @('Warnings', ($pf.Warnings -join '; '))
            )) {
            $preflightRows.Add($row) | Out-Null
        }
        [void]$sb.AppendLine('<section><h2>Preflight</h2>')
        [void]$sb.Append((ConvertTo-EdbHtmlTable -Headers @('Check', 'Value') -Rows $preflightRows))
        [void]$sb.AppendLine('</section>')
    }

    $healthRows = [System.Collections.Generic.List[object[]]]::new()
    foreach ($health in @($ReportDocument.HealthResults)) {
        if ($null -eq $health) { continue }
        $healthRows.Add(@(
                [string]$health.Name
                [string]$health.Status
                [string]$health.Message
                if ($health.CheckedAt) { $health.CheckedAt.ToUniversalTime().ToString('u') } else { '' }
            ))
    }
    [void]$sb.AppendLine('<section><h2>Health Checks</h2>')
    if ($healthRows.Count -eq 0) {
        [void]$sb.AppendLine('<p>No health checks recorded.</p>')
    }
    else {
        [void]$sb.Append((ConvertTo-EdbHtmlTable -Headers @('Name', 'Status', 'Message', 'Checked At') -Rows $healthRows))
    }
    [void]$sb.AppendLine('</section>')

    [void]$sb.AppendLine('<footer>Enterprise Developer Bootstrap - automated installation report</footer></div></body></html>')
    $sb.ToString()
}

function New-EdbJsonReportWriter {
    [CmdletBinding()]
    [OutputType([EdbJsonReportWriter])]
    param()

    [EdbJsonReportWriter]::new()
}

function New-EdbHtmlReportWriter {
    [CmdletBinding()]
    [OutputType([EdbHtmlReportWriter])]
    param()

    [EdbHtmlReportWriter]::new()
}

function Export-EdbReport {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [EdbReportWriterBase]$Writer,

        [Parameter(Mandatory)]
        [object]$ReportDocument,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $Writer.WriteReport($ReportDocument, $OutputPath)
}

function New-EdbInstallationSummary {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$ReportDocument
    )

    $counts = $ReportDocument.Counts
    $status = if ($ReportDocument.Status) { $ReportDocument.Status } else { 'Unknown' }
    $profile = if ($ReportDocument.ProfileName) { $ReportDocument.ProfileName } else { 'default' }

    if ($counts.Failed -gt 0) {
        return "Profile '$profile' completed with errors ($($counts.Succeeded) succeeded, $($counts.Failed) failed, $($counts.Skipped) skipped). Session status: $status."
    }

    if ($counts.Skipped -gt 0 -and $counts.Succeeded -eq 0) {
        return "Profile '$profile' did not install any packages ($($counts.Skipped) skipped). Session status: $status."
    }

    "Profile '$profile' installed $($counts.Succeeded) of $($counts.Total) packages successfully ($($counts.Skipped) skipped). Session status: $status."
}

Export-ModuleMember -Function @(
    'New-EdbJsonReportWriter',
    'New-EdbHtmlReportWriter',
    'Export-EdbReport',
    'New-EdbInstallationSummary'
)
