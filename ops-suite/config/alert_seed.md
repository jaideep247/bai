# Alert configuration — example rows (confirm before transport)

> **First principle:** who hears about a problem, how fast and how loud is configuration, never code.
> **Analogy:** a building's fire panel — zones (rules) are wired to sirens or the control room (channels) by the installer, not by the fire.

## ZCD_OPS_ALCHN

| CHANNEL | CLASS_NAME | DESTINATION | ACTIVE |
|---|---|---|---|
| EMAIL | ZCL_CD_OPS_CHN_EMAIL | *(blank — rule gives the SO23 list)* | X |
| APPLOG | ZCL_CD_OPS_CHN_APPLOG | ZCD_OPS/ALERT | X |

**SLG1 kept to a minimum (user decision 2026-11-07).** No delivered rule writes the application log: findings are
already in `ZCD_OPS_FINDING` (dashboards, morning report), alert attempts in `ZCD_OPS_ALLOG`, parameter errors in the
morning check `PARAM_INVALID`. The APPLOG channel stays available for a rule that explicitly needs SLG1 — keep such a
rule to severity E or higher, DIGEST = X (one log per run, not per finding) and a small MAX_ITEMS.

## E-mail recipients — SO23 shared distribution lists (user decision 2026-11-07)

E-mail DESTINATION and ESCALATION_DEST hold **names of SAPoffice shared distribution lists (SO23)**, comma
separated — never mail addresses. Support adds or removes people in SO23; whoever is on the list when the
alert is sent receives it, with no transport and no change in the suite. Names are upper case, at most
12 characters (SO_OBJ_NAM). The configuration app refuses a name that is not a shared list (message 419),
and the channel refuses the route before anything is sent if a list was deleted later (027, logged F).

| SO23 list (proposed — confirm) | Who | Used by |
|---|---|---|
| ZCD_PAYOPS | Payment operations | EBS_BLOCK, EBS_ERROR, FMON_SLA, FMON_BAIDL, FMON_REGEN |
| ZCD_RETOPS | Returns / NOC operations | FMON_PART |
| ZCD_COMPL | Compliance | NOC_AGING |
| ZCD_RTBSUP | RTB support | HCK_RED, HCK_RECON, ALL_ABORT, RUN_LOCKED, morning report |
| ZCD_RTBLEAD | RTB lead (escalation) | ESCALATION_DEST of EBS_BLOCK, FMON_PART, FMON_SLA, FMON_BAIDL, FMON_REGEN, HCK_RED, HCK_RECON |

## ZCD_OPS_ALRULE

RULE / CHECK / GROUP1 / GROUP2 patterns are **PCRE matched to the complete value, case ignored** (blank = any;
user decision 2026-11-06): `.*SLA.*` = any check code containing SLA, `RUN_LOCKED` = exactly that code. The
configuration app refuses a pattern that does not compile (message 418); check what a pattern captures with
`ZCD_OPS_PATTERN_CHECK` (areas ALERT_*). PE_AREA `*` is not a pattern (it means every area).

| RULE_ID | PE_AREA | MIN_SEVERITY | RULE_PATTERN | CHECK_PATTERN | MIN_RAG | ON_ABORT | CHANNEL | DESTINATION | DIGEST | MAX_ITEMS | THROTTLE_MIN | QUIET | ESCALATE_AFTER / DEST |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| EBS_BLOCK | EBS | B | | | | | EMAIL | ZCD_PAYOPS | X | 50 | 0 | — | 3 / ZCD_RTBLEAD |
| EBS_ERROR | EBS | E | | | A | X | EMAIL | ZCD_PAYOPS | X | 50 | 60 | 22:00–06:00 | — |
| FMON_PART | FMON | E | | .*PARTIAL.* | | | EMAIL | ZCD_RETOPS | X | 50 | 0 | — | 2 / ZCD_RTBLEAD |
| FMON_SLA | FMON | E | | .*SLA.* | | | EMAIL | ZCD_PAYOPS | X | 50 | 30 | — | 3 / ZCD_RTBLEAD |
| FMON_BAIDL | FMON | E | | STAGE_DEADLINE_MISSED | | | EMAIL | ZCD_PAYOPS | X | 10 | 0 | — | 6 / ZCD_RTBLEAD |
| NOC_AGING | FMON | E | | NOC_AGING.* | | | EMAIL | ZCD_COMPL | X | 100 | 1440 | — | — |
| FMON_REGEN | FMON | E | | FILE_REGENERATED_NOT_FAILED\|PRISM_DUPLICATE_NAME\|REGENERATION_MISSING | | | EMAIL | ZCD_PAYOPS | X | 20 | 0 | — | 2 / ZCD_RTBLEAD |
| HCK_RED | HCK | E | | | R | X | EMAIL | ZCD_RTBSUP | X | 50 | 60 | 22:00–06:00 | 2 / ZCD_RTBLEAD |
| HCK_RECON | HCK | E | | (RECON_BREAK\|RECON_SUBLEDGER_BREAK\|STRIPE_GROUP_BREAK) | | | EMAIL | ZCD_RTBSUP | X | 50 | 0 | — | 2 / ZCD_RTBLEAD |
| ALL_ABORT | * | B | | | | X | EMAIL | ZCD_RTBSUP | X | 20 | 15 | — | — |
| RUN_LOCKED | * | E | | RUN_LOCKED | | | EMAIL | ZCD_RTBSUP | | 10 | 60 | — | — |

