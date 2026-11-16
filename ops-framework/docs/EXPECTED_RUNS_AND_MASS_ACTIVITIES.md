# Expected runs and FI-CA mass activities

> **First principle:** a run the scheduler planned is expected until SAP shows its job, and a run that ended is only
> complete when all its intervals finished and its documents are there. A plan that is stale or cannot be read is
> never "nothing was expected".
> **Analogy:** a train timetable and the platform board. The timetable (the scheduler's plan) says the 06:00 train
> should leave; the board (SAP's job tables) shows whether it left, left late, or never arrived at the platform
> because the previous train is still blocking the track. And a train that arrived is not a full delivery until the
> freight it carried (the documents) is counted against the manifest.

Build P of Release 1 (`docs/release/RELEASE_1_PLAN.md` section 2a, row P; product review 2026-11-15, row "SAP batch
monitoring": "add external expected-run and dependency evidence for cases where the scheduler never starts SAP;
extend to FI-CA mass-activity intervals and their document output"; scorecard scenario 1). Status 2026-11-16: built
and lint-clean (abaplint, 7.58 syntax), offline fixtures green; **not activated, ABAP Unit not executed**
(`docs/VERIFY.md` V290-V306).

| Part | Pack (release manifest) | Licence module | Objects |
|---|---|---|---|
| Expected runs (section 2) | CORE | `JOBS` | `ZIF_CA_OPS_XRUN_TYPES`, `ZIF_CA_OPS_EXPECTED_RUN_SRC`, `ZIF_CA_OPS_XRUN_CALENDAR`, `ZCL_CA_OPS_XRUN_SRC_JOBSCH`, `ZCL_CA_OPS_XRUN_MONITOR`, `ZCL_CA_OPS_CHK_XRUN`; plan columns of `ZCA_OPS_JOBSCH` |
| Mass activities (section 3) | FICA_CASH (`src/cash`, package `ZCA_OPS_CASH`) | `CASH_OPS` | `ZIF_CA_OPS_MA_TYPES`, `ZIF_CA_OPS_MA_SRC`, `ZIF_CA_OPS_MA_DAO`, `ZCL_CA_OPS_MA_DAO`, `ZCL_CA_OPS_MA_SRC_JOBS`, `ZCL_CA_OPS_MA_CALENDAR`, `ZCL_CA_OPS_CHK_MA_INTERVAL`; factory `ZCL_CA_OPS_CASH_FACTORY=>GET_MA_DAO` |
| Configuration | CORE table, FICA_CASH rows | `CASH_OPS` on activation | `ZCA_OPS_MAACT` (entity *Mass activities* of `ZUI_CA_OPS_CFG`, generated); delivered rows `config/expected_runs/zca_ops_maact.csv` (area `CA_FICA`, inactive) |

No core object names an object of the FI-CA Cash Operations pack in its code (house check `release_manifest`, root
test `tools/tests/test_expected_runs.py`). The configuration table `ZCA_OPS_MAACT` sits in the core like the payment
file configuration tables of build K, because the generated configuration app is core; its rows are of the pack.

## 1. What is detected

| Check | Code | Severity | Stage | When |
|---|---|---|---|---|
| `ZCL_CA_OPS_CHK_XRUN` (registry row `CA_OPS / EXPECTED_RUNS`, group `FAST`, inactive) | `XRUN_NEVER_STARTED` | E | `SCHEDULER` | due (planned start + late minutes passed), no SAP job of its names, the scheduler did not start it (planned, not started or no state) |
| | | | `HANDOVER` | due, no SAP job, but the scheduler says started / ended OK / ended not OK - it failed before SAP |
| | | | `SAP_QUEUE` | due, the SAP job is released / ready / scheduled and did not start |
| | `XRUN_PRED_NOT_FINISHED` | E | `WAIT_PRED` | due, not started, and its predecessor of the same day has not ended successfully (its SAP job not finished, and the scheduler does not report it ended OK) |
| | `XRUN_HELD` | W | `SCHEDULER` | held at the scheduler after its planned start |
| | `XRUN_STARTED_LATE` | W | `LATE_START` | the SAP job started after the late limit (minutes late in the message) |
| | `XRUN_SOURCE_STALE` | W notice | `SOURCE` | the scheduler source's newest record is older than its limit: evaluation `STALE` |
| | `XRUN_SOURCE_FAILED` | W notice | `SOURCE` | the source cannot be read: not evaluated, the check partial |
| | `XRUN_CONFIG_INVALID` | W notice | `SOURCE` | a source class, a pattern, a plan row or a calendar day is not usable - reported, never "no plan" |
| | `XRUN_READ_CAPPED` | W notice | `SOURCE` | the SAP job read reached `XRUN_MAX_JOBS`: partial |
| `ZCL_CA_OPS_CHK_MA_INTERVAL` (catalogue `FICA_PAYRUN`, check `FICA_MA_INTERVALS`, area `CA_FICA`, group `INTRADAY`, inactive) | `MA_OUTPUT_SHORT` | E | `JOB_OK` / `OUTPUT` | the run ended and its document output is short of the expectation - one finding per company code and currency; `JOB_OK` when the parent job finished successfully (scorecard 1: the scheduler sees green) |
| | `MA_INTERVAL_FAILED` | E | `JOB_OK` / `INTERVAL` | one or more intervals failed, or had not finished when the parent ended - unless a short output already names them |
| | `MA_INTERVAL_OVERRUN` | W | `INTERVAL` | an interval runs longer than its limit while the run goes on |
| | `CASH_NOT_EVALUATED`, `CASH_RESULT_CAPPED` | W notice | - | the cash checks' own notices (build N): a read failed, a row is not usable, a cap was reached - partial, never green |

The job monitor (`docs/JOB_MONITORING.md`) keeps reporting the failure of every SAP job (`JOB_ABORTED`,
`JOB_CHILD_FAILED`); the expected runs report what the job monitor cannot see - an absence - and the mass activity
check reports the business consequence of a failed interval (the documents that are missing, with their money).

## 2. Expected runs from the scheduler (generic, core)

### 2.1 The model

`ZIF_CA_OPS_EXPECTED_RUN_SRC` is the plug-in contract of the scheduler's plan (`ID`, `READ` for a range of days).
`ZIF_CA_OPS_XRUN_TYPES=>TY_EXPECTED` is one expected run:

| Field | Meaning |
|---|---|
| `SOURCE_ID`, `RUN_ID` | the source and the scheduler's own run / order ID (blank = folder, job and planned start identify it) |
| `SCHED_FOLDER`, `SCHED_JOB` | the scheduler's job (as in `ZCA_OPS_JOBSCH`) |
| `SAP_PATTERN` | the SAP job names it starts (PCRE, complete name); blank = the pattern of the scheduler row of the same folder and job |
| `PLAN_DATE`, `PLAN_TIME`, `LATE_MIN` | planned start (system time of the SAP server, as TBTCO) and the minutes until it is late / not started (0 = `XRUN_LATE_MIN`) |
| `PRED_FOLDER`, `PRED_JOB` | the predecessor that must have ended successfully first |
| `SCHED_STATE`, `STATE_AT` | the state at the scheduler: `PLANNED`, `STARTED`, `ENDED_OK`, `ENDED_NOK`, `HELD`, `NOT_STARTED` (blank = not known) and when it was recorded |

A source also returns the days the business calendar does not expect a run (`NOT_EXPECTED`, holidays), the days that
cannot be told (`UNKNOWN`, the calendar does not answer - never a holiday), the rows that are not usable (`INVALID`),
its newest record (`NEWEST_AT`, its freshness) with its own stale limit, and `PARTIAL` when capped.

### 2.2 Delivered source "expected by configuration" (`ZCL_CA_OPS_XRUN_SRC_JOBSCH`)

The framework's own scheduler job configuration `ZCA_OPS_JOBSCH` (entity *Scheduler jobs*) has new plan columns:
`PLAN_DAYS` (seven characters Monday ... Sunday, X = runs; blank = the row is a name mapping only, no expected run),
`PLAN_TIME`, `LATE_MIN`, `CALENDAR_ID` and `PRED_FOLDER` / `PRED_JOB`. For every requested day whose weekday the row
names, one run is expected at its planned start; a day the row's calendar does not expect is a holiday. The
calendar is the class of `XRUN_CALENDAR_CLASS` (`ZIF_CA_OPS_XRUN_CALENDAR`): the core delivers none (blank = the
weekdays only, a row with a calendar ID then has unknown days); the FI-CA Cash Operations pack delivers
`ZCL_CA_OPS_MA_CALENDAR`, which answers through the cash checks' factory calendar (`ZIF_CA_OPS_CASH_DAO=>WORKING_DAY`
- the calendar handling of build N, not a copy). The configuration knows no scheduler state and is as fresh as the
read.

### 2.3 Comparison with SAP's jobs (`ZCL_CA_OPS_XRUN_MONITOR`)

Through the job monitor's data access (`ZIF_CA_OPS_JOB_DAO`: `JOBS_RUNNING` from the earliest planned start less
`XRUN_EARLY_MIN` until now, `WAITING_JOBS` of `XRUN_WAITING_STATUSES`), each read capped at `XRUN_MAX_JOBS`. A job of
the run's names whose start - else planned start, else creation - lies from `XRUN_EARLY_MIN` (60) before to
`XRUN_MATCH_MIN` (720) after the planned start is the run's job; runs are taken earliest plan first and a job serves
one run only. The link is a name and a time window, so its evidence quality is **P** (V292).

| Situation | Verdict |
|---|---|
| started before planned start + late minutes | OK |
| started after it | LATE (`XRUN_STARTED_LATE`) |
| not started, now before the planned start - or within the late minutes and not held | PENDING (no verdict) |
| held at the scheduler after the planned start | HELD |
| due, predecessor of the same day not ended successfully | PRED_OPEN |
| due, the SAP job waits | NEVER, stage `SAP_QUEUE` |
| due, no SAP job, the scheduler started / ended it | NEVER, stage `HANDOVER` (failed before SAP) |
| due, no SAP job, the scheduler did not start it | NEVER, stage `SCHEDULER` |

### 2.4 A scheduler's own export (worked example, never seeded)

`examples/expected_runs` (package `ZXX_XRUN`, compiled against the product by the root test): the site loads its
scheduler's daily plan export into its own table `ZXX_XRUN_PLAN`; `ZCL_XX_XRUN_SRC_EXPORT` returns its runs with the
scheduler's status words mapped to the product's states (an unknown word stays blank - never guessed) and the newest
load time as the freshness - so an export that stopped arriving makes the evaluation `STALE`. Wire it with
`XRUN_SOURCES` = `ZCL_XX_XRUN_SRC_EXPORT,ZCL_CA_OPS_XRUN_SRC_JOBSCH` (the export first: a run of an earlier source
wins over the configured run of the same job and planned start). The SAP job names come from the scheduler rows.

### 2.5 Exception contract and evaluation

Every exception carries one run (`ITEM_COUNT` 1, `UNKNOWN_COUNT` 1 - a run has no amount), the deadline that passed
(`DEADLINE_AT` = planned start + late minutes, UTC from its distance to the server clock), `STAGE`, the owner from the
configuration (`ZIF_CA_OPS_OWNER`: the control covering the check, else the process owner, else none - said so) and
evidence rows: the scheduler record (kind `SCHD`, type `RUN`, key SOURCE / RUN / JOB / PLAN / STATE, quality C), the
SAP job (kind `SAP`, type `JOB`, link object `S4_BACKGROUND_JOB` with `JOBNAME` / `JOBCOUNT`, quality P) or "no SAP
job of these names" (quality U), and for `XRUN_PRED_NOT_FINISHED` the predecessor and its job. The evaluation record
(build O): every run due counts as expected, every started one as observed; a stale source adds `STALE` (with its
source, newest record and limit in `ZCA_OPS_EVALSRC`), a source that cannot be read or a day that cannot be told is
not evaluated (`NOT_EVAL`, partial), a holiday is `HOLIDAY`, a finding `FINDINGS`, all started in time `OK`.

## 3. FI-CA mass-activity intervals and their output (pack FI-CA Cash Operations)

### 3.1 What the reference system shows - and what it does not

The review and the plan named `FKKMAKO` / `FKKMAZE` for the mass activity run header and intervals. The reference
system's dictionary export shows them as the **dunning history** (header per business partner and contract account
with `LAUFD` / `LAUFI` = `MLFID_KK`, items per document line), with no interval, job or status field of a mass
activity run (V298). The run and interval records of the mass activity framework are not in the export (V300), so
they are not read. The check therefore works on what is confirmed:

