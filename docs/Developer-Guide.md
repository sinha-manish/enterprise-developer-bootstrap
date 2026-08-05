# Developer Guide

## Who this is for

Software engineers on Windows 11 Enterprise who need a consistent, IT-approved toolchain.

## Prerequisites

1. PowerShell 7 (`pwsh`)
2. Rights granted by IT (Developer OU, Intune, SCCM, or Local Administrator) for packages that require elevation
3. Network access (corporate proxy supported via `HTTP_PROXY` / `HTTPS_PROXY` / WinHTTP)

## One-command install

From the repository root:

```powershell
pwsh -File .\bootstrap\Install-DeveloperEnvironment.ps1 -Profile FullStack
```

### Profiles

| Profile | Typical use |
|---------|-------------|
| `Backend` | APIs, databases, Docker |
| `Frontend` | Web UI, Node, browsers |
| `FullStack` | Combined backend + frontend + data clients |
| `DevOps` | Cloud CLIs, Terraform, Kubernetes, WSL |
| `DataEngineer` | Python, databases, analytics clients |
| `AIEngineer` | Cursor, Copilot, MCP, Python/Node |
| `QAEngineer` | Browsers, Postman, Docker, Node/Python |

### Useful switches

```powershell
# Preview actions without installing
pwsh -File .\bootstrap\Install-DeveloperEnvironment.ps1 -Profile DevOps -WhatIf

# Resume after interruption
pwsh -File .\bootstrap\Install-DeveloperEnvironment.ps1 -Profile FullStack -Resume

# Install an explicit package list
pwsh -File .\bootstrap\Install-DeveloperEnvironment.ps1 -Packages git,vscode,node

# Skip health validation (not recommended)
pwsh -File .\bootstrap\Install-DeveloperEnvironment.ps1 -Profile Backend -SkipValidation
```

## After install

Bootstrap runs an automatic post-configure phase after successful installs (security baseline, PowerShell profile, VS Code defaults when present, AI MCP notes for AI profiles). Git identity and SSH keys remain explicit:

```powershell
Import-Module .\modules\EDB.Git\EDB.Git.psd1
Set-EdbGitConfiguration -UserName 'Jane Doe' -UserEmail 'jane.doe@company.com'
New-EdbSshKey -Comment 'jane.doe@company.com'
```

VS Code defaults are applied during post-configure when `vscode` is in the profile. You can re-apply manually:

```powershell
Import-Module .\modules\EDB.VSCode\EDB.VSCode.psd1
Install-EdbDefaultVSCodeExtensions
Set-EdbVSCodeSettings -UseRepositoryDefaults
```

## Logs and reports

| Artifact | Location |
|----------|----------|
| Structured logs | `logs/edb-*.log` |
| Resume state | `logs/session-*.state.json` |
| HTML / JSON reports | `reports/` |

## Security expectations

- Do not request or run scripts that disable Defender, BitLocker, or UAC
- SSH private keys are written with restricted ACLs and are never logged
- Secrets in MCP or cloud config templates must be filled locally; they are redacted from logs

## Getting help

See [Troubleshooting](Troubleshooting.md) and [Administrator Guide](Administrator-Guide.md).
