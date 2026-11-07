# Payment Engine Health Check & Morning Report

| | |
|---|---|
| **Payment engine area** | HCK — Health Check (operations suite) |
| **Program** | `ZCD_MORNING_REPORT` |
| **Landscape** | S/4HANA 2023, SAP_BASIS 7.58 — DV1 → QA1 → PS4 |
| **Status** | Built and lint-clean offline; **not yet activated or executed in an SAP system** |
| **Version** | 2026-11-05 — initial version (ops suite consolidation) |

---

# Part 1 — Business & Operations

## 1. What the morning report is

> **First principle:** before the first payment run of the day, someone must know — with evidence — whether yesterday's money movements completed and whether today's can start safely.
>
> **Analogy:** a pilot's pre-flight checklist: a fixed list, each item green or not, and nobody takes off on "probably fine".

The morning report is a daily scorecard of the **payment engine**. It runs a configured list of health checks, compares each measured value with its limits and with its own history, and produces:

- a **health score 0–100** and an overall **RAG** (red / amber / green);
- a **RAG per category** (A–E, below);
- the status of the other monitoring payment engine areas (bank statement validation **EBS**, file monitoring **FMON**, and the health check itself) — the "health of the health check";
- the list of **checks** with a one-line summary each, drill-down to the individual findings;
- the **oldest open exceptions** across all payment engine areas with their owner, due date and age.

It is sent by e-mail (mobile-friendly HTML) to the morning distribution list and is available in SAP (`ZCD_MORNING_REPORT`) with drill-down. Every red or amber finding becomes an **owned exception** with a due date in the shared exception store; nothing is "just a log line".

| Category | Business question | Examples |
|---|---|---|
| **A — Financial integrity** | Did the money and the books stay consistent? | Return debits older than 10 days per company code; reconciliation keys that never reached the general ledger |
| **B — Mass-run and job health** | Did the batch runs complete, on time, at normal speed? | Job duration vs its own history; error rate in the application log; payment-engine volumes per day; job cycles (payment request → wire/ACH/check → ACK → GL) |
| **C — Exception queues** | Is anything waiting too long for a human? | Owned exceptions past their due date; postprocessing backlog |
| **D — Configuration drift** | Did productive settings change outside a transport? | Hash of key customizing tables vs the approved baseline |
| **E — Technical health** | Is the platform under the payment engine healthy? | Cancelled / long-running / late jobs, short dumps, update errors, old locks, failed alert deliveries |

## 2. How to read the scorecard (RAG and score)

> **First principle:** a colour must always mean the same action, whoever reads it.
>
> **Analogy:** traffic lights — nobody negotiates what red means at a crossing.

| RAG | Meaning | Expected action |
|---|---|---|
| **GREEN** | Every measured value within its limits and its normal range | None — glance only |
| **AMBER** | A warning limit was reached, the value is unusual against its own history (baseline outlier), or a check ran longer than its time budget | Look today; decide whether it is timing or a real issue |
| **RED** | An error limit was reached, a check failed to run, a critical job step failed / was missed / is stuck | Act now; follow the triage playbook below and escalate if SLA-bound |
| **N/A (grey)** | Nothing was measured (category without active checks) | Ask whether the category should be monitored |

**Health score.** Each check scores 100 (green), 50 (amber) or 0 (red / not executed), weighted by priority (High 3, Medium 2, Low 1). Score ≥ 90 → GREEN, ≥ 70 → AMBER, below → RED. Two safety rules stop an average from hiding a failure: **any red High-priority check makes the whole day RED**, and **any red check makes the day at least AMBER**. Red checks are counted as *critical*, amber checks as *high*.

**Baseline outlier.** For volumes and durations, a fixed limit is not enough (month-end is busier than mid-month). The check compares today's value with its last runs (z-score or inter-quartile range): far outside the usual range → AMBER, even if no fixed limit was crossed.

## 3. Triage playbook per category

> **First principle:** check the effect, not the job status — a green job that posted nothing is still a problem.
>
> **Analogy:** a doctor reads the symptom first, then orders the test that confirms the cause — not every test for every patient.

| Finding (check code) | First look | Typical cause | Next step / escalation |
|---|---|---|---|
| **A** `THRESHOLD_*` on `RET_AGED` | Drill-down → company code with the count | Returns lot not processed, return reason not mapped, clarification backlog | Collections team: process returns (FP09 / clarification); confirm the returns file was fully loaded (FMON) |
| **A** `GL_TRANSFER_GAP` | Reconciliation key in the finding | Key not closed / transfer job not run / transfer error | Run or rerun the GL transfer for the key; check job `ZPOST_GL*` in the RECON_EOD cycle; Finance if month-end |
| **A** `PAYMENT_NOT_CLEARED` (`A_INFLIGHT`) | Flow + method class (e.g. `DWIR`, `DACH`, `DCHQ`, `CACH`, `CCRD`) and the oldest payments in the finding detail (payment document, method, run date, date it is aged from, age, amount) | No evidence of any purpose yet: wire / ACH - the bank statement line is missing (statement not loaded, reference not in CHECT); an unmapped monetary code is `BTC_ROLE_MISSING`, not this finding; collections - G/L line not cleared (F.13 not run / not matched); Stripe - payout not processed or F.13 not cleared; cheque - not cashed for > 60 / > 90 days | Disbursement ops (flow D) / collections team (flow C): payment trace (`ZCD_OPS_PAYMENT_TRACE`), FEBAN, DFKKCR, FP09; Treasury when the bank has not reported it. The suite clears nothing (`Operations_Runbook.md` §5k) |
| **A** `CLEARING_INCONSISTENT` / `RETURN_INCONSISTENT` (E) | Flow + class; per payment the purpose and which evidence held, is missing or must not hold (or the anomaly of the evidence) | Evidence disagrees: statement line but DPAYH status not CLEARED (or the reverse); cheque B without line, line while blank / V; G/L line cleared without payout log row; payout processed but descriptor not set; assignment changed; returns lot missing / extra / without return line / amount differs | Payment engine support with disbursement ops / collections: FEBEP (FEBAN), DPAYH-ZZ_PAYMENT_STATUS, DFKKCR, DFKKRP (FP09), BSEG (FB03), Stripe payout log (`Operations_Runbook.md` §5l) |
| **A** `CHEQUE_CLARIFICATION` / `MANUAL_CLEARING_REQUIRED` / `CHEQUE_AMOUNT_MISMATCH` (E) | `DCHQ`; cheque number, register state, codes with dates | Several 581 / 255 for one cheque; a bank correction (399 / 699) and the cheque not yet cleared in the register; 581 amount differs from the payment amount | Disbursement ops / payment engine support: clarification worklist, FPCHR (manual clearing), FEBAN (`Operations_Runbook.md` §5l) |
| **A** `UNEXPECTED_SEQUENCE` / `PENDING_OUTCOME_MISSING` (E / per outcome) | Flow + class; codes with dates / pending outcome and its age | The bank code sequence of the payment matches no configured outcome; a redeposit (or other pending outcome) had no follow-up within its maximum age | Treasury / collections: confirm the sequence with the bank; add an outcome row by transport when it is legitimate (`Operations_Runbook.md` §5l) |
| **A** `CLEARING_RULE_INVALID` (E) / `VALUE_DATE_MISSING` / `INFLIGHT_CONFIG` (I / W) | Evidence class and parameter / count of payments / missing calendar, class or rule | A rule row cannot be used (class, parameter, read) - its purposes are not judged; DPAYH value date empty; no calendar; a class without payment methods or CLEARED rule; an evidence kind not configured (Stripe settings) | Payment engine support: fix the row in the HCK configuration app by transport (`Operations_Runbook.md` §5k) |
| **B** `BASELINE_OUTLIER` on `DURATION_MIN` | Job name, mean vs today | Volume spike, lock waits, DB contention, wrong variant | Compare volumes (B_VOLUME); check locks (E_SYSTEM); if the job is SLA-bound escalate to Basis |
| **B** `THRESHOLD_*` on `ERR_RATE_PCT` | Log object / subobject | Master-data errors in a mass run, interface errors | SLG1 for object/subobject and date; fix data; rerun the affected interval |
| **B** volume `BASELINE_OUTLIER` / `THRESHOLD_RED` (low) | Source / LOB, day | Missing inbound file, PRISM hold, source outage | FMON file status; confirm with the source system; do **not** start payment runs on partial input |
| **B** `STEP_FAILED` / `STEP_MISSED` / `STEP_STUCK` / `STEP_BLOCKED` | Cycle / step, job name | Cancelled job, Control-M did not trigger, predecessor failed | Control-M runbook: map Control-M name → SAP job → program + variant; fix predecessor first; rerun; list every downstream step to rerun |
| **C** `THRESHOLD_*` on `OVERDUE` | Payment engine area with overdue items | Exceptions not worked, owner absent | Owner's lead reassigns; waive only with a reason (audited) |
| **C** PPO backlog | Business process | Postprocessing not worked | Responsible team works the PPO queue |
| **D** `PARAM_INVALID` | Area / parameter name, framework message | A parameter of `CD_OPS` / `CD_EBS` / `CD_FMON` / `CD_HCK` that ZCA_PARAM refuses (invalid value or default, unknown name, mandatory value missing, two rows for a single value, area missing / inactive); the run used the code default meanwhile | `Operations_Runbook.md` §5f: correct the value in the app *Parameter areas* (or the definition by transport); SLG1 object ZCD_OPS / PARAM shows when the runs met it |
| **D** `CONFIG_DRIFT` | Table name, baseline taker | Direct change in production, transport not baselined | Find the change (table change logs / transport); if approved, take a new baseline; if not, revert and raise a security incident |
| **D** `CONFIG_NO_BASELINE` | Table name | New table under control | Take the baseline after the next approved transport |
| **E** `JOB_CANCELLED` / `JOB_LATE_START` / `JOB_LONG_RUNNING` | Job name / count | Cancelled step, missing Control-M trigger, runaway job | SM37 job log; Basis if system-related |
| **E** `SHORT_DUMPS` / `UPDATE_ERRORS` / `LOCK_MAX_AGE_MIN` | Count / age | Program error, failed update task, orphan lock | ST22 / SM13 / SM12; Basis; never delete a lock held by an active payment run |
| **E** `ALERT_FAILED` | Channel | Mail server down or application log not written | Alerts are not reaching people — treat as RED for operations |
| **E** `NR_USAGE_HIGH` (`E_NUMRANGE`) | Object, interval (subobject / number / year), usage %, numbers left | A number range object is running out; at 100 % postings of that object stop with a number range error | Payment engine support + Basis: look in SNRO (interval status); plan a new interval or year by transport **before** red; never reset NRLEVEL (`Operations_Runbook.md` §5i) |
| **E** `NR_NO_INTERVAL` / `NR_NOT_NUMERIC` (W) | Object / interval | Object name wrong in PARAM1, only external intervals, no interval for this / next year (create it before 1 January), alphanumeric limits | Correct PARAM1 or create the interval in DV1 (transport); external intervals are not measured |
| **E** `QUEUE_ERROR` / `QUEUE_HOLD` / `QUEUE_STUCK` (`E_QUEUES`) | Source (QOUT / QIN / BGRF), queue, destination, state, entries, oldest age and the transaction in the finding | SYSFAIL / CPICERR: receiver error or connection down; STOP: queue stopped (often deliberately during a release); READY / RUNNING too long: scheduler not running, receiver slow | Basis / middleware support: SMQ1 (outbound), SMQ2 (inbound), SBGRFCMON (bgRFC) - read the error text there; restart / unlock only after the cause is known and by the owning team, never from the suite (`Operations_Runbook.md` §5j) |
| **E** `QUEUE_CONFIG_INVALID` / `QUEUE_NOT_MONITORED` | Source and message | A delivered qRFC field name does not exist (VERIFY-DDIC), the bgRFC table is not whitelisted or not configured | Developer: correct the delivered name or PARAM4; until then the source measures nothing (never zero) |
| `TECH_READ_CAPPED` / `LIMITS_NOT_CONFIGURED` (W) | Parameter or metric named in the message | A read reached `HCK_MAX_TECH_ROWS` / `HCK_INFLIGHT_MAX_ROWS`; no `ZCD_HCK_THRESH` row for a metric the check classifies by | Raise the cap after a QA1 runtime check / maintain the threshold row by transport; until then the result may be incomplete or not judged |
| `HCK_SELF` `PE_AREA_STALE` | Payment engine area | Monitoring job (EBS, FMON or HCK) did not run | Restart the monitoring job; until then, nobody is watching that area |
| `PLUGIN_ERROR` / `AGG_CONFIG_INVALID` | Message text | Configuration error (unknown field, table not whitelisted) or program error | Fix the customizing row; the rest of the report is still valid |
| `TIMEOUT_OVERRUN` | Runtime vs budget | Check too slow for the volume | Performance review of the check (index, narrower window) |

