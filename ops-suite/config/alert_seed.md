# Alert configuration — example rows (confirm before transport)

> **First principle:** who hears about a problem, how fast and how loud is configuration, never code.
> **Analogy:** a building's fire panel — zones (rules) are wired to sirens or the control room (channels) by the installer, not by the fire.

## ZCA_OPS_ALCHN

| CHANNEL | CLASS_NAME | DESTINATION | ACTIVE | TEMPLATE_ID |
|---|---|---|---|---|
| EMAIL | ZCL_CA_OPS_CHN_EMAIL | *(blank — rule gives the SO23 list)* | X | *(blank — generic `ZCA_OPS_ALERT_DEFAULT`)* |
| APPLOG | ZCL_CA_OPS_CHN_APPLOG | ZCD_OPS/ALERT | X | *(blank — the log takes the text)* |

**SLG1 kept to a minimum (user decision 2026-11-07).** No delivered rule writes the application log: findings are
already in `ZCA_OPS_FINDING` (dashboards, morning report), alert attempts in `ZCA_OPS_ALLOG`, parameter errors in the
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
| ZCD_PAYOPS | Payment operations | EBS_BLOCK, EBS_ERROR, FMON_SLA, FMON_ACK, FMON_FILE, FMON_BAIDL, FMON_REGEN |
| ZCD_RETOPS | Returns / NOC operations | FMON_PART |
| ZCD_COMPL | Compliance | NOC_AGING |
| ZCD_RTBSUP | RTB support | HCK_RED, HCK_RECON, ALL_ABORT, RUN_LOCKED, morning report |
| ZCD_RTBLEAD | RTB lead (escalation) | ESCALATION_DEST of EBS_BLOCK, FMON_PART, FMON_SLA, FMON_BAIDL, FMON_REGEN, HCK_RED, HCK_RECON |

## ZCA_OPS_ALRULE

RULE / CHECK / GROUP1 / GROUP2 patterns are **PCRE matched to the complete value, case ignored** (blank = any;
user decision 2026-11-06): `.*SLA.*` = any check code containing SLA, `RUN_LOCKED` = exactly that code. The
configuration app refuses a pattern that does not compile (message 418); check what a pattern captures with
`ZCD_OPS_PATTERN_CHECK` (areas ALERT_*). AREA `*` is not a pattern (it means every area). Since 2026-11-10 the alert rules and channels are tables of the operations framework (`ZCA_OPS_ALRULE` / `ZCA_OPS_ALCHN`, app `ZUI_CA_OPS_CFG`); AREA is a parameter area of ZCA_PARAM (`CD_EBS`, `CD_FMON`, `CD_HCK`, `CD_OPS`, or `*`).

