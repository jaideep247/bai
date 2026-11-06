# Payment Engine Operations Suite (`ops-suite/`)

> **First principle:** one engine, one exception store, one alert router — every check, rule, file expectation and alert route is a customizing row, never a code change.
> **Analogy:** an airport operations centre — runway checks (health checks), baggage tracking (file monitoring) and customs (bank statement validation) all report to one control room board (exception store + morning report) and one paging system (alert router).

Built against `MASTER_PROMPT_FSCD_OPERATIONS_SUITE.md` (repository root) for the payment engine on S/4HANA 2023 (SAP_BASIS 7.58). Consolidates and supersedes the BAI validators (v4), the BAI validation framework packs and the first morning report (snapshots in `../legacy/`).

## What is in it

| Module | Folder | Delivers | Master prompt |
|---|---|---|---|
| **Core** | `src/core` | Result/exception store (ZCD_OPS_RUN / ZCD_OPS_FINDING), parameters, configurable alert router (rules, e-mail / application log / HTTP webhook, throttling, quiet hours, escalation, delivery log), factory/injector, clock | Shared engine, store, alert router |
| **EBS validation** | `src/ebs` | BAI2 + CAMT.053/054 parsers, BTC rule engine (C01–X01, R01–R20, S01–S12), zero-suspense blocking, pre-posting decision with kill switch, report `ZCD_EBS_VALIDATE` | Framework 3 |
| **File monitoring** | `src/fmon` | File registry over the existing ZCD_* tables, SAP → PRISM → bank → SAP event chain, SLA / missing / NACK / ack-mismatch checks, returns & NOC completeness, report `ZCD_FMON_MONITOR` | Framework 2 |
| **Health check & morning report** | `src/hck` | Check engine with categories A–E, baselines and outlier detection, job-cycle monitoring, volume KPIs, health of the health check, report `ZCD_MORNING_REPORT` (ALV + HTML e-mail), analytics CDS for the dashboard | Frameworks 1 and 4 (monitoring), dashboard |

Retrigger of job cycles from SAP (Framework 4, second half) is the next phase: it starts jobs, so it gets its own design review, authorization concept and CAB.

## Documentation (`docs/`)

| Document | Audience |
|---|---|
| `DEVELOPMENT_STANDARDS.md` | Developers — house rules, TDD, headers, lint |
| `EBS_VALIDATION.md`, `EBS_PARSERS.md` | Business/ops (part A) and technical (part B) |
| `FMON_FILE_MONITORING.md` | Business/ops and technical |
| `HCK_MORNING_REPORT.md` | Business/ops and technical |
| `ALERTING.md` | Ops and administrators |
| `Legacy_Parity_Comparison.md` | Reviewers — every difference to the legacy validators |
| `TDD_Approach_and_Coverage.md` | Developers / reviewers — test levels, what is and is not unit tested |
| `Test_and_Validation_Document.md` | CAB evidence (Draft until executed in QA1) |
| `Implementation_Order.md` | Basis / developers — activation and transport order |
| `Operations_Runbook.md` | IT support |
| `Class_Purpose_and_Modification_Log.md`, `Changed_Artifacts.csv`, `Coverage_Run_Register.csv`, `portable_checks.json` | Release evidence |

## Verify offline

```bash
cd ops-suite && npx @abaplint/cli@2
```

```bash
python3 tools/portable_checks.py "$(command -v abaplint)"
```

**What this proves and what it does not:** abaplint checks syntax and typing against SAP stubs at 7.58 rules; the portable checks prove house-rule compliance. Neither proves activation, DDIC existence, ATC or ABAP Unit results — those happen in DV1 (`Test_and_Validation_Document.md` §5). Fields marked `VERIFY-DDIC` in the DAO classes must be confirmed in SE11 first.

## Keeping local and cloud in sync

GitHub (`jaideep247/bai`, branch `claude/loving-albattani-qexsjc`) is the master copy. Cloud sessions (phone or browser) commit and push there; the local clone pulls from it.

- VS Code user settings: `git.autofetch` (every 120 s), `git.postCommitCommand: sync`, `git.confirmSync: false`, `git.pullBeforeCheckout`.
- Commit when a piece of work is done — VS Code pushes it; a cloud session sees it after `git fetch`.
- Never edit the same file in two places between syncs; if it happens, VS Code shows the merge side by side.
- SAP side: abapGit in DV1 pulls `ops-suite/src` from the same repository.