Many "failures" are timing: if a behaviour is working as designed, record it as a *scheduling / configuration alignment opportunity*, not a defect.

## 4. Daily routine

> **First principle:** a report nobody owns is noise.
>
> **Analogy:** the morning stand-up of a ward — one list, one owner per bed, decisions recorded.

1. The scheduled run (native SAP job in SM36 running `ZCD_MORNING_REPORT` with the productive variant) finishes before the first business payment cycle; the e-mail reaches the RTB distribution list.
2. The RTB analyst on duty reads the scorecard, works RED first, then AMBER, using §3.
3. Every RED/AMBER finding is already an owned exception (payment engine area HCK) with a due date; assign the owner the same morning.
4. Persistent false positives are a **threshold change** (customizing, §13) — never "ignore the colour".

---

# Part 2 — Technical

## 5. Architecture and class model

> **First principle:** checks measure, the engine judges — one place decides what is red, so every check is judged by the same rules.
>
> **Analogy:** laboratory analysers produce numbers; the reference ranges printed on the report come from one table, not from each machine.

Layering (development standards §3): interfaces → domain (pure rules, no SQL) → DAO (all SQL) → application (engine) → presentation (report, CDS).

```mermaid
classDiagram
  direction LR
  class ZCD_MORNING_REPORT {
    <<program>>
    selection screen
    SALV + top of list
    CSV export, baseline action
  }
  class ZCL_CD_HCK_ENGINE {
    +run(is_selection) ty_report
    +take_baseline(iv_test_mode) i
    -execute_check() timeout guard, PLUGIN_ERROR
    -evaluate_metrics()
    -pe_area_status() health of health
  }
  class ZIF_CD_HCK_CHECK {
    <<interface>>
    +execute(is_def, it_thresholds, is_context) ty_check_result
  }
  class ZIF_CD_HCK_DAO {
    <<interface>>
    config, metric history, baselines
    TBTCO, BALHDR, SNAP, VBHDR, locks
  }
  class ZCL_CD_HCK_DAO
  class ZCL_CD_HCK_THRESHOLD {
    <<pure>>
    +resolve() '*' fallback
    +evaluate() static + baseline
  }
  class ZCL_CD_HCK_STATS {
    <<pure>>
    mean std_dev percentile z_score IQR
  }
  class ZCL_CD_HCK_SCORE {
    <<pure>>
    +summarize() score, RAG per category
  }
  class ZCL_CD_HCK_CYCLE_EVAL {
    <<pure>>
    +derive_state() +findings_for()
  }
  class ZCL_CD_HCK_AGG_QUERY {
    <<pure>>
    +build() whitelist, DDIC, quoting
    +to_metrics() +measure()
  }
  class ZCL_CD_HCK_REPORT_HTML {
    <<pure>>
    +render() +render_csv() +rag_chip()
  }
  class ZCL_CD_HCK_FACTORY
  class ZCL_CD_HCK_INJECTOR
  class ZCL_CD_OPS_FACTORY {
    <<core>>
    get_store get_alert get_clock get_plugin
  }
  class Checks {
    C_GENERIC_AGG, C_GL_TRANSFER
    C_JOB_RUNTIME, C_APPLOG, C_VOLUME, C_JOB_CYCLE
    C_OVERDUE_EXC, C_CONFIG_DRIFT
    C_TECH_JOBS, C_TECH_SYS, C_ALERT_HEALTH
  }
  ZCD_MORNING_REPORT --> ZCL_CD_HCK_ENGINE
  ZCD_MORNING_REPORT --> ZCL_CD_HCK_REPORT_HTML
  ZCL_CD_HCK_ENGINE --> ZCL_CD_OPS_FACTORY : store, alert, clock, plug-ins
  ZCL_CD_HCK_ENGINE --> ZCL_CD_HCK_FACTORY : DAO
  ZCL_CD_HCK_ENGINE --> ZIF_CD_HCK_CHECK
  ZCL_CD_HCK_ENGINE --> ZCL_CD_HCK_THRESHOLD
  ZCL_CD_HCK_ENGINE --> ZCL_CD_HCK_SCORE
  ZCL_CD_HCK_THRESHOLD --> ZCL_CD_HCK_STATS
  Checks ..|> ZIF_CD_HCK_CHECK
  Checks --> ZIF_CD_HCK_DAO
  Checks --> ZCL_CD_HCK_AGG_QUERY
  Checks --> ZCL_CD_HCK_CYCLE_EVAL
  ZCL_CD_HCK_DAO ..|> ZIF_CD_HCK_DAO
  ZCL_CD_HCK_FACTORY --> ZCL_CD_HCK_DAO
  ZCL_CD_HCK_INJECTOR --> ZCL_CD_HCK_FACTORY : test doubles
```

**Run sequence.**

```mermaid
sequenceDiagram
  participant R as ZCD_MORNING_REPORT
  participant E as ZCL_CD_HCK_ENGINE
  participant D as ZIF_CD_HCK_DAO
  participant C as Check plug-in
  participant S as Core store
  participant A as Core alert
  R->>E: run(selection)
  Note over E: run lock for the variant (not in test mode); held → refused run RUN_LOCKED, nothing else
  E->>S: start_run(HCK, test mode) + commit (not in test mode)
  E->>D: get_check_defs(categories, priorities, ids)
  loop each active check (SEQ)
    E->>C: execute(def, thresholds, context)
    C-->>E: metrics, findings, step states
    Note over E: timeout guard, PLUGIN_ERROR on any exception,<br/>thresholds + baseline per metric
    E->>S: save_findings + commit (not in test mode)
    E->>D: save_metrics, save_results - verdict of the check (not in test mode)
  end
  E->>S: get_last_run(EBS/FMON/HCK) -> HCK_SELF
  E->>D: save_results(SKIPPED rows of a filtered run) (not in test mode)
  E->>S: reconcile(executed check IDs without plugin error) (not in test mode)
  E->>D: get_open_exceptions(top N)
  E->>S: finish_run + commit (not in test mode: results durable first)
  E->>A: dispatch(run, findings) (not in test mode)
  E->>A: send(MORNING, HTML) if requested (not in test mode)
  E->>S: save ALERT_FAILED findings + finish_run + commit (only on a delivery failure)
  E-->>R: report (score, categories, results, pe_areas, exceptions)
  Note over E: run lock released (also on exception)
```

## 6. Tables

> **First principle:** configuration and evidence live in different tables — configuration is transported, evidence never is.
>
> **Analogy:** the recipe book travels between kitchens; the delivery notes stay in the kitchen that received the goods.

| Table | Class | Key | Purpose |
|---|---|---|---|
| `ZCD_HCK_DEF` | C | MANDT, CHECK_ID | Check catalog: category, class, active, SEQ, priority, PARAM1–4, package size, timeout |
| `ZCD_HCK_THRESH` | C | MANDT, CHECK_ID, METRIC, BUKRS | Amber/red limits, direction, baseline mode (NONE/ZSCORE/IQR), z limit / IQR k, lookback; `*` default rows |
| `ZCD_HCK_AGG` | C | MANDT, CHECK_ID, AGG_ID | Generic COUNT/SUM: table, date field + mode (AGE/DAY) + days, group field, 3 conditions |
| `ZCD_HCK_AGGGRP` | C | MANDT, CHECK_ID, AGG_ID, GROUP_VALUE | Expected group values of a grouped aggregate: a group without rows measures 0 (A103) |
| `ZCD_HCK_TABWL` | C | MANDT, TABNAME | Tables the generic aggregate may read (security boundary, with approver) |
| `ZCD_HCK_DRIFT` | C | MANDT, TABNAME | Tables under configuration-drift control |
| `ZCD_JOB_CYCLE` | C | MANDT, CYCLE_ID | Cycle header: text, factory calendar, active |
| `ZCD_JOB_STEP` | C | MANDT, CYCLE_ID, STEP_NO | Job name pattern (PCRE, §9a), program, variant, predecessor, day offset, start window, max runtime, skippable, critical |
| `ZCD_HCK_METRIC` | A | MANDT, RUN_ID, CHECK_ID, METRIC, DIM1, DIM2 | Metric history for baselines, trends, dashboard. Index `HST` (CHECK_ID, METRIC, DIM1, DIM2, MEASURED_AT), `TIM` (MEASURED_AT) |
| `ZCD_HCK_BASELINE` | A | MANDT, TABNAME | Golden baseline hash, row count, taken at / by (per system, never transported) |
| `ZCD_HCK_RESULT` | A | MANDT, RUN_ID, CHECK_ID | **Verdict of each check per run** (design review 2026-11-07), written by the engine from the decision the report uses: executed at, verdict (R / A / G, blank grey), check status (RED / AMBER / GREEN / WARMUP / GREY / FAILED / SKIPPED), completion (COMPLETE / PARTIAL - timeout, budget, capped read / FAILED - plug-in error / SKIPPED - outside the scope of a filtered run), evidence (ALL / PARTIAL / NONE), run scope (variant + selection ranges, message 300), metric / finding / error / warning counts, baseline mode used (NONE / ZSCORE / IQR / MIXED), warm-up, runtime, summary. The health dashboard reads it and never re-derives a status. Index `TIM` (EXECUTED_AT); purge target `HCK_RESULT` (ZCA_PARAM `RETENTION_DAYS_HCK_RESULT`, 400 days) |
| Core `ZCD_OPS_RUN` / `ZCD_OPS_FINDING` | A / A | — | Run header, findings / owned exceptions (read and written only through the core store; HCK DAO only *reads* findings for the exception queue) |
| Framework `ZCA_PARAM_AREA` / `_DEF` / `_VAL` | C | — | Parameters of areas `CD_HCK` / `CD_OPS` (read through `ZCL_CD_OPS_FACTORY=>GET_PARAMS`; the check `D_PARAM_INVALID` reads every definition of the four suite areas) |
| Core `ZCD_OPS_ALLOG` | A | — | Read by `E_ALERT_DELIVERY` (delivered by the core alert router) |