| RULE_ID | AREA | MIN_SEVERITY | RULE_PATTERN | CHECK_PATTERN | MIN_RAG | ON_ABORT | CHANNEL | DESTINATION | DIGEST | MAX_ITEMS | THROTTLE_MIN | QUIET | ESCALATE_AFTER / DEST | TEMPLATE_ID | SHOW_AMOUNTS |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| EBS_BLOCK | CD_EBS | B | | | | | EMAIL | ZCD_PAYOPS | X | 50 | 0 | — | 3 / ZCD_RTBLEAD | ZCD_OPS_ALERT_EBS_BLOCK | |
| EBS_ERROR | CD_EBS | E | | | A | X | EMAIL | ZCD_PAYOPS | X | 50 | 60 | 22:00–06:00 | — | ZCD_OPS_ALERT_EBS | |
| FMON_PART | CD_FMON | E | | LOT_.* *(approved 2026-11-10; was `.*PARTIAL.*`, which matches no check code the suite raises)* | | | EMAIL | ZCD_RETOPS | X | 50 | 0 | — | 2 / ZCD_RTBLEAD | ZCD_OPS_ALERT_RETURNS | |
| FMON_SLA | CD_FMON | E | F_(SLA\|PRISM.*\|FILERCV) *(approved 2026-11-10)* | *(blank; was `.*SLA.*`, which matches no check code - the SLA codes are `NO_<stage>` / `<stage>_LATE`)* | | | EMAIL | ZCD_PAYOPS | X | 50 | 30 | — | 3 / ZCD_RTBLEAD | ZCD_OPS_ALERT_FMON_SLA | |
| FMON_ACK *(new, approved 2026-11-10)* | CD_FMON | E | | (NO_)?BANK_ACK(_LATE)?\|ACK_.+MATCH *(35 characters; the first proposal `...\|ACK_.*_MISMATCH` had 38, longer than CHAR 35)* | | | EMAIL | ZCD_PAYOPS | X | 50 | 30 | — | 3 / ZCD_RTBLEAD | ZCD_OPS_ALERT_ACK | X |
| FMON_FILE *(new, approved 2026-11-10)* | CD_FMON | E | F_(MISSING\|REJECT\|DUP\|SIZE\|PRF.*) | (?!REGENERATION_M\|PRISM_DUP).* *(those two go to FMON_REGEN)* | | | EMAIL | ZCD_PAYOPS | X | 50 | 30 | — | 3 / ZCD_RTBLEAD | ZCD_OPS_ALERT_FMON_FILE | |
| FMON_BAIDL | CD_FMON | E | | STAGE_DEADLINE_MISSED | | | EMAIL | ZCD_PAYOPS | X | 10 | 0 | — | 6 / ZCD_RTBLEAD | ZCD_OPS_ALERT_DEADLINE | |
| NOC_AGING | CD_FMON | E | | NOC_AGING.* | | | EMAIL | ZCD_COMPL | X | 100 | 1440 | — | — | ZCD_OPS_ALERT_NOC | |
| FMON_REGEN | CD_FMON | E | | .*REGEN.*\|PRISM_DUP.* *(2026-11-10: was the three codes spelled out - 68 characters, longer than the pattern field CHAR 35)* | | | EMAIL | ZCD_PAYOPS | X | 20 | 0 | — | 2 / ZCD_RTBLEAD | ZCD_OPS_ALERT_REGEN | |
| HCK_RED | CD_HCK | E | | | R | X | EMAIL | ZCD_RTBSUP | X | 50 | 60 | 22:00–06:00 | 2 / ZCD_RTBLEAD | ZCD_OPS_ALERT_HCK | |
| HCK_RECON | CD_HCK | E | | .*_BREAK *(2026-11-10: was the three codes spelled out - 56 characters, longer than CHAR 35)* | | | EMAIL | ZCD_RTBSUP | X | 50 | 0 | — | 2 / ZCD_RTBLEAD | ZCD_OPS_ALERT_RECON | |
| ALL_ABORT | * | B | | | | X | EMAIL | ZCD_RTBSUP | X | 20 | 15 | — | — | ZCD_OPS_ALERT_ABORT | |
| RUN_LOCKED | * | E | | RUN_LOCKED | | | EMAIL | ZCD_RTBSUP | | 10 | 60 | — | — | ZCD_OPS_ALERT_LOCKED | |

**E-mail templates and amounts (user decisions 2026-11-10).** Every rule names its SAP e-mail template
(`TEMPLATE_ID`, documented sources in `templates/`, created in DV1 and transported; a blank rule uses the
channel default, else the framework's generic `ZCA_OPS_ALERT_DEFAULT`; a message with missing bank ACK files
uses `ZCD_OPS_ALERT_ACK` when its rule names none). `SHOW_AMOUNTS` = X only on `FMON_ACK`: the missing bank
ACK alert shows payments and amounts (user decision); whether other alerts show amounts is an open decision -
the flag stays blank until it is taken (`Release_Readiness.md` §5). The ACK section shows its file amounts
whatever rule carries it. Review of every alert and its business context: `docs/ALERT_CONTEXT_REVIEW.md`.

