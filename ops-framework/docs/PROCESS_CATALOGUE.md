# Process catalogue with activation (ZCA_OPS)

> **First principle:** the product knows which SAP standard processes exist, how they run and how to watch them; a
> customer only says which of them it runs - and from when, why and approved by whom. Everything that monitors,
> shows or reviews a process follows that one switch.
> **Analogy:** the main breaker board of a building. Every circuit (process) is wired and labelled by the
> electrician (the product); the tenant flips the switches of the rooms it uses. A room that is switched off has no
> light on the floor plan (dashboard), no smoke alarm test on the checklist (daily review) and no meter reading
> (checks) - and the wiring stays in the wall for the day the room is used.

Status 2026-11-11: written and statically checked offline (abaplint 0 issues, house checks, tool tests, the
generated seed rows and documents current); **nothing activated, no ABAP Unit run** (`docs/VERIFY.md` V124-V129).
Install: `docs/INSTALL.md` §6d. Generated reference of every process: `docs/catalogue/catalogue.md`.

## 1. What the catalogue is - and what it is not

| Question | Answer |
|---|---|
| What does a catalogue process describe? | One SAP standard business process (payment run, dunning, G/L transfer, ...): its package, SAP component, steps (transactions, programs, mass activity types), standard tables (with their link registry object), the business owner **role**, the typical schedule, its dependencies on other processes, the dashboard card it feeds, and monitoring templates (checks, no-code aggregate rows) |
| What does activation decide? | Whether the customer runs the process, **effective from a date**, with a reason and an approver (four-eyes). Inactive = its checks do not run, its rows and cards do not show, its controls are not expected in the daily review |
| What is it not? | Not a runtime of the process (the framework never starts FPY1 or a dunning run), not a configuration of SAP FI-CA, not a place for customer data. Read-only towards business tables |
| Customer specifics? | Only in a customer layer (package of kind C) of the consumer: its own processes, its activation rows, the mapping of its existing business processes. The product packages name SAP standard objects only |

## 2. Layers (packages)