Every HCK finding: payment engine area `HCK`, `OBJECT_TYPE = 'CHECK'`, `GROUP1` = category, `GROUP2` = check id. Severity B/E/W → owned exception with SLA (`SLA_DAYS_HCK_<sev>`).

## 7. Check catalog

> **First principle:** a check is a measurement plus a list of itemised problems; whether it is red is configuration.
>
> **Analogy:** a thermometer does not decide you have a fever — the threshold on the chart does.

| Class | Cat. | Parameters | Metrics (DIM1 / DIM2) | Own findings |
|---|---|---|---|---|
| `ZCL_CD_HCK_C_GENERIC_AGG` | A, C (any) | rows in ZCD_HCK_AGG | `<AGG_ID>` per group value (e.g. company code) | `AGG_CONFIG_INVALID` per invalid row |
| `ZCL_CD_HCK_C_GL_TRANSFER` | A | P1 lag days (1), P2 window days (7), P3 max keys (500) | `GL_MISSING_KEYS` (*) | `GL_TRANSFER_GAP` per reconciliation key (E) |
| `ZCL_CD_HCK_C_JOB_RUNTIME` | B | P1 job patterns, P2 day offset (1) | `DURATION_MIN` (job / job count) | — (baseline per job via thresholds) |
| `ZCL_CD_HCK_C_APPLOG` | B | P1 log objects, P2 subobjects, P3 day offset (1) | `ERR_RATE_PCT`, `ERR_MESSAGES` (object/subobject / day) | — |
| `ZCL_CD_HCK_C_VOLUME` | B | P1 offset (1), P2 days (1); rows in ZCD_HCK_AGG, expected groups in ZCD_HCK_AGGGRP | `<AGG_ID>` per source/LOB / day; 0 for each silent expected group (A103) | `AGG_CONFIG_INVALID` (also a failed query — no metric, never 0) |
| `ZCL_CD_HCK_C_JOB_CYCLE` | B | P1 cycle date offset (0), P2 cycle ids | `STEPS_NOT_OK`, `STEPS_COMPLETED` (cycle / date) + step board | `STEP_MISSED/FAILED/STUCK/OVERRUN/BLOCKED` |
| `ZCL_CD_HCK_C_OVERDUE_EXC` | C | — | `OVERDUE`, `OLDEST_OVERDUE_DAYS` (payment engine area) | — |
| `ZCL_CD_HCK_C_CONFIG_DRIFT` | D | rows in ZCD_HCK_DRIFT | `DRIFTED_TABLES` (*) | `CONFIG_DRIFT` (E), `CONFIG_NO_BASELINE` (W) |
| `ZCL_CD_HCK_C_PARAM` | D | — (every definition of the four suite areas in ZCA_PARAM plus every delivered one) | `PARAM_INVALID` (*) | `PARAM_INVALID` (E), object key area/name |
| `ZCL_CD_HCK_C_TECH_JOBS` | E | P1 job patterns, P2 long-running min (120), P3 grace min (30) | `CANCELLED`, `LONG_RUNNING`, `LATE_START` (*) | `JOB_CANCELLED` (E), `JOB_LONG_RUNNING`, `JOB_LATE_START` (W) |
| `ZCL_CD_HCK_C_TECH_SYS` | E | — | `SHORT_DUMPS`, `UPDATE_ERRORS`, `LOCK_ENTRIES`, `LOCK_MAX_AGE_MIN` (*) | — |
| `ZCL_CD_HCK_C_ALERT_HEALTH` | E | P1 window hours (24) | `ALERT_FAILED`, `ALERT_THROTTLED` (channel) | — |
| `ZCL_CD_HCK_C_NUMRANGE` | E | P1 number range objects (exact SNRO names, comma list; required) | `NR_USED_PCT` (object/subobject/interval/year; level) | `NR_USAGE_HIGH` (W at amber, E at red), `NR_NO_INTERVAL`, `NR_NOT_NUMERIC`, `LIMITS_NOT_CONFIGURED`, `TECH_READ_CAPPED` (W) |
| `ZCL_CD_HCK_C_QUEUES` | E | P1 queue name PCRE list, P2 destination PCRE list (blank = all), P3 stuck minutes (30), P4 bgRFC source `TABLE=…;NAME=…;DEST=…;STATE=…;DATE=…;TIME=…`; `HCK_QUEUE_ERR_STATES` / `_HOLD_STATES` / `_WAIT_STATES` | `Q_ERROR`, `Q_HOLD`, `Q_STUCK` (entries), `Q_OLDEST_MIN` (level) per source `QOUT` / `QIN` / `BGRF` | `QUEUE_ERROR` (E), `QUEUE_HOLD`, `QUEUE_STUCK`, `QUEUE_CONFIG_INVALID` (W), `QUEUE_NOT_MONITORED` (I) |
| `ZCL_CD_HCK_C_INFLIGHT` | A | P1 factory calendar (fallback of class / house bank), P2 look-back days VALUE_DATE classes (10), P3 look-back days ISSUE_DATE classes (120), P4 payments listed (10); classes, rules, roles, outcomes, settings in the HCK configuration app (§7b) | `PAY_OPEN`, `AGE_OLDEST` (level), `OVER_WARN_CNT`, `OVER_CRIT_CNT`, `PAY_INCONSISTENT`, `PAY_UNDETERMINED` per flow + class (`DWIR` …); `PAY_EXCLUDED` (DIM2 purpose); `OVER_WARN_AMT`, `OVER_CRIT_AMT` (DIM2 currency) | `PAYMENT_NOT_CLEARED` (W / E), `CLEARING_INCONSISTENT`, `RETURN_INCONSISTENT`, `UNEXPECTED_SEQUENCE`, `PENDING_OUTCOME_MISSING`, `CLEARING_UNDETERMINED` (W), `BTC_ROLE_MISSING`, `CHEQUE_LINK_AMBIGUOUS`, `CHEQUE_REGISTER_MISSING`, `CHEQUE_CLARIFICATION`, `MANUAL_CLEARING_REQUIRED`, `CHEQUE_AMOUNT_MISMATCH` (E), `CLEARING_RULE_INVALID`, `VALUE_DATE_MISSING` (I), `INFLIGHT_CONFIG`, `LIMITS_NOT_CONFIGURED`, `TECH_READ_CAPPED` |
| built-in `HCK_SELF` | E | `HCK_WATCH_PE_AREAS`; stale threshold: `ZCD_OPS_MONCFG` row of the area (minutes, the same row as the dashboards), else `HCK_MAX_AGE_H_<pe_area>`, else `HCK_MAX_AGE_HOURS` (hours) | — | `PE_AREA_STALE` (E) |

Engine findings for every check: `THRESHOLD_RED` (E), `THRESHOLD_AMBER` (W), `BASELINE_OUTLIER` (W), `BASELINE_WARMUP` (I, A102), `TIMEOUT_OVERRUN` (W), `PLUGIN_ERROR` (E), `ALERT_FAILED` (W).

### 7a. Known-table checks (USAA reference)
| Check | Class | What it finds |
|---|---|---|
| `C_PRQ_NO_SPE` | `ZCL_CD_HCK_C_PRQ_SPE` | Payment requests that failed (and have no SUCCESS row) without a `ZCD_SPE_EXCP_LOG` row — the source is never told |
| `C_CHQ_STATUS` | `ZCL_CD_HCK_C_CHQ_STATUS` | Cheques whose status went backwards in `ZCD_CHECK_HIST` (ZECT_STATUS: 3 / 4 / 9 terminal, 10 → 9 allowed) |
| `C_PRQ_CANCEL` | `ZCL_CD_HCK_C_PRQ_CANCEL` | PCLM requests CANCELLED although their open item (FIN number = `DFKKOP-ZZ_FIN_TRANS_NUM`) is cleared |

Table and field names come from PARAM1–3 (`NAME=VALUE;…`, `config/hck_seed.md`), are checked against the DDIC and the whitelist, and every query is limited by its date field (`ZCL_CD_HCK_VALUE_QUERY`).

### 7b. Number ranges, queues, payments in flight (2026-11-07)

All three are read-only: they never change an interval, never restart, unlock or delete a queue entry, never post, clear or change a status. Their reads are in `ZCL_CD_HCK_RUNTIME_DAO` (factory `GET_RUNTIME_DAO`) and in the evidence plug-ins; bank lines, cheques, document headers, payment runs and returns come from the payment trace repository (`ZIF_CD_OPS_TRACE_DAO`, core factory) - one definition of each join path. Alerts: the existing rule `HCK_RED` (severity E of a red check, e-mail to the SO23 list) - no new channel, no application-log rule.

