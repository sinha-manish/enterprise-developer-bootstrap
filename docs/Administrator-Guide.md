# Administrator Guide

## Purpose

Enable IT / endpoint teams to distribute Enterprise Developer Bootstrap safely under existing Windows 11 Enterprise controls.

## Deployment model

1. Host this repository on an internal Git remote, Intune Win32 content share, or SCCM package source
2. Grant developers membership in a **Developer OU** / Entra group with rights to install approved Winget packages
3. Optionally pre-install PowerShell 7 and Winget (App Installer) via Intune
4. Developers run `bootstrap\Install-DeveloperEnvironment.ps1 -Profile <Name>`

## Rights model

| Right | Why |
|-------|-----|
| Local Administrator **or** scoped install rights | Packages with `RequiresAdmin: true` (Docker, WSL, Visual Studio, database servers) |
| Network / proxy | Winget and HTTPS downloads |
| PowerShell 7 execution | Framework runtime |

The framework **never**:

- Bypasses UAC
- Disables Microsoft Defender
- Disables BitLocker
- Performs privilege escalation

## Corporate proxy

Set machine or user environment variables before bootstrap:

```text
HTTPS_PROXY=http://proxy.company.com:8080
HTTP_PROXY=http://proxy.company.com:8080
NO_PROXY=localhost,127.0.0.1,.company.com
```

Preflight detects WinHTTP and environment proxies and records them in the report.

## Customizing for your organization

1. Edit `config/packages/catalog.json` (or `.yaml`) — add/remove Winget IDs
2. Edit `config/profiles/*.json` — control which packages each role receives
3. Edit `config/settings/default.json` — retry, logging, parallel defaults
4. Optional `config/settings/local.json` — machine-specific overlays (gitignored)
5. Optional `config/company/` — branding via `EDB.Company`

## Intune / SCCM notes

- Package the repo as content; detection rule: presence of `reports\*.json` from a successful run, or a marker file you add post-success
- Run install in system or user context consistently with Winget scope
- Prefer user-scope Winget installs where possible to reduce elevation prompts

## Validation

```powershell
pwsh -File .\scripts\Invoke-EdbTests.ps1
```

CI runs PSScriptAnalyzer and Pester on `windows-latest` (see `.github/workflows/ci.yml`).

## Support artifacts to collect

- `logs/edb-*.log`
- `logs/session-*.state.json`
- `reports/*.html` and `reports/*.json`
- Output of `Invoke-EdbPreflightCheck`
