# Health Check (HCK) — example customizing (seed)

> **CONFIRM BEFORE TRANSPORT.** Every row below is an *example* built from the landscape facts in
> `docs/DEVELOPMENT_STANDARDS.md` and the Control-M / SAP job schedule wiki (October 2025).
> Job names in the wiki are **placeholders**; the real SAP jobs follow `ZCD_<function>_<ENTITY>`.
> Table/field names marked **VERIFY-DDIC** are not confirmed in this landscape — the engine validates
> them against the runtime DDIC and reports `AGG_CONFIG_INVALID` instead of failing silently, but the
> *business meaning* (which values, which date) must be confirmed by the payment-engine functional team.
> Maintain in DV1 (SM30), transport DV1 → QA1 → PS4. `ZCD_HCK_BASELINE` and `ZCD_HCK_METRIC` are
> application data (delivery class A) and are **never** transported.

## 1. Runtime parameters — `ZCD_OPS_PARAM` (core table)

| PARAM_NAME | PARAM_VALUE | Meaning |
|---|---|---|
| HCK_WATCH_PE_AREAS | `EBS,FMON,HCK` | Payment engine areas whose last run is checked (health of the health check) |
| HCK_MAX_AGE_HOURS | `26` | Default max age of a payment engine area's last run (daily run + 2 h slack) |
| HCK_MAX_AGE_H_FMON | `1` | Fallback only: with the delivered `ZCD_OPS_MONCFG` row FMON = 15 min the self-check and the dashboard both use 15 minutes (`config/alert_seed.md`); this hours value applies only when that row is deleted |
| HCK_TIMEOUT_SEC | `300` | Default check timeout when `ZCD_HCK_DEF-TIMEOUT_SEC` = 0; item-wise checks stop between items once it has passed (BUDGET_EXHAUSTED, A18) |
| HCK_LOOKBACK_RUNS | `8` | Default baseline history points (one point per finished, non-test run — A59) |
| HCK_MAX_RUN_MIN | `120` | A run of a watched area in status R longer than this is HUNG (red self-check, A06); per area `HCK_MAX_RUN_MIN_<AREA>` |
| HCK_FLAT_TOL_PCT | `10` | Flat history (standard deviation 0): adverse change beyond this % of the mean is an outlier (A58) |
| HCK_TOP_N | `20` | Open exceptions listed in the report |
| HCK_MAIL_ROUTE | `MORNING` | Route of the morning report e-mail |
| HCK_MAX_JOB_ROWS | `5000` | TBTCO job runs per read (technical jobs, job cycle, job runtime); hard ceiling 50 000 |
| HCK_MAX_JOB_NAMES | `20000` | Distinct TBTCO job names per window; reaching it fails the check (747); hard ceiling 200 000 |
| HCK_MAX_AGG_ROWS | `5000` | Groups of a generic aggregate / volume check; hard ceiling 50 000 |
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
| E_JOBS | Cancelled, long-running and late jobs | E | ZCL_CD_HCK_C_TECH_JOBS | X | 100 | H | `ZCD_.*` | `120` (min) | `30` (grace min) | 60 |
| E_SYSTEM | Short dumps, update errors, locks | E | ZCL_CD_HCK_C_TECH_SYS | X | 110 | M | | | | 60 |
| E_ALERT_DELIVERY | Alert delivery health (failed / throttled) | E | ZCL_CD_HCK_C_ALERT_HEALTH | X | 120 | M | `24` (hours) | | | 60 |
| C_PRQ_NO_SPE | Payment request failed without SPE row (source never told) | C | ZCL_CD_HCK_C_PRQ_SPE | X | 72 | H | `TABLE=ZCD_PAYM_REQ_LOG;KEY=‹SE11 request key›;STATUS=ZZ_STATUS;DATE=‹SE11 date›` | `FAIL=‹confirm failure values›;OK=SUCCESS;DAYS=3;MAX=200` | `TABLE=ZCD_SPE_EXCP_LOG;KEY=‹SE11 request key›;DATE=‹SE11 date›` | 120 |
| C_CHQ_STATUS | Cheque status went backwards (ZECT_STATUS) | C | ZCL_CD_HCK_C_CHQ_STATUS | X | 74 | M | `TABLE=ZCD_CHECK_HIST;KEY=‹SE11 cheque›;SEQ=‹SE11 counter/time›;STATUS=‹SE11 status›;DATE=‹SE11 date›` | `TERMINAL=3,4,9;ALLOWED=10>9;DAYS=7;MAX=200` | | 120 |
| C_PRQ_CANCEL | Paid payment request left CANCELLED (PCLM) | C | ZCL_CD_HCK_C_PRQ_CANCEL | X | 76 | H | `TABLE=ZCD_PAYM_REQ_LOG;KEY=‹SE11 FIN number›;STATUS=ZZ_STATUS;SOURCE=SOURCE;DATE=‹SE11 date›` | `CANCELLED=CANCELLED;SRC=PCLM;DAYS=7;MAX=200` | `TABLE=DFKKOP;KEY=ZZ_FIN_TRANS_NUM;PAID=AUGBL;DATE=AUGDT` | 300 |

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
Plus `ZCD_HCK_TABWL` row `DFKKOP` and the threshold rows in §3.