- **`E_NUMRANGE`** - NRIV intervals with `EXTERNIND` blank of the PARAM1 objects, not year-dependent (`TOYEAR` 0000) or valid this / next year. Usage = (NRLEVEL − FROMNUMBER) / (TONUMBER − FROMNUMBER) × 100, rounded to 2 decimals, level capped at TONUMBER; NRLEVEL below FROMNUMBER (initial) = 0 %. Limits and level are converted only when they are digits (PCRE constant `GC_PCRE_DIGITS`), else `NR_NOT_NUMERIC`. Limits: `ZCD_HCK_THRESH` `NR_USED_PCT` row `*` (DIM1 is longer than 4 characters), seed amber 85 / red 95. A configured object without interval is a warning - nothing measured is never green.
- **`E_QUEUES`** - sources `QOUT` (TRFCQOUT, SMQ1), `QIN` (TRFCQIN, SMQ2) with delivered field names (VERIFY-DDIC, constants `GC_TRFCQOUT` / `GC_TRFCQIN` of `ZIF_CD_HCK_RUNTIME_TYPES`) and, when PARAM4 names it, a bgRFC table (`BGRF`, SBGRFCMON; must be on `ZCD_HCK_TABWL`). Every name is checked against the runtime DDIC before the read (date field DATS, time field TIMS); a source that fails is `QUEUE_CONFIG_INVALID` and measures nothing. Entries are read grouped per queue / destination / state / day (oldest time of the day; a day group counts as stuck when its oldest entry passes the age limit). State in `HCK_QUEUE_ERR_STATES` → ERROR, in `_HOLD_STATES` → HOLD, in `_WAIT_STATES` and older than PARAM3 minutes → STUCK; a bgRFC source without STATE lists errors only. Queue and destination filters are PCRE on the complete value (case ignored), applied in ABAP; a source without destination is not filtered by PARAM2. Empty queues measure 0 (evidence of health).
- **`A_INFLIGHT`** - payments of payment runs (DPAYH, DOC1R filled, proposal runs excluded) in the look-back window whose method belongs to an active method class of `ZCD_HCK_PMCLASS`; flow from `TFK042Z-XEINZ` (country of the company code): **D** disbursement, **C** collection. A class is watched when it has payment methods and at least one active CLEARED rule. Reversed payments (DFKKKO-STBEL) are left out. What takes a payment out of flight, and what is inconsistent, is configuration (below); payments without a decision are aged. *Age* = VALUE_DATE classes (wire, ACH, card): business days after the **value date** (DPAYH-VALUT; run date when empty, said in the detail and in `VALUE_DATE_MISSING`) in the calendar of the house bank (`ZCD_HCK_PMBANK`, e.g. UK / German bank holidays of Barclays / Commerzbank), else of the class, else PARAM1; ISSUE_DATE classes (cheques): calendar days since the run date. Limits: `ZCD_HCK_THRESH` `AGE_OLDEST` per flow + class (DIM1 = threshold key): AMBER = age from which the payment is late (warning), RED = critical; seed (confirm) wire 1 / 2, ACH and card 2 / 3 business days after the value date, cheque 61 / 91 calendar days (> 60 / > 90). Amounts are reported per currency (USD, EUR, GBP …), never summed across currencies. The finding detail lists the PARAM4 oldest late payments: payment document, method, run date, aged-from date, age, amount - no bank account data. No payment in flight measures 0 for every watched flow + class.

#### 7b-1. Rule table and evidence kinds (user rules 2026-11-07)

> **First principle:** a payment leaves flight only on evidence, and two pieces of evidence that disagree are a finding, not a guess.
> **Analogy:** a parcel is delivered when the courier's scan *and* the recipient's signature agree; one without the other is a query to the depot.

`ZCD_HCK_CLRRULE` (key FLOW + METHOD_CLASS + PURPOSE + SEQ; seed `config/hck_seed.md` §8c) names per row an **evidence kind** (`EVIDENCE_CLASS`, a plug-in implementing `ZIF_CD_HCK_EVIDENCE`, validated on save and at run time), its PARAM1-3 and REQUIRED: `X` mandatory, must hold and indicates the purpose; `C` mandatory corroboration, must hold but never indicates alone; `N` mandatory, must not hold; blank = informational, shown only. Purposes decide in the order **VOIDED → RETURNED → RETRIEVED → PENDING → CLEARED → IN_FLIGHT** (RETRIEVED 2026-11-07: a manual retrieval is not a return - canonical outcome, §7b-5): the first purpose with an `X` row that holds decides. All its `X` / `C` rows hold and no `N` row holds → the payment is excluded and counted (`PAY_EXCLUDED`, DIM2 = purpose; IN_FLIGHT = consistent state, stays in flight and is aged). Some but not all → `CLEARING_INCONSISTENT` (VOIDED, RETRIEVED, PENDING, CLEARED, IN_FLIGHT) or `RETURN_INCONSISTENT` (RETURNED), severity E, the detail names per payment what held, what is missing and what must not hold. An **anomaly** an evidence kind reports itself (code and severity of the evidence) is its own finding. A payment in an inconsistency or anomaly finding is not aged (`PAY_INCONSISTENT`). **Undetermined (design review 2026-11-07, fail closed).** A kind that cannot be used (class, parameters, read error) is `CLEARING_RULE_INVALID` (E); a kind whose settings are not maintained is `INFLIGHT_CONFIG` - warning "not configured - mandatory: purpose not determinable" when a mandatory row (`X` / `C` / `N`) uses it, information when only informational rows do. A purpose is **undetermined** for a payment when one of its `X` rows cannot be evaluated, or when an `X` row holds but a `C` / `N` row cannot be evaluated: no positive conclusion, no later purpose decides (a payment whose RETURNED evidence cannot be read is never concluded CLEARED), the payment stays in flight and is aged, and it is listed in `CLEARING_UNDETERMINED` (W, one finding per flow + class naming the purpose and the unavailable rows; metric `PAY_UNDETERMINED`, not counted in `PAY_INCONSISTENT`). Only informational rows are skipped. Card payments while the Stripe settings are missing are the delivered example ("clearing not determinable: Stripe evidence not configured"); the explicit per-row switch (REQUIRED blank = BSEG decides alone) and its trade-off are in `config/hck_seed.md` §8c. One collect per kind and parameters for all flows / classes (one batch read per kind and run, capped by `HCK_INFLIGHT_MAX_ROWS`, `TECH_READ_CAPPED` naming the table).

| Evidence kind (class) | Holds when | Parameters | Anomaly |
|---|---|---|---|
| `ZCL_CD_HCK_EV_BTC_SEQ` - bank code lifecycle | the outcome of the payment's ordered roles (below) is in PARAM1 | PARAM1 outcomes | `UNEXPECTED_SEQUENCE`, `RETURN_INCONSISTENT`, `PENDING_OUTCOME_MISSING` |
| `ZCL_CD_HCK_EV_STMT_DOC` - statement line | FEBEP-CHECT = AUGBL (any code) | - | - |
| `ZCL_CD_HCK_EV_PAY_STATUS` - payment status | DPAYH-ZZ_PAYMENT_STATUS of the newest run row in PARAM1 | PARAM1 status values (`CLEARED`) | - |
| `ZCL_CD_HCK_EV_CHQ_STATUS` - cheque status | DFKKCR-STATE (confirmed: B cashed, V voided, blank open) in PARAM1 | PARAM1 `B` / `V` | - |
| `ZCL_CD_HCK_EV_STMT_CHEQUE` - cheque on the statement | FEBEP-CHECT = last PARAM1 characters of DFKKCR-ZTNUM **and** the statement's house bank account (FEBKO BUKRS / HBKID / HKTID) = the cheque's paying account (payment company code + DFKKCR-HBKID / HKTID) | PARAM1 suffix length (13) | a line fitting several cheques of one account → `CHEQUE_LINK_AMBIGUOUS` (E) for each, no cashing inherited |
| `ZCL_CD_HCK_EV_GL_XREF2` - G/L line cleared | BSEG line with XREF2 = AUGBL (stable key) and AUGBL filled | PARAM1 G/L accounts (optional) | - |
| `ZCL_CD_HCK_EV_GL_ZUONR` - assignment state | BSEG-ZUONR still AUGBL (`EQUAL`) / no longer AUGBL (`CHANGED`) | PARAM1 `EQUAL` / `CHANGED`, PARAM2 accounts | `EQUAL` violated → `CLEARING_INCONSISTENT` "assignment changed" |
| `ZCL_CD_HCK_EV_RETURN_LOT` - returns lot | DFKKRP-SELW1 = AUGBL | - | - |
| `ZCL_CD_HCK_EV_STRIPE` - Stripe payout | payout log row of the payment intent ID (DFKKOP by AUGBL → intent field → `ZCD_STRP_POUT_LOG`); optional charge / payout / full-ACK conditions | PARAM1 settings set (`ZCD_HCK_EVSET`, field names VERIFY-SE11, DDIC + `ZCD_HCK_TABWL` checked) | refund or partial ACK → `CLEARING_INCONSISTENT` |

Seeded rules (all `config/hck_seed.md` §8c): **rule 1** wire / ACH disbursements cleared = lifecycle CLEARED (495 / 466) AND DPAYH status CLEARED - "on statement but status not CLEARED" / "status CLEARED but no statement line" are `CLEARING_INCONSISTENT`; **rule 2** cheques cleared = state B AND the cheque lifecycle CLEARED (581 with CHECT = last 13 of ZTNUM) or CLEARED_MANUAL (correction cleared in FPCHR); voided = state V AND no cashed line; returned = 255 with the register state of a return (blank today) - not aged (V with a 581, B without a line, a 581 while blank are `CLEARING_INCONSISTENT`; blank without a line is open and aged 60 / 90 days); **rule 3** ACH and card collections cleared = BSEG XREF2 = AUGBL cleared (replaces the BSAS ZUONR read) - ACH also lifecycle CLEARED (166 / 143); **rule 4** returns from the bank code lifecycle and the returns lot (below).

#### 7b-2. Bank code lifecycle of a payment (user correction of rule 4)

The bank statement shows a sequence of codes per payment reference (FEBEP-CHECT = AUGBL). The scheme and code of each line come from the statement format - BAI2 type code in FEBEP-VORGC, ISO Domain-Family-Sub-family of a CAMT import in VGEXT - through the same derivation EBS uses (`ZCL_CD_EBS_SRC_FEB=>LINE_CODE`). `ZCD_HCK_BTCROLE` gives each (flow, class, scheme, code) a role - the same code means different things per flow; the roles ordered by statement date / statement / line form the sequence, e.g. `ORIGINAL,RETURNED`; `ZCD_HCK_SEQOUT` matches it (PCRE, complete value, in SEQ order) to an outcome with the returns lot items expected (DFKKRP count, blank = not checked), a maximum age for pending outcomes and the severity. Codes without a role are ignored. For cheques (rule PARAM2 `ZTNUM`) an outcome row may also require a register state (`REG_STATE`, DFKKCR-STATE, `BLANK` = blank) and may name its own finding (`FINDING`, open list: the outcome is itself a finding, severity of the row, its DESCRIPTION in the detail together with cheque number, register state, codes and dates); a line whose role compares with `R` must carry the payment amount (DPAYH-RWBTR of the same AUGBL - no DFKKCR amount field is read) or the cheque is `CHEQUE_AMOUNT_MISMATCH` (E, manual clearing in FPCHR). The suite only reports - cheques are cleared manually by support in FPCHR. A 581 or correction line whose cheque number matches no cheque cannot be tied to a payment here; EBS reports it at import (rule group BAI581D: R08 cheque amount against the register by ZTNUM; BAI255D: R07C), see `EBS_VALIDATION.md`.