**Regenerated files (facts confirmed by the user 2026-11-07).** `FMON_REGEN` sends `FILE_REGENERATED_NOT_FAILED` (B: a possible duplicate payment file to the bank / IRIS — also from the instant PRISM unit, within seconds), `PRISM_DUPLICATE_NAME` and `REGENERATION_MISSING` to payment operations at once (THROTTLE_MIN 0), escalation to `ZCD_RTBLEAD` after 2 runs. `FILE_REPLACED` is information (severity I) and alerts nobody. The CHECK_PATTERN is PCRE matched to the complete check code (`|` = or).

**Three-way reconciliation (A_RECON_3WAY, 2026-11-07).** `HCK_RECON` routes the true breaks of the
reconciliation - bank <> G/L (`RECON_BREAK`, also unmatched ACH assignment groups), G/L <> payment engine
control total (`RECON_SUBLEDGER_BREAK`) and the Stripe descriptor group (`STRIPE_GROUP_BREAK`), all E - to RTB
support and escalates to the RTB lead after 2 consecutive runs, as `HCK_RED` does; THROTTLE_MIN 0 and no quiet
window (the morning report runs once a day). Timing, cut-off and a pending redeposit (`RECON_TIMING`, I) and
the variance buckets (`RECON_VARIANCE`, W) are never alerted: they are listed in the report and on the dashboard.
`HCK_RED` matches the same E findings in a red run, so the digest can arrive twice (one per rule); to keep only
`HCK_RECON` give `HCK_RED` the CHECK_PATTERN `(?!RECON_|STRIPE_GROUP_).*` (PCRE, complete value) - a decision of
RTB operations, not delivered. In the table above `\|` is the PCRE alternation `|` (escaped for Markdown).

**BAI processing deadline (user requirement 2026-11-07, "alert if BAI is not processed until 10 AM").**
`FMON_BAIDL` additionally has GROUP1_PATTERN `BAI_(JPMC|BOA)_IN` (interfaces; PCRE, complete value) and
GROUP2_PATTERN blank (every condition - GROUP2 carries `NOT_RECEIVED` / `NOT_IMPORTED` / `NOT_POSTED`, so a
second rule may route one condition elsewhere). The deadline rows (`ZCD_FMON_SLA` kind DEADLINE, `config/fmon_seed.md`)
make the finding due at 10:00 US Central (`FMON_TIME_ZONE` = CST); the 5-minute FMON job raises it in the first run after
10:00 (10:00-10:05). Later runs carry the open exception forward and are **not alerted again** (status R in
ZCD_OPS_ALLOG); after 6 consecutive runs (30 minutes) still open the escalation goes to `ZCD_RTBLEAD`.
THROTTLE_MIN 0: the first raise is never held back; there is no quiet window. No APPLOG rule is seeded for
it (SLG1 kept to a minimum - findings in ZCD_OPS_FINDING, e-mail to SO23 lists only). A new rule of this kind
is created in DV1 on a customizing request and transported; in PS4 support only edits existing rules
(SO23 list, severity, ACTIVE; `Operations_Runbook.md` §5h).

Priority (receiver side, `docs/ALERTING.md` — Priority mapping; acknowledgement targets proposed, confirm with RTB operations):

