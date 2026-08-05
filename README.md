# Enterprise Developer Bootstrap

Production-grade framework for provisioning Windows 11 Enterprise developer laptops with a single command.

IT departments configure profiles and packages; developers run one bootstrap script. The framework detects the environment, installs only what the selected profile requires, validates health, and emits HTML/JSON reports.

## Requirements

- Windows 11 Enterprise (or compatible Windows 10/11)
- PowerShell 7+
- Local Administrator rights **or** Developer OU / Intune / SCCM grants for required packages
- Network access (corporate proxy supported)

## Quick start

```powershell
# Clone or copy this repository to the machine, then:
pwsh -File .\bootstrap\Install-DeveloperEnvironment.ps1 -Profile FullStack
```

Other profiles: `Backend`, `Frontend`, `DevOps`, `DataEngineer`, `AIEngineer`, `QAEngineer`.

```powershell
# Dry run
pwsh -File .\bootstrap\Install-DeveloperEnvironment.ps1 -Profile DevOps -WhatIf

# Resume interrupted install
pwsh -File .\bootstrap\Install-DeveloperEnvironment.ps1 -Profile FullStack -Resume
```

## Architecture

Clean Architecture mapped to PowerShell modules:

| Layer | Modules |
|-------|---------|
| Presentation | `bootstrap/`, `scripts/` |
| Application | `EDB.Orchestration`, `EDB.Profiles`, `EDB.InstallPipeline` |
| Domain | `EDB.Contracts`, `EDB.Models` |
| Infrastructure | `EDB.Winget`, `EDB.Chocolatey`, `EDB.Logging`, `EDB.Retry`, `EDB.System`, `EDB.Configuration`, `EDB.Rollback`, `EDB.Health`, `EDB.Reports` |

Domain package modules live under `modules/` (`git`, `vscode`, `node`, `ai`, `cloud/*`, databases, etc.).

See [docs/Architecture.md](docs/Architecture.md).

## Security posture

- Does **not** bypass UAC, disable Defender, or disable BitLocker
- Does **not** perform privilege escalation
- Assumes IT grants rights via Developer OU, Intune, SCCM, or Local Administrator
- Secrets are never written to logs

## Documentation

| Guide | Audience |
|-------|----------|
| [Architecture](docs/Architecture.md) | Platform engineers |
| [Developer Guide](docs/Developer-Guide.md) | Developers |
| [Administrator Guide](docs/Administrator-Guide.md) | IT / endpoint teams |
| [Configuration Guide](docs/Configuration-Guide.md) | Config authors |
| [Package Guide](docs/Package-Guide.md) | Package maintainers |
| [Troubleshooting](docs/Troubleshooting.md) | Support |
| [Production-Readiness Audit](docs/Production-Readiness-Audit.md) | Platform / release gate |

## Testing

```powershell
# Requires PowerShell 7
pwsh -File .\scripts\Invoke-EdbTests.ps1
```

Install test dependencies once:

```powershell
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
Install-Module powershell-yaml -Scope CurrentUser -Force
```

## License

Internal enterprise use. Adjust for your organization's distribution policy.
