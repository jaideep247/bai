# SAP job monitor — every job failure of the client, linked to the job the scheduler saw

> **First principle:** an external scheduler sees only the job it started; the system must watch every job itself, link each failure to its parent and root, and keep the proof before the job tables are reorganised.
> **Analogy:** an airport baggage system — the airline (scheduler) sees the flight leave on time; the baggage tracker sees that one suitcase (a child job) never made it, names the flight it belonged to, and keeps the scan log after the belt records are wiped.

Status 2026-11-11: written and statically checked offline (abaplint 0 issues, house checks, tool tests); **nothing
activated, no ABAP Unit run** (VERIFY V58-V66, §12). Adopted by a consumer in an area of its own (§10).

## 1. What it reports

The monitor is two **registered checks** of the check registry (`ZIF_CA_OPS_CHECK`,
`docs/ADDING_A_BUSINESS_PROCESS.md`), run by the generic runner `ZCA_OPS_CHECK_RUN` in a fast schedule group of the
consumer's area (e.g. `FAST` every 5 minutes). Every job **of the client** is watched (TBTCO is cross-client: filter
`AUTHCKMAN` = logon client), not only configured names; `JOB_EXCLUDE_PCRE` drops noise (PCRE list, complete name).

| Check class | Check code | Severity | Rule |
|---|---|---|---|
| `ZCL_CA_OPS_CHK_JOB_FAIL` (incremental) | `JOB_CHILD_FAILED` | E | A job failed (cancelled, or job log errors) and a linked ancestor exists whose **root** - the job the external scheduler started - did **not** abort: finished (the scheduler shows green) or still active (a scheduler program that starts parallel worker jobs ends *finished* although a worker failed; the board shows the root's live status). One finding per failed job; reference = the root job |
| | `JOB_ABORTED` | E | A cancelled job (TBTCO status `A`) without such an ancestor - its own scheduler or SM37 shows the abort, or its root aborted too |
| | `JOB_LOG_ERROR` | W | A finished job (status `F`) of a watched program (`JOB_LOG_PROGRAMS`, exact names) whose job log holds lines of the types `JOB_LOG_ERROR_TYPES` (E, A, X) |
| `ZCL_CA_OPS_CHK_JOB_STATE` (snapshot) | `JOB_LONG_RUNNING` | W | Active (`R`, `Z`) longer than `JOB_LONG_RUNNING_MIN` minutes - long-running or orphaned |
| | `JOB_NOT_STARTED` | W | Waiting (`JOB_WAITING_STATUSES`: released `S`, ready `Y`) `JOB_NOT_STARTED_MIN` minutes after its planned start (event-triggered jobs have none and are left out) |
| both | `JOB_READ_CAPPED` | W, notify | A read reached its cap; the window continues in the next run (FAIL) / the snapshot is partial (STATE) |
| | `JOB_CONFIG_INVALID` | W | A pattern of the monitor does not compile (`JOB_EXCLUDE_PCRE`, a scheduler row) - reported and left out, never "no exclusion" |
| | `JOB_PLUGIN_FAILED` | W | A resolver, enricher or claim could not be created or raised (trace in DETAILS); the failures are still reported without its links / objects |
| | `JOB_LOG_UNREADABLE` | W | A job log could not be read (message 123 of the reader, trace and error class in the finding): that job is not judged on its log, its other evidence is kept |

**What is not detected here.** A job that was never scheduled at all is an *absence*, not a failure of a job: the
expected-events calendar (job X by time T, after job Z) stays with the consumer (e.g. its job cycle checks); the monitor
reports released jobs that did not start and its own staleness (`CHECK_STALE_MIN_<area>`, runner `CHECK_FAILED`). A job
without a linked parent is not proven independent - the board says *no link found*, never *no parent*.

Object type `JOB`, object key `<job name>/<job count>`, rule ID `JOBMON`; the runner stamps GROUP1 = process and
GROUP2 = check. A job **claimed** by another monitor (§6) gets severity I and action NOTIFY: evidence on the board,
no exception, no alert. Texts: messages 110-129 of `ZCA_OPS`; the finding's CONTEXT holds labelled lines (parent,
root, scheduler job, first step, application logs, business objects), DETAILS the error lines of the job log.

