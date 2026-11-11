# Authorisation object ZCA_OPS — definition sheet (SU20 / SU21 / roles)

> **First principle:** one object guards every operations action of every consumer, so a role says in one place who may run, change or approve in which area.
> **Analogy:** one keycard system for the whole building — the card says which floors (areas) and which doors (activities), not a different key per room.

The object is part of the operations framework (`config/authorizations.json`, serialized to `src/zca_ops.suso.xml`). Its object class `ZCA` and its area field `ZCA_PARAR` belong to the parameter framework ZCA_PARAM (`param-framework/config/authorizations.json`) — install ZCA_PARAM first. Code checks it only through `ZCL_CA_OPS_AUTH` (`ZIF_CA_OPS_AUTH`, factory `ZCL_CA_OPS_FACTORY=>GET_AUTH`); CDS read access through `pfcg_auth( ZCA_OPS, … )` in a DCL. It replaced the first consumer's own object and area field (user decision 2026-11-10: one authorisation object).

## 1. Authorisation fields (SU20)

| Field | Data element | Owner | Values |
|---|---|---|---|
| `ZCA_PARAR` | `ZCA_PARAM_AREA_ID` (CHAR 16) | parameter framework ZCA_PARAM | an area of `ZCA_PARAM_AREA` (one area register: the area of a run, finding, alert rule, lock and configuration app is a parameter area); `CA_OPS` = the framework's own objects (alerting, purge targets, retention purge) |
| `ACTVT` | `ACTIV_AUTH` | SAP | see §2 |
| `BUKRS` | `BUKRS` | SAP | company code of an object that has one; area-wide checks pass `DUMMY` |

## 2. Authorisation object (SU21)

| Object | Class | Fields | Text |
|---|---|---|---|
| `ZCA_OPS` | `ZCA` | `ZCA_PARAR`, `ACTVT`, `BUKRS` | Operations framework: runs, findings, alerts per area |

Permitted activities (SU21 → Activities) — the same activities the first consumer used on its former object:

| ACTVT | Meaning | Framework entry points |
|---|---|---|
| 01 | Create a configuration row (DV1 only, transport); plan a downtime window (2026-11-11) | configuration apps (create of a child row; editing the singleton); downtime app `ZUI_CA_OPS_DTW` (area of the window, checked on save - 152) |
| 02 | Change (configuration row; assign / resolve / classify an exception; sign off a control; change or *End now* a downtime window) | configuration apps, exceptions app `ZUI_CA_OPS_EXC`, daily control review `ZUI_CA_OPS_REV` (action *Mark reviewed*), downtime app (change a window awaiting approval, action *End now*) |
| 03 | Display | every app and DCL, ALV reports; the downtime app, the response-time metrics `ZUI_CA_OPS_MET` and the shift handover `ZUI_CA_OPS_HOVR` (2026-11-11) |
| 06 | Delete a configuration row (DV1 only, transport); delete a downtime window awaiting approval | configuration apps; downtime app |
| 16 | Execute | `ZCA_OPS_RETENTION` (area `CA_OPS`); `ZCA_OPS_CHECK_RUN` (the area of the run - the generic runner of the check registry, process onboarding 2026-11-10); `ZCA_OPS_ESCALATE` (the area escalated, escalation until acknowledged 2026-11-11); a consumer's batch programs (its area) |
| 85 | Approve (second person) | waiver approval in the exceptions app; approval of a planned downtime window in the downtime app (2026-11-11, never by its planner) |

Configuration apps (generated, `tools/rap_generate.py` - the framework's app; a consumer's apps by its own wrapper of the same shared generator): each activity is checked on its own per child entity and the area of the app — 01 create, 02 change, 06 delete; editing the singleton needs at least one of them. The framework's app `ZUI_CA_OPS_CFG` (alert rules, alert channels, purge targets) checks area `CA_OPS`.