- **Runs and intervals** come from a run source (`ZIF_CA_OPS_MA_SRC`, parameter `MA_SOURCE`). The delivered
  `ZCL_CA_OPS_MA_SRC_JOBS` reads SAP's job tables only (through the job monitor's data access): the parent job is a
  job of the activity's names (`JOB_PATTERN`, PCRE) with a step of its program (`PARENT_PROGRAM`, e.g.
  `RFKK_MA_SCHEDULER`, seen on A4H) that ran since the look-back; its intervals are the jobs the job monitor's
  resolvers link to it (`MA_RESOLVERS`, blank = `JOB_RESOLVERS`), numbered in creation order - so an "interval" of
  this source is a parallel job of the run (V300, V301). The run date is the parent's start date (`LAUFD`: the mass
  activity scheduler names a run by the day it runs, fact F18); the run ID is not known to it. A source reading the
  framework's own records replaces it once confirmed.
- **Output** of a payment run: `DPAYH` through the cash checks' data access (`ZIF_CA_OPS_CASH_DAO=>PAYMENT_RUNS`) and
  the payment run check's own sum (`ZCL_CA_OPS_CHK_CASH_PAYRUN=>SUM_BY_RUN`, made public for this - one rule, not a
  copy): expected = the run's payments, or the proposal when it holds more and `CASH_PAYRUN_GAP_ACTIVE` = X (V221);
  observed = the payments with a payment document (`DOC1R`); payments of a payment-order method count as documented
  (`CASH_PAYRUN_ORDER_METHODS`). Matched on the run date and, where the source knows it, the run ID - never on a fixed
  `LAUFI`.