| Flow / class | Codes → roles | Sequences → outcome (DFKKRP items) |
|---|---|---|
| C ACH (BAI) | 166, 143 COLLECTED; 468 COLLECT_FAIL | COLLECTED → CLEARED (0); COLLECT_FAIL → REDEPOSIT_PENDING (0, max 10 days - delayed redeposit, confirmed); COLLECT_FAIL,COLLECTED → CLEARED (0); COLLECT_FAIL,COLLECT_FAIL → RETURNED (1) |
| C ACH (CAMT, methods 1-5) | ISO codes - **confirm** | as BAI once the codes are known |
| D ACH | 466 ORIGINAL; 168 RETURNED; 166 RETRIEVED; 468 RETRIEVE_FAIL | ORIGINAL → CLEARED (0); ORIGINAL,RETURNED → RETURNED (1); ORIGINAL,RETRIEVED → RETRIEVED (0, confirmed); ORIGINAL,RETRIEVE_FAIL → RETRIEVAL_FAILED (0, stays paid); ORIGINAL,RETRIEVED,RETURNED,RETRIEVE_FAIL → RETURNED (1, confirmed: the original failed) |
| D WIR | 495 ORIGINAL; 195 RETURNED | ORIGINAL → CLEARED (0); ORIGINAL,RETURNED → RETURNED (1); no redeposit for wires |
| C CRD | 195 PAYOUT_RECEIVED (Stripe deposit) | reserved for the planned deposit evidence |
| D CHQ (link DFKKCR-DOC1R = AUGBL → last 13 of ZTNUM = FEBEP-CHECT) | 581 CASHED (amount = payment amount); 255 RETURNED; 399, 699 CORRECTION (open list) | any CORRECTION + register B → CLEARED_MANUAL; any CORRECTION otherwise → `MANUAL_CLEARING_REQUIRED` (E, "clear manually in FPCHR"); several 581 or several 255 → `CHEQUE_CLARIFICATION` (E); CASHED → CLEARED (with state B); (CASHED,)RETURNED + register blank → RETURNED, + V → voided after return, + B → `RETURN_INCONSISTENT` ("register still shows cashed"); DFKKRP 0 for all (confirmed) |

Any other sequence is `UNEXPECTED_SEQUENCE` (codes and dates in the detail). **Unmapped codes (design review 2026-11-07).** A line on the payment reference whose (flow, class, scheme, code) has no role is no longer dropped: when it carries an amount (≠ 0, "monetary") and its code is not an approved informational exclusion of its scheme - ZCA_PARAM `HCK_BTC_INFO_BAI2` / `_ISO` / `_PRTRY` (comma lists, delivered blank: codes that never concern a payment, approved on a customizing request) - the lifecycle is **INDETERMINATE** (never CLEARED / RETURNED, the evidence does not hold) and the payment is listed in `BTC_ROLE_MISSING` (E) with scheme, code, posting date, amount and flow / class, so that `ZCD_HCK_BTCROLE` gets the row (or the code the exclusion). A line without amount and without role, and an excluded code, are ignored. Returns lot items other than expected (missing lot, extra lot), a lot without any return line, or the amount of the last line whose role is compared (`COMPARE_AMOUNT`) differing from the lot amount (DFKKRP-BETRW, VERIFY-DDIC) are `RETURN_INCONSISTENT`. A pending outcome older than `MAX_AGE_DAYS` after its last line is `PENDING_OUTCOME_MISSING` ("redeposit outcome missing").

**Cheque lifecycle (code review 2026-11-07).** Correction lines (role COMPARE_AMOUNT `C`, 399 / 699) stop the amount comparison of an earlier 581; one lifecycle per cheque, the newest cheque not voided decides the payment (void and reissue) and the others keep their own outcome in the detail; every anomaly is reported (`TY_EVIDENCE-MORE`: an outcome FINDING no longer hides returns lot, amount or age), the primary one first; REG_STATE applies only to a register row - without one `CHEQUE_REGISTER_MISSING` (E); REG_STATE (CHAR 40) and FINDING (catalogue `ZCL_CD_HCK_EV_SUPPORT=>OUTCOME_FINDINGS`) are validated on save (messages 420 / 421); the lifecycle is evaluated once per link (PARAM2 / PARAM3) and run, found per PARAM1, and DFKKCR is read once per payment and run for all cheque kinds (memo of the collection, `ZCL_CD_HCK_EV_SUPPORT=>START_COLLECTION` at the start of each `A_INFLIGHT` run). Details `config/hck_seed.md` §8f.

**Cheque link (design review 2026-11-07).** Cheque lines (rule PARAM2 `ZTNUM`, and `ZCL_CD_HCK_EV_STMT_CHEQUE`) are read once through `ZCL_CD_HCK_EV_SUPPORT=>LINES_BY_CHEQUE` and tied by the core rule `ZCL_CD_OPS_CHEQUE_LINK`, which the payment trace uses too (full number there): a line belongs to a cheque only when its CHECT is the last N characters of DFKKCR-ZTNUM (as given or without leading zeros) **and** its statement account equals the cheque's paying house bank account. Every eligible cheque is kept: the same suffix on another account never fits (neither cheque inherits the other's cashing), several cheques of the same account for one line make it **ambiguous** - attributed to none, each payment listed in `CHEQUE_LINK_AMBIGUOUS` (E, lifecycle not evaluated). A line or cheque without full account identity fits nothing (fail closed). Candidates are the cheques of the payments in the look-back window; a colliding cheque issued before the window is not a candidate (VERIFY: ZTNUM layout - whether the last 13 characters are unique per house bank account). EBS matches lines to the register at import with its own account-scoped rule (`ZCL_CD_EBS_RULE_BASE=>REGISTER_MATCH`, full number, `HOUSE_BANK_AMBIGUOUS`); it does not use the suffix and is not changed.

**Overlap with EBS.** EBS validates each statement line when it is imported (rule groups BAI166 / 168 / 195D / 466 / 468D: is the payment there, retrieval status, returns lot); `A_INFLIGHT` evaluates the payment's whole lifecycle across lines and days. Both read FEBEP through shared readers (scheme / code derivation `ZCL_CD_EBS_SRC_FEB=>LINE_CODE`, returns lot `ZIF_CD_EBS_SAP_DAO=>GET_RETURN_ITEMS`, DPAYH status `GET_PAYMENTS`); `ZCD_BTC_MAP` (line categories of EBS) and `ZCD_HCK_BTCROLE` (payment lifecycle roles) answer different questions and are not merged.

#### 7b-3. Collections clearing models

After the payment run BSEG-ZUONR and BSEG-XREF2 both carry AUGBL. **ACH collections**: both stay AUGBL; F.13 clears the line one-to-one by ZUONR - cleared = the XREF2 line is cleared; a changed ZUONR is an anomaly ("assignment changed"). **Stripe card collections (method B)**: payout-file processing overwrites ZUONR with the Stripe statement descriptor (XREF2 stays AUGBL); F.13 clears the group of all lines with that descriptor (charges, Stripe fees …) against the BAI 195 deposit on the JPMC account ending 16650 (account from `ZCD_EBS_ACCT`, never hard-coded). Rows: CLEARED = BSEG XREF2 cleared (X) and a payout log row (C); IN_FLIGHT = payout log row (X) and descriptor set (X). So: cleared without payout row, or payout row with ZUONR still AUGBL ("payout processed but descriptor not set") = `CLEARING_INCONSISTENT`; payout + descriptor but F.13 not yet cleared = in flight, late after the `CCRD` limit. XREF2 is the only key used to find the payment (never ZUONR). The group balance of a descriptor (charges + fees = the 195 amount) belongs to the planned transit balancing check, not here.

#### 7b-4. Adding a payment method for collections or disbursements

Worked example: international ACH disbursements through Barclays and Commerzbank (payment methods, statement format and codes not yet given; placeholder rows in `config/hck_seed.md` §8 marked **confirm**).

1. **DV1, HCK configuration app** (`ZUI_CD_HCK_CFG`), on a customizing request: *Payment method classes* - row D / `ACI` (3 characters: flow + class is the threshold key), the SAP payment methods, AGE_BASIS `VALUE_DATE` (or `ISSUE_DATE` for cheques), the calendar; *Factory calendar per house bank* - one row per house bank (Barclays: UK calendar, Commerzbank: German calendar).
2. *Bank transaction code roles* - the codes of the bank's statements with their scheme (CAMT: `ISO`, e.g. ORIGINAL / RETURNED codes), *Role sequence outcomes* - the legitimate sequences (e.g. `ORIGINAL` → CLEARED 0, `ORIGINAL,RETURNED` → RETURNED 1).
3. *Clearing / return evidence rules* - CLEARED (lifecycle CLEARED + DPAYH status), RETURNED (lifecycle RETURNED); reuse the delivered evidence kinds. A plug-in class is needed only for a genuinely new kind of evidence (e.g. a new log table) - one class implementing `ZIF_CD_HCK_EVIDENCE`, no change to the check.
4. `ZCD_HCK_THRESH` `AGE_OLDEST` row for the key (e.g. `DACI`); amounts are reported per currency (EUR / GBP).
5. Test in QA1 (`Test_and_Validation_Document.md` HCK-QA-21 …), then transport DV1 → QA1 → PS4. A collection class (e.g. collection wire or cheque, flow C) is the same steps with flow C.

#### 7b-5. One canonical payment outcome (2026-11-07)

> **First principle:** the rules above are the one definition of a payment's outcome - the morning report, the payment trace and the transactions dashboard must never judge the same payment differently.
> **Analogy:** one referee, three scoreboards.

The evaluation of this check - configuration (method classes, house-bank calendars, rules), reversal (DFKKKO-STBEL), one collect per evidence kind, the decision per payment (purposes in order, X / C / N / blank, anomalies, fail closed) - moved **unchanged** into the shared service `ZIF_CD_OPS_PAY_OUTCOME` / `ZCL_CD_OPS_PAY_OUTCOME` (core factory `GET_PAY_OUTCOME`, injector `INJECT_PAY_OUTCOME`). `A_INFLIGHT` keeps its windows, ageing, metrics and findings: it reads the payments of its windows, lets the evaluator classify and judge them (`LOAD`, `CLASSIFY`, `EVALUATE`) and turns the verdicts into `PAY_EXCLUDED` (status X, DIM2 purpose), aged payments (status O, also UNDETERMINED) and the listings of its findings (status I). Findings, codes, messages and metrics are as before; the existing tests are unchanged and green offline (lint), plus `fixture_*` tests on the shared fixtures.

| Verdict | Outcome | A_INFLIGHT |
|---|---|---|
| Consistent purpose VOIDED / RETURNED / RETRIEVED / PENDING / CLEARED | the purpose | excluded (`PAY_EXCLUDED`) |
| No purpose decided, or consistent IN_FLIGHT | `IN_FLIGHT` | aged |
| A mandatory kind not usable | `UNDETERMINED` | aged, `CLEARING_UNDETERMINED` |
| Some but not all evidence, or an anomaly | `INCONSISTENT` | listed, not aged |
| Payment document reversed | `REVERSED` | left out |
| FIN in two or more sources (attribution, not evidence) | `AMBIGUOUS` | not used (the check has no source) |

The same evaluator gives the payment trace its stage `OUTCOME` (`Payment_Trace.md` §2) and the 5-minute snapshot behind the transactions dashboard its versions (`ZCD_PAY_OUTCOME`, `Dashboard_Transactions.md` §0): no consumer holds a second copy of a rule. Purpose **RETRIEVED** is new (rap generator enum, seed row D ACH RETRIEVED in `config/hck_seed.md` §8c; the D ACH RETURNED row lists `RETURNED` only) - with the old seed a retrieval was excluded as RETURNED. Shared negative fixtures (`ZCL_CD_OPS_PAY_FIXTURE`, test support): retrieval without return, bank line without clearing, two DPAYH runs, FIN in two sources, SUCCESS older than 30 days.