**Patterns corrected (approved by the user 2026-11-10; enter in DV1 and transport).** `FMON_SLA` (`.*SLA.*`) and `FMON_PART`
(`.*PARTIAL.*`) matched no check code the suite raises (the SLA check raises `NO_<stage>` / `<stage>_LATE`, e.g.
`NO_PRISM_HANDOFF`, `BANK_ACK_LATE`; partial return lots are `LOT_UNPROCESSED` / `LOT_NOT_FOUND`), and no rule
selected the missing bank ACK findings or the file failures (`FILE_MISSING`, `NACK`, `FILE_FAILED`,
`DUPLICATE_FILE`, size, PRISM failed) - they reached only the morning report and the dashboards.
`FMON_SLA` now selects the SLA checks by check ID (rule pattern; the ACK stage check `F_BANKACK` goes to
`FMON_ACK`), `FMON_PART` the lot checks, new `FMON_ACK` the ACK codes and new `FMON_FILE` the file checks by check
ID (`config/fmon_seed.md`). Every pattern fits the field (CHAR 35; `FMON_ACK` exactly 35 after shortening `ACK_.*_MISMATCH` to `ACK_.+MATCH`, which selects the same two codes `ACK_COUNT_MISMATCH` / `ACK_AMOUNT_MISMATCH`): `FMON_REGEN` and `HCK_RECON` spelled their codes out
in 68 / 56 characters and are shortened to patterns that select the same codes. Check what a pattern captures with
`ZCD_OPS_PATTERN_CHECK` before the transport.

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
ZCA_OPS_ALLOG); after 6 consecutive runs (30 minutes) still open the escalation goes to `ZCD_RTBLEAD`.
THROTTLE_MIN 0: the first raise is never held back; there is no quiet window. No APPLOG rule is seeded for
it (SLG1 kept to a minimum - findings in ZCA_OPS_FINDING, e-mail to SO23 lists only). A new rule of this kind
is created in DV1 on a customizing request and transported; in PS4 support only edits existing rules
(SO23 list, severity, ACTIVE; `Operations_Runbook.md` §5h).

Priority (receiver side, `docs/ALERTING.md` — Priority mapping; acknowledgement targets proposed, confirm with RTB operations):

| RULE_ID | Priority | Acknowledge within |
|---|---|---|
| EBS_BLOCK, ALL_ABORT, FMON_REGEN | P1 | 15 min, 24×7 |
| EBS_ERROR, FMON_PART, FMON_SLA, FMON_ACK, FMON_FILE, FMON_BAIDL, HCK_RED, HCK_RECON, RUN_LOCKED, NOC_AGING | P2 | 1 h in business hours |
| (warnings W) | P3 | Next business day — morning report and dashboards, no alert |

ESC_OVERRIDE (new rule field, A46): `X` lets a due escalation pass the throttle window — suggested on
EBS_BLOCK and HCK_RED. Escalation counts consecutive runs of the area (a run without an alert of the rule ends
the series).

ZCA_OPS_ALLOG needs the **unique** secondary index `INT` (MANDT, INTENT_KEY, ATTEMPT) — create it in SE11
before go-live; it is what stops two dispatchers sending the same alert (A17). Status values: S sent, F failed,
T throttled, Q quiet, C claimed (in delivery), R repeat (carried-forward exception, not re-alerted), P partial.

Parameters (ZCA_PARAM area `CD_OPS`) for reports sent with `send( )`: `ALERT_MORNING` (morning report SO23 list, LIST, proposed `ZCD_RTBSUP`; a route other than MORNING in `HCK_MAIL_ROUTE` needs its own definition `ALERT_<route>`), `ALERT_DEFAULT` (fallback), `ALERT_ESCALATION_WINDOW_H` (default 24).

Rules of behaviour (proved by `ZCL_CA_OPS_ALERT_POLICY` / `ZCL_CA_OPS_ALERT_ROUTER` unit tests):
- Severity **B** (blocked, never posted) ignores quiet hours.
- Throttled (T) and quiet-hour (Q) decisions are logged in ZCA_OPS_ALLOG — nothing is silently dropped.
- A failing channel is logged as F and never aborts the run; the morning report's "alert delivery health" check counts F rows.
- `send( )` without recipients or on an inactive channel logs F **and raises** (A45).
- An e-mail destination that is not a shared SO23 list is refused before BCS is called (027, logged F).
- MAX_ITEMS keeps the most severe findings (B > E > W > I); the message names how many were held back (A63).
- Test-mode runs never alert.

## Core parameters — framework `ZCA_PARAM`, area `CD_OPS` (retention purge, `ZCA_OPS_RETENTION`)