- **Output** of a dunning run: the notices of `FKKMAKO` (count, `SUM(MSALM)` per `WAERS`) of the run date against the
  activity's minimum (`MIN_OUTPUT`; count only, V299).

### 3.2 Configuration (`ZCA_OPS_MAACT`, entity *Mass activities*)

| Field | Meaning |
|---|---|
| `AREA`, `ACT_ID` | the area of the check and the activity's ID |
| `AKTYP` | mass activity type (`TFK090A-AKTYP` of the site) - a value not confirmed on the reference system stays a placeholder and the row inactive (V302) |
| `PARENT_PROGRAM`, `JOB_PATTERN` | the parent job: program of a step (exact; blank = any), names (PCRE) |
| `OUTPUT_KIND` | `PAYDOC` payment documents, `DUNNING` dunning notices, `NONE` intervals only |
| `MIN_OUTPUT` | minimum output of a run (0 = none; for `PAYDOC` it applies to a run without any payment of the date) |
| `RUN_LIMIT_MIN` | minutes an interval may run (0 = `MA_RUN_LIMIT_MIN`) |
| `ACTIVE` | activation needs licence module `CASH_OPS` |

Delivered rows `PAYRUN` (program `RFKK_MA_SCHEDULER`, output `PAYDOC`) and `DUNNING` (output `DUNNING`) of area
`CA_FICA`, both **inactive**, activity type, dunning program and job names as placeholders.

