# Adding a business process — end to end, Fiori to backend (ZCA_OPS process onboarding)

> **First principle:** a new monitored business flow is configuration plus at most one small check class; everything around the check (run, lock, store, exceptions, alerts, daily review, dashboard, freshness, purge, authorisation) is the framework's and is never written again.
> **Analogy:** plugging a new appliance into a fitted kitchen — the socket, fuse, meter and smoke alarm are already in the wall; you bring the appliance and label the switch.

Status 2026-11-10: written and statically checked offline (abaplint 0 issues, house checks, tool tests); **nothing
activated, no ABAP Unit run** (`docs/VERIFY.md` V46-V54). Install order and the one-off setup:
`docs/INSTALL.md` §6a.

## 0. What a process is and where it shows up

A **business process** is one monitored flow (e.g. a request lifecycle, a payment run, an interface). It lives in
one **area** (a parameter area of ZCA_PARAM: authorisation value `ZCA_PARAR`, run area, alert area) and has one or
more **checks**. A check finds objects that break a rule and returns **findings**; B / E / W findings become owned
exceptions with an SLA due date.

```
 Fiori (OData V4)                         Backend (ZCA_OPS)                                 Data
 ─────────────────                         ─────────────────                                 ────
 ZUI_CA_OPS_CFG  configuration ─────────▶ ZCA_OPS_PROC / _CHECK / _AGG / _TABWL,            customizing (C),
   processes, checks, aggregates,          ZCA_OPS_CONTROL / _CTLT / _CTLCHK, _ALRULE, _PURGE   by transport
   approved tables, controls, rules
                                           job ZCA_OPS_CHECK_RUN (area, schedule group)
                                             └ ZCL_CA_OPS_CHECK_RUNNER ── ZIF_CA_OPS_CHECK ──▶ business tables
                                                 │  ZCL_CA_OPS_CHK_AGG (no code) or           (read only,
                                                 │  your class + its data access class         aggregated on
                                                 ▼                                             the database)
 ZUI_CA_OPS_EXC  exceptions ◀───────────  store ZCA_OPS_RUN / ZCA_OPS_FINDING (GROUP1 = process, GROUP2 = check)
 ZUI_CA_OPS_REV  daily review ◀─────────  control status derived from the findings (CDS)
 ZUI_CA_OPS_DASH area dashboard ◀───────  last run, status, open exceptions, stale flag per check (CDS)
 e-mail / SLG1   alerts ◀───────────────  alert router: rules of the area (GROUP1_PATTERN = process)
                                           ZCA_OPS_RETENTION: findings purged with their runs (+ own tables)
                                           ZCL_CA_OPS_CHK_ONBOARD: every morning, is each process complete?
```

| Piece | Delivered by | What you add |
|---|---|---|
| Run, lock, abort, run header first, test mode | `ZCL_CA_OPS_CHECK_RUNNER`, report `ZCA_OPS_CHECK_RUN` | one job per area and schedule group |
| Check | `ZCL_CA_OPS_CHK_AGG` (no code) | aggregate rows - or one class implementing `ZIF_CA_OPS_CHECK` |
| Findings, exceptions, SLA, carry-forward, auto-resolve | store `ZCL_CA_OPS_STORE`, app `ZUI_CA_OPS_EXC` | SLA parameters of the area (optional) |
| Alert routing | `ZCL_CA_OPS_ALERT_ROUTER`, `ZCA_OPS_ALRULE` | one rule: area of the process, `GROUP1_PATTERN` = process ID |
| Daily review | `ZUI_CA_OPS_REV` (status derived from the findings) | a control (or an existing one) with one covered-check row per check (`GROUP2` = check ID) |
| Area dashboard and freshness | `ZUI_CA_OPS_DASH` (`ZR_CA_OpsCheckStatus`) | `CHECK_STALE_MIN_<area>` (optional; default 1500 minutes) |
| Purge | `ZCA_OPS_RETENTION` (findings with their runs, target RUN) | a purge target only when the process writes own tables |
| Authorisation | object `ZCA_OPS`, DCLs with the company-code rule | a role with `ZCA_PARAR` = the area |
| Completeness | offline check `process_onboarding`; `ZCL_CA_OPS_CHK_ONBOARD` every morning | nothing |
| Runbook, escalation, correlation, downtime (2026-11-11) | `ZCA_OPS_RUNBOOK`, `ZCA_OPS_ALRULE-ESC_*`, `ZCA_OPS_CORR`, downtime app `ZUI_CA_OPS_DTW` (`docs/OPERATIONS_FEATURES.md`) | optional: one runbook row per check (`GROUP2` = check ID; inactive until the link is known), `ESC_AFTER_MIN` on the process's rule, a correlation rule when one cause raises many findings |

