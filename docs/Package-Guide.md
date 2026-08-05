# Package Guide

## Adding a package

1. Choose a stable Winget ID (`winget search <name>`)
2. Add an entry to `config/packages/catalog.json` (and YAML mirror if used)
3. Add the package Id to one or more profiles under `config/profiles/`
4. Set `ValidateCommand` to a non-interactive version check
5. Mark `RequiresAdmin: true` when elevation is mandatory
6. Declare `DependsOn` for ordering (for example `ubuntu` depends on `wsl`)
7. Run unit tests and a `-WhatIf` bootstrap

## Provider selection

1. Winget when `WingetId` is set
2. Chocolatey when Winget is unavailable/fails **and** `ChocolateyId` is set
3. VS Code extension path when `Metadata.installType` is `vscodeExtension`

## Post-install scripts

`PostInstallScript` must be a repo-relative path under `scripts/trusted/*.ps1`.

Inline script content is rejected. Trusted scripts run only after a successful provider install.

## Validation

Health checks execute `ValidateCommand` after install. Commands must be:

- Simple executable invocations (for example `git --version`)
- Non-interactive
- Exit 0 on success
- Free of secrets
- Free of pipes, PowerShell cmdlets, and script metacharacters

Examples: `git --version`, `node --version`, `docker --version`, `pwsh -v`

Unsafe examples (rejected): `exit 0`, `code --list-extensions | Select-String x`, `Get-Process ChatGPT`

## Domain modules

Bootstrap invokes a post-configure phase automatically after successful installs. Domain modules also remain available for manual or IT-driven follow-up:

| Concern | Module |
|---------|--------|
| Git identity / SSH | `EDB.Git` |
| VS Code settings / extensions | `EDB.VSCode` |
| PATH / env / profile | `EDB.Windows` |
| MCP / AI tooling | `EDB.AI` |
| Security baseline asserts | `EDB.Security` |

## Naming

Package Ids are lowercase identifiers used in profiles (`git`, `vscode`, `kubectl`). They are not Winget Ids.
