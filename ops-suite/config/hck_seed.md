# Health Check (HCK) — example customizing (seed)

> **CONFIRM BEFORE TRANSPORT.** Every row below is an *example* built from the landscape facts in
> `docs/DEVELOPMENT_STANDARDS.md` and the Control-M / SAP job schedule wiki (October 2025).
> Job names in the wiki are **placeholders**; the real SAP jobs follow `ZCD_<function>_<ENTITY>`.
> Table/field names marked **VERIFY-DDIC** are not confirmed in this landscape — the engine validates
> them against the runtime DDIC and reports `AGG_CONFIG_INVALID` instead of failing silently, but the
> *business meaning* (which values, which date) must be confirmed by the payment-engine functional team.
> Maintain in DV1 (SM30), transport DV1 → QA1 → PS4. `ZCD_HCK_BASELINE` and `ZCD_HCK_METRIC` are
> application data (delivery class A) and are **never** transported.

## 1. Runtime parameters — framework `ZCA_PARAM`, area `CD_HCK` (and `CD_OPS` for ALERT_ / SLA_)

Definitions (value type, limits, delivered default) of every parameter: `config/param_definitions.csv`; example value rows to confirm per landscape: `config/param_values.csv` (format: `param-framework/docs/ONBOARDING.md` section 6a). Maintained in the framework app *Parameter areas* (`ZUI_CA_PARAM`), area `CD_HCK` - ZCD_OPS_PARAM is retired. A bad value is reported by `D_PARAM_INVALID` (§2) the next morning.

| Parameter | Value | Meaning |
|---|---|---|
| HCK_WATCH_PE_AREAS | `EBS,FMON,HCK` | Payment engine areas whose last run is checked (health of the health check) |
| HCK_MAX_AGE_HOURS | `26` | Default max age of a payment engine area's last run (daily run + 2 h slack) |
| HCK_MAX_AGE_H_FMON | `1` (value row) | Fallback only: with the delivered parameter `MON_STALE_AFTER_MIN_FMON` = 15 min (area CD_OPS, was the `ZCD_OPS_MONCFG` row) the self-check and the dashboard both use 15 minutes (`config/alert_seed.md`); this hours value applies only when that parameter cannot be read (refused value) |
| HCK_TIMEOUT_SEC | `300` | Default check timeout when `ZCD_HCK_DEF-TIMEOUT_SEC` = 0; item-wise checks stop between items once it has passed (BUDGET_EXHAUSTED, A18) |
| HCK_LOOKBACK_RUNS | `8` | Default baseline history points (one point per finished, non-test run — A59) |
| HCK_MAX_RUN_MIN | `120` | A run of a watched area in status R longer than this is HUNG (red self-check, A06); per area `HCK_MAX_RUN_MIN_<AREA>` |
| HCK_FLAT_TOL_PCT | `10` | Flat history (standard deviation 0): adverse change beyond this % of the mean is an outlier (A58) |
| HCK_TOP_N | `20` | Open exceptions listed in the report |
| HCK_MAIL_ROUTE | `MORNING` | Route of the morning report e-mail |
| HCK_MAX_JOB_ROWS | `5000` | TBTCO job runs per read (technical jobs, job cycle, job runtime); hard ceiling 50 000 |
| HCK_MAX_JOB_NAMES | `20000` | Distinct TBTCO job names per window; reaching it fails the check (747); hard ceiling 200 000 |
| HCK_MAX_AGG_ROWS | `5000` | Groups of a generic aggregate / volume check; hard ceiling 50 000 |
| HCK_MAX_TECH_ROWS | `5000` | NRIV intervals / queue groups per read (`E_NUMRANGE`, `E_QUEUES`); hard ceiling 50 000 |
| HCK_QUEUE_ERR_STATES | `SYSFAIL,CPICERR` | qRFC / bgRFC states that are an error (`E_QUEUES`, finding E) |
| HCK_QUEUE_HOLD_STATES | `STOP,WAITSTOP` | States that hold a queue (W) |
| HCK_QUEUE_WAIT_STATES | `READY,RUNNING` | States that are STUCK (W) when older than PARAM3 minutes |
| HCK_INFLIGHT_MAX_ROWS | `5000` | Payments per window and rows of every evidence read (`A_INFLIGHT`); hard ceiling 50 000. Payment methods per class are configuration (posting area `ZPMC`, §8), no longer parameters (HCK_INFLIGHT_WIRE_ / _ACH_ / _CHQ_METHODS retired 2026-11-07) |
| HCK_RECON_LOOKBACK_DAYS | `7` | Days before the report date reconciled by `A_RECON_3WAY` (window = report date - 1 back these days) |
| HCK_RECON_TIMING_DAYS | `3` | Days a reconciliation difference may stay open as timing (statement of the next day / month, transfer lag) |
| HCK_RECON_REDEPOSIT_DAYS | `10` | Days a 468 without returns lot waits for its delayed redeposit (confirmed 10 days) |
| HCK_RECON_TOLERANCE | `0.00` | Absolute tolerance per group day when the set has none (`ZCD_HCK_RCSET-TOLERANCE` wins when > 0) |
| HCK_RECON_MAX_ROWS | `5000` | Unmatched ACH assignment groups per read; hard ceiling 50 000 (`TECH_READ_CAPPED`) |
| ALERT_MORNING | `<payment-engine RTB distribution list>` | Recipients of the morning report (**confirm**) |
| HCK_SCORE_GREEN_MIN | `90` | Score ≥ 90 → GREEN |
| HCK_SCORE_AMBER_MIN | `70` | Score ≥ 70 → AMBER, below → RED |
| HCK_WEIGHT_H / _M / _L | `3` / `2` / `1` | Score weight per priority |
| SLA_DAYS_HCK_E | `1` | Due date of HCK error findings (core store) |
| SLA_DAYS_HCK_W | `3` | Due date of HCK warning findings |

Alert routing of findings (channels, recipients, throttling, quiet hours) is customizing of the core
table `ZCD_OPS_ALRULE` — suggested HCK rule: payment engine area `HCK`, minimum severity `E`, channel `EMAIL`,
digest per run, rule/group pattern blank = any (patterns are PCRE matched to the complete value,
case ignored; `*` alone is not a valid PCRE - confirm with the core owner).

**Payment status lag (`A_INFLIGHT`, 2026-11-08, `HCK_MORNING_REPORT.md` §7b-6):**