| Rank | Package | Kind | ID prefix | Monitoring area | Holds |
|---|---|---|---|---|---|
| 10 | `S4CORE` | S product baseline | `S4_` | `CA_S4CORE` | S/4HANA core processes every system has: background job processing (**active by default**, monitored by the framework's job monitor), electronic bank statement import and posting |
| 20 | `FICA` | I industry package | `FICA_` | `CA_FICA` | SAP FI-CA standard processes: payment run, payment lots and cash journal, returns lots, bank statement to payment lots, clearing / reset clearing, reversal, dunning, invoicing, interest, write-off, instalment plans, deferral, correspondence, G/L transfer and reconciliation keys |
| 30 | `FSCD` | I industry package | `FSCD_` | `CA_FSCD` | SAP FS-CD (insurance) standard processes on top of FI-CA: payment plans and debit entry, premium collection, broker reports, coinsurance, commission interface, claims disbursement through the standard claims interface, FS-RI integration |
| 100 | customer (e.g. `XX`) | C customer layer | `XX_` | - | the customer's own processes, its activation rows, the mapping of its business processes, its decision list |

A higher rank may depend on and switch a lower one, never the reverse (a product process never depends on a
customer process). Switching a package off (`ZCA_OPS_CATPKG-ACTIVE`) switches all its processes off, whatever their
rows say - e.g. a customer without insurance switches `FSCD` off.

The package and process IDs of the catalogue match the link registry's layers where they overlap (`S4CORE`, `FICA`):
a catalogue table names its link registry object (`ZCA_OPS_CATTAB-LINK_OBJECT`, e.g. `DPAYH` -> `FICA_PAYMENT_RUN`),
so the drill-down of a process starts from the right business object (`docs/LINK_REGISTRY.md`).

## 3. Model (tables, maintained in `ZUI_CA_OPS_CFG`, delivered by transport)

| Table | Key | Content | Checks on save |
|---|---|---|---|
| `ZCA_OPS_CATPKG` | package | kind S / I / C, rank, ID prefix, monitoring area, description, owner, active | kind (413), area (435) |
| `ZCA_OPS_CATPRC` | catalogue process | package, name, SAP component, dashboard card, business owner role, typical schedule, delivered default `DFLT_ACTIVE`, evidence C / V with the VERIFY item, sequence | evidence (413), VERIFY item required for V (235) |
| `ZCA_OPS_CATSTP` | process, step number | kind T transaction / P program / M mass activity type / J job / E event, SAP object, what it does, evidence | kind, evidence (413), VERIFY item (235) |
| `ZCA_OPS_CATTAB` | process, table | role H header / I item / L log / S status / C configuration, link registry object, meaning, evidence | a confirmed table exists in the runtime DDIC (082), role, evidence, VERIFY item |
| `ZCA_OPS_CATDEP` | process, predecessor | H hard (needs it active and run first) / S soft (uses its data) | kind (413) |
| `ZCA_OPS_CATACT` | process, effective-from date | active, customer package, reason, approver, approved on | reason, package and approver required (235); approver a user of the client **other than the user who saves** (240, four-eyes) |
| `ZCA_OPS_PROC` (existing) | area, business process | + `CAT_PROCESS`: the catalogue process this business process monitors | - |

Cross-row rules (ID prefix of the package, package known, dependency on a known process of the same or a lower
package, no dependency cycle, activation of a known process with reason and approver) are checked by
`ZCL_CA_OPS_CATALOG=>VALIDATE` (findings `CAT_INVALID` of the onboarding check, messages 247-253) and offline by
`tools/process_catalogue.py`.

**Relation to `ZCA_OPS_PROC` (reuse, not duplication).** The catalogue describes *what* a standard process is
(product knowledge, the same in every system). `ZCA_OPS_PROC` stays the customer's *monitoring onboarding* of a
process in an area: owner and backup users, runbook, role, purge - the things that are personal to a landscape. One
field ties them: `ZCA_OPS_PROC-CAT_PROCESS`. A catalogue process may be monitored by several business processes
(areas); a business process without `CAT_PROCESS` is not in the catalogue and behaves as before. The checks of a
catalogue process are the registered checks (`ZCA_OPS_CHECK`) of its business processes; the dashboard area it
feeds is their area.

## 4. Activation - the rule (one rule, three places)

On a day D (today for the dashboard, the runner and the review):

1. The package of the process is switched off or unknown -> **inactive** (source P).
2. Else the activation row of the process with the **latest effective-from date on or before D** decides (source A,
   with its reason and approver). A row of a later date is planned and does not count yet - this is how a go-live
   or a switch-off is prepared in advance.
3. Else the delivered default `DFLT_ACTIVE` (source D). Product processes are delivered **inactive**, except the
   baseline `S4_BATCH_JOBS` (every system runs background jobs; all its names confirmed). A product process with a
   VERIFY item is never active by default (offline check).

A business process of `ZCA_OPS_PROC` is **in effect** when its row is active and it names no catalogue process or
its catalogue process is active. A `CAT_PROCESS` that is not in the catalogue does **not** stop monitoring
(fail-open): the onboarding check reports it as an error (`CAT_REF_UNKNOWN`) - a typo must never switch monitoring
off silently.

The same rule lives in `ZCL_CA_OPS_CATALOG` (ABAP: runner, onboarding check, consumers, a test tool), in
`ZI_CA_OpsCatProcEff` / `ZI_CA_OpsProcEff` (CDS: dashboard, review, catalogue list) and in
`tools/process_catalogue.py` (offline: documents, proposal). The tests of each assert the same cases (default,
deciding row on its own date, package off, unknown).

## 5. What happens end to end when a process is switched off (or on)

```
 ZUI_CA_OPS_CFG  Process catalogue activation   (DV1, customizing request -> transport; approver = another user)
        |
        v
 ZCA_OPS_CATACT  row (process, effective from, active, reason, approver)
        |
        +--> ZCL_CA_OPS_CATALOG=>INACTIVE_ONBOARDED --> runner ZCA_OPS_CHECK_RUN: checks of the business processes
        |                                               not in effect are not run; one information finding
        |                                               PROCESS_INACTIVE per check (message 241); not reconciled
        |
        +--> ZI_CA_OpsCatProcEff -> ZI_CA_OpsProcEff -> ZI_CA_OpsChkEff --> area dashboard rows (ZR_CA_OpsCheckStatus)
        |                                                                --> active processes (ZR_CA_OpsProcStatus)
        |                                            -> ZI_CA_OpsChkProcOff -> ZI_CA_OpsCtlProcOff --> daily review
        |                                                                       (ZI_CA_OpsCtlSlice: no slice)
        +--> ZCL_CA_OPS_CHK_ONBOARD (every morning): gaps only of processes in effect; catalogue findings
```

| Where | Process active | Process switched off |
|---|---|---|
| Runner `ZCA_OPS_CHECK_RUN` | its checks run as before | its checks are **not run**; one information finding `PROCESS_INACTIVE` per check (GROUP1 / GROUP2 stamped; no alert by a rule with minimum severity W or E). Its open exceptions **stay open** - a switch-off is not a fix; an operator resolves or waives them |
| Area dashboard `ZUI_CA_OPS_DASH` - *Checks by area* | its checks shown (with catalogue process and dashboard card) | its checks **not shown** (the slices are built from `ZI_CA_OpsChkEff`) |
| Area dashboard - *Active business processes* (`ZC_CA_OpsProcStatus`) | one row per business process and company-code slice with **its own KPIs**: checks in effect, checks with open exceptions, stale checks, open exceptions, worst status, *active but not monitored*, and its catalogue information (component, card, owner role, schedule, active since, reason) | **no row** |
| Overview cards of a consumer | KPI card *Active business processes* (data points `ActiveProcesses`, `UnmonitoredProcesses`, `OpenExceptions`) and list card *Business processes - attention* on `ZC_CA_OpsProcStatus`; the check-level card *Business processes* on `ZC_CA_OpsCheckStatus` counts only checks in effect | not counted |
| Daily review `ZUI_CA_OPS_REV` | its controls expected as before | a control whose **every** covered check (GROUP2 row) is a check switched off by its process is **not expected** (no slice). A control with one check in effect, or a RULE_ID / CHECK_CODE row, stays expected |
| Onboarding check (every morning) | gaps checked (check, control, alert rule, owner, purge, role); `CAT_NO_CHECK` (W) when no check in effect monitors it; `CAT_DEP_INACTIVE` (W) when a hard predecessor is not active | no gap of it is expected; `CHECK_PROC_INACTIVE` (W) for each of its checks still active - switch the check off too, or the process on |
| Catalogue list `ZC_CA_OpsCatalogue` (`ZUI_CA_OPS_DASH`) | Active today, decided by (A / D / P), effective from, reason, approver, checks in effect | inactive, the same columns |
| Exceptions app, alerting, purge | unchanged | unchanged (existing exceptions remain workable) |

A process switched **on** reverses each line from the next run / the next read of the app: nothing is migrated.

## 6. Standard content of the product (SAP standard only)

`docs/catalogue/catalogue.md` (generated) lists every process with its steps, tables, dependencies and monitoring
checks. Summary: 23 processes (42 steps, 48 tables, 7 dependencies) - S4CORE 2, FICA 14, FSCD 7; 22 carry at least one VERIFY item and are delivered
inactive; `S4_BATCH_JOBS` is the only one active by default. VERIFY items: **V127** program / transaction / mass
activity names, **V128** tables and fields, **V129** monitoring conditions, values and limits. Every monitoring row
of the product (`config/catalogue/monitoring`, 27 checks, 26 aggregate rows) is delivered **inactive**; a name that
is not known yet is a placeholder in angle quotes.

Names treated as confirmed (evidence C) are the ones confirmed in a reference landscape or stable SAP standard:
`FPY1`, `RFKK_MA_SCHEDULER`, `FP05`, `FPCJ`, `FP07`, `FP08`, `FP09`, `FP04`, `FPR1`, `FPVA`, `FPVB`, `FPG1`,
`FPCOPARA`, `FF_5`, `RFEBKA00`, `FEBAN`, `SM37`; tables `DPAYH`, `DPAYP`, `DFKKOP`, `DFKKKO`, `DFKKCR`, `TFK042Z`,
`DFKKZK`, `DFKKZP`, `DFKKRH`, `DFKKRP`, `FKKMAKO`, `FKKMAZE`, `DFKKSUMC`, `FEBKO`, `FEBEP`, `TBTCO`, `TBTCP`. Every
field used in a monitoring condition is a VERIFY item until checked in SE11 of the target system (S/4HANA 2023).

### Generic risk checks

| Check | Process | How | Configure before activation |
|---|---|---|---|
| `FICA_WO_LIMIT` - write-offs above a limit | `FICA_WRITEOFF` | no-code aggregate: `DFKKOP` items cleared with the write-off clearing reason in the **last day** (`MAX_AGE_DAYS` 1, new window of the aggregate rows) with the local-currency amount above the limit, per company code | the write-off clearing reason value, the limit (V129) |
| `FICA_WO_REASON` - write-offs outside the reason list | `FICA_WRITEOFF` | no-code aggregate: the same items whose write-off reason is **none of** the approved list (operator `NI`, new) | the approved reasons (V129) |
| `FICA_GL_OUTAGE` - accounting around a planned downtime | `FICA_GL_TRANSFER` | class `ZCL_CA_OPS_CHK_OUTAGE`: for every **approved planned downtime window** of the area (`ZIF_CA_OPS_DOWNTIME`) that ended within `CAT_OUTAGE_DAYS`, each of its aggregate rows is measured in the window - `OUT_POST`: documents entered inside the window (date **and time**, new `TIME_FIELD`); `OUT_GLKEY`: reconciliation keys of the window's days plus `CAT_OUTAGE_MARGIN_DAYS` not transferred to the G/L. Findings per window, rule and company code; the check is always partial - an operator closes the exception after the accounting was confirmed | the window's time zone against the entry time of the documents, the key status table (V128, V129); a downtime window entered in the check's area |

## 7. How a customer activates, deactivates or adds a process

**Activate a standard process** (e.g. dunning from 1 March):
1. Business decision recorded (owner role of the process, reason) - the consumer's decision list.
2. DV1, `ZUI_CA_OPS_CFG` -> *Process catalogue activation*: new row `FICA_DUNNING`, effective from `20270301`,
   active, the customer package, reason; **approver** = the business approver's user (not the user who saves; 240).
   Transport. Production may only switch a row (configuration of the client policy), never create one.
3. Monitoring: close the VERIFY items of its monitoring rows, then switch on its business process and checks of
   `config/catalogue/monitoring` (area `CA_FICA`, or copy them into the customer's own area with `CAT_PROCESS` set),
   the control and the alert rule; create the area in ZCA_PARAM and the role (`docs/ADDING_A_BUSINESS_PROCESS.md`).
4. From the effective date: the runner runs its checks, the dashboard shows it, the review expects its control; the
   next morning the onboarding check reports nothing (`CAT_NO_CHECK` while no check is in effect).

**Deactivate** (e.g. dunning stops on 1 July): a new row `FICA_DUNNING`, effective from `20270701`, **not active**,
reason, approver. The history stays (the earlier row is kept); from 1 July the checks are skipped, the rows vanish
from the dashboard and the control from the review. Open exceptions stay open until resolved or waived.

**Add an own process**: in the customer layer (`config/catalogue/` of the consumer, prefix of its package), with
steps, tables, dependencies; set `CAT_PROCESS` of its business process; regenerate (`tools/process_catalogue.py`).

**Switch a whole package off**: `ZCA_OPS_CATPKG-ACTIVE` blank (e.g. `FSCD` for a customer without insurance).

Offline, before every transport: `python3 tools/process_catalogue.py --check` in the framework and in the consumer.

## 8. A test tool reads the same catalogue

User decision: one shared process catalogue. A test tool reads it through its own catalogue-source adapter (e.g. an
implementation of its `ZIF_CA_TT_CATALOG_SOURCE` over `ZIF_CA_OPS_CATALOG`); nothing of the test tool is in this
framework.

| Test tool asks | Catalogue answers (`ZIF_CA_OPS_CATALOG`) |
|---|---|
| process with its effective activation | `DEFINITION( process, today )-PROCESS` + `-STATE-ACTIVE` (package off / unknown -> inactive) |
| process package | `-PACKAGE` (kind S / I / C maps to the tool's layer standard / industry / customer) |
| steps of the process | `-STEPS` in step order: kind T -> transaction step, P / J -> job / program step, M -> mass activity (program `RFKK_MA_SCHEDULER` with the activity type), E -> no executable step |
| prerequisite between steps | the previous step of the same process; between processes `-DEPENDENCIES` (hard = prerequisite) |
| tables to check after a step | `-TABLES` (with the link registry object for a drill-down) |
| line of business | `-PROCESS-COMPONENT` (FI-CA, FS-CD, ...) |

Process IDs are CHAR 20 in both. A step with evidence V (VERIFY) is offered inactive by the adapter.

## 9. Worked example - customer XX (fictitious)

`config/catalogue/examples/xx_layer.json` (validated with the product packages by the house check, never seeded):

| Row | Meaning |
|---|---|
| package `XX`, kind C, rank 100, prefix `XX_` | the customer layer |
| process `XX_REQ_LIFE` - payment request lifecycle (portal) | an own process: request intake (placeholder, VERIFY), paid by `FPY1`; depends (hard) on `FICA_PAYRUN` |
| activation `FICA_PAYRUN` from `20270101` active | go-live of the payment run |
| activation `FICA_DUNNING` from `20270101` not active | XX does not dun - stays off (documented decision) |
| activation `FICA_INVOICING` from `20270701` active | invoicing from the second release - planned in advance |

State: on 2026-12-31 only `S4_BATCH_JOBS` and `XX_REQ_LIFE` are active; on 2027-01-01 the payment run joins; on
2027-07-01 invoicing. XX maps its business process `XX_PAY / REQ_LIFE` to `XX_REQ_LIFE` (`CAT_PROCESS`) and its
payment run checks to `FICA_PAYRUN`; until 1 January the runner skips the payment run checks with an information
finding, the dashboard shows only the job and request processes.

## 10. Authorisation (decision)

- **Maintaining** packages, processes and activation rows: `ZCA_OPS` with `ZCA_PARAR` = `CA_OPS` and 01 / 02 / 06 in
  the configuration app, DV1 only (client policy of the app), transported - like every configuration row.
- **Approval of an activation**: the approver is recorded in the row and must be **another existing user** than the
  one who saves it (message 240, checked on save). **No activity 85** for activation changes - decision: activation
  is configuration that travels by transport through the change process (CAB); 85 stays for decisions taken in
  production (waivers, downtime approval). The onboarding check reports an activation row without approver (253).
- **Reading**: the catalogue list `ZC_CA_OpsCatalogue` needs `ZCA_OPS` 03 for `CA_OPS` (product configuration, no
  business data); the active-process rows `ZC_CA_OpsProcStatus` follow the area dashboard rule (area AND company
  code of the slice, `docs/auth_zca_ops.md` §3c).

## 11. Limits (by design)

- Activation is per client (one customer per system); there is no per-company-code activation - a process some
  company codes do not use is active and its checks are company-code aware.
- The catalogue does not discover processes in the system (no scan of job logs or mass activity runs): activation is
  a decision, documented and approved.
- The dashboard and the review read today's activation (`$session.system_date`); a past day of the review shows the
  controls expected today.
- The outage check compares the window's entered date and time with the documents' entry date and time as stored;
  both must be in the same time zone (V129).

## Related

`docs/ADDING_A_BUSINESS_PROCESS.md` (onboarding a business process, `CAT_PROCESS`), `docs/LINK_REGISTRY.md` (business
objects of the tables), `docs/OPERATIONS_FEATURES.md` (planned downtime), `docs/JOB_MONITORING.md` (the monitor of
`S4_BATCH_JOBS`), `docs/catalogue/catalogue.md` (generated reference).
