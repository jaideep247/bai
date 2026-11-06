# Alert configuration — example rows (confirm before transport)

> **First principle:** who hears about a problem, how fast and how loud is configuration, never code.
> **Analogy:** a building's fire panel — zones (rules) are wired to sirens, pagers or the control room (channels) by the installer, not by the fire.

## ZCD_OPS_ALCHN

| CHANNEL | CLASS_NAME | DESTINATION | ACTIVE |
|---|---|---|---|
| EMAIL | ZCL_CD_OPS_CHN_EMAIL | *(blank — rule gives recipients)* | X |
| APPLOG | ZCL_CD_OPS_CHN_APPLOG | ZCD_OPS/ALERT | X |
| HTTP | ZCL_CD_OPS_CHN_HTTP | ZCD_OPS_WEBHOOK *(SM59 destination, created by Basis)* | |

## ZCD_OPS_ALRULE

| RULE_ID | PE_AREA | MIN_SEVERITY | RULE_PATTERN | CHECK_PATTERN | MIN_RAG | ON_ABORT | CHANNEL | DESTINATION | DIGEST | MAX_ITEMS | THROTTLE_MIN | QUIET | ESCALATE_AFTER / DEST |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| EBS_BLOCK | EBS | B | | | | | EMAIL | payment-ops DL | X | 50 | 0 | — | 3 / RTB lead DL |
| EBS_ERROR | EBS | E | | | A | X | EMAIL | payment-ops DL | X | 50 | 60 | 22:00–06:00 | — |
| EBS_LOG | EBS | W | | | | | APPLOG | ZCD_OPS/EBS | X | 500 | 0 | — | — |
| FMON_PART | FMON | E | | *PARTIAL* | | | EMAIL | returns-ops DL | X | 50 | 0 | — | 2 / RTB lead DL |
| FMON_SLA | FMON | E | | *SLA* | | | EMAIL | payment-ops DL | X | 50 | 30 | — | 3 / RTB lead DL |
| NOC_AGING | FMON | E | | NOC_AGING* | | | EMAIL | compliance DL | X | 100 | 1440 | — | — |
| HCK_RED | HCK | E | | | R | X | EMAIL | RTB support DL | X | 50 | 60 | 22:00–06:00 | 2 / RTB lead DL |
| ALL_ABORT | * | B | | | | X | HTTP | ZCD_OPS_WEBHOOK | X | 20 | 15 | — | — |
| RUN_LOCKED | * | E | | RUN_LOCKED | | | EMAIL | RTB support DL | | 10 | 60 | — | — |

Priority (receiver side, `docs/ALERTING.md` — Priority mapping; acknowledgement targets proposed, confirm with RTB operations):

| RULE_ID | Priority | Acknowledge within |
|---|---|---|
| EBS_BLOCK, ALL_ABORT | P1 | 15 min, 24×7 |
| EBS_ERROR, FMON_PART, FMON_SLA, HCK_RED, RUN_LOCKED, NOC_AGING | P2 | 1 h in business hours |
| EBS_LOG | P3 | Next business day (morning report) |

For a webhook receiver map `dedupKey` to the de-duplication field (ServiceNow *Message key*, PagerDuty `dedup_key`).

ESC_OVERRIDE (new rule field, A46): `X` lets a due escalation pass the throttle window — suggested on
EBS_BLOCK and HCK_RED. Escalation counts consecutive runs of the area (a run without an alert of the rule ends
the series).

ZCD_OPS_ALLOG needs the **unique** secondary index `INT` (MANDT, INTENT_KEY, ATTEMPT) — create it in SE11
before go-live; it is what stops two dispatchers sending the same alert (A17). Status values: S sent, F failed,
T throttled, Q quiet, C claimed (in delivery), R repeat (carried-forward exception, not re-alerted), P partial.

ZCD_OPS_PARAM for reports sent with `send( )`: `ALERT_MORNING` (morning report distribution list), `ALERT_DEFAULT` (fallback), `ALERT_ESCALATION_WINDOW_H` (default 24).

Rules of behaviour (proved by `ZCL_CD_OPS_ALERT_POLICY` / `ZCL_CD_OPS_ALERT_ROUTER` unit tests):
- Severity **B** (blocked, never posted) ignores quiet hours.
- Throttled (T) and quiet-hour (Q) decisions are logged in ZCD_OPS_ALLOG — nothing is silently dropped.
- A failing channel is logged as F and never aborts the run; the morning report's "alert delivery health" check counts F rows.
- `send( )` without recipients or on an inactive channel logs F **and raises** (A45).
- MAX_ITEMS keeps the most severe findings (B > E > W > I); the message names how many were held back (A63).
- Test-mode runs never alert.

## Core parameters — `ZCD_OPS_PARAM` (retention purge, `ZCD_OPS_PURGE`)

| PARAM_NAME | PARAM_VALUE | Meaning |
|---|---|---|
| RETENTION_DAYS_RUN | `400` | Runs and their findings older than this are purged — never a run that still holds an open, assigned or validly waived exception |
| RETENTION_DAYS_ALERT_LOG | `180` | Alert log rows (by send time) |
| RETENTION_DAYS_FMON_EVENT | `400` | FMON file events (by creation time) |
| RETENTION_DAYS_HCK_METRIC | `400` | HCK metric history (by measurement time; baselines need the history) |
| PURGE_PACKAGE_SIZE | `1000` | Rows (RUN: runs) deleted per package; commit after each package |

Any value below 30 days is raised to 30 (`ZCL_CD_OPS_PURGE=>GC_MIN_DAYS`).