Definitions (value type, limits, delivered default) of every parameter: `config/param_definitions.csv`; example value rows to confirm per landscape: `config/param_values.csv` (format: `param-framework/docs/ONBOARDING.md` section 6a). Maintained in the framework app *Parameter areas* (`ZUI_CA_PARAM`), area `CD_OPS` - ZCD_OPS_PARAM is retired.

| Parameter | Delivered default | Meaning |
|---|---|---|
| RETENTION_DAYS_RUN | `400` | Runs and their findings older than this are purged — never a run that still holds an open, assigned or validly waived exception |
| RETENTION_DAYS_ALERT_LOG | `180` | Alert log rows (by send time) |
| RETENTION_DAYS_FMON_EVENT | `400` | FMON file events (by creation time) |
| RETENTION_DAYS_HCK_METRIC | `400` | HCK metric history (by measurement time; baselines need the history) |
| RETENTION_DAYS_FMON_PRISM | `400` | PRISM status API events (`ZCD_FMON_PRISM`, by receipt time); the file history stays in the FMON events |
| PURGE_PACKAGE_SIZE | `1000` | Rows (RUN: runs) deleted per package; commit after each package (INT, at least 1) |

Any value below 30 days is raised to 30 (`ZCL_CA_OPS_PURGE=>GC_MIN_DAYS`). A new purge target needs a definition `RETENTION_DAYS_<target>` (the portable check `param_definitions_complete` enumerates the targets).

## Monitor freshness — `ZCA_PARAM` `MON_STALE_AFTER_MIN_<area>` (area `CD_OPS`; was `ZCD_OPS_MONCFG`, table consolidation 2026-11-08)

One parameter per payment engine area (INT, at least 1, app *Parameter areas* `ZUI_CA_PARAM_O4`): minutes after the last completed run before the monitor counts as **stale**. The "as of" CDS views of the dashboards (`ZR_CD_FmonAsOf`, `ZR_CD_EbsAsOf`, `ZR_CD_HckAsOf`, overview `ZI_CD_OpsFreshU`, through `ZI_CD_OpsStaleCfg`, which reads the framework tables `ZCA_PARAM_DEF` / `ZCA_PARAM_VAL` because CDS cannot call the parameter API) and the morning report's self-check (`HCK_SELF`, `PE_AREA_STALE`, through the parameter API) read the **same** parameter with the same rule - maintained value, else definition default - so they cannot disagree. The delivered definition defaults below apply without a value row. Only when a parameter cannot be read (refused value, `D_PARAM_INVALID`) the self-check falls back to `HCK_MAX_AGE_H_<area>`, then `HCK_MAX_AGE_HOURS`; without a definition (not transported) the dashboards use the same values as literals.

| Parameter | Delivered default (minutes) | Why |
|---|---|---|
| `MON_STALE_AFTER_MIN_CD_FMON` | 15 | Native SAP job every 5 minutes: 3 missed runs |
| `MON_STALE_AFTER_MIN_CD_EBS` | 1560 | Daily run + 2 h slack (26 h) |
| `MON_STALE_AFTER_MIN_CD_HCK` | 1560 | Daily morning report + 2 h slack (26 h) |
| `MON_STALE_AFTER_MIN_CD_OPS` | 30 | Payment outcome snapshot lag (2026-11-08): minutes behind the evidence, 6 x the 5-minute cadence; also A_INFLIGHT `PAY_SNAPSHOT_STALE` |

The delivered values equal the CDS fallback literals and their ABAP constants (`ZIF_CD_FMON_TYPES=>GC_DASHBOARD-STALE_AFTER_MIN`, `ZIF_CD_HCK_TYPES=>GC_PARAM_DEFAULT-MAX_AGE_HOURS` × 60) — portable checks `cds_abap_parity` and `param_definitions_complete`. No value row is delivered (`config/param_values.csv`): a landscape changes a threshold with a value row. Time zone per area: not configurable (time stamps are UTC); future extension.

## Missing bank ACK mail — layout (user request 2026-11-10; sample with made-up values)

