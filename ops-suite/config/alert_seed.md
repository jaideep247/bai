# Alert configuration — example rows (confirm before transport)

> **First principle:** who hears about a problem, how fast and how loud is configuration, never code.
> **Analogy:** a building's fire panel — zones (rules) are wired to sirens or the control room (channels) by the installer, not by the fire.

## ZCD_OPS_ALCHN

| CHANNEL | CLASS_NAME | DESTINATION | ACTIVE |
|---|---|---|---|
| EMAIL | ZCL_CD_OPS_CHN_EMAIL | *(blank — rule gives recipients)* | X |
| APPLOG | ZCL_CD_OPS_CHN_APPLOG | ZCD_OPS/ALERT | X |

## ZCD_OPS_ALRULE

RULE / CHECK / GROUP1 / GROUP2 patterns are **PCRE matched to the complete value, case ignored** (blank = any;
user decision 2026-11-06): `.*SLA.*` = any check code containing SLA, `RUN_LOCKED` = exactly that code. The
configuration app refuses a pattern that does not compile (message 418); check what a pattern captures with
`ZCD_OPS_PATTERN_CHECK` (areas ALERT_*). PE_AREA `*` is not a pattern (it means every area).

| RULE_ID | PE_AREA | MIN_SEVERITY | RULE_PATTERN | CHECK_PATTERN | MIN_RAG | ON_ABORT | CHANNEL | DESTINATION | DIGEST | MAX_ITEMS | THROTTLE_MIN | QUIET | ESCALATE_AFTER / DEST |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| EBS_BLOCK | EBS | B | | | | | EMAIL | payment-ops DL | X | 50 | 0 | — | 3 / RTB lead DL |
| EBS_ERROR | EBS | E | | | A | X | EMAIL | payment-ops DL | X | 50 | 60 | 22:00–06:00 | — |
| EBS_LOG | EBS | W | | | | | APPLOG | ZCD_OPS/EBS | X | 500 | 0 | — | — |
| FMON_PART | FMON | E | | .*PARTIAL.* | | | EMAIL | returns-ops DL | X | 50 | 0 | — | 2 / RTB lead DL |
| FMON_SLA | FMON | E | | .*SLA.* | | | EMAIL | payment-ops DL | X | 50 | 30 | — | 3 / RTB lead DL |
| NOC_AGING | FMON | E | | NOC_AGING.* | | | EMAIL | compliance DL | X | 100 | 1440 | — | — |
| HCK_RED | HCK | E | | | R | X | EMAIL | RTB support DL | X | 50 | 60 | 22:00–06:00 | 2 / RTB lead DL |
| ALL_ABORT | * | B | | | | X | EMAIL | RTB support DL | X | 20 | 15 | — | — |
| RUN_LOCKED | * | E | | RUN_LOCKED | | | EMAIL | RTB support DL | | 10 | 60 | — | — |

Priority (receiver side, `docs/ALERTING.md` — Priority mapping; acknowledgement targets proposed, confirm with RTB operations):

| RULE_ID | Priority | Acknowledge within |
|---|---|---|
| EBS_BLOCK, ALL_ABORT | P1 | 15 min, 24×7 |
| EBS_ERROR, FMON_PART, FMON_SLA, HCK_RED, RUN_LOCKED, NOC_AGING | P2 | 1 h in business hours |
| EBS_LOG | P3 | Next business day (morning report) |

ESC_OVERRIDE (new rule field, A46): `X` lets a due escalation pass the throttle window — suggested on
EBS_BLOCK and HCK_RED. Escalation counts consecutive runs of the area (a run without an alert of the rule ends
the series).

ZCD_OPS_ALLOG needs the **unique** secondary index `INT` (MANDT, INTENT_KEY, ATTEMPT) — create it in SE11
before go-live; it is what stops two dispatchers sending the same alert (A17). Status values: S sent, F failed,
T throttled, Q quiet, C claimed (in delivery), R repeat (carried-forward exception, not re-alerted), P partial.

