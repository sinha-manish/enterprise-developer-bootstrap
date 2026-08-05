# Production-Readiness Audit

**Product:** Enterprise Developer Bootstrap (EDB)  
**Repository:** `d:\developer_domain_kit`  
**Audit date:** 2026-08-05 (regenerated after Critical remediation)  
**Previous audit:** Critical items C1–C8 were open  
**Verdict:** **Critical issues C1–C8 are remediated.** High/Medium/Low items from the prior audit remain open and should be addressed before a broad Intune/SCCM rollout.

| Severity | Open | Notes |
|----------|-----:|-------|
| Critical | 0 | C1–C8 fixed in this remediation pass |
| High | 12 | Unchanged from prior audit (H1–H12) |
| Medium | 14 | Unchanged from prior audit |
| Low | 8 | Unchanged from prior audit |

**Test status after remediation:** 109 passed, 0 failed, 3 inconclusive.

---

## Critical remediation status

### C1 — Provider failures reported as Succeeded — FIXED

| Field | Detail |
|-------|--------|
| **Root cause** | `Install-EdbWingetPackage` returned `Failed` objects without throwing; `Install-EdbSinglePackage` always emitted `Succeeded`. |
| **Files** | `modules/EDB.InstallPipeline/EDB.InstallPipeline.Install.ps1` |
| **Fix** | Inspect provider result `Status`; throw on `Failed` (enables Chocolatey fallback); return `Skipped`/`Succeeded` results unchanged. |
| **Tests** | `propagates provider Failed status instead of Succeeded (C1)` |

### C2 — `-WhatIf` still bootstraps Winget — FIXED

| Field | Detail |
|-------|--------|
| **Root cause** | WhatIf still called `New-EdbOrchestrationProviders` without skipping Winget bootstrap. |
| **Files** | `EDB.Orchestration.Bootstrap.ps1`, `EDB.Orchestration.Internal.ps1`, `EDB.Winget.Bootstrap.ps1` |
| **Fix** | Pass `-SkipWingetBootstrap:$WhatIfPreference`; `Install-EdbWingetIfMissing` honors `SupportsShouldProcess`. |
| **Tests** | WhatIf bootstrap test mocks `Install-EdbWingetIfMissing` to throw if called. |

### C3 — Parallel ignores deps / AllowParallel — FIXED

| Field | Detail |
|-------|--------|
| **Root cause** | Parallel path ran the full ordered list concurrently. |
| **Files** | `EDB.InstallPipeline.Install.ps1`, `EDB.InstallPipeline.psm1` |
| **Fix** | `Resolve-EdbPackageWaves` builds topo waves; serial (`AllowParallel:$false`) packages run first per wave; parallelizable packages run in a throttled batch afterward. |
| **Tests** | `builds dependency waves and separates AllowParallel` |

### C4 — Catalog scripts are arbitrary code — FIXED

| Field | Detail |
|-------|--------|
| **Root cause** | Inline `PostInstallScript` / `ValidateCommand` written to temp `.ps1` and executed. |
| **Files** | Install pipeline trusted-script resolver; `EDB.Health.psm1`; catalog ValidateCommands sanitized; `scripts/trusted/` |
| **Fix** | PostInstall only allows `scripts/trusted/*.ps1`. ValidateCommand must be a simple CLI (no pipes/cmdlets/metacharacters); executed via resolved executable + argv. |
| **Tests** | Trusted path rejection tests; `Test-EdbValidateCommandIsSafe`; unsafe ValidateCommand → Unhealthy |

### C5 — Domain modules never invoked — FIXED

| Field | Detail |
|-------|--------|
| **Root cause** | `Start-EdbBootstrap` never called domain post-configure APIs. |
| **Files** | `EDB.Orchestration.PostConfigure.ps1`, Bootstrap wiring, Developer Guide |
| **Fix** | `Invoke-EdbPostConfigure` runs after successful installs: Security baseline, PowerShell profile, VS Code defaults, Git detection, AI MCP notes for AI profiles. Skipped under WhatIf. |
| **Tests** | WhatIf returns skipped post-configure actions |

### C6 — PostInstallScript replaces install — FIXED

| Field | Detail |
|-------|--------|
| **Root cause** | Non-empty PostInstallScript short-circuited before Winget/Chocolatey. |
| **Files** | `EDB.InstallPipeline.Install.ps1` |
| **Fix** | Provider install first; trusted PostInstallScript only after success. |
| **Tests** | `runs provider install before trusted PostInstallScript (C6)` |

### C7 — Health failures do not fail session — FIXED

| Field | Detail |
|-------|--------|
| **Root cause** | Final status ignored unhealthy health results; entrypoint always exited 0. |
| **Files** | `EDB.Orchestration.Bootstrap.ps1`, `bootstrap/Install-DeveloperEnvironment.ps1` |
| **Fix** | Unhealthy checks set session `Failed`; health skipped on WhatIf/ReportOnly; entrypoint `exit 1` on Failed. |
| **Tests** | `marks session Failed when health checks are unhealthy (C7)` |

### C8 — Invalid PostgreSQL Winget ID — FIXED

| Field | Detail |
|-------|--------|
| **Root cause** | Catalog used non-existent `PostgreSQL.PostgreSQL`. |
| **Files** | `config/packages/catalog.json`, `catalog.yaml` |
| **Fix** | Pinned `PostgreSQL.PostgreSQL.16`. |
| **Tests** | `pins PostgreSQL to a versioned Winget id (C8)` |

---

## Remaining High issues (not in this pass)

H1 SessionId correlation (partially improved: session created before logger with shared id; full Resume-without-id still open)  
H2 Chocolatey auto-bootstrap / true fallback (partial: Winget failure now can fall through to Chocolatey when id present)  
H3 Dual catalog JSON/YAML drift  
H4 local.json overlays unused  
H5 Rollback callback splat  
H6 WhatIf health (fixed as part of C7 skip)  
H7 Choco remote bootstrap Bypass  
H8 SSH empty passphrase / Force  
H9 Security baseline stub quality  
H10 Remaining fragile validates (GUI apps on PATH)  
H11 DefaultScope unused  
H12 pip installType  

---

## Enterprise gate (updated)

- [x] C1–C8 fixed and covered by Pester  
- [x] WhatIf skips Winget bootstrap and post-configure mutation paths  
- [x] Bootstrap exit code non-zero on Failed  
- [x] PostgreSQL Winget ID pinned  
- [ ] Catalog Winget IDs validated in CI (`winget show`) — still recommended  
- [ ] Single config source of truth (H3)  
- [ ] Remaining High items before broad pilot  
- [ ] Signing / internal package acquisition decided  

---

## Appendix — severity rubric

| Severity | Meaning |
|----------|---------|
| **Critical** | Incorrect success, security RCE/mutation under dry-run, or core profile install broken |
| **High** | Feature advertised but broken/unsafe; resume/audit/enterprise policy failure |
| **Medium** | Maintainability, coverage, consistency, or secondary profile defects |
| **Low** | Hygiene, unused exports, hardening niceties |
