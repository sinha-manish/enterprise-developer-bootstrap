# Configuration Guide

## Layout

```text
config/
  packages/catalog.json|yaml     # Software catalog
  profiles/*.json|yaml           # Developer profiles
  settings/default.json|yaml     # Framework settings
  settings/local.json            # Optional local overrides (gitignored)
  vscode/                        # VS Code defaults
  git/                           # Git templates
  ai/                            # MCP templates
  company/                       # Company branding templates
```

JSON is preferred in CI. YAML requires the `powershell-yaml` module:

```powershell
Install-Module powershell-yaml -Scope CurrentUser -Force
```

If both `catalog.json` and `catalog.yaml` exist, the configuration loader prefers JSON to avoid duplicate package IDs.

## Settings keys

| Key | Meaning |
|-----|---------|
| `LogLevel` | Trace, Debug, Information, Warning, Error, Critical |
| `WriteToConsole` | Mirror logs to the console |
| `ParallelInstalls` | Max parallel package installs when `-Parallel` is used |
| `DefaultProvider` | `Winget` (Chocolatey is fallback only) |
| `RetryCount` | Transient failure retries |
| `RequirePreflight` | Abort when preflight errors exist |
| `GenerateReports` | Emit HTML/JSON reports |
| `ReportFormats` | `Json`, `Html` |

## Profile schema

```json
{
  "Name": "Backend",
  "Description": "API and service development",
  "Packages": ["git", "vscode", "node"],
  "Settings": {}
}
```

## Package schema

```json
{
  "Id": "git",
  "DisplayName": "Git",
  "WingetId": "Git.Git",
  "ChocolateyId": "",
  "Category": "Vcs",
  "Profiles": ["Backend", "Frontend"],
  "RequiresAdmin": false,
  "DependsOn": [],
  "ValidateCommand": "git --version",
  "PostInstallScript": "",
  "AllowParallel": true,
  "Metadata": {}
}
```

Special metadata:

- `installType: vscodeExtension` with `extensionId` — installs via `code --install-extension`
- Packages must define `WingetId` and/or `ChocolateyId`, unless `Metadata.installType` covers installation

## Loading from scripts

```powershell
. .\scripts\Initialize-EdbModulePath.ps1
Import-Module EDB.Configuration
Get-EdbPackageCatalog
Get-EdbSettings -IncludeLocalOverrides
```