### 7c. Suppressions (operations app)
Known findings can be suppressed per check, object pattern and company code for a period (`ZUI_CD_HCK_SUP_O4`; more than `HCK_SUPPRESS_MAX_DAYS` = 7 days needs a second user). A suppressed finding stays on the report as information "Suppressed until … by …", is not alerted and does not make the check red or amber.

## 8. Thresholds and baselines

> **First principle:** a limit is either absolute (policy) or relative to the metric's own history (normality) — the table says which.
>
> **Analogy:** a speed limit vs "you usually drive this road at 40, today you did 90".

- Resolution: (metric, company code) → (metric, `*`) → (`*`, `*`). DIM1 is used as the company-code key only when it has ≤ 4 characters; job names and log objects use the `*` row.
- Static: higher-is-worse → value ≥ red = RED, ≥ amber = AMBER, zero limit = not set. Lower-is-worse → value ≤ red = RED, ≤ amber = AMBER; both zero = off.
- Baseline: history = last `LOOKBACK_RUNS` runs of the same check/metric/DIM1/DIM2 series (A101; default `HCK_LOOKBACK_RUNS` = 8), at least 3 points. ZSCORE: z ≥ `Z_LIMIT` (default 3; ≤ −limit when lower is worse). IQR: beyond Q3 + k·IQR (or Q1 − k·IQR), k = `Z_LIMIT` (default 1.5). Outlier → AMBER when static limits are green.
- Baseline warm-up (A102): fewer than 3 history runs of the series → finding `BASELINE_WARMUP` (information). A static RED / AMBER still stands and a static GREEN stays GREEN; a baseline-only metric (no static limit) leaves the check **grey WARM-UP**, never GREEN. Warm-up checks are counted per category and in the scorecard line, not scored, and are neither passed nor failed in the run counters.
- Statistics are sample statistics (n−1), percentiles interpolate linearly (`ZCL_CD_HCK_STATS`).

### 8a. Row caps (parameters, 2026-11-07)

| Parameter | Default | Hard ceiling (constant) | Cap reached |
|---|---|---|---|
| `HCK_MAX_JOB_ROWS` | 5 000 | 50 000 (`ZIF_CD_HCK_TYPES=>GC_MAX_JOB_ROWS`) | technical-jobs / job-cycle check reports the cap (possibly incomplete) |
| `HCK_MAX_JOB_NAMES` | 20 000 | 200 000 (`ZIF_CD_HCK_TYPES=>GC_MAX_JOB_NAMES`) | message 747, the check fails loudly |
| `HCK_MAX_AGG_ROWS` | 5 000 | 50 000 (`ZIF_CD_HCK_DAO=>GC_MAX_AGG_ROWS`) | groups not returned are unknown, never zero |
| `HCK_MAX_TECH_ROWS` | 5 000 | 50 000 (`ZIF_CD_HCK_RUNTIME_TYPES=>GC_MAX_TECH_ROWS`) | NRIV intervals / queue groups of one read: `TECH_READ_CAPPED` (W) |
| `HCK_INFLIGHT_MAX_ROWS` | 5 000 | 50 000 (`ZIF_CD_HCK_RUNTIME_TYPES=>GC_MAX_INFLIGHT_ROWS`) | payments of one window / bank lines of one read: `TECH_READ_CAPPED` (W) |

Effective cap = parameter (default when not maintained, blank, not a number or not positive), cut to the ceiling (`ZCL_CD_HCK_PARAM=>ROW_CAP`). Raise a cap only after checking the runtime of the read in QA1; the ceilings bound memory and runtime of one check.

## 9. Job cycle monitor (Control-M fallback, monitoring only)

> **First principle:** a chain is healthy only when every link ran, in order, inside its window.
>
> **Analogy:** a relay race — a fast runner is useless if the baton was never handed over.

Per step (`ZCL_CD_HCK_CYCLE_EVAL`): step date = cycle date + `DAY_OFFSET`. The step's instance is the earliest TBTCO job matching the `JOBNAME` pattern (PCRE, complete name, case ignored) that started on the step date at or after `WINDOW_FROM`.

| State | Rule |
|---|---|
| `COMPLETED` | Instance finished (F); overrun flag when runtime > `MAX_RUNTIME_MIN` |
| `FAILED` | Instance cancelled (A) |
| `RUNNING` | Instance active (R) within `MAX_RUNTIME_MIN` |
| `STUCK` | Instance active beyond `MAX_RUNTIME_MIN` |
| `NOT_STARTED` | No started instance and `WINDOW_TO` not yet passed; *blocked* when the predecessor is FAILED/MISSED/STUCK |
| `MISSED` | No started instance and `WINDOW_TO` passed |

Findings: MISSED → E if critical, I if skippable, else W; FAILED → E if critical else W; STUCK → E; overrun → W; blocked → W. Non-working days of the cycle's factory calendar are skipped. **Retrigger / restart from SAP, outage mode and Control-M divergence detection are a later phase** — this release only monitors. Repeating schedules (every 5 min / hourly) are watched by `E_JOBS`; a cycle step models one expected instance.

### 9a. Patterns (PCRE, user decision 2026-11-06)

Job names of `ZCD_JOB_STEP`, the job-name lists (PARAM1 of `ZCL_CD_HCK_C_TECH_JOBS` / `_JOB_RUNTIME`), the log object / subobject lists (PARAM1 / PARAM2 of `_APPLOG`), the cycle ids (PARAM2 of `_JOB_CYCLE`) and suppression key patterns are PCRE matched to the **complete value**, case ignored: `ZCD_PAYM_WIRE_.*` captures every job starting with ZCD_PAYM_WIRE_, `ZCD_POST_GL` only that job. List items are separated by `,` or `;`. Invalid patterns are configuration errors, never an empty selection: a parameter list raises E373 (PLUGIN_ERROR of the check), a step job name gives `PATTERN_INVALID` for the step (E, counted not OK, not MISSED, message 371), a suppression key pattern is not applied and gives `SUPPRESSION_PATTERN_INVALID` (W, message 372); the job-step app and the suppression app refuse them on save (418).

TBTCO / BALHDR are not read with a pattern in SQL (`Performance_Review.md` §6b): the DAO reads the distinct job names of the date window (or of the open statuses), capped at parameter `HCK_MAX_JOB_NAMES` (default 20 000, hard ceiling `GC_MAX_JOB_NAMES` = 200 000; reaching it raises message 747 — the check fails loudly, never partly), matches them in ABAP and reads the runs of the matched names (FOR ALL ENTRIES, then ordered and capped at parameter `HCK_MAX_JOB_ROWS`, default 5 000, ceiling `GC_MAX_JOB_ROWS` = 50 000; a check that reaches it reports the cap as before); BALHDR counters are grouped per object / subobject for the day and filtered in ABAP. Check a job-name pattern before saving it: `ZCD_OPS_PATTERN_CHECK`, area HCK_JOB (job names of TBTCO in the window against step and list patterns); suppression keys: area HCK_SUPPR.

## 10. Generic aggregate security

> **First principle:** customizing may choose *what* to count, never *how* SQL is written.
>
> **Analogy:** a vending machine — you press numbered buttons; you cannot reach inside.

`ZCL_CD_HCK_AGG_QUERY=>build` (pure, unit-tested): the table must be active in `ZCD_HCK_TABWL` (message 302); field names (sum, date, group, conditions) must exist in the runtime DDIC of that table (`describe_by_name` + `get_ddic_field_list`, classic EXCEPTIONS; 303/304); operators only EQ NE GT LT GE LE IN (305); character literals are quoted with `cl_abap_dyn_prg=>quote` (inner quotes doubled), numeric literals must match a number pattern (306); date fields must be DATS (309); SUM needs a numeric field (318). The DAO executes the validated query (COUNT/SUM, optional GROUP BY, max 5 000 groups) and maps database errors to message 308.

## 11. Dashboard CDS layer (embedded analytics)

> **First principle:** the dashboard reads the same store the report writes — one truth, two views.
>
> **Analogy:** the scoreboard and the referee's notebook record the same match.

Sources in `cds/` (ADT text sources; release-dependent annotations marked *verify on target release*):

| View | Type | Content |
|---|---|---|
| `ZI_CD_OpsRun` | basic | Run headers (all payment engine areas), `RunDate` |
| `ZI_CD_OpsRunCube` / `ZC_CD_OpsRunQry` | cube / query | Runs, red runs, findings, runtime (sum, max, average formula) per payment engine area/day |
| `ZI_CD_OpsFinding` | basic | Findings / owned exceptions with `IsOverdue`, `DaysPastDue`, `CreatedDate` |
| `ZI_CD_OpsFindingCube` / `ZC_CD_OpsFindingQry` | cube / query | Finding, open, overdue counts, max days past due, amount per payment engine area/category/check/severity/owner |
| `ZI_CD_HckCheck` | dimension | Check text, category, priority |
| `ZI_CD_HckMetric` / `ZI_CD_HckMetricCube` / `ZC_CD_HckMetricQry` | basic / cube / query | Metric trend (volumes per source/LOB per day, durations, error rates) |
| `ZI_CD_FmonFlowCube` / `ZC_CD_FmonFlowQry` | cube / query | Files, records, control totals, ACK / NACK, rejected / partial per source / LOB / payment method / bank / business date (over `src/fmon` `ZI_CD_FmonFlowFile`; the Fiori deliverable is the file monitoring dashboard, `Dashboard_File_Monitoring.md`) |
| `ZI_CD_OpsAnalytics` (DCL) | role | `pfcg_auth( ZCD_OPS, ZCD_PE_AREA, ACTVT = '03' )` on basic views and cubes — authorization object `ZCD_OPS` must be created (SU21) |

The health check dashboard (`src/hck`, `Dashboard_Health_Check.md`) shows the verdict of each check as the engine persisted it (`ZCD_HCK_RESULT` → `ZI_CD_HckResult` → `ZR_CD_HckCheck`, design review 2026-11-07): dashboard and report mail show the same status, completion, evidence and scope.

Amounts are DEC without currency reference: always slice by `Currency` before reading totals. Recommended consumption: Fiori "Analytical List Page" / KPI tiles or Analysis for Office on the three queries; test mode runs are filtered out of the run cube and filterable in the findings query.

## 12. Morning report program

> **First principle:** the program presents; it never decides.
>
> **Analogy:** the newsreader reads the bulletin, the newsroom writes it.

Selection screen (maintain selection texts / text symbols):

| Element | Text |
|---|---|
| TEXT-B01 | Report date |
| TEXT-B02 | Scope |
| TEXT-B03 | Output |
| TEXT-B04 | Administration |
| P_TODAY / P_YDAY / P_CUST / P_DATE | Today / Yesterday / Custom date / Report date |
| S_CAT / S_PRIO / S_CHECK | Category (A–E) / Priority (H, M, L) / Check ID |
| P_MODS | Include EBS / FMON / HCK payment engine area status |
| P_TEST | Test mode (nothing saved, no mail) — default ON for dialog use |
| P_MAIL | Send morning report e-mail (route MORNING) |
| P_EXC | Show open exceptions list |
| P_EXP / P_FILE | Export CSV to application server / file path (AUTHORITY_CHECK_DATASET) |
| P_BASE | Take configuration baseline (S_TABU_NAM 02 on ZCD_HCK_BASELINE) |