**Auto-resolve.** `JOB_FAIL` is incremental - a later window never re-reads a job - so its result is always
**partial**: an exception is resolved by its owner in the exceptions app, never because the job is no longer shown.
`JOB_STATE` reads every active and waiting job each run, so it is complete (unless capped) and the runner resolves the
exception of a job that has since ended or started.

## 2. Architecture

```
 job ZCA_OPS_CHECK_RUN (area, FAST)                                    SAP (read only)
   └ ZCL_CA_OPS_CHECK_RUNNER ── ZCL_CA_OPS_CHK_JOB_FAIL / _STATE
                                  └ ZCL_CA_OPS_JOB_MONITOR (engine, no SQL)
                                      ├ ZIF_CA_OPS_JOB_DAO / ZCL_CA_OPS_JOB_DAO ──────▶ TBTCO, TBTCP, BALHDR
                                      │                                         └──▶ ZCA_OPS_JOB* (evidence, watermark,
                                      │                                               scheduler rows)
                                      ├ ZCL_CA_OPS_JOB_LOG_CACHE (budget) ─ ZIF_CA_OPS_JOB_LOG
                                      │      └ ZCL_CA_OPS_JOB_LOG ── BP_JOBLOG_READ (TEST-SEAM)
                                      ├ resolvers ZIF_CA_OPS_JOB_RESOLVER (JOB_RESOLVERS, in order)
                                      ├ enrichers ZIF_CA_OPS_JOB_ENRICHER (JOB_ENRICHERS) - consumer's business context
                                      └ claims    ZIF_CA_OPS_JOB_CLAIM    (JOB_CLAIMS)    - de-duplication
   findings ─▶ store (exceptions ZUI_CA_OPS_EXC, alerts, daily review, area dashboard)
 board ZUI_CA_OPS_JOBS (read only) ◀── ZR_CA_OpsJobFailure over ZCA_OPS_JOB + live TBTCO + open exception
```

A check never commits: the evidence and the watermark are written by `ZIF_CA_OPS_JOB_DAO=>SAVE` (insert or replace by
key) in the runner's LUW, committed with the findings, rolled back with an aborted run, and **never in test mode**.
This is the one documented exception to "a check never persists" of `ZIF_CA_OPS_CHECK`: the evidence is the
monitor's own data (`OWN_DATA` = X, purge target `JOB_EVIDENCE`).

**LUW and concurrency.** One commit owner: the runner (`COMMIT WORK` of the store after the findings); the monitor,
its DAO, resolvers and plug-ins never commit or roll back. Inside `FAILURES` every read - job logs included - happens
before the first write, so the run's writes are evidence + watermark only, all insert-or-replace by key (idempotent: a
run repeated after an abort writes the same rows). `BP_JOBLOG_READ` may read a log through the server that wrote it;
should that open a database commit (VERIFY V60), an earlier check of the same run could have its evidence committed
early - harmless, as the rows are idempotent and the watermark of `FAILURES` is written after its own reads. Two runs
of the same area and group are excluded by the runner's lock (`RUN_LOCKED`); a second area running the monitor keeps its
own watermark (one monitor per client is the design, §10). No enqueue is taken on SAP job objects. Nothing is ever written to a SAP table: no job is
released, cancelled, changed or restarted - restarts stay with the external scheduler and the consumer's runbook.

## 3. Window, watermark and caps (`ZCL_CA_OPS_JOB_MONITOR=>WINDOW`)

| Situation | Window read |
|---|---|
| First run of an area and check (no row in `ZCA_OPS_JOBWM`) | now − `JOB_LOOKBACK_MIN` (60) → now |
| Later runs | watermark − `JOB_OVERLAP_MIN` (10) → now (a job whose end time is written late is not lost) |
| Watermark after now (clock moved back) | now → now: nothing is skipped, the next run reads normally |

