# Authorisation of the payment engine suite — object ZCA_OPS (roles, entry points, DCLs)

> **First principle:** one object guards every operations action, so a role says in one place who may run, change or approve.
> **Analogy:** one keycard system for the whole building — the card says which floors (areas) and which doors (activities), not a different key per room.

**Since 2026-11-10 the suite has no authorisation object of its own** (user decision: one authorisation object). The object is the operations framework's `ZCA_OPS` (object class `ZCA` and area field `ZCA_PARAR` of the parameter framework ZCA_PARAM); its definition sheet - fields, activities, framework roles and checks - is **`ops-framework/docs/auth_zca_ops.md`**. The suite's former object `ZCD_OPS` and field `ZCD_PE_AREA` are retired (never activated, nothing to migrate); the portable check `auth_fields_defined` fails if either appears in code or a DCL. This sheet keeps what is the suite's: the area values, its roles, its entry points and its DCLs. The code checks only through `ZCL_CA_OPS_AUTH` (`ZIF_CA_OPS_AUTH`, `ZCL_CA_OPS_FACTORY=>GET_AUTH`).

## 1. Area values of the suite (field ZCA_PARAR)

The areas are parameter areas of ZCA_PARAM (`config/param_areas.csv`, one area register): `CD_EBS` EBS validation · `CD_FMON` file monitoring · `CD_HCK` health check / morning report · `CD_OPS` cross-area objects of the suite (payment worklist and trace, transactions dashboard, approved tables). The framework's own objects (alert rules and channels, purge targets, retention purge `ZCA_OPS_RETENTION`) use area `CA_OPS`. Before 2026-11-10 the values were `EBS`, `FMON`, `HCK`, `CORE`.

**Business processes onboarded through the framework (process onboarding, 2026-11-10).** A process monitored by the framework's check registry gets its **own area** (its runs would otherwise be the "last run" of an engine's area, e.g. the morning report's self-check of `CD_HCK`): proposal `CD_COLL` - collections payment request lifecycle (BASE), process `BASE_REQ_LIFE` (`config/process_register.csv`, `docs/processes/CD_COLL_BASE_REQ_LIFE.md`). The area is created in ZCA_PARAM **when the process is activated** (P2 open, `config/control_seed.md` §2a); the roles are defined in §3 (operator `Z_CD_OPS_COLL`, `CD_COLL` in `Z_CD_OPS_BATCH` and `Z_CD_OPS_APPROVER`, display in `ZCD_OPS_PROD_SUPPORT`, 2026-11-10) and created in PFCG on activation.

**SAP job failures (2026-11-11, area `CD_JOBS`, decision D-PO1).** The framework's SAP job monitor
(`ops-framework/docs/JOB_MONITORING.md`) runs for the suite as process `CD_JOBS` / `SAP_JOBS`
(`docs/processes/CD_JOBS_SAP_JOBS.md`), **active**: area `CD_JOBS` is delivered in `config/param_areas.csv`. Roles in
§3: display in `ZCD_OPS_PROD_SUPPORT` and `Z_CD_OPS_DISPLAY`, operator `Z_CD_OPS_OPERATOR` (02 / 03), approver
`Z_CD_OPS_APPROVER` (85), job user `Z_CD_OPS_BATCH` (16) - details in §3 *SAP job failures*.

## 2. Activities used by the suite

The same activities as before on `ZCD_OPS`: 01 create (configuration row; FMON: record a PRISM status event), 02 change, 03 display, 06 delete, 16 execute, 85 approve - see `ops-framework/docs/auth_zca_ops.md` §2. `BUKRS` keeps restricting objects with a company code (statement, open item, threshold row); area-wide checks pass it as `DUMMY`.

## 3. Roles (PFCG) — proposal