## 1. Decide before you build

| Question | Rule |
|---|---|
| Which **area**? | A process gets **its own area** when its runs would otherwise be the latest run of another engine's area (a consumer's self-check reads the last run of an area). The area is a parameter area (≤ 16 characters, e.g. `ZXX_PAY`), created when the process is activated. |
| **Process ID**, **check IDs** | ≤ 20 characters, upper case. The check ID is GROUP2 of every finding - the key of controls, alert patterns and the dashboard; never rename it. |
| **No-code aggregate or class?** | Aggregate when the rule is *rows of one approved table in a status (+ one more condition), counted or aged in days from a date field, per company code*. A class when it needs a join or anti-join (A without B), the latest row per object, times in hours, amounts, or several tables. |
| **Schedule group** | One run per area and group (run variant): e.g. `DAILY` before the review cut-off, `HOURLY` for a flow with an SLA in hours. |
| **Company code** | When the business object has one, the check is company-code aware: the aggregate row names the company-code field, a class fills `COMPANY_CODE` of every finding. Findings are then read, counted and changed per company code (`docs/auth_zca_ops.md` §3c). |
| **Own tables?** | Normally none: findings are the evidence. A process that writes own tables registers a purge target (`OWN_DATA` = X). |
| **Fields not confirmed?** | Never guess table or field names: write placeholders (‹status table›) and deliver every row **inactive**; the offline check refuses an active row with a placeholder or a VERIFY marker. |

## 2. Scaffold the configuration (offline, 2 minutes)

`tools/abaptools/new_process.py` (repository tools, not imported into SAP) writes every row a process needs into the
seed files of a component folder (`config/*.csv`, the columns of the tables), the process document
`docs/processes/<AREA>_<PROCESS>.md` (owner team, checks, apps, job, parameters, VERIFY list) and, on request, a check
class skeleton with its test class. Rows are appended once - run it again after the specification grew.

```sh
# from the repository root - simple case on the command line
python3 tools/abaptools/new_process.py --root <component> --area ZXX_PAY --process PAY_LIFE \
    --name "Payment lifecycle" --role Z_XX_PAY_OPERATOR --owner-team "Payment operations" \
    --agg "PAY_PENDING:COUNT:ZXX_REQUEST:STATUS:EQ:PENDING" --class "PAY_REFUND:ZCL_XX_C_REFUND" --dry-run

# full case: a specification file (JSON), kept next to the seed files
python3 tools/abaptools/new_process.py --root <component> --spec <component>/config/processes/<AREA>_<PROCESS>.json
```