### 3.3 Exception content

Built by the cash checks' run context (`ZCL_CA_OPS_CASH_CTX`, build N): count and amount per company code and
currency (never summed across currencies; count only when the output has no amount - `UNKNOWN_COUNT` = count), the
oldest item (run date) and age, the next cutoff (deadline, calendar `CASH_CALENDAR`), the owner (the control
covering `FICA_MA_INTERVALS`, else the process owner), the stage, and evidence at source grain: the run
(`AKTYP/LAUFD/LAUFI`), the parent job (`JOBNAME/JOBCOUNT`, link `S4_BACKGROUND_JOB`), the payment run
(`LAUFD/LAUFI`, link `FICA_PAYMENT_RUN`, output `PAYDOC`), and for each failed / unfinished / overrunning interval its
number (`INTERVAL`) and its job. Details lines 621-623 (run, intervals, output).

**Overlap with the payment run check (decision D-P2).** A payment without payment document after a run whose job
finished is also `PAYRUN_NO_DOCUMENT` of `FICA_CASH_PAYRUN` (stage `JOB_OK`, build N). Activate one of the two rules
for the payment run, or route one of them to information only - both report the same 250.00 EUR of scorecard 1.

## 4. Scorecard scenario 1, walked through

*"SAP job finished, child interval failed, and the batch produced only part of the expected financial output."*
Fixture `MA-01` (`config/expected_runs/fixtures.json`, ABAP Unit `ZCL_CA_OPS_CHK_MA_INTERVAL` method
`JOB_OK_INTERVAL_FAILED_SHORT`):

1. Given: the payment run's parent job `ZT_FPY1_PAY01 / 06000001` started 2026-11-12 06:00 and **finished**
   (TBTCO `F`, the scheduler shows green); its three parallel jobs, interval 2 (`ZT_FPY1_PAY01_W / 06010002`)
   **cancelled** (`A`); `DPAYH` run 2026-11-12 / `PAY01`, company code `ZT01`: three payments (400.00, 250.00,
   250.00 EUR), the 250.00 EUR one without payment document.
2. The run source returns the run with its three intervals; the parent ended, so interval 2 is failed.
3. Output `PAYDOC`: expected 3 payment documents (900.00 EUR), observed 2 (650.00 EUR) - short 1, 250.00 EUR.
4. One finding (the short output names the failed interval, no second finding):

