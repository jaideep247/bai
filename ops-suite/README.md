# Payment Engine Operations Suite (`ops-suite/`)

> **First principle:** one engine, one exception store, one alert router — every check, rule, file expectation and alert route is a customizing row, never a code change.
> **Analogy:** an airport operations centre — runway checks (health checks), baggage tracking (file monitoring) and customs (bank statement validation) all report to one control room board (exception store + morning report) and one paging system (alert router).

Built against `REQUIREMENTS_FSCD_OPERATIONS_SUITE.md` (repository root) for the payment engine on S/4HANA 2023 (SAP_BASIS 7.58). Consolidates and supersedes the BAI validators (v4), the BAI validation framework packs and the first morning report (snapshots in `../legacy/`).

## What is in it

| Payment engine area | Folder | Delivers | Requirements baseline |
|---|---|---|---|
| **Core** | `src/core` | The shared objects of the suite on top of the operations framework ZCA_OPS (`ops-framework/`, store ZCA_OPS_RUN / ZCA_OPS_FINDING with exception carry-forward, alert router, run lock, configuration gate, retention purge `ZCA_OPS_RETENTION`, authorisation object ZCA_OPS): payment engine constants (areas CD_EBS / CD_FMON / CD_HCK / CD_OPS = parameter areas of ZCA_PARAM), runtime parameters over the framework adapter ZCL_CA_OPS_PARAMS with the suite's prefixes (delivered definitions `config/param_definitions.csv`), purge targets `ZCL_CD_OPS_PURGE_TARGET` (registry ZCA_OPS_PURGE, `config/purge_targets.csv`), bank ACK alert section `ZCL_CD_OPS_ACK_MAIL`, read-only 360° payment trace `ZCD_OPS_PAYMENT_TRACE`, payment worklist and outcome snapshot, pattern check `ZCD_OPS_PATTERN_CHECK` and one-off migration `ZCD_OPS_PATTERN_MIGRATE`, suite factory/injector | Payment engine services over the framework |
| **EBS validation** | `src/ebs` | BAI2 + CAMT.053/054 parsers, BTC rule engine (C01–X01, R01–R19, R21 (configurable lookup), S01–S12), zero-suspense blocking, post-posting batch report `ZCD_EBS_VALIDATE` (read-only) | Framework 3 |
| **File monitoring** | `src/fmon` | File registry over the existing ZCD_* tables, SAP → PRISM → bank → SAP event chain, SLA / missing / NACK / ack-mismatch checks, returns & NOC completeness, report `ZCD_FMON_MONITOR` | Framework 2 |
| **Health check & morning report** | `src/hck` | Check engine with categories A–E, baselines and outlier detection, job-cycle monitoring, volume KPIs, health of the health check, report `ZCD_MORNING_REPORT` (ALV + HTML e-mail), analytics CDS for the dashboard | Frameworks 1 and 4 (monitoring), dashboard |

