# Architecture

## Product

**Enterprise Developer Bootstrap (EDB)** provisions Windows 11 Enterprise developer workstations from declarative profiles and package catalogs. IT owns configuration; developers execute a single bootstrap command.

## Principles

1. **Single responsibility** — each module owns one concern.
2. **Dependency inversion** — application code depends on contracts in `EDB.Contracts`, not concrete providers.
3. **Configuration over code** — packages and profiles are YAML; reports and session state are JSON.
4. **Fail closed on security** — no UAC bypass, no Defender/BitLocker disable, no privilege escalation.
5. **Observability** — structured logging, retry, rollback journal, HTML/JSON reports, health checks.

## Layer map

```
Presentation     bootstrap/, scripts/
Application      EDB.Orchestration, EDB.Profiles, EDB.InstallPipeline
Domain           EDB.Contracts, EDB.Models
Infrastructure   EDB.Winget, EDB.Chocolatey, EDB.Logging, EDB.Retry,
                 EDB.System, EDB.Configuration, EDB.Rollback,
                 EDB.Health, EDB.Reports
Domain packages  modules/EDB.Git, EDB.VSCode, EDB.Node, EDB.Python, EDB.Java, EDB.DotNet,
                 EDB.Docker, EDB.Windows, EDB.Postgres, EDB.MongoDB, EDB.MySql, EDB.Redis,
                 EDB.Aws, EDB.Azure, EDB.Gcp, EDB.Terraform, EDB.Kubernetes, EDB.AI,
                 EDB.Security, EDB.Company
```

Logical domain folders (`modules/git`, `modules/vscode`, `modules/cloud/aws`, …) contain README pointers to the corresponding `EDB.*` modules for discoverability. See [Domain-Module-Map.md](Domain-Module-Map.md).

## Install pipeline

1. Preflight — OS version, admin token, Winget, internet, corporate proxy
2. Resolve — profile → package IDs → dependency graph → skip already installed
3. Execute — Winget primary, Chocolatey fallback when configured; retry + optional parallel
4. Configure — Git, PATH, VS Code, PowerShell profile, Docker/WSL where applicable
5. Validate — health checks per package
6. Report — HTML + JSON under `reports/`
7. Rollback — best-effort uninstall of packages installed in the failed session

## Dependency injection

Orchestration constructs concrete services (logger, providers, report writers) and passes them into the pipeline as contract-typed parameters. Tests substitute fakes that implement the same method surface.

## Package providers

| Priority | Provider | When used |
|----------|----------|-----------|
| 1 | Winget | Default when `WingetId` is set |
| 2 | Chocolatey | When no Winget ID, or Winget fails and `ChocolateyId` is set |

## State and resume

Session state is written to `logs/session-<id>.state.json`. `-Resume` reloads completed package IDs and continues from the first incomplete item.

## Module size policy

Public cmdlets stay focused. When a file approaches ~300 lines, split into Private helpers or additional Public files loaded by the root `.psm1`.