`JOB_FAIL` reads the cancelled jobs (status `A`) and the finished jobs of watched programs (status `F`, a step of
`JOB_LOG_PROGRAMS`) whose **end** lies in the window, oldest end first, each read capped at `JOB_MAX_JOBS` (2000,
ceiling 50 000). The **new watermark** is the end of the window, or - when a read reached its cap - the end of its
last row read; when the job log budget (`JOB_MAX_LOG_READS`, 50, ceiling 500 per run, shared by detection, resolvers
and evidence) stops the evaluation of a finished job, the watermark stays at that job's end. Jobs of the overlap that
are already kept as a failure (`ZIF_CA_OPS_JOB_DAO=>REPORTED`, failure codes) are dropped: **no job is reported
twice**. History is never re-scanned. Times are TBTCO's server date and time, compared with the server clock
(`ZIF_CA_OPS_CLOCK=>TODAY` / `TIME`).

Job logs are read only for finished jobs of watched programs (detection), failed jobs (evidence) and resolver
candidates - never for every job; each log once per run (`ZCL_CA_OPS_JOB_LOG_CACHE`).

## 4. Parent / child linking - resolvers and their evidence quality

`JOB_RESOLVERS` lists the resolver classes in order. For each failed job (then for each new ancestor, up to
`JOB_MAX_DEPTH` = 3 levels, ceiling 10; a job already known is never followed again - no cycle) the first resolver
that returns a link wins; a resolver works set-based (one call for all jobs of a level) through the monitor's data
access and log reader. `children( )` of the same resolvers gives the children of each failing job's parent (context
on the board, at most `JOB_MAX_CHILDREN` = 50 per parent). Every link carries the resolver ID and its **evidence
quality**: **C confirmed** by a key, **P probable** by a heuristic.

| Resolver | Class | Link | Quality | Delivered | VERIFY |
|---|---|---|---|---|---|
| (a) FIELD | `ZCL_CA_OPS_JOB_RES_FIELD` | Two TBTCO fields that hold the parent job name and count, named in `JOB_PARENT_FIELDS`; checked against the runtime DDIC of TBTCO (RTTI) before any read - a field the release does not have is refused (127), never put into SQL; blank parameter = off | C | **off** (not in the default list, blank parameter) | V62 - whether 7.58 has such fields at all; V63 dynamic SQL |
| (b) EVENT | `ZCL_CA_OPS_JOB_RES_EVENT` | A job started by an event of `JOB_EVENT_IDS` (default `SAP_END_OF_JOB`, "start after job") whose EVENTPARM is the predecessor's job name (32) and count (8); kept only when that job exists; children by the same event parameter | C | **on** | V61 - event ID and parameter layout. An event raised by a program (`BP_EVENT_RAISE`) names no job: left to the heuristic |
| (c) JOBLOG | `ZCL_CA_OPS_JOB_RES_JOBLOG` | A job log line of a configured message (`JOB_CHILD_MSG_IDS`, `MSGID/MSGNO` list) whose text matches `JOB_CHILD_MSG_PCRE` (group 1 job name, group 2 job count) names the child; parents: the heuristic's candidates whose log names the child | C | **off** (blank parameters) | V62 - the message announcing a released job |
| (d) parallel processing | consumer plug-in (e.g. a fictitious `ZCL_XY_JOB_RES_PARALLEL`) | The worker jobs of one run of an application's parallel processing framework (job name pattern with a run token, scheduler program, time window) | P (C once linked through the application's run tables) | consumer | consumer's own VERIFY |
| (e) HEURISTIC | `ZCL_CA_OPS_JOB_RES_HEUR` | The **only** job that ran when the child was created (TBTCO SDLDATE / SDLTIME), has a step of the child's scheduling user (SDLUNAME = the parent step's AUTHCKNAM - the user a releasing program runs under) and, when `JOB_PARENT_PROGRAMS` is maintained, a step of one of those programs; two candidates = **no link** (ambiguous, never a guess) | P | **on** (last) | - |

Delivered `JOB_RESOLVERS` = `ZCL_CA_OPS_JOB_RES_EVENT,ZCL_CA_OPS_JOB_RES_HEUR`; FIELD goes first and JOBLOG before
the heuristic once their parameters are confirmed, a consumer's resolver before the heuristic.

## 5. The granularity chain kept as evidence

The standard reorganisation deletes job headers, steps and logs (SM65 / RSBTCDEL2), spool requests (SP01 / RSPO1041)
and application logs (SLG2 expiry). The monitor keeps **only what proves the failure** and is deleted by them - nothing
that stays readable (program texts, variant contents, the spool itself, application log messages, business documents).