Findings `NO_BANK_ACK`, `BANK_ACK_LATE`, `ACK_COUNT_MISMATCH`, `ACK_AMOUNT_MISMATCH` and `STAGE_DEADLINE_MISSED` of stage `ACK_RECEIVED` carry their file evidence; any FMON rule that selects them sends this layout - the seeds had none (the `FMON_ERR` named here before does not exist), so rule `FMON_ACK` is proposed above (2026-11-10). Since 2026-11-10 the subject is the key `SUBJECT` and the table the block `TABLE_SECTION` of the e-mail template `ZCD_OPS_ALERT_ACK` (`templates/zcd_ops_alert_ack.md`); the built-in layout shows the same. Since 2026-11-10 the table is the suite's alert section plug-in `ZCL_CD_OPS_ACK_MAIL` (`ZIF_CA_OPS_ALERT_SECTION`) of the framework's alert policy, configured in parameter `ALERT_SECTION_CLASS` (area `CA_OPS`, value row in `config/param_values.csv`).

Subject: `[PS4][CD_FMON][E] Missing bank ACK: 2 file(s), 121 payments, CAD 2,500.00; USD 1,234,567.80`

| House bank | Bank | File name | Payment method | Payments | Amount | Payment run (date / ID) | Generated in SAP | Delivered to bank | ACK due | Overdue by |
|---|---|---|---|---:|---:|---|---|---|---|---|
| JPMC1/OPS01 | JPMC | ACH_JPMC_20261110_01.txt | ACH | 120 | USD 1,234,567.80 | 2026-11-10/R0001 | 2026-11-10 06:02:11 CST | 2026-11-10 06:07:40 CST | 2026-11-10 09:00:00 CST | 1 h 35 min |
| BOA01 | BOA | WIRE_BOA_20261110_02.txt | WIRE | 1 | CAD 2,500.00 | 2026-11-10/R0002 | 2026-11-10 07:15:03 CST | 2026-11-10 07:16:20 CST | 2026-11-10 10:00:00 CST | 0 h 35 min |
| Total | | 2 | | 121 | CAD 2,500.00 / USD 1,234,567.80 | | | | | |

Below the table: the run / job line (message 803) and, if the alert also selected other findings, the general findings table. The text version lists the same columns separated by ` | `.

**User decision 2026-11-10:** dollar amounts and payment counts are shown in the missing-ACK alert. Masking of amounts in other alerts remains an open decision (`Release_Readiness.md` §5). No payee or member data; bank accounts only as house bank / account ID.

## Purge targets of the suite (registry ZCA_OPS_PURGE, 2026-11-10)

The retention purge is the framework's (`ZCA_OPS_RETENTION`, `ZCL_CA_OPS_PURGE`): its own targets RUN (runs, findings,
exception history) and ALERT_LOG, then every active row of `ZCA_OPS_PURGE`. The suite registers its targets in DV1 on a
customizing request in the framework app `ZUI_CA_OPS_CFG` (entity *Purge targets*; class and parameter are checked on
save, messages 410 / 434 / 435). Rows: `config/purge_targets.csv`.

| TARGET | CLASS_NAME | PARAM_AREA | PARAM_NAME | ACTIVE |
|---|---|---|---|---|
| FMON_EVENT | ZCL_CD_OPS_PURGE_TARGET | CA_OPS | RETENTION_DAYS_FMON_EVENT | X |
| FMON_FILE | ZCL_CD_OPS_PURGE_TARGET | CA_OPS | RETENTION_DAYS_FMON_FILE | X |
| FMON_PRISM | ZCL_CD_OPS_PURGE_TARGET | CA_OPS | RETENTION_DAYS_FMON_PRISM | X |
| HCK_METRIC | ZCL_CD_OPS_PURGE_TARGET | CA_OPS | RETENTION_DAYS_HCK_METRIC | X |
| HCK_RESULT | ZCL_CD_OPS_PURGE_TARGET | CA_OPS | RETENTION_DAYS_HCK_RESULT | X |
| PAY_OUTCOME | ZCL_CD_OPS_PURGE_TARGET | CA_OPS | RETENTION_DAYS_PAY_OUTCOME | X |

Keep rules are unchanged (`ZCL_CD_OPS_PURGE_TARGET`): the current version of a payment that is not final is never deleted;
a registry file an open, assigned or validly waived FMON exception refers to is kept; never below 30 days (engine); one
package per commit (engine); test mode counts only (engine).