| Item | Value |
|---|---|
| Check code / severity | `MA_OUTPUT_SHORT` / E (owned exception) |
| Stage | `JOB_OK` - the job reports success, the business output is incomplete (message 619: "Job ZT_FPY1_PAY01 ended OK, run 2026-11-12/PAY01 output 2 of 3 expected documents") |
| Object key | `PAYRUN/20261112/PAY01/ZT01/EUR` |
| Count / amount / currency | 1 / 250.00 / EUR (`UNKNOWN_COUNT` 0) |
| Deadline | next working day of `CASH_CALENDAR` at the control's cutoff (10:00, `CONTROL_TIME_ZONE`): 2026-11-16 10:00 UTC |
| Owner | `ZT_OWNER`, team `ZT_TEAM`, source C (the control covering `FICA_MA_INTERVALS`) |
| Evidence | `AKTYP/LAUFD/LAUFI = ZPAY/20261112/PAY01`; `JOBNAME/JOBCOUNT = ZT_FPY1_PAY01/06000001` (S4_BACKGROUND_JOB); `LAUFD/LAUFI = 20261112/PAY01` (FICA_PAYMENT_RUN); `INTERVAL = 2`; `JOBNAME/JOBCOUNT = ZT_FPY1_PAY01_W/06010002` (S4_BACKGROUND_JOB) |
| Evaluation | `FINDINGS`, complete |

The job monitor reports the cancelled parallel job itself (`JOB_CHILD_FAILED` under a finished root) - the board
links job and finding; the expected-run check sees the run started in time (OK).

## 5. Parameters (area CA_OPS, `docs/PARAMETERS.md`)

`XRUN_SOURCES` (`ZCL_CA_OPS_XRUN_SRC_JOBSCH`), `XRUN_CALENDAR_CLASS` (blank), `XRUN_LOOKBACK_DAYS` (1),
`XRUN_LATE_MIN` (30), `XRUN_EARLY_MIN` (60), `XRUN_MATCH_MIN` (720), `XRUN_SOURCE_STALE_MIN` (60), `XRUN_MAX_JOBS`
(5 000), `XRUN_WAITING_STATUSES` (P, S, Y); `MA_LOOKBACK_DAYS` (2), `MA_RUN_LIMIT_MIN` (120), `MA_SOURCE`
(`ZCL_CA_OPS_MA_SRC_JOBS`), `MA_RESOLVERS` (blank = `JOB_RESOLVERS`), `MA_MAX_RUNS` (200), `MA_MAX_INTERVALS` (500).
Messages 600-614 (expected runs) and 615-623 (mass activities) of `ZCA_OPS`; 624-629 free.

## 6. Proof offline

- ABAP Unit (doubles): `ZCL_CA_OPS_XRUN_SRC_JOBSCH` (weekdays, holiday, unknown calendar day, invalid run days, cap,
  weekday), `ZCL_CA_OPS_XRUN_MONITOR` (every verdict and stage, window, one job per run, patterns from the scheduler
  row, cap), `ZCL_CA_OPS_CHK_XRUN` (XRUN-01 ... XRUN-06, unknown source class; contract gaps empty),
  `ZCL_CA_OPS_MA_SRC_JOBS` (parent and intervals in creation order, states, other names, invalid pattern),
  `ZCL_CA_OPS_MA_DAO` (OSQL on `ZCA_OPS_MAACT` and `FKKMAKO`), `ZCL_CA_OPS_MA_CALENDAR`, `ZCL_CA_OPS_CHK_MA_INTERVAL`
  (MA-01 ... MA-05, two parents of one date, proposal only with the gap rule).
- Fixture spec `config/expected_runs/fixtures.json` (XRUN-01 never started, XRUN-02 predecessor not finished, XRUN-03
  stale scheduler source, XRUN-04 holiday, XRUN-05 source not readable, XRUN-06 failed before SAP; MA-01 scorecard 1,
  MA-02 interval failed, MA-03 overrun, MA-04 dunning below minimum, MA-05 runs not readable) and reference model
  `tools/abaptools/expected_runs.py`; root test `tools/tests/test_expected_runs.py`.
- Field references: only fields of the reference system's export (`TBTCO`, `TBTCP` through the job monitor's reads,
  `DPAYH` through the cash checks' reads, `FKKMAKO` `LAUFD`, `LAUFI`, `WAERS`, `MSALM`) - house check `ddic_fields`.

## 7. Limits and open items

- An interval of the delivered source is a parallel job of the run, not an interval of the mass activity framework
  (V300); a run's ID is unknown to it, so several runs of one activity on one date share their output (V304).
- Times of a plan are system time of the SAP server (V293); a scheduler in another time zone converts in its source.
- The core has no factory calendar of its own (decision D-P3).
- Nothing is started, held, released or restarted; restarts stay with the scheduler and the runbook.