| RULE_ID | Priority | Acknowledge within |
|---|---|---|
| EBS_BLOCK, ALL_ABORT, FMON_REGEN | P1 | 15 min, 24×7 |
| EBS_ERROR, FMON_PART, FMON_SLA, FMON_BAIDL, HCK_RED, HCK_RECON, RUN_LOCKED, NOC_AGING | P2 | 1 h in business hours |
| (warnings W) | P3 | Next business day — morning report and dashboards, no alert |

ESC_OVERRIDE (new rule field, A46): `X` lets a due escalation pass the throttle window — suggested on
EBS_BLOCK and HCK_RED. Escalation counts consecutive runs of the area (a run without an alert of the rule ends
the series).

ZCD_OPS_ALLOG needs the **unique** secondary index `INT` (MANDT, INTENT_KEY, ATTEMPT) — create it in SE11
before go-live; it is what stops two dispatchers sending the same alert (A17). Status values: S sent, F failed,
T throttled, Q quiet, C claimed (in delivery), R repeat (carried-forward exception, not re-alerted), P partial.

Parameters (ZCA_PARAM area `CD_OPS`) for reports sent with `send( )`: `ALERT_MORNING` (morning report SO23 list, LIST, proposed `ZCD_RTBSUP`; a route other than MORNING in `HCK_MAIL_ROUTE` needs its own definition `ALERT_<route>`), `ALERT_DEFAULT` (fallback), `ALERT_ESCALATION_WINDOW_H` (default 24).

Rules of behaviour (proved by `ZCL_CD_OPS_ALERT_POLICY` / `ZCL_CD_OPS_ALERT_ROUTER` unit tests):
- Severity **B** (blocked, never posted) ignores quiet hours.
- Throttled (T) and quiet-hour (Q) decisions are logged in ZCD_OPS_ALLOG — nothing is silently dropped.
- A failing channel is logged as F and never aborts the run; the morning report's "alert delivery health" check counts F rows.
- `send( )` without recipients or on an inactive channel logs F **and raises** (A45).
- An e-mail destination that is not a shared SO23 list is refused before BCS is called (027, logged F).
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

## Monitor freshness — `ZCA_PARAM` `MON_STALE_AFTER_MIN_<area>` (area `CD_OPS`; was `ZCD_OPS_MONCFG`, table consolidation 2026-11-08)

One parameter per payment engine area (INT, at least 1, app *Parameter areas* `ZUI_CA_PARAM_O4`): minutes after the last completed run before the monitor counts as **stale**. The "as of" CDS views of the dashboards (`ZR_CD_FmonAsOf`, `ZR_CD_EbsAsOf`, `ZR_CD_HckAsOf`, overview `ZI_CD_OpsFreshU`, through `ZI_CD_OpsStaleCfg`, which reads the framework tables `ZCA_PARAM_DEF` / `ZCA_PARAM_VAL` because CDS cannot call the parameter API) and the morning report's self-check (`HCK_SELF`, `PE_AREA_STALE`, through the parameter API) read the **same** parameter with the same rule - maintained value, else definition default - so they cannot disagree. The delivered definition defaults below apply without a value row. Only when a parameter cannot be read (refused value, `D_PARAM_INVALID`) the self-check falls back to `HCK_MAX_AGE_H_<area>`, then `HCK_MAX_AGE_HOURS`; without a definition (not transported) the dashboards use the same values as literals.

| Parameter | Delivered default (minutes) | Why |
|---|---|---|
| `MON_STALE_AFTER_MIN_FMON` | 15 | Native SAP job every 5 minutes: 3 missed runs |
| `MON_STALE_AFTER_MIN_EBS` | 1560 | Daily run + 2 h slack (26 h) |
| `MON_STALE_AFTER_MIN_HCK` | 1560 | Daily morning report + 2 h slack (26 h) |

The delivered values equal the CDS fallback literals and their ABAP constants (`ZIF_CD_FMON_TYPES=>GC_DASHBOARD-STALE_AFTER_MIN`, `ZIF_CD_HCK_TYPES=>GC_PARAM_DEFAULT-MAX_AGE_HOURS` × 60) — portable checks `cds_abap_parity` and `param_definitions_complete`. No value row is delivered (`config/param_values.csv`): a landscape changes a threshold with a value row. Time zone per area: not configurable (time stamps are UTC); future extension.