**Operations response features - activities (2026-11-11, `docs/OPERATIONS_FEATURES.md`).** No new activity and no
new field: a downtime window is planned with 01, changed / deleted (while awaiting approval) with 02 / 06, ended early
with 02 and approved with **85** by a second user - the same four-eyes activity as the waiver approval, because both
are "a second person lets an exception go unalerted / unworked"; the planner is refused by the behaviour pool (147),
whatever his roles. A landscape that wants the downtime approver separate from the waiver approver gives the two
roles different areas or adds a customer activity (as for the sign-off below) - documented as the alternative, not
built. The escalation job needs 16 for the area it escalates; runbook links and correlation rules are rows of
`ZUI_CA_OPS_CFG` (01 / 02 / 06 for `CA_OPS`, DV1 only). The metrics and the handover are read-only (03, DCL).

**Daily control review - activity of the sign-off (decision 2026-11-10).** The sign-off uses the existing change
activity **02** of the control's area, not a new activity: the reviewer is the operator who already works the
area's exceptions with 02, so no SU21 change and no new role field are needed; a display role (03) sees the
review but cannot sign off. A landscape that wants sign-off separated from exception handling adds an activity
(e.g. a customer activity in TACT) to the object and changes `ZBP_R_CA_OPSCTLREVIEW` - documented here as the
alternative, not built. **Confirmed by the user 2026-11-10:** 02 stays shared between sign-off and exception handling;
no separate sign-off activity.

## 3. Roles (PFCG) — proposal

| Role | ZCA_PARAR | ACTVT | BUKRS |
|---|---|---|---|
| `Z_CA_OPS_DISPLAY` | * | 03 | * |
| `Z_CA_OPS_BATCH` (job user) | `CA_OPS` + the consumer areas it runs | 16 | * |
| `Z_CA_OPS_CONFIG` (configuration owner of the framework) | `CA_OPS` | 01, 02, 03, 06 | * |
| `Z_CA_OPS_DOWNTIME_PLANNER` (2026-11-11: plans downtime windows of an area) | the area | 01, 02, 03, 06 | * |
| `Z_CA_OPS_DOWNTIME_APPROVER` (2026-11-11: approves them - never the planner) | the area | 03, 85 | * |

**SAP job monitor (2026-11-11).** The job user of `ZCA_OPS_CHECK_RUN` for the monitor's area also needs `S_BTCH_JOB`
JOBACTION `PROT` (display job log), JOBGROUP `*` - read only; the monitor never releases, cancels, changes or restarts
a job, so no other batch authorisation (VERIFY V64, `docs/JOB_MONITORING.md` §10).

A consumer adds its own roles with its areas (in its own authorisation sheet; the demo consumer: area `CA_DEMO`, `docs/INSTALL.md`). Segregation of duties: the operator (02) and the approver (85) of an area are different users; the exceptions app also refuses an approval by the requester (four-eyes).

## 3a. Read access (DCL)