| CHECK_ID | AGG_ID | TABNAME | AGG_FUNC | DATE_FIELD | DATE_MODE | AGE_DAYS_MIN | GROUP_FIELD | COND1 | Note |
|---|---|---|---|---|---|---|---|---|---|
| C_PPO_BACKLOG | PPO_AGED | /SAPPO/ORDER_HDR | COUNT | `<creation date (DATS), VERIFY-DDIC>` | AGE | 3 | `<business process field, VERIFY-DDIC>` | `<status field> NE <completed status>` VERIFY-DDIC | If the creation column is a time stamp, set DATE_MODE blank and use a status condition only |
| B_VOLUME | FEB_STMT | FEBKO | COUNT | AZDAT (VERIFY-DDIC) | DAY | (set by check) | `<format/sender field, VERIFY-DDIC>` | | Statements loaded per day (BAI vs CAMT) |
| B_VOLUME | PAY_REQ | ZCD_PAYM_REQ_LOG | COUNT | `<request date field (DATS), VERIFY-DDIC>` | DAY | (set by check) | `<source field, VERIFY-DDIC>` | ZZ_STATUS EQ `SUCCESS` | Never "highest COUNTER" — status SUCCESS per standards |

### 4a. Expected groups — `ZCD_HCK_AGGGRP` (audit A103)

A grouped aggregate only returns groups that have rows: a company code or source that delivered nothing
would simply be absent. Each row below names a group value the aggregate must report; when the query
returns no row for it, the check measures **0** for that group, so a lower-is-worse threshold on that
company can fire while another company is active. A **failed** query is an `AGG_CONFIG_INVALID` error
finding and measures nothing — it never reads as zero volume. When a grouped result reaches the row cap
(5 000 groups) it may be cut off and missing groups are not filled.

| CHECK_ID | AGG_ID | GROUP_VALUE | DESCRIPTION |
|---|---|---|---|
| B_VOLUME | PAY_REQ | `<source system 1, from ZCD_PAYM_REQ_LOG-SOURCE, VERIFY-SE16>` | Payment requests expected daily |
| A_RET_AGED | RET_AGED | `<company code, VERIFY with Treasury>` | Company codes reported even when nothing is aged |

Maintained in the health check configuration app (entity *Expected groups*), table logging on.

## 5. Table whitelist — `ZCD_HCK_TABWL`

| TABNAME | DESCRIPTION | ACTIVE | APPROVED_BY |
|---|---|---|---|
| DFKKOP | payment engine open items (aging) | X | `<security reviewer>` |
| DFKKRP | payment engine returns items | X | `<security reviewer>` |
| FEBKO | Bank statement headers (volume) | X | `<security reviewer>` |
| ZCD_PAYM_REQ_LOG | Payment request log (volume; known-table checks C_PRQ_*) | X | `<security reviewer>` |
| ZCD_SPE_EXCP_LOG | Payment request status updates to the source (C_PRQ_NO_SPE) | X | `<security reviewer>` |
| ZCD_CHECK_HIST | Cheque status history from IRIS (C_CHQ_STATUS) | X | `<security reviewer>` |
| /SAPPO/ORDER_HDR | Postprocessing orders (backlog) | X | `<security reviewer>` |

No HR, partner bank or card tables — the aggregate check returns counts/sums only, but the whitelist is the
security boundary; every new row needs a reviewer.

## 6. Configuration drift — `ZCD_HCK_DRIFT`

| TABNAME | DESCRIPTION | ACTIVE |
|---|---|---|
| TFK042Z | Payment program: collections vs disbursements (XEINZ) | X |
| TFK033D | Account determination (no `*` wildcard in this landscape) | X |
| ZCD_HCK_DEF | Health check catalog | X |
| ZCD_HCK_THRESH | Health check thresholds | X |
| ZCD_HCK_AGG | Generic aggregates | X |
| ZCD_HCK_AGGGRP | Expected groups of aggregates (A103) | X |
| ZCD_OPS_PARAM | Suite parameters | X |
| ZCD_JOB_STEP | Job cycle steps | X |

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

## 8. Messages — class `ZCD_OPS`, range 300–399 (merge into `config/zcd_ops_messages.md`)

| No. | Text |
|---|---|
| 300 | Check &1: class &2 does not implement ZIF_CD_HCK_CHECK |
| 301 | Check &1 failed: &2 |
| 302 | Table &1 is not on the health check whitelist ZCD_HCK_TABWL |
| 303 | Table &1 does not exist in the ABAP Dictionary |
| 304 | Field &1 does not exist in table &2 |
| 305 | Operator &1 for field &2 is not supported (EQ NE GT LT GE LE IN) |
| 306 | Value &1 is not a valid number for field &2 |
| 307 | Aggregate &1 of check &2: date mode &3 is invalid (AGE, DAY, blank) |
| 308 | Aggregate on table &1 (&2) failed in the database |
| 309 | Date field &1 of table &2 is not of type DATS |
| 310 | Check &1 has no aggregate definition in ZCD_HCK_AGG |
| 311 | Hash of table &1 could not be calculated |
| 312 | (reserved) |
| 313 | Lock table could not be read (ENQUEUE_READ return code &1) |
| 314 | Configuration baseline taken for &1 tables &2 |
| 315 | Morning report exported to &1 |
| 316 | Export file &1 could not be opened for writing |
| 317 | Aggregate function &1 of check &2 is not supported (COUNT, SUM) |
| 318 | SUM field &1 of table &2 is not numeric |

Core messages also used by HCK: 010, 041, 050, 051.