| Specification key | Becomes |
|---|---|
| `area`, `process`, `name`, `owner_team`, `auth_role`, `own_data`, `purge_target` | `config/process_register.csv` (`ZCA_OPS_PROC`; OWNER / BACKUP blank: no person in a repository) |
| `checks[].id`, `description`, `bukrs_aware`, `class` or `aggregates[]`, `schedule_group` | `config/check_registry.csv` (`ZCA_OPS_CHECK`; aggregates: class `ZCL_CA_OPS_CHK_AGG`) |
| `checks[].aggregates[]` (`table`, `func`, `date_field`, `min_age_days`, `bukrs_field`, `status_*`, `cond_*`, `amber`, `red`, `check_code`) | `config/check_aggregates.csv` (`ZCA_OPS_AGG`) and `config/approved_tables.csv` (`ZCA_OPS_TABWL`) |
| `control` (`area`, `id`, `create`) | a new control in `control_register.csv` + `control_guidance.csv`, or an existing one; always `control_checks.csv` (`GROUP2` = check ID) |
| `alert_rule` (`id`, `min_severity`, `destination`) | `config/alert_rules.csv` (`ZCA_OPS_ALRULE`: area, `GROUP1_PATTERN` = process) |
| `purge_class`, `purge_param` | `config/purge_targets.csv` (only with own tables) |
| `new_area` | `config/param_areas.csv` - only for an active process (an inactive delivered area would be reported every morning by a consumer's parameter check); otherwise named in the document |
| `checks[].skeleton`, `skeleton_dir` | `zcl_..._c_....clas.abap` + `.clas.testclasses.abap` implementing `ZIF_CA_OPS_CHECK` |
| `verify` | the VERIFY list of the document |
| `active: false` | every row inactive (placeholders allowed) |

Then run the component's house checks: `process_onboarding` fails until the process has checks, a control covering
each check, an alert rule of its area, an owner (or an `Owner team:` line in its document), purge coverage and a role
named in the component's authorisation sheet, and no active row carries a placeholder.

## 3. Backend: the check

### 3a. No code: aggregate rows (`ZCA_OPS_AGG`)

One row = one database aggregate over an approved table (`ZCA_OPS_TABWL`, area + table; plus `S_TABU_NAM` 03 of the
running user). Every field name is checked against the runtime DDIC of the table on save (messages 082 / 083) and at
run time; literals are quoted, operators come from a fixed list - nothing of the row reaches SQL unchecked.

| Field | Meaning |
|---|---|
| `AGG_FUNC` | `COUNT` = rows matching; `AGE` = days since the oldest `DATE_FIELD` of the rows matching |
| `DATE_FIELD`, `MIN_AGE_DAYS` | only rows with a filled date at least that many days old (never a future date) |
| `BUKRS_FIELD` | one result and one finding per company code (`COMPANY_CODE` of the finding); required when the check is company-code aware (103) |
| `STATUS_FIELD` / `STATUS_OP` (EQ, NE, IN) / `STATUS_VALUE` | the status the rows are in; IN takes a comma list |
| `COND_FIELD` / `COND_OP` (EQ NE GT LT GE LE IN) / `COND_VALUE` | one more condition |
| `AMBER`, `RED` | value ≥ RED: error (owned exception); ≥ AMBER: warning; below: nothing (the runner resolves the earlier exception) |
| `CHECK_CODE` | the check code of the findings (default `AGG_COUNT` / `AGG_AGE`) |

A row that cannot be measured is an `AGG_CONFIG_INVALID` finding and makes the check partial (its earlier exceptions
stay open); the other rows are still measured. A check without an active row raises 092 (`CHECK_FAILED`).

**Performance:** the database aggregates (`COUNT(*)` / `MIN`, `GROUP BY` the company-code field, at most 10 000
groups); no row is transferred. The approved table needs an index that starts with the status field (and the
company-code field) - VERIFY-SE11 per table (V48).

### 3b. One class: `ZIF_CA_OPS_CHECK`

```abap
INTERFACE zif_ca_ops_check PUBLIC.
  METHODS run IMPORTING is_check         TYPE zif_ca_ops_chk_types=>ty_check     " registry row
                        is_context       TYPE zif_ca_ops_chk_types=>ty_context   " run ID, test mode, today, now
              RETURNING VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result    " findings, items, partial
              RAISING   zcx_ca_ops_error.
ENDINTERFACE.
```

Rules for the class (house style of `ZCA_OPS` and of its consumers):

- **Read only**, and only through the process's own data access class (all SQL there, explicit field lists, one
  set-based read - a join / anti-join or aggregate on the database, no SELECT in a loop, `FOR ALL ENTRIES` only after
  a driver check); the class itself has no SQL. A confirmed table or field only; anything else is a VERIFY-SE11
  placeholder and the row stays inactive.
- One finding per object that breaks the rule: `OBJECT_KEY` (with `CHECK_CODE` and `COMPANY_CODE` the identity of
  the exception - keep it stable), `CHECK_CODE`, `SEVERITY`, `COMPANY_CODE`, `MESSAGE` from the consumer's message
  class (`ZCL_CA_OPS_UTIL=>MESSAGE_TEXT`), `BUSINESS_DATE` / `ITEM_COUNT` / `CONTEXT` where known; never amounts in
  `CONTEXT`. Leave `GROUP1` / `GROUP2` blank: the runner stamps process and check.