| Projection (service) | DCL | Condition |
|---|---|---|
| `ZC_CA_OpsException` (`ZUI_CA_OPS_EXC`) | `ZC_CA_OPSEXCEPTION` | the company-code rule of §3c on `Area`, `CompanyCode` (company code of the finding) |
| `ZC_CA_OpsExcHist` (same service) | `ZC_CA_OPSEXCEPTION` | the rule of §3c on the exception (path `_Exception.Area`, `_Exception.CompanyCode`) |
| `ZC_CA_OpsCtlReview` (`ZUI_CA_OPS_REV`) | `ZC_CA_OPSCTLREVIEW` | the rule of §3c on `Area` (of the control) and `CompanyCode` (of the slice) |
| `ZC_CA_OpsCheckStatus` (`ZUI_CA_OPS_DASH`, area dashboard, 2026-11-10) | `ZC_CA_OPSCHECKSTATUS` | the rule of §3c on `Area` (of the check) and `CompanyCode` (of the slice: blank = area-level row with run and freshness, else the open exceptions of that company code) |
| `ZC_CA_OpsJobFailure` and its facet views `ZC_CA_OpsJobStep`, `_Msg`, `_Alog`, `_Bo` (`ZUI_CA_OPS_JOBS`, SAP job failures board, 2026-11-11) | `ZC_CA_OPSJOBFAILURE` | the rule of §3c on `Area` (of the monitor run that kept the job) and `CompanyCode` (of an enricher's business object; blank = area-level) |
| `ZC_CA_OpsDowntime` (`ZUI_CA_OPS_DTW`, planned downtime, 2026-11-11) | `ZC_CA_OPSDOWNTIME` | `Area` authorised (03) - a window is area-level, it has no company code; the findings it marks keep their own company code and rule |
| `ZC_CA_OpsExcMetric` (`ZUI_CA_OPS_MET`, response-time metrics, 2026-11-11) | `ZC_CA_OPSEXCMETRIC` | the rule of §3c on `Area` and `CompanyCode` of the exception episode (the company code is a dimension, so a sum or average after the filter never mixes company codes) |
| `ZC_CA_OpsHandover` (`ZUI_CA_OPS_HOVR`, shift handover, 2026-11-11) | `ZC_CA_OPSHANDOVER` | the rule of §3c on `Area` and `CompanyCode` of the row (exceptions, escalations, control slices per company code; downtime area-level) |

VERIFY-ADT: `pfcg_auth` on a projection view and on a path to the parent (7.58) - V04, V36, V51, V76, V78.

**Correlated exceptions (2026-11-11).** The company code is part of every correlation key, so a parent and its
children always share the company code: the exceptions app's facets *Correlated exceptions* / *Parent exception*
show rows of `ZC_CA_OpsException` under its own DCL, and the open-children count (`ZI_CA_OpsCorrCount`) is a count
of one company code (`docs/OPERATIONS_FEATURES.md` §4).

**Business processes (process onboarding, 2026-11-10).** A registered process (`ZCA_OPS_PROC`) names in `AUTH_ROLE` the PFCG role that grants `ZCA_OPS` for its area (03 display, 02 operator, 16 for the job user of `ZCA_OPS_CHECK_RUN`); the onboarding check reports a process without a role or whose area is not an active parameter area (`PROC_NO_AUTH`), and the offline check `process_onboarding` requires the role in the consumer's authorisation sheet. A process gets its own area when its runs would otherwise be the latest run of another engine's area.

## 3c. Company-code isolation (2026-11-10)

> **First principle:** a finding of a company code is read, counted and changed only by users authorised for that company code; a finding without one belongs to the area.
> **Analogy:** a shared mailroom with locked pigeonholes per company - the noticeboard (area-level notices) is for everyone of the department, a pigeonhole opens only with its own key.

**Data.** `ZCA_OPS_FINDING-BUKRS` (data element `BUKRS`): the company code of the finding, **blank = not company-specific** (an area-level finding: a run, a file, a job, a configuration problem). The producer fills `TY_FINDING-COMPANY_CODE` where it knows the company code at finding time (no extra read); `ZCL_CA_OPS_STORE` stores it. The exception history `ZCA_OPS_EXC_HIST` keeps the exception key (run, finding number) and **no copy** of the company code - its DCL reads it through the path `_Exception.CompanyCode`. The company code is **part of the identity of an exception**: the carry-forward inherits owner, waiver, reason code and due date only from an earlier exception with the same object type, object key, check code **and company code** (two findings that differ only in the company code are two exceptions; an object key need not contain the company code).

**Read rule (every DCL on findings, history, slices and counts built on them):**

```
( Area ) = aspect pfcg_auth( ZCA_OPS, ZCA_PARAR, ACTVT = '03' )
and ( CompanyCode is initial
   or ( Area, CompanyCode ) = aspect pfcg_auth( ZCA_OPS, ZCA_PARAR, BUKRS, ACTVT = '03' ) )
```

Area authorised AND ( company code blank OR ( area, company code ) authorised ). **Area-level rows (blank company code) are visible with the area authorisation** - the rule, not a switch (approved by the user 2026-11-10, decision D-CC1 of the consumer suite). A switch is not cheap: a DCL cannot read a parameter, so "area-level rows only for users with every company code" would be a second variant of every role (`BUKRS = '*'` as fixed value of the first condition - VERIFY-ADT that a fixed `'*'` requires full authorisation) - **a decision for the owner of the roles**, not built.

**Counts and aggregates.** A DCL on an aggregating view entity filters the **result rows** of that view, after its GROUP BY; the DCLs of the views underneath are not evaluated when a view reads them (access control applies to the entity the ABAP SQL / OData request names), and `inheriting conditions from entity` copies the conditions onto the elements of the reading view - also after its aggregation. So a count that mixes company codes in one row cannot be protected by any DCL. The framework and its consumers therefore never aggregate across company codes in one row: **the company code is a key of every row that carries a count of findings** - a finding row has its own company code; an aggregate is a **slice** per company code (the daily control review: `ZI_CA_OpsCtlSlice`, one row per control, business date and company code; blank = the area-level slice that always exists). A DCL on the slice's own company code is a filter on the findings before a card or an analytical list sums the slices (OData `$apply` aggregates after the DCL's WHERE). Run telemetry that has no company code (run status, RAG, runtime, item counters of `ZCA_OPS_RUN`, the evidence run of a control) is area-level and sits on the area-level slice only, so a sum over the slices counts it once.