**Production-support dashboards (read-only, Fiori elements OData V4):** file monitoring (`src/fmon`, `ZUI_CD_FMON_FLOW`), EBS validation (`src/ebs`, `ZUI_CD_EBS_DASH`), health checks / morning report (`src/hck`, `ZUI_CD_HCK_DASH`), transactions in SAP (`src/core`, `ZUI_CD_TRX_DASH`, live items with the canonical payment outcome of the 5-minute snapshot - the same verdict as the morning report and the payment trace, `ZIF_CD_OPS_PAY_OUTCOME`; request side in `cds/`, `ZUI_CD_TRX_REQ`, after SE11), and the overview page (`src/core`, `ZUI_CD_OPS_OVERVIEW`) with the launchpad space *Production Support* (documented, created in the system). **Control center (2026-11-10):** the overview page shows the daily controls of the business date (checks reviewed / awaiting / overdue, controls flagged, daily health checks, attention queue - signed off in the framework's *Daily control review* `ZUI_CA_OPS_REV`), the payment lifecycle (live DPAYH counts per configured stage, `ZCD_OPS_PAYSTAGE`) with its payments, and the open reconciliation variances of `A_RECON_3WAY` (`docs/Dashboard_Production_Support.md` §1a, controls and their mapping `config/control_seed.md`).

**New business processes (process onboarding, 2026-11-10):** a new monitored flow is added through the operations framework - its own area, rows of the framework's process register and check registry (no-code aggregate rows or one check class implementing `ZIF_CA_OPS_CHECK`), a control, an alert rule - scaffolded by `../tools/abaptools/new_process.py` and checked offline (portable check `process_onboarding`) and every morning (`D_PROC_ONBOARD` through the adapter `ZCL_CD_HCK_C_FRAMEWORK`). Guide: `ops-framework/docs/ADDING_A_BUSINESS_PROCESS.md`; worked example (inactive, placeholders): collections request lifecycle `CD_COLL` / `BASE_REQ_LIFE`, `config/control_seed.md` §2b, `docs/processes/`.

Retrigger of job cycles from SAP (Framework 4, second half) is the next phase: it starts jobs, so it gets its own design review, authorization concept and CAB.

## Documentation (`docs/`)

| Document | Audience |
|---|---|
| `DEVELOPMENT_STANDARDS.md` | Developers — house rules, TDD, headers, lint |
| `EBS_VALIDATION.md`, `EBS_PARSERS.md` | Business/ops (part A) and technical (part B) |
| `FMON_FILE_MONITORING.md` | Business/ops and technical |
| `HCK_MORNING_REPORT.md` | Business/ops and technical |
| `ALERTING.md` | Ops and administrators |
| `ALERT_CONTEXT_REVIEW.md` | Ops, RTB, reviewers — every alert the suite sends: rule, recipients, e-mail template, business context before / after, gaps left (2026-11-10) |
| `../templates/` (folder `ops-suite/templates`) | Configuration owners, Basis — the suite's SAP e-mail templates (SMTG) as documented sources with the DV1 creation steps |
| `Legacy_Parity_Comparison.md` | Reviewers — every difference to the legacy validators |
| `TDD_Approach_and_Coverage.md` | Developers / reviewers — test levels, what is and is not unit tested |
| `Test_and_Validation_Document.md` | CAB evidence (Draft until executed in QA1); §6.16 two-user company-code isolation test |
| `QA1_Pilot.md` | Pilot lead, RTB operations, reviewers — QA1 pilot of one collections flow, one disbursement flow, one BAI account: operating boundary, preconditions, daily routine, scenario tests S1-S6, acceptance per rollout step, exit criteria, evidence map of the 12 controls |
| `Implementation_Order.md` | Basis / developers — abapGit import, activation and transport order |
| `history/Audit_History.md` | Reviewers — every review and audit finding: decision, where it lives now, open residual |
| `RAP_Apps_Design.md` | Everyone — decisions D-1…D-6 for the RAP configuration and operations apps |
| `RAP_Config_Apps.md` | Configuration owners, RTB — the four configuration apps, client policy, validations, DV1 steps |
| `FICA_Posting_Areas.md` | FI-CA team, configuration owners, Basis — customer posting areas ZRSN / ZPMC / ZBTM / ZBTR: setup in DV1, layouts, FQC0 maintenance guide, morning check |
| `RAP_Ops_Apps.md` | Operations, approvers, RTB — exceptions, suppressions, manual file status, PRISM requests handled manually (four-eyes, history, DV1 steps, QA1 cases) |
| `Hardcoding_Inventory.md` | Reviewers — literals by category before / after phase 5 (generated by `tools/literal_scan.py`) |
| `USAA_Known_Tables.md` | Developers, RTB — confirmed landscape tables, fields and joins used by the suite |
| `VERIFY_Suite.md` | Reviewers, release manager — the suite's own VERIFY items (V82-V93, moved from the framework's list) and where its other items are |
| `ATC_Validation.md` | Reviewers, QA — ATC-equivalent offline checks, exemptions, what DV1 ATC must confirm |
| `RAP_Apps_Design.md` | Business owner, architects — configuration and operations apps, authorisation, run lock, carry-forward, purge |
| `Operations_Runbook.md` | IT support |
| `Performance_Review.md` | Developers, reviewers, Basis — the eight performance fixes (before / after access paths), sorted / hashed tables, field symbols, why no AMDP, deferred items, VERIFY-SE11 index list |
| `Payment_Trace.md` | L1/L2 support, reviewers — read-only 360° payment trace: stages, statuses, FIN + source and reversed-item lookups, VERIFY-SE11 list, QA cases |
| `Dashboard_File_Monitoring.md` | L1/L2 support, team leads — file monitoring dashboard (analytical list page, tiles, OVP-ready KPI): flow buckets, as-of / stale rule, SLA status, drill-down, coverage limits, QA cases |
| `Dashboard_EBS_Validation.md` | L1/L2 support, treasury — EBS validation dashboard: statements / lines / findings, validation status, unevaluated lines, POSTING_INCOMPLETE, returns / NOC by reason, as of, QA cases |
| `Dashboard_Health_Check.md` | L1/L2 support, team leads — health check dashboard: status per check and category, scorecard, warm-up, metric trends (DIM2 series), as of, QA cases |
| `Dashboard_Transactions.md` | L1/L2 support, disbursement ops — transactions dashboard: live funnel posted → paid → settled / returned, payment runs, returns / NOC by reason, request side after SE11 (what lights up when), payment trace navigation, QA cases |
| `Dashboard_Production_Support.md` | L1/L2 support, launchpad admins — overview page (cards, one-service design), monitor freshness, critical exceptions, space *Production Support*, catalogs, target mappings, roles |
| `Class_Purpose_and_Modification_Log.md`, `Changed_Artifacts.csv`, `Coverage_Run_Register.csv`, `portable_checks.json` | Release evidence |