Output: SALV with a scorecard header (score, RAG, red/amber counts, mode, RAG per category, payment engine area status), exception-column lights, double-click → findings popup (job-cycle checks show the step board; checks without findings show their metrics); then the open-exception list. In background both lists go to the spool. Schedule with a variant `P_TEST = space`, `P_MAIL = X`.

## 13. Extension guide — customizing only

> **First principle:** a new question about the payment engine costs table rows, not a transport of code.
>
> **Analogy:** a railway signal box — routes are set on the panel, the track is not re-laid.

| Change | Rows to add (SM30, DV1 → QA1 → PS4) |
|---|---|
| **New aggregate check** (e.g. acceptance test 1, return debits > 10 days by company code) | `ZCD_HCK_TABWL` (table, approver) → `ZCD_HCK_AGG` (CHECK_ID, AGG_ID, table, COUNT/SUM, date field, `AGE`, days, group field, conditions) → `ZCD_HCK_DEF` (CHECK_ID, category, `ZCL_CD_HCK_C_GENERIC_AGG`, active, SEQ, priority) → `ZCD_HCK_THRESH` (`*` row, optional company-code rows). See `config/hck_seed.md` §4. |
| **New threshold / company-code override** | One `ZCD_HCK_THRESH` row with the company code in `BUKRS` (the `*` row stays the default) |
| **Switch a metric to baseline detection** | `ZCD_HCK_THRESH-BASELINE_MODE` = `ZSCORE` or `IQR`, `Z_LIMIT`, `LOOKBACK_RUNS` |
| **New job-cycle step** (acceptance test 5) | One `ZCD_JOB_STEP` row: job pattern, predecessor, day offset, window, max runtime, critical/skippable |
| **New job cycle** | `ZCD_JOB_CYCLE` row + steps; it is picked up by `B_CYCLE_*` (PARAM2 blank = all cycles) |
| **New volume source / LOB** | `ZCD_HCK_TABWL` + `ZCD_HCK_AGG` row under `B_VOLUME` (DAY mode set by the check; group field = source/LOB) + optional threshold |
| **New SLG1 object** | Extend `PARAM1` of `B_APPLOG` |
| **New table under drift control** | `ZCD_HCK_DRIFT` row, then take a baseline |
| **Watch another payment engine area** | ZCA_PARAM `HCK_WATCH_PE_AREAS` (plus definitions `HCK_MAX_AGE_H_<area>` / `HCK_MAX_RUN_MIN_<area>` for the new area); its stale threshold in `ZCD_OPS_MONCFG` (app *Monitor freshness*; fallback `HCK_MAX_AGE_H_<pe_area>`) |
| **Who is alerted** | Core `ZCD_OPS_ALRULE` (payment engine area HCK, severity, group/check pattern, channel) — not an HCK table |
| New check *logic* (only when no existing class fits) | New class implementing `ZIF_CD_HCK_CHECK` (only SQL via a DAO method), then a `ZCD_HCK_DEF` row |

Acceptance test 4 of the requirements baseline (statement balance rule) belongs to the EBS payment engine area's rule tables; for HCK the equivalent proof is that limits and rules are rows in `ZCD_HCK_THRESH` / `ZCD_HCK_AGG` (QA1 case HCK-QA-04).

## 14. Testing

> **First principle:** pure rules are proven without a database; glue is proven in QA1 with real data.
>
> **Analogy:** test the recipe on paper, then taste the dish in the real kitchen.

ABAP Unit (RISK LEVEL HARMLESS, DURATION SHORT; pure classes without doubles; engine with `LTD_*` doubles through `ZCL_CD_HCK_INJECTOR` and `ZCL_CD_OPS_INJECTOR`; DAO with `cl_osql_test_environment`):

| Test class (local) | Class under test | Test methods |
|---|---|---|
| `ltc_stats` | `ZCL_CD_HCK_STATS` | mean_of_empty_is_zero, single_value_zero_stddev, mean_of_known_series, p50_even_count_averages, p50_odd_count_is_middle, sample_stddev_known_series, percentile_interpolates, zscore_measures_distance, zscore_zero_without_spread, iqr_flags_high_outlier, iqr_keeps_inner_value, iqr_low_side_when_lower_bad |
| `ltc_threshold` | `ZCL_CD_HCK_THRESHOLD` | bukrs_row_beats_star_row, star_row_without_bukrs_row, unknown_metric_no_threshold, red_when_value_reaches_red, amber_between_amber_and_red, green_below_amber, lower_worse_red_at_zero, zero_red_disabled_when_higher, zscore_outlier_turns_amber, short_history_no_baseline, iqr_outlier_turns_amber |
| `ltc_score` | `ZCL_CD_HCK_SCORE` | all_green_scores_hundred, red_high_forces_red, score_weighted_by_priority, category_takes_worst_rag, no_results_grey_zero, red_counts_critical |
| `ltc_cycle_eval` | `ZCL_CD_HCK_CYCLE_EVAL` | no_run_before_window_end, no_run_after_window_missed, active_job_is_running, stuck_step_after_max_runtime, finished_job_is_completed, slow_finish_flags_overrun, cancelled_job_is_failed, failed_pred_blocks_step, critical_missed_is_error, skippable_missed_is_info, completed_step_no_finding |
| `ltc_agg_query` | `ZCL_CD_HCK_AGG_QUERY` | builds_aging_where, rejects_unlisted_table, rejects_unknown_field, rejects_unknown_operator, rejects_text_numeric_field, rejects_non_date_age_field, rejects_sum_on_text_field, escapes_quote_in_literal, in_list_quotes_each_value, day_mode_compares_one_date, no_rows_give_star_zero, group_rows_become_dims |
| `ltc_report_html` | `ZCL_CD_HCK_REPORT_HTML` | escapes_markup_in_values, red_chip_label_and_colour, green_chip_label_and_colour, grey_chip_for_unknown_rag, empty_exceptions_say_none, category_row_has_chip, csv_quotes_and_neutralises |
| `ltc_param` | `ZCL_CD_HCK_PARAM` | list_items_are_pcre, blank_list_gives_no_pattern, invalid_pattern_is_refused, text_int_uses_default |
| `ltc_engine` | `ZCL_CD_HCK_ENGINE` | all_green_scores_hundred, red_metric_turns_check_red, failed_plugin_does_not_abort, timeout_overrun_is_flagged, test_mode_saves_nothing, real_run_persists_dispatches, mail_goes_to_morning_route, stale_module_fails_self, category_rag_and_score |
| `ltc_dao` | `ZCL_CD_HCK_DAO` | history_newest_first_capped, history_only_same_dimension, saved_metric_is_read_back, overdue_open_and_assigned |

**Deliberately not unit tested**

| Object | Reason | Covered instead by |
|---|---|---|
| DAO reads of TBTCO, BALHDR, SNAP_BEG, VBHDR, DFKKSUMC/DFKKKO/BKPF; `ENQUEUE_READ`; `DATE_CONVERT_TO_FACTORYDATE`; `get_table_fields` (RTTI) | Thin wrappers over SAP standard tables / FMs with unverified fields; doubling them proves only the double | QA1 cases HCK-QA-06…10; the logic consuming their output is unit-tested (cycle eval, threshold, agg query) |
| DAO `aggregate` and `compute_table_hash` (dynamic SQL on arbitrary tables) | Dynamic FROM on non-doubled tables; the SQL text is built and tested in the pure builder | `ltc_agg_query`; QA1 HCK-QA-01, HCK-QA-05 |
| Check plug-ins `ZCL_CD_HCK_C_*` | Glue: parameter → DAO → pure helper; no own rules | Pure tests of `agg_query`, `cycle_eval`, `param`; engine tests through LTD plug-ins; QA1 cases |
| `ZCL_CD_HCK_ENGINE=>take_baseline` | AUTHORITY-CHECK + DAO wrapper | QA1 HCK-QA-05 |
| `ZCD_MORNING_REPORT` (SALV, OPEN DATASET) | Presentation only | QA1 HCK-QA-11 |
| E-mail delivery (core `send` / `dispatch`, BCS) | Core payment engine area | Engine tests assert the calls; QA1 HCK-QA-12 |
| CDS views and DCL | Not executable offline | QA1 HCK-QA-13 (data preview / RSRT) |

**Recommended QA1 functional test cases**