| Parameter | Type | Default | Meaning |
|---|---|---|---|
| `HCK_PAY_STATUS_LAG_MIN` | INT 0..10080 | `120` | Minutes after the bank evidence (end of the statement line's day) or the bank ACK before a DPAYH status that did not follow is `PAY_STATUS_LAG` (W); the payment status job runs hourly |
| `HCK_PAY_STATUS_ACK_OPEN` | LIST | `ISSUED` | DPAYH statuses that must have changed once the bank ACK is received (payment-level `TRACE_SRC_ACK` or the payment run's file) |
| `HCK_PAY_ACK_FILE_CLASSES` | LIST | `CACH,CCRD` | Flow + method classes acknowledged **per file** (2026-11-08): their status lag after the ACK uses the `ACK_RECEIVED` of the FMON file of the payment run; every other class per payment (`TRACE_SRC_ACK`). Cheques `DCHQ` per payment - **VERIFY** (add `DCHQ` by transport if the bank acknowledges cheques per file) |
| `HCK_PAY_ACK_FILE_SRC` | CHAR | `REGUT` | FMON source (`ZCD_FMON_SRC`) whose `GROUP_FIELDS` name the payment run of a file (`config/fmon_seed.md`; the fields must be DPAYH payment run fields LAUFD / LAUFI / HBKID, VERIFY-SE11). Blank `GROUP_FIELDS` = `INFLIGHT_CONFIG` W once per run, nothing judged |

No alert rule is delivered for `PAY_STATUS_LAG` (morning report and dashboard only).

## 2. Check catalog — `ZCD_HCK_DEF`

Pattern lists (PARAM1 of `B_JOB_RUNTIME` / `E_JOBS`, PARAM1-2 of `B_APPLOG`, PARAM2 of `B_CYCLE_*`) and the
job names of `ZCD_JOB_STEP` are **PCRE matched to the complete value, case ignored** (user decision
2026-11-06): `ZCD_.*` = every name starting with ZCD_, `ZCD_POST_GL` = exactly that job. List items are
separated by `,` or `;` (an item cannot contain them, so no `{m,n}` quantifier). Check a pattern with
`ZCD_OPS_PATTERN_CHECK` before saving it; an invalid pattern raises message 373 / a PATTERN_INVALID finding.

| CHECK_ID | DESCRIPTION | CAT | CLASS_NAME | ACTIVE | SEQ | PRIO | PARAM1 | PARAM2 | PARAM3 | TIMEOUT_SEC |
|---|---|---|---|---|---|---|---|---|---|---|
| A_RET_AGED | Return debits aging > 10 days by company code | A | ZCL_CD_HCK_C_GENERIC_AGG | X | 10 | H | | | | 120 |
| A_GL_TRANSFER | payment engine reconciliation keys reached the GL | A | ZCL_CD_HCK_C_GL_TRANSFER | X | 20 | H | `1` (lag days) | `7` (window days) | `500` (max keys) | 300 |

A_GL_TRANSFER PARAM4 = BKPF-AWTYP of the transfer (default `FKKSU`, VERIFY-DDIC); a key counts as transferred
per company code only with a non-reversed BKPF of that type (A43). Metric GL_MISSING_KEYS carries the
uncapped count.
| B_JOB_RUNTIME | Batch job duration vs rolling baseline | B | ZCL_CD_HCK_C_JOB_RUNTIME | X | 30 | M | `ZCD_.*` | `1` (yesterday) | | 120 |
| B_APPLOG | Application log error rate per object | B | ZCL_CD_HCK_C_APPLOG | X | 40 | M | `FKK.*,ZCD.*` (**confirm objects**) | | `1` | 120 |
| B_VOLUME | Payment engine volumes (yesterday) | B | ZCL_CD_HCK_C_VOLUME | X | 50 | L | `1` (offset) | `1` (days) | | 300 |
| B_CYCLE_TODAY | Job cycles of today (so far) | B | ZCL_CD_HCK_C_JOB_CYCLE | X | 60 | H | `0` | (blank = all) | | 60 |
| B_CYCLE_PRIOR | Job cycles of yesterday (incl. after-midnight steps) | B | ZCL_CD_HCK_C_JOB_CYCLE | X | 61 | H | `1` | | | 60 |
| C_OVERDUE_EXC | Owned exceptions past their due date | C | ZCL_CD_HCK_C_OVERDUE_EXC | X | 70 | H | | | | 60 |
| C_PPO_BACKLOG | Postprocessing (PPO) backlog older than 3 days | C | ZCL_CD_HCK_C_GENERIC_AGG | X | 80 | M | | | | 120 |
| D_CONFIG_DRIFT | Customizing drift vs golden baseline | D | ZCL_CD_HCK_C_CONFIG_DRIFT | X | 90 | M | | | | 120 |
| D_PARAM_INVALID | Parameters ZCA_PARAM refuses (areas CD_OPS / CD_EBS / CD_FMON / CD_HCK) | D | ZCL_CD_HCK_C_PARAM | X | 95 | H | | | | 60 |
| D_POSTAREA_INVALID | Entries of the posting areas ZRSN / ZPMC / ZBTM / ZBTR the suite cannot use (2026-11-08) | D | ZCL_CD_HCK_C_POSTAREA | X | 96 | H | | | | 60 |
| E_JOBS | Cancelled, long-running and late jobs | E | ZCL_CD_HCK_C_TECH_JOBS | X | 100 | H | `ZCD_.*` | `120` (min) | `30` (grace min) | 60 |
| E_SYSTEM | Short dumps, update errors, locks | E | ZCL_CD_HCK_C_TECH_SYS | X | 110 | M | | | | 60 |
| E_ALERT_DELIVERY | Alert delivery health (failed / throttled) | E | ZCL_CD_HCK_C_ALERT_HEALTH | X | 120 | M | `24` (hours) | | | 60 |
| C_PRQ_NO_SPE | Payment request failed without SPE row (source never told) | C | ZCL_CD_HCK_C_PRQ_SPE | X | 72 | H | `TABLE=ZCD_PAYM_REQ_LOG;KEY=‹SE11 request key›;STATUS=ZZ_STATUS;DATE=‹SE11 date›` | `FAIL=‹confirm failure values›;OK=SUCCESS;DAYS=3;MAX=200` | `TABLE=ZCD_SPE_EXCP_LOG;KEY=‹SE11 request key›;DATE=‹SE11 date›` | 120 |
| C_CHQ_STATUS | Cheque status went backwards (ZECT_STATUS) | C | ZCL_CD_HCK_C_CHQ_STATUS | X | 74 | M | `TABLE=ZCD_CHECK_HIST;KEY=‹SE11 cheque›;SEQ=‹SE11 counter/time›;STATUS=‹SE11 status›;DATE=‹SE11 date›` | `TERMINAL=3,4,9;ALLOWED=10>9;DAYS=7;MAX=200` | | 120 |
| C_PRQ_CANCEL | Paid payment request left CANCELLED (PCLM) | C | ZCL_CD_HCK_C_PRQ_CANCEL | X | 76 | H | `TABLE=ZCD_PAYM_REQ_LOG;KEY=‹SE11 FIN number›;STATUS=ZZ_STATUS;SOURCE=SOURCE;DATE=‹SE11 date›` | `CANCELLED=CANCELLED;SRC=PCLM;DAYS=7;MAX=200` | `TABLE=DFKKOP;KEY=ZZ_FIN_TRANS_NUM;PAID=AUGBL;DATE=AUGDT` | 300 |
| A_INFLIGHT | Payments sent but not cleared on the bank statement | A | ZCL_CD_HCK_C_INFLIGHT | X | 25 | H | `<factory calendar of the payment engine, confirm>` | `10` (days, VALUE_DATE classes) | `120` (days, ISSUE_DATE classes) | 300 |
| E_NUMRANGE | Number ranges nearly exhausted (NRIV) | E | ZCL_CD_HCK_C_NUMRANGE | X | 105 | H | `<FI-CA document number object, VERIFY in SNRO (e.g. FKK_BELEG)>,<payment run / payment lot / returns lot objects, VERIFY in SNRO>` | | | 60 |
| A_RECON_3WAY | Three-way reconciliation bank / G/L transit / payment engine | A | ZCL_CD_HCK_C_RECON3 | X | 27 | H | | | | 300 |
| E_QUEUES | qRFC / bgRFC queues in error or stuck | E | ZCL_CD_HCK_C_QUEUES | X | 115 | H | `<payment engine queue patterns, e.g. ZCD_.*, confirm in SMQ1 / SMQ2>` (blank = all) | `<destination patterns, e.g. PRISM.*>` (blank = all) | `30` (stuck minutes) | 60 |

`A_INFLIGHT` PARAM1 = factory calendar when the class / house bank has none (§8a / §8b, entries of the posting area ZPMC), PARAM4 = payments listed per finding (blank = 10). Flow D / C from TFK042Z-XEINZ; classes, ageing basis and calendars (`*` entries and house-bank entries) in the posting area `ZPMC`; VALUE_DATE classes aged in business days after the value date (DPAYH-VALUT, VERIFY-DDIC; run date when empty), ISSUE_DATE classes in calendar days since the run date. What takes a payment out of flight (cleared, returned, voided, pending) and what is inconsistent is configuration: `ZCD_HCK_CLRRULE` with the evidence kinds, roles and outcomes of §8. Reversed payments (DFKKKO-STBEL) are left out.
`A_RECON_3WAY` has no PARAM1-4: the window, timing, redeposit days, tolerance and the row cap are ZCA_PARAM `HCK_RECON_*` (§1); the sets and bank code roles are §10. It also reads EBS_FEB_CREDIT_IND / EBS_FEB_DEBIT_IND, EBS_GL_LEDGER (owned by EBS) and TRACE_GL_AWTYP (core) - one definition each.
`E_NUMRANGE` PARAM1 = exact SNRO object names (comma list, not patterns - NRIV is read by key); only internal intervals, current / next year or not year-dependent.
`E_QUEUES` PARAM4 = bgRFC source (blank = bgRFC not monitored, information finding): `TABLE=<bgRFC unit / error table, VERIFY in SE11 / SBGRFCMON>;NAME=<queue or destination field>;DEST=<destination field>;STATE=<state field, omit = every row is an error>;DATE=<DATS field>;TIME=<TIMS field>` (≤ 100 characters) plus a `ZCD_OPS_TABWL` row HCK / READ for that table. The qRFC sources TRFCQOUT / TRFCQIN are delivered (field names VERIFY-DDIC, constants of `ZIF_CD_HCK_RUNTIME_TYPES`).

`HCK_SELF` (health of the health check) is built in — no row needed.

**Known-table checks (USAA reference, `docs/USAA_Known_Tables.md`).** Confirmed: `ZZ_STATUS` with `SUCCESS` (never the highest `COUNTER`), `SOURCE`, `ZCD_SPE_EXCP_LOG` needed for every failure, `ZECT_STATUS` 3 / 4 / 9 terminal and 10 → 9 allowed, `DFKKOP-ZZ_FIN_TRANS_NUM`. Every `‹SE11›` name is validated against the DDIC at run time — a wrong name gives a `PLUGIN_ERROR` (message 304), never a wrong count. `AUGDT` (clearing date) on DFKKOP: VERIFY-SE11. Each value query is limited by its `DATE` field (message 323) and by `ROWS` (default 50 000).

## 3. Thresholds — `ZCD_HCK_THRESH` (`*` = default row; company-code rows override)

| CHECK_ID | METRIC | BUKRS | AMBER | RED | HIGHER_IS_WORSE | BASELINE_MODE | Z_LIMIT | LOOKBACK_RUNS |
|---|---|---|---|---|---|---|---|---|
| A_RET_AGED | RET_AGED | * | 1 | 25 | X | NONE | | |
| A_RET_AGED | RET_AGED | `<bukrs, confirm>` | 10 | 100 | X | NONE | | |
| A_GL_TRANSFER | GL_MISSING_KEYS | * | 1 | 5 | X | NONE | | |
| C_PRQ_NO_SPE | PRQ_FAILED_NO_SPE | * | 1 | 1 | X | NONE | | |
| C_CHQ_STATUS | CHEQUE_REGRESSION | * | 1 | 5 | X | NONE | | |
| C_PRQ_CANCEL | PRQ_PAID_CANCELLED | * | 1 | 1 | X | NONE | | |
| B_JOB_RUNTIME | DURATION_MIN | * | 0 | 240 | X | ZSCORE | 3 | 8 |
| B_APPLOG | ERR_RATE_PCT | * | 5 | 20 | X | NONE | | |
| B_APPLOG | ERR_MESSAGES | * | 0 | 0 | X | IQR | 1.5 | 20 |
| B_VOLUME | * | * | 0 | 0 | ' ' | ZSCORE | 3 | 20 |
| B_VOLUME | PAY_REQ | * | 100 | 0 | ' ' | ZSCORE | 3 | 20 |
| B_CYCLE_TODAY | STEPS_NOT_OK | * | 1 | 2 | X | NONE | | |
| B_CYCLE_PRIOR | STEPS_NOT_OK | * | 1 | 2 | X | NONE | | |
| C_OVERDUE_EXC | OVERDUE | * | 1 | 20 | X | NONE | | |
| C_OVERDUE_EXC | OLDEST_OVERDUE_DAYS | * | 3 | 10 | X | NONE | | |
| C_PPO_BACKLOG | PPO_AGED | * | 50 | 500 | X | ZSCORE | 3 | 8 |
| E_JOBS | CANCELLED | * | 1 | 3 | X | NONE | | |
| E_JOBS | LATE_START | * | 1 | 5 | X | NONE | | |
| E_SYSTEM | SHORT_DUMPS | * | 1 | 20 | X | NONE | | |
| E_SYSTEM | UPDATE_ERRORS | * | 1 | 5 | X | NONE | | |
| E_SYSTEM | LOCK_MAX_AGE_MIN | * | 60 | 240 | X | NONE | | |
| E_ALERT_DELIVERY | ALERT_FAILED | * | 1 | 5 | X | NONE | | |
| D_PARAM_INVALID | PARAM_INVALID | * | 1 | 1 | X | NONE | | |
| D_POSTAREA_INVALID | POSTAREA_INVALID | * | 1 | 1 | X | NONE | | |
| E_NUMRANGE | NR_USED_PCT | * | 85 | 95 | X | NONE | | |
| E_QUEUES | Q_ERROR | * | 1 | 10 | X | NONE | | |
| E_QUEUES | Q_HOLD | * | 1 | 5 | X | NONE | | |
| E_QUEUES | Q_STUCK | * | 1 | 50 | X | NONE | | |
| E_QUEUES | Q_OLDEST_MIN | * | 60 | 240 | X | NONE | | |
| A_INFLIGHT | AGE_OLDEST | DWIR | 1 | 2 | X | NONE | | |
| A_INFLIGHT | AGE_OLDEST | DACH | 3 | 4 | X | NONE | | |
| A_INFLIGHT | AGE_OLDEST | CACH | 3 | 4 | X | NONE | | |
| A_INFLIGHT | AGE_OLDEST | DCHQ | 0 | 0 | X | NONE | | |
| A_INFLIGHT | AGE_OLDEST | CCRD | 3 | 4 | X | NONE | | |
| A_INFLIGHT | AGE_OLDEST | DACI | 7 | 8 | X | NONE | | |

`A_INFLIGHT` AGE_OLDEST (**confirm**): the key (BUKRS column) is flow + method class; AMBER / RED = the age from which a payment is late (warning) / critical, because a limit is reached at value ≥ limit and 0 means *not set*. **Confirmed by the user 2026-11-08:** wire is cleared the next business day → AMBER 1 (clear it today) / RED 2; ACH (both flows) clears in 1 to 3 business days and card in 3 business days → AMBER 3 / RED 4; business days after the value date by the factory calendar. Cheques: no limit (AMBER = RED = 0, not set) - when a cheque is cashed depends on the payee, and there is no stale-cheque policy (user 2026-11-08); outstanding cheques are still counted and listed, never late. International ACH (Barclays, Commerzbank): cleared within at most 7 days (user 2026-11-08) → AMBER 7 / RED 8, by the class / house-bank calendar. A stale-cheque limit (e.g. void after N days) is a row change here if the payment engine has such a policy - **confirm**. The check classifies every payment with the same row (counts OVER_WARN_CNT / OVER_CRIT_CNT, amounts per currency) and the engine judges AGE_OLDEST with it - one source. A watched key without row is `LIMITS_NOT_CONFIGURED` (W), never green. `E_NUMRANGE` uses the `*` row (DIM1 object/subobject/interval/year is longer than 4 characters); `E_QUEUES` rows may be overridden per source (`QOUT`, `QIN`, `BGRF`).

Rules: higher-is-worse → a zero limit means *not set*; lower-is-worse (`' '`) → both limits apply
(`PAY_REQ` red 0 = no payment requests yesterday is RED); amber = red = 0 → static limits off.
`DIM1` is used as the company-code key only when it fits 4 characters (company code, source code);
longer dimensions (job names, log objects) use the `*` row.

## 4. Generic aggregates — `ZCD_HCK_AGG`

**Acceptance test 1 — "return debits aging > 10 days by company code" is these rows only (no code):**

| CHECK_ID | AGG_ID | TABNAME | AGG_FUNC | SUM_FIELD | DATE_FIELD | DATE_MODE | AGE_DAYS_MIN | GROUP_FIELD | COND1 | COND2 |
|---|---|---|---|---|---|---|---|---|---|---|
| A_RET_AGED | RET_AGED | DFKKOP | COUNT | | FAEDN | AGE | 10 | BUKRS | AUGST EQ `''` (open) | HVORG IN `<return-debit main transactions, confirm in TFKHVO>` |

VERIFY-DDIC: DFKKOP-FAEDN, AUGST, HVORG, BUKRS (standard payment engine names, not in the confirmed list).
Alternative after confirmation: returns items via DFKKRP (DFKKRP-SELW1 = DFKKOP-AUGBL is confirmed).
Variant with amounts: `AGG_FUNC = SUM`, `SUM_FIELD = BETRH` (VERIFY-DDIC).
Plus the `ZCD_OPS_TABWL` row HCK / READ `DFKKOP` (§5) and the threshold rows in §3.

| CHECK_ID | AGG_ID | TABNAME | AGG_FUNC | DATE_FIELD | DATE_MODE | AGE_DAYS_MIN | GROUP_FIELD | COND1 | Note |
|---|---|---|---|---|---|---|---|---|---|
| C_PPO_BACKLOG | PPO_AGED | /SAPPO/ORDER_HDR | COUNT | `<creation date (DATS), VERIFY-DDIC>` | AGE | 3 | `<business process field, VERIFY-DDIC>` | `<status field> NE <completed status>` VERIFY-DDIC | If the creation column is a time stamp, set DATE_MODE blank and use a status condition only |
| B_VOLUME | FEB_STMT | FEBKO | COUNT | AZDAT (VERIFY-DDIC) | DAY | (set by check) | `<format/sender field, VERIFY-DDIC>` | | Statements loaded per day (BAI vs CAMT) |
| B_VOLUME | PAY_REQ | ZCD_PAYM_REQ_LOG | COUNT | `<request date field (DATS), VERIFY-DDIC>` | DAY | (set by check) | `<source field, VERIFY-DDIC>` | ZZ_STATUS EQ `SUCCESS` | Never "highest COUNTER" — status SUCCESS per standards |

### 4a. Expected groups — `ZCD_HCK_AGG-EXPECTED_GROUPS` (audit A103; was `ZCD_HCK_AGGGRP`, table consolidation 2026-11-08)

A grouped aggregate only returns groups that have rows: a company code or source that delivered nothing
would simply be absent. `EXPECTED_GROUPS` of the aggregate row names the group values it must report -
a comma list of distinct values (each at most 70 characters, CHAR 255 in all; the app refuses an empty
element, a repeat or a too long value, message 426, and a list without `GROUP_FIELD`, message 423); when
the query returns no row for a listed value, the check measures **0** for that group, so a
lower-is-worse threshold on that company can fire while another company is active. The readers
(`ZCL_CD_HCK_C_GENERIC_AGG`, `ZCL_CD_HCK_C_VOLUME`) parse the list once per aggregate
(`ZCL_CD_HCK_AGG_QUERY=>EXPECTED_GROUPS`). A **failed** query is an `AGG_CONFIG_INVALID` error
finding and measures nothing — it never reads as zero volume. When a grouped result reaches the row cap
(5 000 groups) it may be cut off and missing groups are not filled.

| CHECK_ID | AGG_ID | EXPECTED_GROUPS | Meaning (was one ZCD_HCK_AGGGRP row per value) |
|---|---|---|---|
| B_VOLUME | PAY_REQ | `<source system 1, from ZCD_PAYM_REQ_LOG-SOURCE, VERIFY-SE16>` (further sources comma-separated) | Payment requests expected daily |
| A_RET_AGED | RET_AGED | `<company code, VERIFY with Treasury>` (further company codes comma-separated) | Company codes reported even when nothing is aged |

Maintained in the health check configuration app (entity *Generic aggregates*, field *Expected groups*), table logging on.

## 5. Table whitelist — `ZCD_OPS_TABWL`, area HCK, purpose READ

Since the table consolidation of 2026-11-08 the HCK whitelist (was `ZCD_HCK_TABWL`), the drift list (was `ZCD_HCK_DRIFT`, §6) and the FMON approved tables (was `ZCD_FMON_TABWL`, `config/fmon_seed.md`) are one core table, `ZCD_OPS_TABWL`, maintained in the core configuration app (*Approved tables per reader*). Every HCK read of a configured table (generic aggregates, value queries `C_*`, the bgRFC queue source of `E_QUEUES`, the Stripe evidence of `A_INFLIGHT`) needs an active row `HCK` / `READ` of the whole table (`FIELD_NAME` blank - the app refuses a field on an HCK row, message 423); a row of another purpose (`DRIFT`) or area (`FMON` / `SOURCE`) never approves an HCK read.

| PE_AREA | PURPOSE | TABLE_NAME | FIELD_NAME | DESCRIPTION | ACTIVE | APPROVED_BY |
|---|---|---|---|---|---|---|
| HCK | READ | DFKKOP | (blank) | payment engine open items (aging; `A_INFLIGHT` Stripe evidence: payment intent ID by AUGBL) | X | `<security reviewer>` |
| HCK | READ | ZCD_STRP_POUT_LOG | (blank) | Stripe payout log (`A_INFLIGHT` Stripe evidence, fields VERIFY-SE11) | X | `<security reviewer>` |
| HCK | READ | DFKKRP | (blank) | payment engine returns items | X | `<security reviewer>` |
| HCK | READ | FEBKO | (blank) | Bank statement headers (volume) | X | `<security reviewer>` |
| HCK | READ | ZCD_PAYM_REQ_LOG | (blank) | Payment request log (volume; known-table checks C_PRQ_*) | X | `<security reviewer>` |
| HCK | READ | ZCD_SPE_EXCP_LOG | (blank) | Payment request status updates to the source (C_PRQ_NO_SPE) | X | `<security reviewer>` |
| HCK | READ | ZCD_CHECK_HIST | (blank) | Cheque status history from IRIS (C_CHQ_STATUS) | X | `<security reviewer>` |
| HCK | READ | /SAPPO/ORDER_HDR | (blank) | Postprocessing orders (backlog) | X | `<security reviewer>` |
| HCK | READ | `<bgRFC unit / error table, VERIFY>` | (blank) | bgRFC units in error (`E_QUEUES` PARAM4); counts only | X | `<security reviewer>` |

No HR, partner bank or card tables — the aggregate check returns counts/sums only, but the whitelist is the
security boundary; every new row needs a reviewer.

## 6. Configuration drift — `ZCD_OPS_TABWL`, area HCK, purpose DRIFT

| PE_AREA | PURPOSE | TABLE_NAME | FIELD_NAME | DESCRIPTION | ACTIVE |
|---|---|---|---|---|---|
| HCK | DRIFT | TFK042Z | (blank) | Payment program: collections vs disbursements (XEINZ) | X |
| HCK | DRIFT | TFK033D | (blank) | Account determination (`*` wildcard works in FQC0 - confirmed by the user 2026-11-08) | X |
| HCK | DRIFT | ZCD_HCK_DEF | (blank) | Health check catalog | X |
| HCK | DRIFT | ZCD_HCK_THRESH | (blank) | Health check thresholds | X |
| HCK | DRIFT | ZCD_HCK_AGG | (blank) | Generic aggregates with their expected groups (A103) | X |
| HCK | DRIFT | ZCD_JOB_STEP | (blank) | Job cycle steps | X |
| HCK | DRIFT | ZCD_FMON_SLA | (blank) | FMON stage SLAs: durations and deadlines (ZCD_FMON_DEADL merged) | X |
| HCK | DRIFT | ZCD_FMON_CAL | (blank) | FMON expected files | X |
| HCK | DRIFT | ZCD_OPS_ALRULE | (blank) | Alert rules | X |

A drift row hashes the whole table; it approves no read (the hash is read by the HCK DAO with its own static rule, `ZCL_CD_HCK_DAO=>COMPUTE_TABLE_HASH`).

Deadlines, SLAs, calendar and alert rules are listed on purpose (user decision 2026-11-07): new rows come only by transport from DV1, but support may edit existing rows in PS4 (due time, severity, ACTIVE, SO23 list; `Operations_Runbook.md` §5h). Such a production edit is exactly what drift control should show: the table is reported as `CONFIG_DRIFT` until the same change is transported from DV1 and the baseline is taken again.

Parameters (ZCA_PARAM) are not under drift control: their changes are logged by the framework (table logging, customizing requests) and checked every morning by `D_PARAM_INVALID`.

After every approved transport: run `ZCD_MORNING_REPORT` with **Take config baseline** (needs S_TABU_NAM
02 for ZCD_HCK_BASELINE).

## 7. Job cycles (from the SAP Job Schedule wiki) — `ZCD_JOB_CYCLE` / `ZCD_JOB_STEP`

> Monitoring only. Retrigger / restart from SAP is a later phase (Framework 4 part 2).
> Windows are the wiki's Control-M start times plus 30 minutes; ACK windows are assumptions — **confirm**.

| CYCLE_ID | DESCRIPTION | CALENDAR | ACTIVE |
|---|---|---|---|
| COLL_DAY | Collections daily (Stripe, BAI, evening ACH) | `<factory calendar, confirm>` | X |
| DISB_DAY | Disbursements daily (payment requests, wire, check, ACH, ACKs) | `<confirm>` | X |
| RECON_EOD | Reconciliation end of day (GL close, BlackLine expense) | `<confirm>` | X |

| CYCLE_ID | STEP | DESCRIPTION | JOBNAME (pattern) | PROGRAM | PRED | DAY_OFFSET | WINDOW_FROM | WINDOW_TO | MAX_MIN | SKIPPABLE | CRITICAL |
|---|---|---|---|---|---|---|---|---|---|---|---|
| COLL_DAY | 010 | Stripe payout / chargeback | `ZSTRP_PAYOUT.*` | | | 0 | 06:00 | 06:30 | 30 | | X |
| COLL_DAY | 020 | BAI load JPMC + BOA | `ZBAI_FILE_LOAD.*` | | | 0 | 08:20 | 08:50 | 45 | | X |
| COLL_DAY | 030 | ACH PNC & PUB evening (first run) | `ZCOLL_PAY_EVE.*` | RFKK_MA_SCHEDULER | | 0 | 21:15 | 21:45 | 45 | | |
| DISB_DAY | 010 | Payment request cycle morning (first run) | `ZPAYM_REQ_MORN.*` | RFKK_MA_SCHEDULER | | 0 | 04:00 | 04:30 | 30 | | X |
| DISB_DAY | 020 | LifeCo wire / ACH morning | `ZPAYM_REQ_LIFE.*` | RFKK_MA_SCHEDULER | 010 | 0 | 07:15 | 07:45 | 30 | | |
| DISB_DAY | 030 | Regular payment cycle (first hourly run) | `ZPAYM_REQ_REG.*` | RFKK_MA_SCHEDULER | | 0 | 10:00 | 10:30 | 30 | | |
| DISB_DAY | 040 | Wire CORP payment | `ZPAYM_WIRE_CORP.*` | RFKK_MA_SCHEDULER | | 0 | 13:30 | 14:00 | 30 | | X |
| DISB_DAY | 050 | Wire acknowledgment | `ZPAYM_WIRE_ACK.*` | | 040 | 0 | 14:00 | 18:00 | 30 | | |
| DISB_DAY | 060 | ACH PNC & PUB evening (first run) | `ZPAYM_REQ_EVE.*` | RFKK_MA_SCHEDULER | | 0 | 17:00 | 17:30 | 30 | | |
| DISB_DAY | 070 | ECT check payment | `ZPAYM_CHECK_ECT.*` | RFKK_MA_SCHEDULER | | 0 | 19:30 | 20:00 | 45 | | X |
| DISB_DAY | 080 | ACH CORP payment | `ZPAYM_ACH_CORP.*` | RFKK_MA_SCHEDULER | | 0 | 20:00 | 20:30 | 45 | | X |
| DISB_DAY | 090 | ACH acknowledgment | `ZPAYM_ACH_ACK.*` | | 080 | 0 | 20:30 | 23:59 | 30 | | |
| RECON_EOD | 010 | Recon key close / transfer / GL OFSAA | `ZPOST_GL.*` | | | 0 | 23:30 | 23:59 | 60 | | X |
| RECON_EOD | 020 | BlackLine expense (LifeCo wire, ACH PNC, PUB) | `ZEXPENSE_GL.*` | | 010 | 1 | 02:00 | 02:30 | 60 | | X |

Repeating schedules (auto express checks every 5 min, hourly regular cycle) are watched by `E_JOBS`
(cancelled / late / long-running) — a cycle step models one expected instance.

**Acceptance test 5 — add a step by customizing only:** insert one `ZCD_JOB_STEP` row, e.g.
`DISB_DAY | 035 | LifeCo wire / ACH continuous (first run) | ZPAYM_REQ_REG2.* | RFKK_MA_SCHEDULER | 030 | 0 | 10:15 | 10:45 | 30 | | ` —
the next morning report shows the step's state in the `B_CYCLE_*` drill-down; no code, no transport of programs.

## 8. Payments in flight (`A_INFLIGHT`) — method classes, evidence rules, bank code roles, outcomes

User rules 2026-11-07. Method classes and bank code roles are entries of the FI-CA customer posting areas **ZPMC** and **ZBTR** (user decision 2026-11-08, were ZCD_HCK_PMCLASS / ZCD_HCK_BTCROLE), maintained by the FI-CA team in FQC0 (`docs/FICA_Posting_Areas.md`); the evidence rules and role-sequence outcomes stay in the generated HCK configuration app (`ZUI_CD_HCK_CFG`, *Clearing / return evidence rules*, *Role sequence outcomes*; the Stripe evidence settings are ZCA_PARAM parameters, §8d). Everything gets new entries / rows only in DV1 on a customizing request (D-3); production may switch app rows off (`ACTIVE`) - a posting area entry has no ACTIVE flag (it applies while it exists; a class or code not yet confirmed is not entered). Every row is keyed by **flow + method class** (in ZBTR usage `LIFECYCLE` the two are one key SCOPE, e.g. `DACH`): a new class (e.g. collection cheques, international ACH) is entries of ZPMC / ZBTR, rows in the two app tables plus `ZCD_HCK_THRESH` limits — no code, no domain, no parameter. METHOD_CLASS, ROLE and OUTCOME are open lists (documented values below), only FLOW (D / C), PURPOSE, REQUIRED, AGE_BASIS, SCHEME, EXPECTED_DFKKRP and SEVERITY are validated as fixed values (the app for its tables, the morning check `D_POSTAREA_INVALID` for ZPMC / ZBTR); EVIDENCE_CLASS must implement `ZIF_CD_HCK_EVIDENCE` (app check on save, runtime check `CLEARING_RULE_INVALID`). METHOD_CLASS has 3 characters because flow + class (e.g. `CCRD`) is the 4-character threshold key.

### 8a. Posting area `ZPMC` — payment method classes (payment methods confirmed by the user; was `ZCD_HCK_PMCLASS`)

FQC0 entries, keys FLOW / PAY_METHOD / HOUSE_BANK, results METHOD_CLASS / AGE_BASIS / CALENDAR (`docs/FICA_Posting_Areas.md` §2). **One entry per payment method** (the former comma list PAY_METHODS); HOUSE_BANK `*` = the class of the payment method at every house bank.

| FLOW | PAY_METHOD | HOUSE_BANK | METHOD_CLASS | AGE_BASIS | CALENDAR | Text (documentation only) |
|---|---|---|---|---|---|---|
| D | E | * | WIR | VALUE_DATE | | Wire disbursements |
| D | A | * | ACH | VALUE_DATE | | ACH disbursements - bulk vendor |
| D | G | * | ACH | VALUE_DATE | | ACH disbursements - member |
| D | C | * | CHQ | ISSUE_DATE | | Disbursement cheques (cheque register DFKKCR) |
| C | 1 | * | ACH | VALUE_DATE | | ACH collections (CAMT statements) |
| C | 2 | * | ACH | VALUE_DATE | | ACH collections (CAMT statements) |
| C | 3 | * | ACH | VALUE_DATE | | ACH collections (CAMT statements) |
| C | 4 | * | ACH | VALUE_DATE | | ACH collections (CAMT statements) |
| C | 5 | * | ACH | VALUE_DATE | | ACH collections (CAMT statements) |
| C | H | * | ACH | VALUE_DATE | | ACH collections (BAI statements) |
| C | I | * | ACH | VALUE_DATE | | ACH collections (BAI statements) |
| C | J | * | ACH | VALUE_DATE | | ACH collections (BAI statements) |
| C | K | * | ACH | VALUE_DATE | | ACH collections (BAI statements) |
| C | L | * | ACH | VALUE_DATE | | ACH collections (BAI statements) |
| C | B | * | CRD | VALUE_DATE | | Card collections (Stripe) |
| D | `‹confirm›` | * | ACI | VALUE_DATE | `‹UK / DE factory calendar, confirm›` | International ACH disbursements (Barclays, Commerzbank) - **confirm; do not enter before** |

CALENDAR blank = PARAM1 of `A_INFLIGHT`. The payment methods of one class share ageing basis and calendar (check message 433). Today there are no collection wires; a future collection wire or cheque class is entries here plus its rules (§8c), roles / outcomes (§8e / §8f) and limits (§3). One payment method is in one class per flow: the key FLOW + PAY_METHOD + `*` exists once, and a house-bank entry (§8b) must name the same class (message 385 in the morning check `D_POSTAREA_INVALID`; message 385 also stops `A_INFLIGHT` if the configuration ever disagrees).

### 8b. Posting area `ZPMC` entries with a house bank — factory calendar per house bank (optional override; was `ZCD_HCK_PMBANK`, then ZCD_HCK_PMCLASS rows with HBKID)

An entry with a house bank only overrides the calendar of its class for the payments of that bank. FQC0 picks the house-bank entry for those payments (an exact key beats `*`), so it repeats the class of the payment method; CALENDAR is required and AGE_BASIS stays blank (messages 422 / 423); the `*` entry of the same flow + payment method must exist (431). One entry per payment method of the class.

| FLOW | PAY_METHOD | HOUSE_BANK | METHOD_CLASS | AGE_BASIS | CALENDAR | Text (documentation only) |
|---|---|---|---|---|---|---|
| D | `‹ACI method, confirm›` | `‹Barclays house bank, confirm›` | ACI | (blank) | `‹UK calendar›` | UK bank holidays - **confirm; do not enter before** |
| D | `‹ACI method, confirm›` | `‹Commerzbank house bank, confirm›` | ACI | (blank) | `‹DE calendar›` | German bank holidays - **confirm; do not enter before** |

Resolution per payment (unchanged): the house-bank entry of the payment's house bank (DPAYH-HBKID, VERIFY-DDIC) → CALENDAR of the class (`*` entries) → PARAM1 of the check → no calendar (every day counts, warning `INFLIGHT_CONFIG`).

### 8c. `ZCD_HCK_CLRRULE` — clearing / return evidence rules

REQUIRED (design review 2026-11-07): `X` **mandatory**, must hold and indicates the purpose; `C` **mandatory corroboration**, must hold but never indicates on its own; `N` **mandatory**, must not hold; blank = **informational**, shown in the finding only. A mandatory row whose evidence kind is not configured (settings missing), invalid or unreadable makes its purpose **undetermined** for the payment: no positive conclusion, no later purpose decides, the payment stays in flight (aged) and is listed in `CLEARING_UNDETERMINED` (W, metric `PAY_UNDETERMINED`) with a configuration finding (`INFLIGHT_CONFIG` W "not configured - mandatory", or `CLEARING_RULE_INVALID` E). Only informational rows are skipped when their kind is not usable (`INFLIGHT_CONFIG` I). Purposes decide in the order VOIDED, RETURNED, RETRIEVED, PENDING, CLEARED, IN_FLIGHT (RETRIEVED added 2026-11-07 for the canonical payment outcome: a retrieval is not a return): the first purpose with an `X` row that holds decides - all its `X` / `C` rows hold and no `N` row holds = excluded (counted in `PAY_EXCLUDED`; IN_FLIGHT = consistent, stays in flight and is aged), otherwise `CLEARING_INCONSISTENT` (VOIDED, PENDING, CLEARED, IN_FLIGHT) / `RETURN_INCONSISTENT` (RETURNED) naming what held, what is missing and what must not hold.

| FLOW | METHOD_CLASS | PURPOSE | SEQ | EVIDENCE_CLASS | PARAM1 | PARAM2 | REQUIRED | DESCRIPTION | ACTIVE |
|---|---|---|---|---|---|---|---|---|---|
| D | WIR | CLEARED | 010 | ZCL_CD_HCK_EV_BTC_SEQ | `CLEARED` | | X | Rule 1: bank code lifecycle (495) | X |
| D | WIR | CLEARED | 020 | ZCL_CD_HCK_EV_PAY_STATUS | `CLEARED` | | X | Rule 1: DPAYH-ZZ_PAYMENT_STATUS | X |
| D | WIR | RETURNED | 010 | ZCL_CD_HCK_EV_BTC_SEQ | `RETURNED` | | X | Rule 4: 495 → 195 with one returns lot item | X |
| D | WIR | RETURNED | 020 | ZCL_CD_HCK_EV_PAY_STATUS | `RETURNED` | `ISSUED,CONFIRMED` | X | DPAYH status RETURNED (ISSUED / CONFIRMED = not yet) | X |
| D | ACH | CLEARED | 010 | ZCL_CD_HCK_EV_BTC_SEQ | `CLEARED,RETRIEVAL_FAILED` | | X | Rule 1: 466 (retrieval failed = stays paid) | X |
| D | ACH | CLEARED | 020 | ZCL_CD_HCK_EV_PAY_STATUS | `CLEARED` | | X | Rule 1: DPAYH-ZZ_PAYMENT_STATUS | X |
| D | ACH | RETURNED | 010 | ZCL_CD_HCK_EV_BTC_SEQ | `RETURNED` | | X | Rule 4: 466 → 168 (also after a retrieval: 466, 166, 168, 468) | X |
| D | ACH | RETURNED | 020 | ZCL_CD_HCK_EV_PAY_STATUS | `RETURNED` | `ISSUED,CONFIRMED` | X | DPAYH status RETURNED (ISSUED / CONFIRMED = not yet) | X |
| D | ACH | RETRIEVED | 010 | ZCL_CD_HCK_EV_BTC_SEQ | `RETRIEVED` | | X | Manual retrieval 466 → 166 without return - not a return (canonical outcome RETRIEVED, 2026-11-07) | X |
| D | ACH | RETRIEVED | 020 | ZCL_CD_HCK_EV_PAY_STATUS | `RETRIEVED` | `ISSUED,CONFIRMED` | X | DPAYH status RETRIEVED (ISSUED / CONFIRMED = not yet) | X |
| D | CHQ | VOIDED | 010 | ZCL_CD_HCK_EV_CHQ_STATUS | `V` | `STOPPED` | X | Rule 2: state V or DPAYH status STOPPED (either alone) | X |
| D | CHQ | VOIDED | 020 | ZCL_CD_HCK_EV_BTC_SEQ | `CLEARED,CLEARED_MANUAL` | `ZTNUM` (PARAM3 `13`) | N | No cashed line (voided cheque or stopped cheque cashed) | X |
| D | CHQ | VOIDED | 030 | ZCL_CD_HCK_EV_CHQ_STATUS | `B` | | N | Register not cashed (stopped cheque cashed: state B) | X |
| D | CHQ | RETURNED | 010 | ZCL_CD_HCK_EV_BTC_SEQ | `RETURNED` | `ZTNUM` (PARAM3 `13`) | X | 581,255 / 255 with the register state of a return (blank today) | X |
| D | CHQ | CLEARED | 010 | ZCL_CD_HCK_EV_CHQ_STATUS | `B` | | X | Rule 2: DFKKCR-STATE B = cashed | X |
| D | CHQ | CLEARED | 020 | ZCL_CD_HCK_EV_BTC_SEQ | `CLEARED,CLEARED_MANUAL` | `ZTNUM` (PARAM3 `13`) | X | Rule 2: 581 on the statement (CHECT = last 13 of ZTNUM) or cleared manually after a correction | X |
| C | ACH | RETURNED | 010 | ZCL_CD_HCK_EV_BTC_SEQ | `RETURNED` | | X | Rule 4: 468, 468 with one returns lot item | X |
| C | ACH | PENDING | 010 | ZCL_CD_HCK_EV_BTC_SEQ | `REDEPOSIT_PENDING` | | X | Delayed redeposit (one 468, within 10 days) | X |
| C | ACH | CLEARED | 010 | ZCL_CD_HCK_EV_BTC_SEQ | `CLEARED` | | X | 166 / 143 (also after a redeposit) | X |
| C | ACH | CLEARED | 020 | ZCL_CD_HCK_EV_GL_XREF2 | `‹clearing accounts, optional›` | | X | Rule 3: BSEG XREF2 = AUGBL cleared (F.13 by ZUONR) | X |
| C | ACH | CLEARED | 030 | ZCL_CD_HCK_EV_GL_ZUONR | `EQUAL` | `‹clearing accounts›` | (blank) | ZUONR stays AUGBL (changed = anomaly) | X |
| C | CRD | CLEARED | 010 | ZCL_CD_HCK_EV_GL_XREF2 | `‹clearing accounts, optional›` | | X | Rule 3: BSEG XREF2 = AUGBL cleared (F.13 by descriptor) | X |
| C | CRD | CLEARED | 020 | ZCL_CD_HCK_EV_STRIPE | | | C | Stripe payout log row of the payment intent (mandatory corroboration; blank = explicit BSEG-only choice, below) | X |
| C | CRD | IN_FLIGHT | 010 | ZCL_CD_HCK_EV_STRIPE | | | X | Payout processed ... | X |
| C | CRD | IN_FLIGHT | 020 | ZCL_CD_HCK_EV_GL_ZUONR | `CHANGED` | `‹clearing accounts›` | X | ... and descriptor set (ZUONR no longer AUGBL) | X |

**Payment status rows (confirmed DPAYH-ZZ_PAYMENT_STATUS values, user 2026-11-08: ISSUED file sent to the bank, CONFIRMED bank ACK received, CLEARED, RETURNED, RETRIEVED, STOPPED cheques only; the hourly payment status job updates them).** The RETURNED / RETRIEVED status rows stand next to the bank evidence the same way as the CLEARED rows (`X`): status RETURNED / RETRIEVED without the bank line is `RETURN_INCONSISTENT` / `CLEARING_INCONSISTENT`. PARAM2 of `ZCL_CD_HCK_EV_PAY_STATUS` lists the statuses the status job has not updated yet (`ISSUED,CONFIRMED`): a payment in such a status is **pending**, not missing - when the bank evidence of the purpose holds and the status is the only gap, the payment stays **IN_FLIGHT** (aged; never inconsistent; no later purpose decides) and the morning report lists it as `PAY_STATUS_LAG` (W) once `HCK_PAY_STATUS_LAG_MIN` (120) minutes have passed (`HCK_MORNING_REPORT.md` §7b-6). The CLEARED status rows keep PARAM2 blank (rule 1 unchanged: on the statement but status not CLEARED = `CLEARING_INCONSISTENT`); `ISSUED,CONFIRMED` in their PARAM2 would make that case in flight + `PAY_STATUS_LAG` as well - a customizing decision open for the user.

**Stopped cheques (user decision 2026-11-08).** A stopped cheque is the **same outcome as voided** - no new outcome value. VOIDED / 010 holds when DFKKCR-STATE = V **or** the DPAYH status is STOPPED (PARAM2 of `ZCL_CD_HCK_EV_CHQ_STATUS`: payment statuses that hold on their own, with or without register row); either one is enough. The N rows apply to both: a cashed line (020, 581 / correction cleared manually) or the register state B (030) = `CLEARING_INCONSISTENT`, the detail naming "stopped cheque cashed" (the DESCRIPTION of rows 020 / 030, CHAR 60, is the text of the finding - keep the words when the row is edited; 255 + V stays voided after return). STOPPED with the register state still blank = VOIDED, no finding. Because VOIDED decides before CLEARED, a stopped cheque never reaches the CLEARED rows: an N row "status STOPPED must not hold" on CLEARED would never be evaluated and is **not** delivered (first proposal of 2026-11-08, superseded by the user decision). **Stop and reissue (confirmed by the user 2026-11-08, VERIFY closed).** A stop and reissue of a cheque creates a **new payment reference** (new payment document / AUGBL) and a **new cheque number**; the stopped payment keeps status STOPPED (VOIDED here) and the reissue is a separate payment with its own lifecycle (cleared when cashed: state B and its 581). The two are never judged together, so a cashed reissue never reads as "stopped cheque cashed" (ABAP Unit `stop_reissue_judged_apart`, fixture `CHEQUE_REISSUED`).

What the card rows give: cleared G/L line without payout log row = `CLEARING_INCONSISTENT` (CLEARED, condition missing); payout log row but ZUONR still AUGBL = `CLEARING_INCONSISTENT` "payout processed but descriptor not set" (IN_FLIGHT); payout row + descriptor + line not yet cleared = in flight, aged - late after the `CCRD` limit ("F.13 not cleared"). **While the Stripe settings (§8d) are not maintained** the Stripe rows are mandatory but not evaluable: card payments are reported as "clearing not determinable: Stripe evidence not configured" (`CLEARING_UNDETERMINED` W per payment, `INFLIGHT_CONFIG` W for the kind), stay in flight and are aged - they are never cleared on BSEG alone. **Explicit switch (visible configuration choice, per row):** to let the BSEG XREF2 row decide alone until the Stripe field names are maintained, set REQUIRED of the CLEARED / 020 Stripe row to blank (informational) on a customizing request and set it back to `C` together with the §8d settings. Trade-off: with blank, a cleared G/L line without a payout log row is counted as cleared (no `CLEARING_INCONSISTENT` "cleared without payout row"), so a payout file that never arrived is not seen by this check; with `C` (delivered) the card class shows undetermined payments and, after the `CCRD` limit, late payments every day until the settings exist. The IN_FLIGHT rows stay `X`: without Stripe settings they are undetermined too (payment in flight, aged). Planned, not delivered: a 195 deposit on the JPMC collection account ending 16650 for the descriptor's payout date (needs a payout-date evidence kind; account from `ZCD_EBS_ACCT`, never hard-coded) - **confirm**; the group balance of a descriptor (sum of charges and fees = the 195 amount) is proven by the three-way reconciliation check `A_RECON_3WAY` (§10, `STRIPE_GROUP_BREAK`).

### 8d. Stripe evidence settings — framework `ZCA_PARAM`, area `CD_HCK`, parameters `HCK_STRIPE_*` (field names VERIFY-SE11)

Table consolidation 2026-11-08: the name / value rows of `ZCD_HCK_EVSET` (set `STRIPE`) are parameters of the framework, maintained in the app *Parameter areas* (`ZUI_CA_PARAM_O4`, area `CD_HCK`). Definitions: `config/param_definitions.csv`; every parameter is **delivered blank** (landscape-specific) - blank table or intent field = Stripe evidence not configured (`INFLIGHT_CONFIG`, card payments undetermined, §8c). No set id dimension: one Stripe payout log per landscape (a second log would be a second evidence kind), so the Stripe rows of §8c no longer need PARAM1 (not read). The framework validates the value types (table name: DDIC; field names: name pattern; lists: comma lists); `ZCL_CD_HCK_EV_STRIPE` checks table and fields against the DDIC and `ZCD_OPS_TABWL` HCK / READ before each read; a refused value is `D_PARAM_INVALID` the next morning.

| Parameter (was SET STRIPE, NAME) | Value type | Value to maintain (VERIFY-SE11 / **confirm**) | Meaning |
|---|---|---|---|
| `HCK_STRIPE_TABLE` (TABLE) | DDIC, developer-owned | `ZCD_STRP_POUT_LOG` | Stripe payout log (FMON source STRIPE_PAYOUT_IN); also a `ZCD_OPS_TABWL` row HCK / READ |
| `HCK_STRIPE_INTENT_FIELD` (INTENT_FIELD) | CHAR `[A-Z][A-Z0-9_]*`, developer-owned | `‹SE11 payment intent ID field›` | Payout log: payment intent ID |
| `HCK_STRIPE_DFKKOP_FIELD` (DFKKOP_INTENT_FIELD) | CHAR, developer-owned | `‹SE11 DFKKOP payment intent field›` | Open item: payment intent ID (DFKKOP read by AUGBL; DFKKOP on `ZCD_OPS_TABWL` HCK / READ) |
| `HCK_STRIPE_TYPE_FIELD` (TYPE_FIELD) | CHAR, developer-owned | `‹SE11 record type field›` | Optional: record type |
| `HCK_STRIPE_PAYOUT_FIELD` (PAYOUT_FIELD) | CHAR, developer-owned | `‹SE11 payout ID field›` | Optional: payout ID filled = contained in a payout |
| `HCK_STRIPE_ACK_FIELD` (ACK_FIELD) | CHAR, developer-owned | `‹SE11 ACK status field›` | Optional: ACK status |
| `HCK_STRIPE_CHARGE` (CHARGE) | LIST | `‹charge record type›` | Optional: record types that count (record types: payout, refund, fees, network cost, charge) |
| `HCK_STRIPE_REFUND` (REFUND) | LIST | `‹refund record type›` | Optional: refund = anomaly `CLEARING_INCONSISTENT` |
| `HCK_STRIPE_ACK_FULL` (ACK_FULL) | LIST | `‹ACK full value›` | Optional: ACK values that count |
| `HCK_STRIPE_ACK_PARTIAL` (ACK_PARTIAL) | LIST | `‹ACK partial value›` | Optional: partial ACK = anomaly |

The former reserved setting `REQ_INTENT_FIELD` (never read: the chain DFKKOP → payout log does not need it) has no parameter - nothing unused is delivered.

### 8e. Posting area `ZBTR` usage `LIFECYCLE` — bank transaction code roles (scheme from the statement format: FEBEP-VORGC = BAI2, VGEXT = ISO / PRTRY, `ZCL_CD_EBS_SRC_FEB=>LINE_CODE`; was `ZCD_HCK_BTCROLE`)

FQC0 entries of the customer posting area ZBTR (user decision 2026-11-08), keys USAGE / SCOPE / SCHEME / CODE / FAMILY / SUB_FAMILY, results ROLE / COMPARE_AMOUNT (`docs/FICA_Posting_Areas.md` §2). One posting area holds the roles of both checks: `USAGE` `LIFECYCLE` (these entries; `A_INFLIGHT` and the payment outcome) and `RECON` (§10b; `A_RECON_3WAY`). SCOPE of a lifecycle entry = flow + method class (`DWIR`, `CACH`, … - the 4-character threshold key of §3; form `[DC]` + class, message 425; the class must be in ZPMC for the flow, 430). An ISO code is entered as domain / family / sub-family (CODE / FAMILY / SUB_FAMILY); BAI2 leaves FAMILY and SUB_FAMILY blank. No `*` in ZBTR (427). Lifecycle roles are an open list, but a reconciliation role (LEG, DEPOSIT, CUTOFF, REDEPOSIT, CHEQUE, OTHER, IGNORE) is refused on a lifecycle entry (424) and a lifecycle entry needs a role (422); each check reads only its own usage.

| USAGE | SCOPE (flow + class) | SCHEME | CODE | FAMILY | SUB_FAMILY | ROLE | COMPARE_AMOUNT | Text (documentation only) |
|---|---|---|---|---|---|---|---|---|
| LIFECYCLE | DWIR | BAI2 | 495 | | | ORIGINAL | | Original wire (confirmed) |
| LIFECYCLE | DWIR | BAI2 | 195 | | | RETURNED | X | Wire return |
| LIFECYCLE | DACH | BAI2 | 466 | | | ORIGINAL | | Original ACH disbursement |
| LIFECYCLE | DACH | BAI2 | 168 | | | RETURNED | X | Return of the original payment (DFKKRP expected) |
| LIFECYCLE | DACH | BAI2 | 166 | | | RETRIEVED | | Retrieval succeeded |
| LIFECYCLE | DACH | BAI2 | 468 | | | RETRIEVE_FAIL | | Retrieval failed |
| LIFECYCLE | CACH | BAI2 | 166 | | | COLLECTED | | Successful collection |
| LIFECYCLE | CACH | BAI2 | 143 | | | COLLECTED | | Successful collection |
| LIFECYCLE | CACH | BAI2 | 468 | | | COLLECT_FAIL | X | Collection failure (delayed redeposit) |
| LIFECYCLE | CACH | ISO | `‹domain›` | `‹family›` | `‹sub-family›` | COLLECTED | | CAMT methods 1-5, collection - **confirm; do not enter before** |
| LIFECYCLE | CACH | ISO | `‹domain›` | `‹family›` | `‹sub-family›` | COLLECT_FAIL | X | CAMT methods 1-5, collection return - **confirm; do not enter before** |
| LIFECYCLE | CCRD | BAI2 | 195 | | | PAYOUT_RECEIVED | | Stripe payout deposit (incoming transfer); used by the planned deposit evidence |
| LIFECYCLE | DCHQ | BAI2 | 581 | | | CASHED | R | Cheque paid (confirmed); amount compared with the payment amount (DPAYH-RWBTR of the AUGBL) |
| LIFECYCLE | DCHQ | BAI2 | 255 | | | RETURNED | | Cheque returned (confirmed) |
| LIFECYCLE | DCHQ | BAI2 | 399 | | | CORRECTION | C | Bank correction of cheque number / amount (confirmed); C = an earlier 581 amount is superseded, not compared |
| LIFECYCLE | DCHQ | BAI2 | 699 | | | CORRECTION | C | Bank correction (confirmed); further correction codes = more entries (open list) |
| LIFECYCLE | DACI | ISO | `‹domain›` | `‹family›` | `‹sub-family›` | ORIGINAL | | International ACH (Barclays / Commerzbank), original - **confirm; do not enter before** |
| LIFECYCLE | DACI | ISO | `‹domain›` | `‹family›` | `‹sub-family›` | RETURNED | X | International ACH return - **confirm; do not enter before** |

ROLE is up to 15 characters (`PAYOUT_RECEIVED`) - VERIFY-SE11 that TFK033D-FUNnn holds 15 (`docs/FICA_Posting_Areas.md` §4). The same code means different things per flow + class: 468 = collection failure (C ACH) and retrieval failure (D ACH); 195 = wire return (D WIR) and Stripe payout deposit (C CRD); 166 = collection (C ACH) and retrieval (D ACH).

**Codes without a role (design review 2026-11-07).** A monetary line (amount ≠ 0) on the payment reference whose code has no entry here is `BTC_ROLE_MISSING` (E, lifecycle INDETERMINATE - the payment is never concluded CLEARED / RETURNED by the lifecycle) unless the code is an approved informational exclusion of its scheme in ZCA_PARAM (area `CD_HCK`, LIST, delivered blank - add a code only with the business confirmation that it never concerns the payment):

| Parameter | Value (example, **confirm**) | Meaning |
|---|---|---|
| `HCK_BTC_INFO_BAI2` | (blank) | BAI2 type codes that never concern a payment (e.g. a bank fee or an information line carrying the payment reference) |
| `HCK_BTC_INFO_ISO` | (blank) | ISO Domain-Family-Sub-family codes of CAMT lines, same meaning |
| `HCK_BTC_INFO_PRTRY` | (blank) | Proprietary codes, same meaning |

### 8f. `ZCD_HCK_SEQOUT` — outcomes of role sequences (first active pattern by SEQ matching the whole sequence)

| FLOW | METHOD_CLASS | SEQ | SEQ_PATTERN | OUTCOME | EXPECTED_DFKKRP | MAX_AGE_DAYS | SEVERITY | DESCRIPTION | ACTIVE |
|---|---|---|---|---|---|---|---|---|---|
| C | ACH | 010 | `COLLECTED` | CLEARED | 0 | | | 166 / 143 (confirm) | X |
| C | ACH | 020 | `COLLECT_FAIL` | REDEPOSIT_PENDING | 0 | 10 | | Redeposit pending, 10 days (confirmed) | X |
| C | ACH | 030 | `COLLECT_FAIL,COLLECTED` | CLEARED | 0 | | | Redeposit succeeded (confirm) | X |
| C | ACH | 040 | `COLLECT_FAIL,COLLECT_FAIL` | RETURNED | 1 | | | Final failure with returns lot (confirm) | X |
| D | ACH | 010 | `ORIGINAL` | CLEARED | 0 | | | 466 (confirm) | X |
| D | ACH | 020 | `ORIGINAL,RETURNED` | RETURNED | 1 | | | 466 → 168 (confirmed) | X |
| D | ACH | 030 | `ORIGINAL,RETRIEVED` | RETRIEVED | 0 | | | 466 → 166, no DFKKRP (confirmed) | X |
| D | ACH | 040 | `ORIGINAL,RETRIEVE_FAIL` | RETRIEVAL_FAILED | 0 | | | 466 → 468, payment stays paid (confirm) | X |
| D | ACH | 050 | `ORIGINAL,RETRIEVED,RETURNED,RETRIEVE_FAIL` | RETURNED | 1 | | | 466, 166, 168, 468: the original failed (confirmed) | X |
| D | WIR | 010 | `ORIGINAL` | CLEARED | 0 | | | 495 (confirmed) | X |
| D | WIR | 020 | `ORIGINAL,RETURNED` | RETURNED | 1 | | | 495 → 195 (confirmed) | X |
| D | ACI | 010 | `ORIGINAL` | CLEARED | 0 | | | International ACH - **confirm** | (blank) |
| D | ACI | 020 | `ORIGINAL,RETURNED` | RETURNED | 1 | | | International ACH return - **confirm** | (blank) |

Disbursement cheques (lines linked by DFKKCR-DOC1R = AUGBL → ZTNUM → last 13 characters = FEBEP-CHECT; REG_STATE = DFKKCR-STATE list, `BLANK` = blank state; FINDING = the outcome is itself a finding, its DESCRIPTION goes into the detail; EXPECTED_DFKKRP 0 for every cheque outcome - confirmed: a returned cheque has no returns lot, only the register changes, so a returns lot = `RETURN_INCONSISTENT`):

| FLOW | METHOD_CLASS | SEQ | SEQ_PATTERN | REG_STATE | OUTCOME | FINDING | EXPECTED_DFKKRP | SEVERITY | DESCRIPTION | ACTIVE |
|---|---|---|---|---|---|---|---|---|---|---|
| D | CHQ | 001 | `.*CORRECTION.*` | `B` | CLEARED_MANUAL | | 0 | | Correction, cleared manually in FPCHR (confirmed) | X |
| D | CHQ | 002 | `.*CORRECTION.*` | | MANUAL_CLEARING | MANUAL_CLEARING_REQUIRED | 0 | E | Correction on the statement - clear manually in FPCHR | X |
| D | CHQ | 010 | `.*(CASHED.*CASHED\|RETURNED.*RETURNED).*` | | CLARIFICATION | CHEQUE_CLARIFICATION | 0 | E | Several 581 / 255 for one cheque - check the clarification worklist | X |
| D | CHQ | 020 | `CASHED` | | CLEARED | | 0 | | 581 (confirmed; with state B by the CLEARED rule) | X |
| D | CHQ | 030 | `(CASHED,)?RETURNED` | `BLANK` | RETURNED | | 0 | | Returned cheque: register state blank today (confirmed; may change if the register gets a returned status - change REG_STATE only) | X |
| D | CHQ | 040 | `(CASHED,)?RETURNED` | `V` | RETURNED_VOIDED | | 0 | | Voided after the return (confirmed, counted as VOIDED) | X |
| D | CHQ | 050 | `(CASHED,)?RETURNED` | `B` | RETURN_NOT_REGISTERED | RETURN_INCONSISTENT | 0 | E | 255 on the statement but the cheque register still shows cashed | X |

**Code review 2026-11-07 (cheque lifecycle).** COMPARE_AMOUNT `C` (correction): a line of this role after the last `R` line supersedes its amount - a 581 corrected by 399 / 699 and cleared in FPCHR is never `CHEQUE_AMOUNT_MISMATCH`. Several cheques on one payment document (a **defensive path**: a stop and reissue creates a new payment document and cheque number, user 2026-11-08, so a reissue is never a second cheque of the same document; the handling stays for register data that does carry two cheques): the lifecycle is evaluated **per cheque** (ZTNUM within HBKID / HKTID); the newest cheque not voided (DFKKCR-STATE ≠ V) decides the payment (also for `ZCL_CD_HCK_EV_CHQ_STATUS` and `ZCL_CD_HCK_EV_STMT_CHEQUE`), the other cheques are shown with their own outcome and their anomalies are reported too. An outcome row with REG_STATE applies only to a cheque register row (cheque link); when the first matching row needs a register state and the payment has none (document link, or no DFKKCR row) the payment is `CHEQUE_REGISTER_MISSING` (E) - never a silent `UNEXPECTED_SEQUENCE`. REG_STATE is CHAR 40 (no truncation), validated on save: tokens `BLANK` or one upper-case state character (message 420). FINDING is validated on save against the catalogue of in-flight finding codes (`ZCL_CD_HCK_EV_SUPPORT=>OUTCOME_FINDINGS`: CHEQUE_CLARIFICATION, MANUAL_CLEARING_REQUIRED, RETURN_INCONSISTENT, CLEARING_INCONSISTENT, CHEQUE_AMOUNT_MISMATCH, UNEXPECTED_SEQUENCE, PENDING_OUTCOME_MISSING; upper case, message 421) - a new finding code is a code change with its runbook triage, not configuration only. An outcome that is itself a finding no longer hides the returns lot, amount and age checks: every anomaly is reported, the outcome's finding first. Reads: the rows CLEARED / 020 (`CLEARED,CLEARED_MANUAL`), VOIDED / 020 and RETURNED / 010 share the link `ZTNUM` / 13 - the lifecycle of each payment is evaluated once per link and run and only "found" is derived per PARAM1; DFKKCR is read once per payment and run for every cheque kind (`CHECKS_OF`), FEBEP and DFKKRP once per link.

No REDEPOSIT_PENDING row for wires (no delayed redeposit). Any other sequence is `UNEXPECTED_SEQUENCE` (codes and dates in the detail). Longer retrieval sequences are not specified yet. OUTCOME values are an open list: an outcome counts only where a §8c row names it in PARAM1 (IN_FLIGHT or any unlisted outcome = in flight, aged).

## 9. Messages

HCK messages are numbers 300–399 and 650–699 of class `ZCD_OPS`, listed with every other message in `config/zcd_ops_messages.md`.

## 10. Three-way reconciliation (`A_RECON_3WAY`) — `ZCD_HCK_RCSET`, posting area `ZBTR` (usage RECON)

> **CONFIRM BEFORE TRANSPORT.** Example rows; G/L accounts, house bank IDs and codes are placeholders until Finance / Treasury confirm them. New rows only on a customizing request in DV1 (HCK configuration app *Reconciliation clearing account sets*; the bank code roles are FQC0 entries of ZBTR, D-3).

### 10a. `ZCD_HCK_RCSET` — clearing account sets (one transit / clearing account in one currency)

HKONT in internal format is not required: the check converts it (ALPHA). The house bank account (BUKRS + HBKID + HKTID) must have an active `ZCD_EBS_ACCT` row with ACCOUNT_NO = the 10-character payment engine account of FEBEP-XBLNR (as EBS) - otherwise `RECON_CONFIG` (NO_ACCOUNT). One active set per BUKRS / HKONT / WAERS (a second is `RECON_CONFIG` DUPLICATE).

| SET_ID | KIND | SIDE | BUKRS | HKONT | WAERS | HBKID | HKTID | INVERT_BANK | LEG_BANK | LEG_FICA | TOLERANCE | DESCRIPTION | ACTIVE |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| COLL_ACH | ACH_ZUONR | C | `‹US company code›` | `‹ACH collection clearing account›` | USD | `‹JPMC house bank›` | `‹collection account ID›` | | X | X | 0 | ACH collections: day legs + one-to-one by assignment | X |
| DISB_ACH | THREEWAY | D | `‹US company code›` | `‹ACH disbursement transit account›` | USD | `‹JPMC house bank›` | `‹disbursement account ID›` | | X | X | 0 | ACH disbursements (466 / 168 / 166 / 468) | X |
| DISB_WIRE | THREEWAY | D | `‹US company code›` | `‹wire transit account›` | USD | `‹JPMC house bank›` | `‹wire account ID›` | | X | X | 0 | Wire disbursements (495 / 195) | X |
| DISB_CHQ | THREEWAY | D | `‹US company code›` | `‹cheque clearing account›` | USD | `‹house bank›` | `‹cheque account ID›` | | X | X | 0 | Cheques (581 cashed weeks after the run: cheque bucket) | X |
| STRIPE_US | STRIPE | C | `‹US company code›` | `‹Stripe clearing account›` | USD | `‹JPMC house bank›` | `‹account ID of the JPMC account ending 16650›` | | | | 0 | Stripe descriptor group = BAI 195 deposit + fees | X |

The JPMC account ending 16650 is an **example value**: it is the `ZCD_EBS_ACCT` row named by HBKID / HKTID of `STRIPE_US`, never a literal in code. A Stripe set compares only the descriptor groups (LEG_BANK / LEG_FICA are not used); the deposit code is its `DEPOSIT` row below.

### 10b. Posting area `ZBTR` usage `RECON` — role of each bank code per set (was `ZCD_HCK_RCBTC`, then ZCD_HCK_BTCROLE)

| USAGE | SCOPE (set id) | SCHEME | CODE | FAMILY | SUB_FAMILY | ROLE | COMPARE_AMOUNT | Text (documentation only) |
|---|---|---|---|---|---|---|---|---|
| RECON | COLL_ACH | BAI2 | 166 | | | LEG | | ACH collected |
| RECON | COLL_ACH | BAI2 | 143 | | | LEG | | Collected (BAI 143, collections only) |
| RECON | COLL_ACH | BAI2 | 468 | | | REDEPOSIT | | Collection failure, delayed redeposit within HCK_RECON_REDEPOSIT_DAYS when no returns lot |
| RECON | DISB_ACH | BAI2 | 466 | | | LEG | | ACH original |
| RECON | DISB_ACH | BAI2 | 168 | | | CUTOFF | | ACH return - processed in the next period (cut-off) |
| RECON | DISB_ACH | BAI2 | 166 | | | CUTOFF | | ACH retrieval - processed in the next period (cut-off) |
| RECON | DISB_ACH | BAI2 | 468 | | | OTHER | | Retrieval failure (stays paid) |
| RECON | DISB_WIRE | BAI2 | 495 | | | LEG | | Wire original |
| RECON | DISB_WIRE | BAI2 | 195 | | | CUTOFF | | Wire return |
| RECON | DISB_CHQ | BAI2 | 581 | | | CHEQUE | | Cheque cashed |
| RECON | DISB_CHQ | BAI2 | 255 | | | CHEQUE | | Cheque returned |
| RECON | DISB_CHQ | BAI2 | 399 | | | CHEQUE | | Correction (confirm) |
| RECON | DISB_CHQ | BAI2 | 699 | | | CHEQUE | | Correction (confirm) |
| RECON | STRIPE_US | BAI2 | 195 | | | DEPOSIT | | Stripe payout deposit |

A code on the set's account without an entry is **unmapped** (bucket UNMAPPED, `RECON_VARIANCE` W naming the code): add the entry by transport, or `IGNORE` for a code that never carries money of the set (e.g. balance records); `*` is refused (427) because it would hide new codes. Roles: `LEG` compared, `DEPOSIT` Stripe deposit, `CUTOFF` return / retrieval of the next period, `REDEPOSIT` failure with delayed redeposit, `CHEQUE` cheque exception, `OTHER` explained variance, `IGNORE` not money of the set. SCOPE = the set id of §10a, SCHEME `BAI2`: the morning check `D_POSTAREA_INVALID` refuses another scheme, a COMPARE_AMOUNT and any other role on a RECON entry (messages 413 / 423), and these seven roles on a lifecycle entry (424). BAI2 type codes (FEBEP-VORGC) only; CAMT (VGEXT) codes are not reconciled yet (**confirm**). The lifecycle roles of §8e answer a different question: same posting area, usage `LIFECYCLE`, read only by `A_INFLIGHT` - a lifecycle entry never reaches the reconciliation and a RECON entry never reaches the lifecycle.

### 10c. Thresholds and alerts

No `ZCD_HCK_THRESH` row is needed: the check raises its own findings (breaks E, variances W, timing / cut-off / pending redeposit I). Optional trend row: `A_RECON_3WAY | RC_BREAKS | * | 1 | 1 | X | NONE`. Alerts: the HCK rules of `config/alert_seed.md` (`RECON_BREAK`, `RECON_SUBLEDGER_BREAK`, `STRIPE_GROUP_BREAK` to the RTB support list, escalated to the RTB lead).