| Table (A) | Key | Fields and why each is needed |
|---|---|---|
| `ZCA_OPS_JOB` | job name, job count | `AREA` (read authorisation of the board), `BUKRS` (company code from an enricher: isolation), `JOB_ROLE` F failure / A ancestor / C child context, `CHECK_CODE` / `SEVERITY` / `OBJECT_KEY` (join to the finding and its open exception), `STATUS` at detection (TBTCO is reorganised), planned / created / start / end date and time (proof of the time-window links and of long-running / not-started), `SCHED_USER` (the heuristic's link), `SERVER`, `EVENT_ID` / `EVENT_PARM` (proof of an event link), `PARENT_*` with `LINK_RESOLVER` / `LINK_QUALITY`, `ROOT_*` / `ROOT_STATUS` / `DEPTH` (what the scheduler saw), `SCHED_FOLDER` / `SCHED_JOB` / `CRITICALITY` (external scheduler job of the root at detection), `LOG_ERRORS`, `FAILED_CHILDREN`, `CLAIMED_BY` (de-duplication), `DETECTED_AT` / `DETECTED_ON` / `RUN_ID` (when and by which run; purge; "today") |
| `ZCA_OPS_JOBSTEP` | + step | program, variant, step user, spool list ID (TBTCP is reorganised with the job) |
| `ZCA_OPS_JOBMSG` | + line | the error / abort lines of the job log only (`JOB_LOG_ERROR_TYPES`, at most `JOB_MAX_MESSAGES` = 20 per job): message class, number, type, text, time |
| `ZCA_OPS_JOBALOG` | + log number | BALHDR header of an application log linked to the job: object / subobject, external number, date / time, user, program, error and abort counters, quality - **P**: no BALHDR field names the job, the link is step user + step program + run time (at most `JOB_MAX_APPLOGS` = 20 per job; the messages stay in SLG1 until expiry) |
| `ZCA_OPS_JOBBO` | + object number | business objects of the consumer's enrichers: type, key, label, company code, count, quality |
| `ZCA_OPS_JOBWM` | area, check ID | the watermark (end of the last window read completely, run ID) - never purged |
| `ZCA_OPS_JOBSCH` (C) | scheduler folder, job | the external scheduler's jobs and the SAP job names (PCRE, complete name) each starts, criticality H / M / L, active, sequence (first match wins) - configuration app `ZUI_CA_OPS_CFG`, entity *Scheduler jobs*; the board shows *scheduler job → SAP root job → failed child* |

Indexes (DDL comments, VERIFY V65): `ZCA_OPS_JOB` DET (`DETECTED_AT`, purge), PAR (parent: children facet), ROL
(area, role, date: list report). Purge target **`JOB_EVIDENCE`** (`ZCL_CA_OPS_JOB_PURGE`, registry row of
`ZCA_OPS_PURGE` delivered by the consumer, retention `RETENTION_DAYS_JOB_EVIDENCE` = 180 days, at least 30): a package
of jobs detected before the cutoff with their steps, lines, log links and objects (child keys read for the package,
deleted from the table of keys).

## 6. Enrichers, claims, scheduler mapping

- **Enricher** (`ZIF_CA_OPS_JOB_ENRICHER`, `JOB_ENRICHERS` in order): one call per run with the failed jobs and their
  ancestors and their steps; adds business objects and sees those of the enrichers before it (e.g. a business run found
  from a parallel processing run). When the objects of a job name exactly one company code, the job's finding and evidence
  carry it (company-code isolation of the exceptions app and the board).
- **Claim** (`ZIF_CA_OPS_JOB_CLAIM`, `JOB_CLAIMS`): another monitor that already reports a job's **own** failure
  (e.g. a consumer's named job cycles in its daily health report) claims it; the job monitor keeps the evidence with
  an information finding *failure reported by …* - one alert per failure. A failed child of a claimed job is still
  reported (the other monitor does not see children).
- **Scheduler mapping** (`ZCA_OPS_JOBSCH`): the root job's name is matched to the active rows in sequence; the first
  matching row's folder / job / criticality go to the finding's context and the evidence. Seed the rows from the
  consumer's job cycle configuration and complete them from the scheduler's export.

## 7. Performance (TBTCO can hold hundreds of thousands of rows)

| Read | Bound | Index (VERIFY-SE11 V58) |
|---|---|---|
| Cancelled jobs of the window | `STATUS = 'A'`, end date / time in the window, `AUTHCKMAN`, `UP TO JOB_MAX_JOBS` | TBTCO index on STATUS (+ ENDDATE); else a secondary index STATUS, ENDDATE, ENDTIME |
| Finished jobs of watched programs | `STATUS = 'F'`, end in the window, join TBTCP on the key, `PROGNAME IN` exact names, capped | as above + TBTCP primary key |
| Active / waiting jobs | status list, start / planned start before a point, capped | STATUS |
| Resolver reads | key (FOR ALL ENTRIES), event parameter, created / running in a few minutes' window, capped | TBTCO key; EVENTID; SDLDATE (V58) |
| Steps, application logs | key; BALHDR date window + user + program, capped | TBTCP key; BALHDR ALDATE (V59) |
| Job logs | `JOB_MAX_LOG_READS` per run (50) | `BP_JOBLOG_READ` reads the log file / TBTCO-JOBLOG |

Volume: a consumer with heavy parallel processing (hundreds of worker jobs an hour on peak days) is the design case. A
5-minute window holds a few hundred ended jobs at peak; the cancelled ones are few. One FAST
run is expected well below a minute (QA1 at peak: VERIFY V58 with ST05 / PlanViz). A cap reached at peak is reported
(`JOB_READ_CAPPED`) and the next run continues from the watermark - nothing is lost. Patterns are never sent to SQL
(PCRE in ABAP after the bounded read).

## 8. The board `ZUI_CA_OPS_JOBS` (read only)

Service `ZUI_CA_OPS_JOBS` (binding `ZUI_CA_OPS_JOBS_O4`, OData V4 - UI), list report and object page *SAP job
failures* on `ZC_CA_OpsJobFailure` (root `ZR_CA_OpsJobFailure` over `ZCA_OPS_JOB`, left outer joins to TBTCO for the
**live status** - blank once reorganised - and to `ZI_CA_OpsJobExc` for the **open exception**).

| Part | Content |
|---|---|
| List (default filter *Failure* = X, newest first) | job, count, check code (coloured by severity), status at detection, status now, parent, root, scheduler job, start / end, server, scheduled by, company code, detected at, exception status (intent navigation to the exceptions app `ZCAOpsException-manage`) |
| Object page facets | *Job* (header, dates, server, user, error lines count, reported by); *Parent, root and scheduler job* (parent with resolver and quality, root and its status, depth, scheduler folder / job / criticality, start event); *Exception* (status, owner, due date; assign / resolve in `ZUI_CA_OPS_EXC`); *Steps* (program, variant, user, spool); *Job log errors*; *Application logs* (SLG1 by log number); *Child jobs* (self association: jobs kept with this job as parent, with their status - and navigation to the parent); *Business objects* |
| Overview cards (a consumer exposes `ZC_CA_OpsJobFailure`) | KPI *Job failures today*: data points `FailuresToday`, `AbortedToday`, `ChildFailedToday`, `NotStartedToday`, `LongRunningToday` (summed after the DCL, server date of detection); list *Job failures - today* (variants `Today`) |
| Job log lines | The board shows the kept error lines of a job log to every reader of the area - in SM37 a job log of another user needs `S_BTCH_JOB` `PROT`. The lines are the error / abort messages only; DETAILS of a finding (shown in e-mails only by rules with `SHOW_AMOUNTS`) carries them, the CONTEXT never. A consumer whose job logs may hold personal data sets `JOB_MAX_MESSAGES` = 0 |
| Read access | DCL `ZC_CA_OPSJOBFAILURE`: `ZCA_OPS` 03 for the area and, for a job with a company code, the company code (rule of `auth_zca_ops.md` §3c) on the root and every facet view |
| Launchpad | semantic object / action `ZCAJobFailure-display` → the list report; role: `S_SERVICE` `ZUI_CA_OPS_JOBS_O4` + `ZCA_OPS` 03 of the consumer's area |
| Tests | `ZCL_CA_OPS_JOB_CDS_TEST` (counters of today, open exception joined, live status until the reorganisation) |

## 9. Objects and tests

| Object | Test (ABAP Unit, doubles) |
|---|---|
| `ZIF_CA_OPS_JOB_TYPES`, `ZIF_CA_OPS_JOB_DAO`, `ZIF_CA_OPS_JOB_LOG`, `ZIF_CA_OPS_JOB_RESOLVER`, `ZIF_CA_OPS_JOB_ENRICHER`, `ZIF_CA_OPS_JOB_CLAIM` | - |
| `ZCL_CA_OPS_JOB_MONITOR` | 15: detection rules, child under a finished / cancelled / running root (recursive), log errors, log budget, overlap, exclusion, claim, test mode, window (look-back, overlap, clock), cap, failing resolver, company code and scheduler job, long-running / not started |
| `ZCL_CA_OPS_JOB_DAO` | OSQL on TBTCO, TBTCP, BALHDR and the monitor's tables (9) |
| `ZCL_CA_OPS_JOB_RES_FIELD` / `_EVENT` / `_JOBLOG` / `_HEUR` | 4 / 4 / 4 / 4 with data access and log doubles (DDIC check of FIELD by RTTI) |
| `ZCL_CA_OPS_JOB_LOG` | TEST-SEAM `JOBLOG_READ` (3) - the function module is never called in tests |
| `ZCL_CA_OPS_JOB_LOG_CACHE`, `ZCL_CA_OPS_JOB_TIME` | 2, 5 |
| `ZCL_CA_OPS_CHK_JOB_FAIL`, `ZCL_CA_OPS_CHK_JOB_STATE` | 1 each (delegation, partial / complete) |
| `ZCL_CA_OPS_JOB_PURGE` | OSQL (1) |
| CDS `ZR_CA_OpsJobFailure` | `ZCL_CA_OPS_JOB_CDS_TEST` (3) |

## 10. Adopting it (a consumer)

1. Area of its own (decision of `ADDING_A_BUSINESS_PROCESS.md` §1), process with the two checks in a fast schedule group
   (`CLASS_NAME` = `ZCL_CA_OPS_CHK_JOB_FAIL`, `ZCL_CA_OPS_CHK_JOB_STATE`), `OWN_DATA` = X, purge target row
   `JOB_EVIDENCE` / `ZCL_CA_OPS_JOB_PURGE` / `CA_OPS` / `RETENTION_DAYS_JOB_EVIDENCE`, control, alert rule (severity E).
2. Value rows: `JOB_LOG_PROGRAMS` (programs whose job log is checked), `JOB_PARENT_PROGRAMS`, `JOB_EXCLUDE_PCRE`, its
   own resolver / enricher / claim classes in `JOB_RESOLVERS` / `JOB_ENRICHERS` / `JOB_CLAIMS` once confirmed;
   `CHECK_STALE_MIN_<area>` for the dashboard freshness.
3. Scheduler rows in `ZCA_OPS_JOBSCH`; roles with `ZCA_OPS` for the area (03 board, 02 operator, 85 approver, 16 job
   user) and **`S_BTCH_JOB` JOBACTION `PROT`, JOBGROUP `*`** for the job user (job logs of other users' jobs, V64) - no
   other batch authorisation.
4. Schedule `ZCA_OPS_CHECK_RUN` with the area and the fast group every 5 minutes; test mode first.

One monitor per client is enough (it watches every job of the client); a second area running it keeps its own
watermark and would report the same jobs again.

## 11. Parameters

`docs/PARAMETERS.md` (prefix `JOB_`, area `CA_OPS`).

## 12. VERIFY

The offline lint does **not** check SAP DDIC fields: a probe with an invented TBTCO field in the DAO lint-passed
(2026-11-11). Every TBTCO / TBTCP / BALHDR / TBTC5 field and the function module interface is therefore unverified
until V58-V60 are closed in DV1.

`docs/VERIFY.md` V58-V66 (framework); a consumer keeps the VERIFY items of its own plug-ins, job naming and scheduler
export in its own release documentation.