| ID | Scenario | Configuration | Expected result |
|---|---|---|---|
| HCK-QA-01 | **Acceptance test 1**: add "return debits aging > 10 days by company code" by customizing only | Seed §4 rows: TABWL `DFKKOP`, AGG `A_RET_AGED/RET_AGED`, DEF `A_RET_AGED`, THRESH `*` 1/25 + one company-code row; test data: open return-debit items due 11+ days ago in two company codes | Report shows `A_RET_AGED` with one metric per company code; the company with ≥ 25 items is RED with `THRESHOLD_RED`; the override company uses its own limits; no transport of code objects |
| HCK-QA-02 | Invalid aggregate row is contained | AGG row with a misspelled field / table not whitelisted | `AGG_CONFIG_INVALID` (messages 304 / 302) for that row; other rows and checks still measured |
| HCK-QA-03 | Plug-in failure does not abort | `ZCD_HCK_DEF` row with a non-existent class name | That check RED with `PLUGIN_ERROR` (message 030/300); report complete |
| HCK-QA-04 | **Acceptance test 4 (HCK counterpart)**: change a rule / limit by customizing only | Change `ZCD_HCK_THRESH` `C_OVERDUE_EXC/OVERDUE/*` red from 20 to 1; next run | Same data now RED; no code change. (The statement-balance rule of test 4 itself is proven in the EBS payment engine area.) |
| HCK-QA-05 | Config drift and baseline | Take baseline (P_BASE), change one row of `ZCD_HCK_THRESH` in QA1, run | `D_CONFIG_DRIFT` RED with `CONFIG_DRIFT` naming the table, baseline time and user; re-baseline → GREEN; user without S_TABU_NAM 02 gets message 041 |
| HCK-QA-06 | **Acceptance test 5**: add a job-cycle step by customizing only | Insert `ZCD_JOB_STEP DISB_DAY/035` (seed §7) | Next run's `B_CYCLE_TODAY` drill-down lists step 035 with its state |
| HCK-QA-07 | Job-cycle states | Schedule a test job matching a step pattern: (a) cancel it, (b) let it exceed MAX_RUNTIME_MIN, (c) never schedule it and wait past WINDOW_TO, (d) cancel the predecessor | (a) FAILED, (b) STUCK, (c) MISSED (E if critical), (d) successor NOT_STARTED + `STEP_BLOCKED` |
| HCK-QA-08 | Technical checks | Cancel a `ZCD_*` test job; create a lock older than 60 min; force a short dump | `E_JOBS` `JOB_CANCELLED`; `E_SYSTEM` LOCK_MAX_AGE_MIN amber; SHORT_DUMPS ≥ 1 |
| HCK-QA-09 | Baseline outlier | Run `B_JOB_RUNTIME` daily ≥ 3 days, then slow one job artificially | `BASELINE_OUTLIER` (AMBER) with mean and z in the message |
| HCK-QA-10 | GL transfer completeness | Reconciliation key with totals records and no GL transfer in the window | `GL_TRANSFER_GAP` per key; metric GL_MISSING_KEYS |
| HCK-QA-11 | Report in dialog and background | Run interactively in test mode; then as background job with productive variant and CSV export | Dialog: scorecard + ALV + drill-downs, nothing saved; background: spool lists, ZCD_OPS_RUN/FINDING rows, ZCD_HCK_METRIC rows, CSV file on the application server |
| HCK-QA-12 | Mail and alerts | ALERT_MORNING maintained; P_MAIL = X; one red finding | One HTML mail (renders on phone and desktop, RAG chips); core `dispatch` logs to ZCD_OPS_ALLOG per alert rule; test mode sends nothing |
| HCK-QA-13 | Dashboard | Activate CDS + DCL, role with ZCD_OPS ZCD_MODULE = HCK only | Queries return HCK data only; run, finding and metric trends consistent with the morning report |
| HCK-QA-14 | Health of the health check | Suspend the EBS validation job for > 26 h | `HCK_SELF` RED with `PE_AREA_STALE` for EBS |
| HCK-QA-18 | Number range nearly exhausted | QA1 test object (SNRO) with an interval of 100 numbers, NRLEVEL 86 / 96; PARAM1 = the object | `E_NUMRANGE` AMBER / RED with `NR_USAGE_HIGH` naming object, interval, 85 % / 95 %, numbers left; object without interval → `NR_NO_INTERVAL` |
| HCK-QA-19 | Queue in error / stuck | Outbound queue to an unreachable test destination (SYSFAIL / CPICERR); a stopped test queue; PARAM1 = its name pattern | `E_QUEUES` `QUEUE_ERROR` (E) naming SMQ1, `QUEUE_HOLD`; metrics `Q_ERROR` / `Q_HOLD` QOUT; queue left untouched |
| HCK-QA-20 | Payments in flight | Payment run with one wire, one ACH (value date one / three business days back), one cheque older than 61 days, no statement line; one collection; one returned payment | `A_INFLIGHT` `PAYMENT_NOT_CLEARED` per flow + class with the oldest payments in the detail; the returned payment is not listed; after the statement line is loaded the payment drops out |
| HCK-QA-21 | Clearing and return evidence (user rules 1-4) | Cases of `Test_and_Validation_Document.md` HCK-QA-21 .. 26 (wire / ACH status and line, cheque B / V / blank, collection BSEG XREF2, ACH return sequences, redeposit, Stripe) | Excluded per purpose / `CLEARING_INCONSISTENT` / `RETURN_INCONSISTENT` / `UNEXPECTED_SEQUENCE` / `PENDING_OUTCOME_MISSING` as listed there |

### Phase 6 audit changes (operations notes)

- **Baseline retake:** configuration-drift hashes are canonical (length-prefixed fields, version `2`, A57).
  Baselines taken before are reported as CONFIG_BASELINE_OUTDATED until `take_baseline` is run once.
- **Time budget:** item-wise checks stop between items at TIMEOUT_SEC (BUDGET_EXHAUSTED, A18). A synchronous
  check still cannot be interrupted inside one SQL; long checks belong in a separate job step / variant.
- **Self-checks:** a hung run (status R beyond HCK_MAX_RUN_MIN) and an empty selection are red (A06); green
  needs at least one executed business check.
- **History:** one point per finished, non-test run, as of the report date (A59); flat history uses
  HCK_FLAT_TOL_PCT (A58).
- **Metric kinds (A88):** checks classify metrics as volume, level or rate (ZCD_HCK_METRIC-KIND / WEIGHT);
  the dashboard cube adds volumes, takes MAX / average of levels and weights rates. Rows written before the
  change count as volumes.
- **CSV export** is written to a temp file and published only when complete (A61).

## 15. VERIFY-DDIC register and what is not verified

> **First principle:** say what you checked; everything else is a hypothesis.
>
> **Analogy:** a surveyor marks which boundary stones were found on site and which were copied from an old map.

`"VERIFY-DDIC:` markers (all in `ZCL_CD_HCK_DAO`):

1. `TBTCO`-JOBNAME, JOBCOUNT, STATUS, SDLSTRTDT, SDLSTRTTM, STRTDATE, STRTTIME, ENDDATE, ENDTIME (`get_job_runs`)
2. `BALHDR`-OBJECT, SUBOBJECT, ALDATE, MSG_CNT_AL, MSG_CNT_E, MSG_CNT_A (`get_applog_stats`)
3. `DFKKKO`-BUDAT (`get_fikeys_without_gl`)
4. `BKPF`-AWKEY carries the FIKEY of the payment engine transfer (confirmed path names BSEG-AWKEY; BKPF chosen for its AWTYP/AWKEY index) (`get_fikeys_without_gl`)
5. `SNAP_BEG`-DATUM (else SNAP with SEQNO = '000') (`count_short_dumps`)
6. `VBHDR`-VBRC <> 0 = update request in error (`count_update_errors`)
7. `SEQG3`-GTDATE / GTTIME (`read_lock_stats`)
8. `TBTCP`-PROGNAME / VARIANT, step 1 (`get_job_runs`, A42)
9. `BKPF`-AWTYP `FKKSU`, BUKRS, STBLG (`get_fikeys_without_gl`, A43)

`ZCL_CD_HCK_RUNTIME_DAO` / `ZIF_CD_HCK_RUNTIME_TYPES` (2026-11-07):

10. `NRIV`-OBJECT, SUBOBJECT, NRRANGENR, TOYEAR, FROMNUMBER, TONUMBER, NRLEVEL, EXTERNIND (`get_number_ranges`; character limits CHAR 20)
11. `TRFCQOUT`-QNAME, DEST, QSTATE, QRFCDATUM, QRFCUZEIT and `TRFCQIN`-QNAME, QSTATE, QRFCDATUM, QRFCUZEIT (constants `GC_TRFCQOUT` / `GC_TRFCQIN`, validated at run time; also whether the queue state shown in SMQ1 / SMQ2 is held in these tables or in TRFCQSTATE)
12. bgRFC unit / error table and its fields (PARAM4 of `E_QUEUES`; SBGRFCMON tables on 7.58)
13. `DPAYH`-XVORL, BUKRS, PYMET, HBKID, VALUT, RWBTR, WAERS; `TFK042Z` key LAND1 / ZLSCH via `T001`-LAND1 (`get_issued_payments`)
14. `BSEG`-XREF2 / ZUONR / AUGBL / HKONT read by BUKRS + XREF2 + GJAHR (FOR ALL ENTRIES, `get_gl_lines_by_xref2`): BSEG has no index on XREF2 - access path in a QA1 SQL trace (secondary index BUKRS / XREF2, or the clearing accounts in PARAM1); fiscal year = calendar year assumed
15. `FEBEP`-VORGC / VGEXT (bank code of the line, as the EBS read) and the CHECT form of AUGBL / ZTNUM (with or without leading zeros - both are read); ZTNUM length and the 13-character suffix; `DFKKCR`-STATE is **confirmed** (B / V / blank)
16. `DFKKRP`-BETRW (returned amount, shared EBS read `GET_RETURN_ITEMS`)
17. Stripe payout log `ZCD_STRP_POUT_LOG` field names and the DFKKOP payment intent field (`ZCD_HCK_EVSET`, validated against the DDIC and `ZCD_HCK_TABWL` at run time)
18. `DPAYH` by DOC1R (`get_issued_payments_by_doc`, canonical payment outcome): index on DOC1R; DOC1R not unique (re-runs) - the latest run (LAUFD, then LAUFI, descending) is judged

Seed-only (customizing, validated at runtime against the DDIC): DFKKOP-FAEDN/AUGST/HVORG/BUKRS/BETRH, FEBKO-AZDAT and format field, ZCD_PAYM_REQ_LOG date/source fields, /SAPPO/ORDER_HDR fields, return-debit main transactions, log objects, factory calendars, real SAP job names behind the wiki placeholders.

Not verified (offline build): activation, DDIC existence, ABAP Unit execution, CDS/DCL syntax on 2023 (release-dependent annotations marked), FM interfaces (`ENQUEUE_READ`, `DATE_CONVERT_TO_FACTORYDATE`, `AUTHORITY_CHECK_DATASET`), dynamic SQL behaviour for SUM into DECFLOAT34, BKPF-AWKEY vs FIKEY length comparison, performance at 10M+ open items (the aging aggregate on DFKKOP needs an index on the date/clearing fields or a narrower condition — performance test phase). Timeouts are measured, not enforced: a synchronous check cannot be killed (parallel aRFC with a server-group time-out is the later option).

## 16. Design decisions and the legacy morning report

> **First principle:** keep the ideas that served the operators; remove the mechanisms that put the system at risk.
>
> **Analogy:** renovating a house — keep the floor plan people know, replace the wiring.

**Kept from the existing morning report:** rule categories (now A–E), priority filter (H/M/L) and check-id filter, overall health score (now 0–100, priority-weighted, with the "red High forces RED" rule), critical / high counts, e-mail of the result, export (CSV on the application server), the quick date window (today / yesterday / custom) and the application-log error analysis (now aggregated from BALHDR counters instead of loading every message).

**Dropped defects:** free-text dynamic SQL and a regex "SQL security validator" (replaced by whitelist + DDIC-validated names + quoted literals), WRITE lists (SALV + HTML), invented tables (only core and HCK tables plus standard tables marked VERIFY-DDIC), placeholder e-mail/export that never sent or wrote, mail only when "critical", `SELECT *`, missing test mode.

**Changes vs the build brief:** `ZCD_HCK_AGG` keyed by CHECK_ID **+ AGG_ID** (one check holds several aggregates — volumes) and a `DATE_MODE` (AGE/DAY); `ZCD_HCK_DEF-ROUTE` removed — alert routing is now core customizing `ZCD_OPS_ALRULE` via `dispatch( )`, the morning mail is a deliberate `send( 'MORNING' )`; `ZCD_JOB_STEP-DAY_OFFSET` added (cycles crossing midnight, e.g. BlackLine at 02:00); check interface gets an execution context (report date, now, test mode); pure rule classes split out (`SCORE`, `CYCLE_EVAL`, `AGG_QUERY`, `PARAM`) so they are tested without doubles; overdue exceptions include disposition A (assigned) as well as O; empty aggregates measure 0 under `*` so a silent feed is visible; DIM1 longer than 4 characters uses the `*` threshold row instead of being truncated; new check `E_ALERT_DELIVERY` reads `ZCD_OPS_ALLOG`.