| Role | ZCA_PARAR | ACTVT | BUKRS |
|---|---|---|---|
| `Z_CD_OPS_DISPLAY` | * | 03 | * |
| `Z_CD_OPS_BATCH` (Control-M job user) | CD_EBS, CD_FMON, CD_HCK, CD_OPS, CA_OPS, CD_COLL (check run `ZCA_OPS_CHECK_RUN` of the collections request lifecycle, 2026-11-10), **CD_JOBS** (check run of the SAP job monitor, group `FAST` every 5 minutes, 2026-11-11 - plus `S_BTCH_JOB`, see *SAP job failures* below) | 16 | * |
| `Z_CD_OPS_OPERATOR` (RTB operations) | CD_EBS, CD_FMON, CD_HCK, **CD_JOBS** (assign / resolve SAP job failures, 2026-11-11) | 02, 03 | own company codes |
| `Z_CD_OPS_APPROVER` (team lead, not the operator) | CD_EBS, CD_FMON, CD_HCK, CD_COLL (waivers of the collections request lifecycle, 2026-11-10), **CD_JOBS** (waivers of SAP job failures, 2026-11-11) | 03, 85 | own company codes |
| `Z_CD_OPS_CONFIG` (configuration owner) | per payment engine area | 01, 02, 03, 06 (create, change, display, delete of configuration rows; each checked on its own) | * |
| `Z_CD_OPS_PRISM` (PRISM technical user `PRISM_FMON`, type B) | CD_FMON | 01 | DUMMY — plus `S_ICF` ICF_FIELD `SERVICE`, ICF_VALUE `ZCD_PRISM` (the SICF node's authorisation value) |
| `Z_CD_OPS_COLL` (collections operations - operator of process `BASE_REQ_LIFE`, 2026-11-10; details below) | CD_COLL | 02, 03 | own company codes |

**`Z_CD_OPS_COLL` - collections operations (operator of the collections request lifecycle, 2026-11-10).** Single role for the
team that works the exceptions of process `CD_COLL` / `BASE_REQ_LIFE` (BASE request lifecycle and Stripe premium refund,
checks R1-R4, `docs/processes/CD_COLL_BASE_REQ_LIFE.md`). Same shape as `Z_CD_OPS_OPERATOR`, for one area:

| Authorisation | Values | Gives |
|---|---|---|
| `ZCA_OPS` | ZCA_PARAR `CD_COLL`; ACTVT `02`, `03`; BUKRS the team's company codes | display of the area's findings, exceptions and area dashboard rows (DCL rule of §3d); assign, resolve, request a waiver and classify an exception of those company codes (`ZCL_CA_OPS_EXC_POLICY=>MAY_ACT`) |
| `S_SERVICE` | `ZUI_CA_OPS_EXC_O4` (exceptions app), `ZUI_CA_OPS_DASH_O4` (area dashboard), `ZUI_CD_OPS_OVERVIEW_O4` (overview cards) | the three OData services the team opens |
| Launchpad | business catalog `ZCD_OPS_BC_COLL` (tiles *Owned exceptions* filtered to area `CD_COLL`, *Area dashboard*), page *Exceptions* and *Overview* of space *Production Support* | entry points |

Not in the role (by design): `85` (waiver approval - `Z_CD_OPS_APPROVER` with `CD_COLL`, another person), `16` (the check run -
job user `Z_CD_OPS_BATCH`), `01` / `06` (configuration - `Z_CD_OPS_CONFIG`, DV1 only). **Sign-off:** the control
*Base-rejected items* (`BASE_REJECTS`) belongs to area `CD_COLL` (moved from `CD_HCK` 2026-11-10, user decision), so this
team signs it off in the daily control review with its `CD_COLL` 02 (per company-code slice, D-CC5); the shift
reviewers (`ZCD_OPS_REVIEWER`) can sign it off too - their role carries `CD_COLL` 02 since 2026-11-10. No business-table authorisation: the checks only
read (`ZCA_OPS_TABWL` approved tables, `S_TABU_NAM` 03 of the job user). Delivery: the PFCG roles are created with the values
above when P2 is activated (area `CD_COLL` in `ZCA_PARAM_AREA` first); display of `CD_COLL` is already in business role
`ZCD_OPS_PROD_SUPPORT` (`docs/Dashboard_Production_Support.md` §4). Test: QA1 case OVP-16 plus the two-user script
(Test_and_Validation §6.16) with a `CD_COLL` exception of company code 1000.

**SAP job failures (area `CD_JOBS`, 2026-11-11).** Process `SAP_JOBS` (`docs/processes/CD_JOBS_SAP_JOBS.md`), board
`ZUI_CA_OPS_JOBS` of the framework, overview cards on `ZUI_CD_OPS_OVERVIEW`:

| Role | Authorisation | Values | Gives |
|---|---|---|---|
| `ZCD_OPS_PROD_SUPPORT`, `Z_CD_OPS_DISPLAY` (display) | `ZCA_OPS` | ZCA_PARAR `CD_JOBS`; ACTVT `03`; BUKRS own company codes (or *) | the board, its facets and the overview cards (DCL `ZC_CA_OPSJOBFAILURE`, rule of §3d: a job carries a company code only when an enricher found one), the exceptions of the area in `ZUI_CA_OPS_EXC`, the area dashboard rows of `CD_JOBS` |
| | `S_SERVICE` | `ZUI_CA_OPS_JOBS_O4` (board), `ZUI_CA_OPS_EXC_O4`, `ZUI_CA_OPS_DASH_O4`, `ZUI_CD_OPS_OVERVIEW_O4` | the OData services |
| `Z_CD_OPS_OPERATOR` (operator) | `ZCA_OPS` | ZCA_PARAR `CD_JOBS`; ACTVT `02`, `03` | assign, resolve, classify, request a waiver of a job failure; sign off control `SAP_JOB_FAILURES` (02) |
| `Z_CD_OPS_APPROVER` (approver) | `ZCA_OPS` | ZCA_PARAR `CD_JOBS`; ACTVT `03`, `85` | approve a waiver (another person than the requester) |
| `Z_CD_OPS_BATCH` (job user of `ZCA_OPS_CHECK_RUN`, `P_AREA` = `CD_JOBS`, `P_GROUP` = `FAST`) | `ZCA_OPS` | ZCA_PARAR `CD_JOBS`; ACTVT `16` | the check run (runner checks 16 for the area) |
| | `S_BTCH_JOB` | JOBACTION `PROT` (display job log), JOBGROUP `*` | `BP_JOBLOG_READ` of jobs of other users (failed jobs, watched programs, resolver candidates; at most `JOB_MAX_LOG_READS` per run) - read only; **no** `RELE`, `DELE`, `PLAN`, `MOVE`, no `S_BTCH_ADM` (the monitor never changes, releases, cancels or restarts a job). VERIFY-SU24 V64 |

TBTCO / TBTCP / BALHDR are read with ABAP SQL (no table authorisation is checked for static SQL); restarts stay
with Control-M and the runbook (`docs/Operations_Runbook.md` §5q).

Segregation of duties: the operator (02) and the approver (85) of a payment engine area and company code are different users; the apps additionally refuse an approval by the requester (four-eyes).

**PRISM status API (2026-11-06, `docs/PRISM_Status_API.md` §9).** The API checks `ZCA_OPS` ACTVT **01** for FMON (it *creates* an evidence record in the suite's own store). Activity 01 / FMON is also in `Z_CD_OPS_CONFIG`; the endpoint is therefore additionally restricted by the SICF authorisation value `ZCD_PRISM` (`S_ICF`), which only `Z_CD_OPS_PRISM` carries — a configuration owner cannot post PRISM events. The role is created in DV1 and assigned in PS4 only at switch S-PRISM (`Implementation_Order.md` step 1e). The bgPF unit runs under the calling user and needs no further authorisation (suite tables only; VERIFY in QA1).

## 3a. Dashboards (read-only, decision 2026-11-06)

| Dashboard (service) | ZCA_PARAR | BUKRS | ACTVT | DCL |
|---|---|---|---|---|
| File monitoring (`ZUI_CD_FMON_FLOW`) | CD_FMON | open exceptions: company code of the finding (rule of §3d); files, events, KPI: — (area-level, FMON has no company code) | 03 | `ZC_CD_FMONFLOW` |
| EBS validation (`ZUI_CD_EBS_DASH`) | CD_EBS | company code of the statement / line / finding; run and KPI rows per company-code slice (rule of §3d); as-of: — | 03 | `ZC_CD_EBSDASH` |
| Health checks (`ZUI_CD_HCK_DASH`) | CD_HCK | company code of the finding / metric; check, category, run, KPI, red-amber rows per company-code slice (rule of §3d); as-of: — | 03 | `ZC_CD_HCKDASH` |
| Transactions (`ZUI_CD_TRX_DASH`, `cds/ZUI_CD_TRX_REQ`) | **CD_OPS** | **company code of the open item** (payment run rows: area only) | 03 | `ZC_CD_TRXDASH`, `ZC_CD_TRXREQ` |
| SAP job failures board (`ZUI_CA_OPS_JOBS`, framework; 2026-11-11) | CD_JOBS | company code of an enricher's business object (blank = area-level, the rule of §3d) | 03 | `ZC_CA_OPSJOBFAILURE` |
| Production-support overview (`ZUI_CD_OPS_OVERVIEW`) | the area of each card / row | as the area dashboard; critical exceptions, daily controls (slice) and variances by the rule of §3d; payment lifecycle by company code; freshness: — | 03 | the area DCLs + `ZC_CD_OPSOVERVIEW` |

**Why CD_OPS for transactions (no new value):** the transactions dashboard shows the same evidence as the 360° payment trace (request, open item, payment run, bank line, return), which is guarded by CORE 03 plus the company code of each item (`Payment_Trace.md` §6). One area keeps one rule for "may see payment evidence"; a new value (e.g. TRX) would need a domain change and a second grant for the same data. CORE 03 already covers the read-only alert / parameter apps — a user who should see neither gets no CORE. Company code is mapped in the DCL, so `Z_CD_OPS_OPERATOR` (own company codes) sees only its own transactions.

Roles: `Z_CD_OPS_DISPLAY` (ZCA_PARAR *, 03, BUKRS *) covers all dashboards. Business roles per launchpad page (`Dashboard_Production_Support.md` §5) add the catalogs and `S_SERVICE` for the bindings; they grant no activity other than 03.

## 3b. Every entry point and the ZCA_OPS check it makes (audit mapping, 2026-11-08)

Every `AUTHORITY-CHECK` on `ZCA_OPS` is in one class, `ZCL_CA_OPS_AUTH` (`ZIF_CA_OPS_AUTH`, factory `GET_AUTH`). The engines (`ZCL_CD_EBS_ENGINE`, `ZCL_CD_FMON_ENGINE`, `ZCL_CD_HCK_ENGINE`, …) are called only from the entry points below, which check before the engine is created. The suite has no RFC-enabled function module and no other external entry point.

**Batch programs and reports**

| Entry point | ZCA_PARAR | ACTVT | When |
|---|---|---|---|
| `ZCD_EBS_VALIDATE` (job / SE38) | CD_EBS | 16 | At start, before the run; a bank file on the application server is a file name only, resolved in logical path `ZCD_OPS_EBS_IN` (FILE) and checked with `S_DATASET` activity READ (`ZCL_CA_OPS_FILE_PATH`, 2026-11-10) |
| `ZCD_FMON_MONITOR` (job `ZCD_FMON_MONITOR_ALL` step 1) | CD_FMON | 16 | At start |
| `ZCD_OPS_PAY_SNAPSHOT` (job `ZCD_FMON_MONITOR_ALL` step 2) | CD_OPS | 16 | At start |
| `ZCD_MORNING_REPORT` | CD_HCK | 16 | At start; the CSV export takes a file name only, resolved in logical path `ZCD_OPS_HCK_OUT` (FILE) and checked with `S_DATASET` activity WRITE (`ZCL_CA_OPS_FILE_PATH`, 2026-11-10) |
| `ZCA_OPS_RETENTION` | CD_OPS | 16 | At start |
| `ZCA_OPS_CHECK_RUN` (job, `P_AREA` = `CD_JOBS`, `P_GROUP` = `FAST`, every 5 minutes; 2026-11-11) | CD_JOBS | 16 | At start (framework runner); `BP_JOBLOG_READ` needs `S_BTCH_JOB` PROT of the job user |
| `ZCD_OPS_PAYMENT_TRACE` | CD_OPS | 03, plus company code per item | At start; a step on an item of a company code without 03 is shown as not authorised |
| `ZCD_OPS_PATTERN_CHECK` | each area | 03 | Per area read |
| `ZCD_OPS_PATTERN_MIGRATE` | each area | 02 | Per area, before anything is written (DV1, customizing request) |
| HCK checks reading a configured table (aggregates, value queries, queue and reference sources, drift hash) | — | `S_TABU_NAM` 03 | Before every dynamic read (`ZCL_CD_HCK_DAO=>GET_TABLE_FIELDS`, `ZIF_CA_OPS_AUTH=>MAY_READ_TABLE`, 2026-11-10), in addition to the approved-table list; refused = message 813 |
| EBS lookup rule R21 (`ZCD_EBS_LOOKUP`) | — | `S_TABU_NAM` 03 | Per lookup table at run time (`ZCL_CD_EBS_SAP_DAO=>GET_LOOKUP_ROWS`), after the field-level approval in `ZCD_OPS_TABWL` (area EBS, purpose LOOKUP; message 812); the approval is also checked when the lookup is saved |
| FMON dynamic reader (`ZCD_FMON_SRC` / `_LOTCFG` tables) | — | `S_TABU_NAM` 03 | Per table (`ZCL_CD_FMON_DDIC=>MAY_READ`, now the shared `ZIF_CA_OPS_AUTH=>MAY_READ_TABLE`) |
| PRISM status API (`POST /sap/zcd_ops/prism_status`, `ZCL_CD_FMON_PRISM_API`) | CD_FMON | 01 | Per call, before the event is stored; the bgPF unit it queues runs only for that stored event |

**RAP services (Fiori apps)**

| Service | Behaviour pool | Operation | ZCA_PARAR | ACTVT |
|---|---|---|---|---|
| `ZUI_CD_EBS_CFG`, `ZUI_CD_FMON_CFG`, `ZUI_CD_HCK_CFG`, `ZUI_CD_OPS_CFG` (configuration apps) | `ZBP_R_CD_EBSCFGALL`, `…FMONCFGALL`, `…HCKCFGALL`, `…OPSCFGALL` | Edit / update of the singleton (global authorisation of the root, `ZCL_CA_OPS_CFG_GATE=>MAY_EDIT`) | CD_EBS / CD_FMON / CD_HCK / CD_OPS (framework app ZUI_CA_OPS_CFG: CA_OPS) | at least one of 01, 02, 06 |
| same | same | Create of a child row (global authorisation of the root, create-by-association `%assoc`) | same | 01 |
| same | same | Change of a child row (global authorisation of the child entity, authorisation master) | same | 02 |
| same | same | Delete of a child row (global authorisation of the child entity) | same | 06 |
| same | same | Create and delete offered at all (global feature control) | — | Only in a client that records customizing changes (DV1), D-3; not an activity check |
| `ZUI_CA_OPS_EXC` (exceptions) | `ZBP_R_CA_OPSEXCEPTION` | Assign, resolve (instance authorisation) | Area of the exception | 02 |
| same | same | Approve a waiver (second person; the requester is refused) | Area of the exception | 85 |
| `ZUI_CD_HCK_SUP` (suppressions) | `ZBP_R_CD_HCKSUPPRESS` | Create, end suppression | CD_HCK | 02 |
| same | same | Approve suppression (second person) | CD_HCK | 85 |
| `ZUI_CD_FMON_MAN` (file manual status) | `ZBP_R_CD_FMONFILE` | Action set manual status | CD_FMON | 02 |
| `ZUI_CD_FMON_PRQ` (PRISM request handled manually) | `ZBP_R_CD_FMONPRQWA` | Create (records the reference and resolves the exception) | CD_FMON | 02 |
| Dashboards (`ZUI_CD_*_DASH`, `ZUI_CD_FMON_FLOW`, `ZUI_CD_TRX_REQ`, `ZUI_CD_OPS_OVERVIEW`) | — (read-only) | Read through the DCLs of §3a | per §3a | 03 |

The four configuration apps are generated (`tools/rap_generate.py`): every child entity is its own global authorisation master (VERIFY-ADT: child entity as authorisation master with draft on 7.58), so a user with 02 only can change but not add or delete rows, 01 only can add but not change, 06 can delete. Tests: the generated permission tests of each behaviour pool (02 only, 01 only, 06 only, no activity) and `ZCL_CA_OPS_CFG_GATE` (`edit_with_delete_only`, `no_activity_no_edit`).

## 3c. Read access of the operations apps (DCL, 2026-11-10)

The operations apps were readable with `S_SERVICE` alone (`#NOT_REQUIRED`). Their projections now carry `@AccessControl.authorizationCheck: #CHECK` and a DCL on `ZCA_OPS` activity 03, like the dashboards. Actions keep their own instance checks in the behaviour pools (unchanged).

| Projection (service) | DCL | Condition |
|---|---|---|
| `ZC_CA_OpsException` (`ZUI_CA_OPS_EXC`) | `ZC_CA_OPSEXCEPTION` | the rule of §3d on area and company code of the finding |
| `ZC_CA_OpsExcHist` (same service) | `ZC_CA_OPSEXCEPTION` | the rule of §3d on the exception (path `_Exception`) |
| `ZC_CD_FmonFile` (`ZUI_CD_FMON_MAN`) | `ZC_CD_FMONFILE` | fixed `ZCA_PARAR = 'CD_FMON'`, ACTVT 03 (no area element in the view) |
| `ZC_CD_FmonPrqWa` (`ZUI_CD_FMON_PRQ`) | `ZC_CD_FMONPRQWA` | fixed `ZCA_PARAR = 'CD_FMON'`, ACTVT 03 |
| `ZC_CD_HckSuppress` (`ZUI_CD_HCK_SUP`) | `ZC_CD_HCKSUPPRESS` | fixed `ZCA_PARAR = 'CD_HCK'`, ACTVT 03, and BUKRS of a suppression of a company code (§3d) |

VERIFY-ADT: `pfcg_auth` with an empty element list and fixed field values, and the path to the parent entity, on 7.58. Roles: `Z_CD_OPS_DISPLAY` (03, all areas) already covers them; `Z_CD_OPS_OPERATOR` / `_APPROVER` carry 03 for their areas.

**Field names checked offline.** The kernel check of `ZCL_CA_OPS_AUTH` used the field name `ZCD_MODULE`, which SU21 does not know - every check failed. It now uses `ZCA_PARAR` (§1). The portable check `auth_fields_defined` (`tools/auth_checks.py`) fails when an `AUTHORITY-CHECK` on `ZCA_OPS` or a `pfcg_auth( ZCA_OPS, … )` names a field that §1 / §2 do not define.

**S_DATASET (2026-11-10).** The application-server files of the suite are reached only through logical paths of transaction FILE: `ZCD_OPS_EBS_IN` (EBS bank file, READ) and `ZCD_OPS_HCK_OUT` (morning report CSV, WRITE), each with a logical file name of the same name for `FILE_VALIDATE_NAME`. The user enters a file name only (no `/`, `\` or `..`, message 808). Roles running these programs need `S_DATASET` with the program name, activity `33` (read) / `34` (write) - and `06` (delete) for the export, whose temporary file is deleted - for the physical path of the logical path.

## 3d. Company-code isolation (2026-11-10)

> **First principle:** a user scoped to company code 1000 never sees findings, history, counts or drill-downs of company code 2000 - in any app, card, count, value help or navigation.
> **Analogy:** one office building, one lock per company on each filing cabinet; the department noticeboard (area-level notices) is open to the department.

The rule is the framework's (`ops-framework/docs/auth_zca_ops.md` §3c): **area authorised AND ( company code blank OR ( area, company code ) authorised )**; area-level rows (blank company code: runs, files, jobs, configuration problems) are visible with the area authorisation. Making that switchable needs a second variant of every role (a decision, not built).

**Fill matrix - where the company code of a finding comes from (no new database read in a hot path):**

| Check family | Company code filled | Blank (area-level) |
|---|---|---|
| EBS validation (rules S01-S13, R01-R22) | statement and line findings: the statement's company code (FEBKO-BUKRS, already in the package - `ZCL_CD_EBS_ENGINE->ADD_CONTEXT`) | run findings (`ENG`, circuit breaker `CB`, plug-in errors at run level), bank-file findings before import (object FILE) |
| Payment worklist / snapshot (`ZCL_CD_OPS_PAY_SNAPSHOT`) | `PAY_SOURCE_AMBIGUOUS` aggregate: one finding per class, finding, run date **and company code** of its payments | technical findings (`SNAPSHOT_FAILED`, `PAY_OUTCOME_CONFIG`, `PARALLEL_OFF`, `BATCH_INCOMPLETE`, `READ_CAPPED`) |
| Payment trace, payment requests, transactions dashboard | - (no findings; read per company code by `ZC_CD_TRXDASH` / `ZC_CD_TRXREQ` and the trace) | - |
| File monitoring (all F_* checks, PRISM evidence) | - | every finding: the interface register `ZCD_FMON_IFACE` has no company code (adding one would need the per-file counts sliced first, VERIFY V44) |
| Health checks - generic aggregate / volume (`ZCD_HCK_AGG`) | aggregates with `GROUP_FIELD` = `BUKRS` (`ZIF_CD_HCK_TYPES=>GC_COMPANY_CODE_FIELD`): metric, metric history (`ZCD_HCK_METRIC-BUKRS`) and threshold findings carry the group value | aggregates grouped by another field or not grouped |
| Health checks - `A_RECON_3WAY` (`ZCL_CD_HCK_C_RECON3`) | metrics and findings of a reconciliation set: the set's company code (`ZCD_HCK_RCSET-BUKRS`) | the check's configuration findings without a set |
| Health checks - overdue exceptions (`C_OVERDUE`) | per area **and company code** of the exceptions (DIM2, metric company code) | overdue exceptions without company code |
| Health checks - all others (jobs, cycles, queues, number ranges, parameters, posting areas, drift, application log, technical, alert health, `A_INFLIGHT`, `A_GL_TRANSFER`, `C_CHQ_STATUS`, PRQ checks) | - | area-level: no company-code dimension in their measurement (`A_INFLIGHT`, `A_GL_TRANSFER`, `C_CHQ_STATUS`, PRQ checks count items of every company code - decision D-CC3 in `Release_Readiness.md`) |

**DCLs changed (rule above on every entity built on findings, history, metrics or their counts):** `ZC_CA_OPSEXCEPTION` (exceptions + history), `ZC_CA_OPSCTLREVIEW` (framework); `ZC_CD_EBSDASH` (statements, lines, returns / NOC, findings, problems, run and KPI slices; as-of area-level), `ZC_CD_FMONFLOW` (open exceptions; files, events, KPI, failures area-level), `ZC_CD_HCKDASH` (checks, categories, runs, metrics, findings, KPI, red-amber; as-of area-level), `ZC_CD_HCKSUPPRESS` (BUKRS of the suppression), `ZC_CD_OPSOVERVIEW` (critical exceptions, daily controls, variances; freshness area-level), `ZI_CD_OPSANALYTICS` (findings and metrics with their cubes; runs and files area-level). Unchanged: `ZC_CD_TRXDASH`, `ZC_CD_TRXREQ` (already by company code), `ZC_CD_FMONFILE`, `ZC_CD_FMONPRQWA` (files and PRISM requests handled manually: FMON objects without company code, no findings). **Counts:** a row that counts findings is a slice per company code (EBS runs and KPI `ZI_CD_EbsRunSlice`, HCK checks `ZI_CD_HckCheckSlice`, runs `ZI_CD_HckRunSlice`, KPI `ZI_CD_HckOpenSlice`, categories, the framework's control review `ZI_CA_OpsCtlSlice`): run and verdict telemetry on the area-level slice only, the findings of a company code on its own slice - the DCL on the slice is a filter on the findings before the analytical list or card sums (`$apply` after the DCL's WHERE). The run header's finding count of every company code (`ZCA_OPS_RUN-FINDING_COUNT`, `ZCD_HCK_RESULT-FINDING_COUNT`) is no longer exposed (EBS / HCK as-of, HCK check, analytics run cube). Navigations from a slice to findings read the target entity with its own DCL.

**Write side:** exceptions app actions and the control review sign-off with the object's company code (framework, `ZCL_CA_OPS_EXC_POLICY=>MAY_ACT`); suppressions: create (validation on save), end and approve of a suppression of a company code need `ZCA_OPS` 02 / 85 for `CD_HCK` with that `BUKRS` (`ZCL_CD_HCK_SUPPRESSION=>CHECK_COMPANY_CODE`, message 840); a suppression of a company code now also matches the findings of that company code (their `BUKRS`), not only object keys that contain it. **Alerts:** rule pattern `BUKRS_PATTERN` (`config/alert_seed.md`). **Morning report e-mail** (`ALERT_MORNING`) is a central report to one SO23 list with the exceptions of every company code - area-level by design (decision D-CC4).

## Daily control review (2026-11-10)

Reviewers sign off the suite's controls in the framework app `ZUI_CA_OPS_REV` with `ZCA_OPS` **02** for the control's area (`CD_FMON`, `CD_EBS`, `CD_HCK`, and `CD_COLL` for *Base-rejected items* since 2026-11-10) - the activity decision is the framework's (`ops-framework/docs/auth_zca_ops.md` §2). Since the company-code isolation a row is a slice (control, date, company code; blank = area-level) and the sign-off of a company-code slice needs 02 with that `BUKRS`. Proposed role `ZCD_OPS_REVIEWER`: ZCA_PARAR = the control areas (`CD_FMON`, `CD_EBS`, `CD_HCK`, `CD_COLL`), ACTVT 02 + 03, BUKRS *; because sign-off and exception handling share activity 02 (framework decision), `CD_COLL` 02 also lets a reviewer assign, resolve, request a waiver for and classify `CD_COLL` exceptions - as it already does for the other three areas (02 stays shared, no separate sign-off activity - user decision 2026-11-10); display of the review list needs 03 only. The overview cards of the control center are read with 03 (DCL `ZC_CD_OPSOVERVIEW`; payment lifecycle and payments additionally by company code). The control register itself (owners, cut-offs, covered checks) is configuration of area `CA_OPS` in `ZUI_CA_OPS_CFG` (01 / 02 / 06, DV1, transport; existing rows editable in production through the configuration gate).