Parameters (ZCA_PARAM area `CD_OPS`) for reports sent with `send( )`: `ALERT_MORNING` (morning report distribution list, LIST - **confirm**; a route other than MORNING in `HCK_MAIL_ROUTE` needs its own definition `ALERT_<route>`), `ALERT_DEFAULT` (fallback), `ALERT_ESCALATION_WINDOW_H` (default 24).

Rules of behaviour (proved by `ZCL_CD_OPS_ALERT_POLICY` / `ZCL_CD_OPS_ALERT_ROUTER` unit tests):
- Severity **B** (blocked, never posted) ignores quiet hours.
- Throttled (T) and quiet-hour (Q) decisions are logged in ZCD_OPS_ALLOG — nothing is silently dropped.
- A failing channel is logged as F and never aborts the run; the morning report's "alert delivery health" check counts F rows.
- `send( )` without recipients or on an inactive channel logs F **and raises** (A45).
- MAX_ITEMS keeps the most severe findings (B > E > W > I); the message names how many were held back (A63).
- Test-mode runs never alert.

## Core parameters — framework `ZCA_PARAM`, area `CD_OPS` (retention purge, `ZCD_OPS_PURGE`)

Definitions (value type, limits, delivered default) of every parameter: `config/param_definitions.csv`; example value rows to confirm per landscape: `config/param_values.csv` (format: `param-framework/docs/ONBOARDING.md` section 6a). Maintained in the framework app *Parameter areas* (`ZUI_CA_PARAM`), area `CD_OPS` - ZCD_OPS_PARAM is retired.

| Parameter | Delivered default | Meaning |
|---|---|---|
| RETENTION_DAYS_RUN | `400` | Runs and their findings older than this are purged — never a run that still holds an open, assigned or validly waived exception |
| RETENTION_DAYS_ALERT_LOG | `180` | Alert log rows (by send time) |
| RETENTION_DAYS_FMON_EVENT | `400` | FMON file events (by creation time) |
| RETENTION_DAYS_HCK_METRIC | `400` | HCK metric history (by measurement time; baselines need the history) |
| RETENTION_DAYS_FMON_PRISM | `400` | PRISM status API events (`ZCD_FMON_PRISM`, by receipt time); the file history stays in the FMON events |
| PURGE_PACKAGE_SIZE | `1000` | Rows (RUN: runs) deleted per package; commit after each package (INT, at least 1) |

Any value below 30 days is raised to 30 (`ZCL_CD_OPS_PURGE=>GC_MIN_DAYS`). A new purge target needs a definition `RETENTION_DAYS_<target>` (the portable check `param_definitions_complete` enumerates the targets).

## Monitor freshness — `ZCD_OPS_MONCFG` (configuration app *Alerting and monitor freshness*, entity *Monitor freshness*)

One row per payment engine area: minutes after the last completed run before the monitor counts as **stale**. The "as of" CDS views of the dashboards (`ZR_CD_FmonAsOf`, `ZR_CD_EbsAsOf`, `ZR_CD_HckAsOf`, overview `ZI_CD_OpsFreshU`) and the morning report's self-check (`HCK_SELF`, `PE_AREA_STALE`) read the **same** row, so they cannot disagree. Without a row the dashboards use the delivered value below and the self-check falls back to `HCK_MAX_AGE_H_<area>`, then `HCK_MAX_AGE_HOURS`.

| PE_AREA | STALE_AFTER_MIN | Why |
|---|---|---|
| FMON | 15 | Native SAP job every 5 minutes: 3 missed runs |
| EBS | 1560 | Daily run + 2 h slack (26 h) |
| HCK | 1560 | Daily morning report + 2 h slack (26 h) |

The delivered values equal the CDS fallback literals and their ABAP constants (`ZIF_CD_FMON_TYPES=>GC_DASHBOARD-STALE_AFTER_MIN`, `ZIF_CD_HCK_TYPES=>GC_PARAM_DEFAULT-MAX_AGE_HOURS` × 60) — portable check `cds_abap_parity`. Time zone per area: not configurable (time stamps are UTC); future extension.