**Write rule.** Every action on an exception (assign, resolve, request / approve waiver, classify) and the sign-off of a control slice is authorised with the company code of the object: `ZCL_CA_OPS_EXC_POLICY=>MAY_ACT` - `ZCA_OPS` with the activity for the area (BUKRS `DUMMY`) and, for a company code, for the area with `BUKRS` = that company code (instance authorisation of `ZBP_R_CA_OPSEXCEPTION` and `ZBP_R_CA_OPSCTLREVIEW`). A user of company code 1000 can neither change nor approve nor sign off an object of 2000; area-level objects need the area authorisation only.

**Alerts.** An alert rule (`ZCA_OPS_ALRULE`) has the pattern `BUKRS_PATTERN` (PCRE on the company code of the finding, complete value, blank = any; checked on save like the other patterns). A rule whose list serves one company code names it (`1000`); findings of another company code never reach that list, and area-level findings reach it only when the pattern accepts blank (`1000|`). A rule without a company-code pattern sends every company code's findings of its area to its list - use it only for lists that may see them all. Run-level triggers (RAG, abort) carry no findings and are area-level.

| Object | Read (DCL) | Write |
|---|---|---|
| Exceptions app `ZC_CA_OpsException` / `ZC_CA_OpsExcHist` | rule above (history: path to the exception) | `MAY_ACT` with the exception's company code (02; 85 to approve a waiver) |
| Daily control review `ZC_CA_OpsCtlReview` (slice per company code) | rule above on the slice's company code | `MAY_ACT` with the slice's company code (02) |
| Alert e-mail | - | rule pattern `BUKRS_PATTERN` |

Tests: `ZCL_CA_OPS_EXC_POLICY` (`ltc_isolation`: own company code allowed, other refused, area-level with the area, other area refused, activity counts), `ZCL_CA_OPS_STORE` (`stores_company_code`, `carry_other_company_separate`), `ZCL_CA_OPS_ALERT_POLICY` (`bukrs_pattern_keeps_list`), `ZCL_CA_OPS_REVIEW_DAO` (`slices_are_separate`), `ZCL_CA_OPS_CTL_CDS_TEST` (`ltc_slice`, `ltc_day`), `ZCL_CA_OPS_DCL_TEST` (access-control double: user A of one company code). VERIFY V35-V43.

## 3b. Checks offline

A consumer's offline check may read §1 and §2 of this sheet and fail when an `AUTHORITY-CHECK` on `ZCA_OPS` (`zif_ca_ops_auth=>gc_object`) or a `pfcg_auth( ZCA_OPS, … )` in the framework or the consumer names a field the sheet does not define (the first consumer has such a check, `auth_fields_defined`). A wrong field name makes every kernel check fail (sy-subrc 12) and every DCL deny.

**S_DATASET.** `ZCL_CA_OPS_FILE_PATH=>PHYSICAL` resolves application server files only through a logical path of transaction FILE named by the consumer and checks `S_DATASET` (`AUTHORITY_CHECK_DATASET`, READ / WRITE). **S_TABU_NAM.** `ZIF_CA_OPS_AUTH=>MAY_READ_TABLE` checks display (03) of every table a consumer reads by a configured name.