## Verify offline

```bash
cd ops-suite && npx @abaplint/cli@2
```

```bash
python3 tools/portable_checks.py "$(command -v abaplint)"
```

Tools: `tools/abapgit_serialize.py`, `rap_generate.py`, `param_definitions.py`, `modernize.py`,
`literal_scan.py`, `class_purpose.py` and `name_checks.py` are the suite's profiles of the repository's shared
tools (`../tools/abaptools`, tests `../tools/tests`, run `python3 -m unittest discover -s tools/tests` from the
repository root); each keeps its command and its `--check` option. The operations framework's own app
`ZUI_CA_OPS_CFG` is generated from `ops-framework/` (its `tools/rap_generate.py`), no longer from here.

Test paths: every class has its own test include or a row in `tools/test_path_register.csv` (covering include or exemption with reason); `tools/test_checks.py` (run by the portable checks) also proves that DAO tests double every table they reach and that no test of a class without SQL uses a real DAO. The per-class register is `docs/Coverage_Run_Register.csv`.

**What this proves and what it does not:** abaplint checks syntax and typing against SAP stubs at 7.58 rules; the portable checks prove house-rule compliance. The ATC-equivalent run (`abaplint.atc.json`, see `docs/ATC_Validation.md`) leaves two documented exemptions. Neither proves activation, DDIC existence, the real ATC result or ABAP Unit results — those happen in DV1 (`Test_and_Validation_Document.md` §5). Fields marked `VERIFY-DDIC` in the DAO classes must be confirmed in SE11 first.

## Keeping local and cloud in sync

GitHub (`jaideep247/bai`, branch `main`) is the master copy. Changes are committed and pushed there; the local clone pulls from it.

- VS Code user settings: `git.autofetch` (every 120 s), `git.postCommitCommand: sync`, `git.confirmSync: false`, `git.pullBeforeCheckout`.
- Commit when a piece of work is done — VS Code pushes it; any other clone sees it after `git fetch`.
- Never edit the same file in two places between syncs; if it happens, VS Code shows the merge side by side.
- SAP side: abapGit in DV1 pulls `ops-suite/src` from the same repository.