- `PARTIAL` = X when the check read less than all (a cap reached, an object it could not evaluate): its earlier
  exceptions then stay open. Raise `ZCX_CA_OPS_ERROR` (or the consumer's subclass) for a configuration or read error:
  the runner records one `CHECK_FAILED` finding and runs the next check.
- Never commit, alert, persist or write a business table. Test with a data access double (ABAP Unit, `RISK LEVEL
  HARMLESS DURATION SHORT`) and the data access class with `cl_osql_test_environment`.

The scaffold's skeleton compiles and has its test class; it reads nothing until the data access class is written.

## 4. Configuration in DV1 (Fiori, customizing request, then transport)

| # | App | Rows |
|---|---|---|
| 1 | Parameter app `ZUI_CA_PARAM_O4` | the area (when new); `SLA_DAYS_<area>_E` / `_W` (optional), `CHECK_STALE_MIN_<area>` (optional) |
| 2 | `ZUI_CA_OPS_CFG` → *Approved tables* | the tables of the aggregate rows (reviewer in `APPROVED_BY`) |
| 3 | `ZUI_CA_OPS_CFG` → *Business processes* | the process: owner and backup (users, checked), runbook link, role, own tables, purge target |
| 4 | `ZUI_CA_OPS_CFG` → *Registered checks* | one row per check: class (checked: implements `ZIF_CA_OPS_CHECK`), schedule group, company-code aware |
| 5 | `ZUI_CA_OPS_CFG` → *Aggregate checks (no code)* | the aggregate rows (table and fields checked against the DDIC) |
| 6 | `ZUI_CA_OPS_CFG` → *Controls*, *Guidance*, *Covered checks* | a control (or an existing one) and one covered-check row per check: `CHECK_AREA` = area, `MATCH_FIELD` = `GROUP2`, `MATCH_VALUE` = check ID |
| 7 | `ZUI_CA_OPS_CFG` → *Alert rules* | the rule: area, `GROUP1_PATTERN` = process ID, minimum severity, SO23 list, digest, throttle (`docs/ALERT_TEMPLATES.md` for the e-mail) |
| 8 | `ZUI_CA_OPS_CFG` → *Purge targets* | only for own tables (`README.md`, *How a consumer uses it*, step 6) |

New rows only in DV1 by transport; production may switch a row off (`ACTIVE`), never create one.

## 5. Authorisation

A role per audience with `ZCA_OPS`, `ZCA_PARAR` = the area: display 03 (exceptions app, review, dashboard - the DCLs
apply area AND (blank company code OR area + company code)), operator 02 (assign, resolve, classify, sign off), approver
85, job user 16 (`ZCA_OPS_CHECK_RUN`). Name the role in `AUTH_ROLE` of the process and in the consumer's authorisation
sheet (the offline check looks for it there). `docs/auth_zca_ops.md`.

## 6. Run

Schedule `ZCA_OPS_CHECK_RUN` with `P_AREA` = the area, `P_GROUP` = the schedule group, test mode off, one job per
group, before the review cut-off of the control. First run in test mode (nothing written, no alert; the findings in a
list, message 102). A second start while one runs is refused (RUN_LOCKED); a failed check is `CHECK_FAILED`; no
active check of the group is `CHECKS_NOT_REGISTERED` (error).

## 7. Where the process shows up (Fiori)

| App | What |
|---|---|
| `ZUI_CA_OPS_EXC` | the exceptions of the process: filter area, GROUP1 = process, GROUP2 = check; assign, resolve, waive, classify |
| `ZUI_CA_OPS_REV` | the control and its status per business date and company code, sign-off |
| `ZUI_CA_OPS_DASH` | *Checks by area*: per check and company code the last run, run RAG, status (worst open exception), open exceptions, **stale** when no run completed or the last is older than `CHECK_STALE_MIN_<area>` (else `CHECK_STALE_MIN_DEFAULT`) minutes. **Overview cards** (2026-11-10): a consumer that exposes `ZC_CA_OpsCheckStatus` in its overview service gets the KPI card *Business processes* (data points `ProcessChecks`, `ChecksFlagged`, `ChecksStale`, `OpenExceptions`) and the list card *Process checks - attention* (variants `Attention`) without new CDS - a new process appears on them once its checks are active |
| E-mail | the alert rule of the process (template of the rule / channel / default) |
| Consumer overview pages | select from `ZR_CA_OpsCheckStatus` and `ZR_CA_OpsCtlReview` (cards) |

## 8. Completeness - offline and every morning

| When | Check | Reports |
|---|---|---|
| Every change (offline) | `python3 tools/checks.py` of the component - check `process_onboarding` (`tools/abaptools/onboarding.py`) | a process without check, control coverage, alert rule, owner, purge or role; a check of an unknown process or class; an aggregate on a table not approved; an active row with a placeholder or VERIFY marker |
| Every morning (runtime) | `ZCL_CA_OPS_CHK_ONBOARD` (registry row `CA_OPS` / `ONBOARDING`, or a consumer's daily report through its adapter) | `PROC_NO_CHECK` (E), `PROC_NO_CONTROL`, `PROC_NO_ALERT_RULE`, `PROC_NO_OWNER`, `PROC_NO_PURGE`, `PROC_NO_AUTH` (W) per active process; a closed gap is resolved by the next run |

## 9. Checklist

- [ ] Area, process ID, check IDs decided (own area; IDs stable)
- [ ] Specification written, scaffold run, document completed (owner team, VERIFY list)
- [ ] Aggregate rows or one check class + data access class + tests (OSQL, doubles)
- [ ] Tables / fields confirmed in SE11 - or rows inactive with placeholders
- [ ] Index of every approved table (status field first)
- [ ] Role and authorisation sheet; job user 16
- [ ] DV1 rows in `ZUI_CA_OPS_CFG` and the parameter app; transport
- [ ] Job `ZCA_OPS_CHECK_RUN` per schedule group; test mode run first
- [ ] Offline `process_onboarding` green; next morning no onboarding finding

## 10. Worked example — a collections request lifecycle with a card refund (fictitious)

The example is fictitious: a consumer with prefix `XX` receives collection requests from a source system
`PORTAL` through a middleware. Its own documents give the meaning of every table and status (a known-tables
document, a control seed); the framework only provides the mechanism. A real consumer writes the same kind of
specification with its own names.

**The flow.** `PENDING` = future-dated request waiting for its request date → on the request date the account
validation runs → `SCHEDULED` (SAP sends it to `PORTAL`) → `PORTAL` answers `ACCEPTED` (SAP continues: the payment
run collects) **or rejects**. For a **card payment** the money is collected by a card payment provider before SAP
gets the request, so a reject must end in a **refund** that SAP calls at that provider.

**What is not confirmed (VERIFY-SE11).** The table and field of the request status and their values (incl. the
reject value), the date fields, the company-code field, where the source's answer is logged, and the table of the
refund call with its success value. Therefore **every row below is delivered inactive with placeholders**; nothing
reads a business table until these questions are answered.

| Check | Rule | Kind | Row (placeholders in ‹ ›) |
|---|---|---|---|
| `COLL_R1_PENDING` | a `PENDING` request past its request date (validation did not move it) | aggregate R1 | AGE of ‹request date field›, `MIN_AGE_DAYS` 1, ‹status field› EQ `PENDING`, per ‹company code field›, ‹amber› / ‹red› days |
| `COLL_R2_SCHEDULED` | `SCHEDULED` with no answer of the source | class `ZCL_XX_COLL_C_NO_ANSWER` | hours since ‹status change time stamp› of requests whose latest status is `SCHEDULED`, amber / red in hours (limits in hours belong to a check class, §11) |
| `COLL_R3_REFUND` | source-rejected card request **without a successful refund** - the control's main check | class `ZCL_XX_COLL_C_REFUND` | one anti-join in its data access class: requests with ‹reject value› whose ‹refund log› has no row with ‹success value›; findings `REFUND_MISSING` (E) per request, `REFUND_FAILED` (E) for a failed call, company code on the finding |
| `COLL_R4_ACCEPTED` | `ACCEPTED` not collected on the request date | aggregate R4 | COUNT, ‹status field› EQ `ACCEPTED`, ‹request date field› at least 1 day old, ‹amber› / ‹red› |

**Specification** (the consumer's `config/processes/XX_COLL_PORTAL_REQ_LIFE.json`, excerpt):

```json
{ "area": "XX_COLL", "process": "PORTAL_REQ_LIFE", "name": "Collections request lifecycle (portal)",
  "auth_role": "Z_XX_OPS_COLL", "schedule_group": "DAILY", "active": false,
  "control": {"area": "XX_COLL", "id": "PORTAL_REJECTS", "create": false},
  "alert_rule": {"id": "COLL_LIFE", "min_severity": "E", "destination": "‹SO23 list - confirm›"},
  "checks": [
    {"id": "COLL_R1_PENDING", "bukrs_aware": true,
     "aggregates": [{"id": "R1", "table": "‹status table›", "func": "AGE", "date_field": "‹request date field›",
                     "min_age_days": 1, "bukrs_field": "‹company code field›", "status_field": "‹status field›",
                     "status_op": "EQ", "status_value": "PENDING", "amber": "‹amber days›", "red": "‹red days›"}]},
    {"id": "COLL_R3_REFUND", "bukrs_aware": true, "class": "ZCL_XX_COLL_C_REFUND", "skeleton": true,
     "skeleton_dir": "docs/processes/XX_COLL_PORTAL_REQ_LIFE_skeleton"} ] }
```

**What the scaffold writes** (consumer folder, all inactive): the process `XX_COLL` / `PORTAL_REQ_LIFE` (role
`Z_XX_OPS_COLL`, findings only - no purge target), four registered checks (schedule group `DAILY`, company-code
aware), three aggregate rows and the approved ‹status table›, four covered-check rows of the existing control
`PORTAL_REJECTS` (`CHECK_AREA` = `XX_COLL`, `GROUP2`), the alert rule `COLL_LIFE` (`GROUP1_PATTERN` =
`PORTAL_REQ_LIFE`), the process document with its VERIFY list and the R3 skeleton outside the imported sources (no
confirmed table to read). Not delivered until activation: the area `XX_COLL` itself, the role, the SLA and freshness
parameters.

**R3 data access, once the tables are confirmed** (sketch - every ‹ › is a VERIFY-SE11 name):

```abap
" ZCL_XX_COLL_REFUND_DAO=>REJECTED_WITHOUT_REFUND - one anti-join on the database, read only
SELECT req~‹request key›, req~‹company code field›, req~‹status change date field›
  FROM ‹status table› AS req
  WHERE req~‹status field› = @‹reject value›
    AND req~‹status change date field› <= @lv_latest
    AND NOT EXISTS ( SELECT ‹request key› FROM ‹refund log› AS ref
                       WHERE ref~‹request key› = req~‹request key›
                         AND ref~‹refund status› = @‹success value› )
  ORDER BY req~‹request key›
  INTO TABLE @rt_rejects
  UP TO @iv_max ROWS.
```

**Activation** (after the answers): replace the placeholders in the specification, run the scaffold again (it adds
nothing that exists - edit the rows), write and test `ZCL_XX_COLL_C_REFUND` with its data access class, create the
area, role and parameters, set the rows and the control active, schedule `ZCA_OPS_CHECK_RUN` (`XX_COLL`, `DAILY`),
and confirm the next morning that the onboarding check reports nothing for `PORTAL_REQ_LIFE`.

## 11. Limits (by design)

- The no-code aggregate counts and ages in **days of a date field**, one table, two conditions; anything else is a
  class. Metrics with history, baselines (z-score / IQR) and sums stay with a consumer's own engine (the first
  consumer's health check keeps its richer aggregate for those).
- The runner runs checks of one area and group in sequence, synchronously; a check stops itself at a cap and reports
  partial. No retrigger, no posting, no outbound call: read-only towards business tables.
- Freshness is per area and schedule group (one run variant); a process that needs another threshold gets its own
  `CHECK_STALE_MIN_<area>` - or its own area.

## Related: a customer's payment model (2026-11-11)

A business process registers checks; the **payment model** gives the same customer a categorised, drillable view of
its payments and requests (persona overview pages, payment and request object pages, business-date trend) from a
mapping spec and the product templates - `docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md`. The two are independent: a
process's findings appear in the payment model's exception trend when its area is listed in the spec (`model.areas`).
