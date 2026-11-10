# QA1 pilot — one collections flow, one disbursement flow, one BAI account

> **First principle:** a pilot proves that the suite *notices* what goes wrong in a real flow and tells the right person with evidence - nothing in the pilot repairs anything.
> **Analogy:** a smoke-detector test in one wing of the building: you light a controlled smoke candle in each room and check that the right alarm rings at the right desk, before the detectors go into every wing; the fire brigade (SAP and Control-M procedures) still puts out the fires.

Status 2026-11-10: plan and test pack. **Nothing has been activated or run in an SAP system**; every expected result below is
derived from the code and configuration in this repository and becomes evidence only when executed in QA1. Fields in
`<angle brackets>` are filled by the pilot lead before the start (no names of people in this repository).

| Field | Value (fill before the pilot) |
|---|---|
| `<collections flow>` | e.g. one ACH collection file interface of `ZCD_FMON_IFACE` (`ACK_LEVEL` FILE) |
| `<disbursement flow>` | e.g. one ACH or wire disbursement interface (`ACK_LEVEL` PAYMENT) with its PRISM stages |
| `<BAI account>` | one payment engine account of `ZCD_EBS_ACCT` (house bank / account ID) and its statement interface (`BAI_*_IN`) |
| `<clearing job>` | SM37 job name (PCRE) of the clearing job, window and calendar from the Control-M schedule |
| `<pilot company code>` / `<second company code>` | company codes of the two-user test (`Test_and_Validation_Document.md` §6.16) |
| Pilot lead, operator, approver, reviewers | roles below; persons recorded in the private site, not here |

## 1. Operating boundary (applies to every step of the pilot)

**Posting, clearing, job restarts and file retransmission stay under the existing SAP and Control-M procedures; the suite only reads, reports, routes and records sign-off.** In the pilot the suite: reads FS-CD / FI tables and its own tables, writes only its own runs, findings, exception history, alert log, sign-offs and file evidence (`ZCA_OPS_*`, `ZCD_*` of the suite), sends e-mails to SO23 lists, and shows apps and cards. It never posts, clears, releases, restarts a job, regenerates or retransmits a file, and has no navigation to transactions that do. Incidents, RCA and the backlog stay in the team's private site (user decision 2026-11-10: no incidents in SAP); the observation and next action of a sign-off name the site entry when there is one.

## 2. Scope

| In scope | Out of scope |
|---|---|
| `<collections flow>`: expected file (calendar), generation, PRISM hand-off / receipt / delivery, bank ACK per file, ACK totals | other interfaces (their rows stay inactive in QA1 for the pilot window or are simply not judged) |
| `<disbursement flow>`: payment run, file, PRISM stages, ACK per payment, payments in flight (`A_INFLIGHT`) | posting / clearing / retransmission (operating boundary) |
| `<BAI account>`: statement import (FEB), EBS validation of its statements and lines, BAI deadline, three-way reconciliation of its set | IDoc interfaces (none in use, user decision 2026-11-10) |
| Morning report, overview page, daily control review (12 controls), exceptions app, alert e-mails | PS4 (only after the go / no-go of §8) |
| Company-code isolation with two users (§6.16 of the test document) | incidents in SAP |

**What the pilot automates and shows (and where).**

| Capability | How the suite does it | Evidence in SAP |
|---|---|---|
| Expected versus observed | FMON calendar (`ZCD_FMON_CAL`) against files received / generated (`F_MISSING`, `F_LATE`); SLA stages per interface (`ZCD_FMON_SLA`: `F_PRISM`, `F_PRISMRCV`, `F_PRISMDLV`, `F_BANKACK`, `F_DEADLINE`); three-way reconciliation expected / actual per group-day (`A_RECON_3WAY`); job cycle steps against their window (`B_CYCLE_*`, `B_CLEAR_*`) | `ZCA_OPS_FINDING` (check codes `FILE_MISSING`, `NO_<stage>`, `<stage>_LATE`, `STAGE_DEADLINE_MISSED`, `RECON_BREAK`, `STEP_MISSED`); file dashboard; open variances card |
| Stale-run detection | every dashboard row carries the *as of* of the last completed run and a stale flag (`MON_STALE_AFTER_MIN_<area>`: FMON 15 min, EBS / HCK 26 h); the freshness card of the overview; the morning report's own health (`HCK_SELF`: `RUN_HUNG`, `CHECKS_NOT_CONFIGURED`); stale running runs refused / reported (`ZIF_CA_OPS_STORE=>GET_STALE_RUNS`) | freshness card red; `ZCA_OPS_RUN` status R older than the limit; finding `RUN_HUNG` |
| Acknowledgement matching | ACK stage SLA (`F_BANKACK`: `NO_BANK_ACK`, `BANK_ACK_LATE`), ACK totals against the file (`F_ACKMATCH`: `ACK_COUNT_MISMATCH`, `ACK_AMOUNT_MISMATCH`, tolerance 0.01), per-payment status lag (`A_INFLIGHT` `PAY_STATUS_LAG`) | file dashboard (ACK count / amount, bucket PARTIAL); exceptions app; alert `FMON_ACK` |
| Exception routing | every B / E / W finding is an owned exception with an SLA due date; alert rules route by area, severity, check pattern and company code to SO23 lists, throttled / escalated; failed deliveries are logged and become `ALERT_FAILED` findings | `ZCA_OPS_FINDING` (owner, due date), `ZCA_OPS_ALLOG` (one row per routing decision), exceptions app history |
| Morning handoff | morning report e-mail (route MORNING) by 07:00 + overview page + daily control review with sign-off per control slice by the cut-off (08:30 payment files / clearing job, 09:00 others, `CONTROL_TIME_ZONE` = CST) | `ZCA_OPS_REVIEW` rows (checked by, verified at, observation, next action); cards *Checks reviewed n / m*, *Review overdue* |

## 3. Preconditions (all before day 1 of the pilot)

**3.1 Activation order (DV1, then the same transports to QA1).**
1. ZCA_PARAM 1.1.0 (`param-framework/`), its VERIFY list closed.
2. ZCA_OPS (`ops-framework/`, packages `ZCA_OPS`, `ZCA_OPS_UI`; without the demo), `ops-framework/docs/VERIFY.md` V01-V43 closed in DV1, incl. the company-code isolation V35-V43; SE11 indexes of the DDL comments (MOD, OPN, OBJ, RUL, INT unique, FND).
3. The suite (`ops-suite/src`), then the ADT-only objects of `ops-suite/cds/` (`Implementation_Order.md`); service bindings `ZUI_CA_OPS_EXC_O4`, `ZUI_CA_OPS_REV_O4`, `ZUI_CA_OPS_CFG_O4`, `ZUI_CD_*_O4`; launchpad space *Production Support*.
4. Customizing transports (§3.4) and job variants; ABAP Unit of all three packages green (§8 step 2).

**3.2 Roles (PFCG, QA1).**

| Role | ZCA_OPS (ZCA_PARAR / ACTVT / BUKRS) | Purpose in the pilot |
|---|---|---|
| Operator (user A) | CD_EBS, CD_FMON, CD_HCK, CD_OPS / 02, 03 / `<pilot company code>` | works exceptions, signs off controls of its company code |
| Operator (user B) | same areas / 02, 03 / `<second company code>` | two-user isolation test |
| Approver | same areas / 03, 85 / both company codes | approves waivers and long suppressions (never the requester) |
| Reviewer (`ZCD_OPS_REVIEWER`) | CD_FMON, CD_EBS, CD_HCK / 02, 03 / as the slices to sign off | daily control review |
| Display (`Z_CD_OPS_DISPLAY`) | * / 03 / * | pilot lead, auditors |
| Batch user (`Z_CA_OPS_BATCH`) | CA_OPS + CD_* / 16 / * | FMON monitor, EBS validation, morning report, retention |

**3.3 Parameters (ZCA_PARAM, value rows in QA1).** Areas `CD_OPS`, `CD_EBS`, `CD_FMON`, `CD_HCK`, `CA_OPS` registered; `CONTROL_TIME_ZONE` = `CST` (VERIFY STZAC), `CONTROL_TEAMS`, `EXC_REASON_CODES`; `SLA_DAYS_CD_<area>_<B|E|W>`; `MON_STALE_AFTER_MIN_FMON` / `_EBS` / `_HCK`; `FMON_TIME_ZONE`; `ALERT_MORNING`, `ALERT_DEFAULT`; `ALERT_TEMPLATE_DEFAULT`, `ALERT_MAIL_RENDERER` (`SMTG`, or `BUILTIN` if templates are not yet created); EBS: `EBS_FEB_POSTED_FIELDS`, read mode; HCK: report variant of `ZCD_MORNING_REPORT`. Every parameter the morning check `D_PARAM_INVALID` refuses is fixed before day 1.

**3.4 Configuration rows (customizing requests from DV1).**

| Table / app | Rows for the pilot |
|---|---|
| `ZCD_FMON_IFACE`, `ZCD_FMON_SLA`, `ZCD_FMON_CAL`, `ZCD_FMON_CHK` | the rows of `<collections flow>` and `<disbursement flow>` (name pattern checked with `ZCD_OPS_PATTERN_CHECK`), their SLA rows incl. `SENT_TO_PRISM`, `PRISM_RECEIVED`, `PRISM_DELIVERED`, `ACK_RECEIVED`; the statement interface of `<BAI account>` with its 10:00 DEADLINE row; calendar rows of the pilot days (`config/fmon_seed.md`) |
| `ZCD_EBS_ACCT` and the EBS rule registry | `<BAI account>` (bank key exactly as in the statement); rule rows of `config/zcd_ebs_rule_def.csv` |
| `ZCD_HCK_DEF`, `ZCD_HCK_THRESH`, `ZCD_JOB_CYCLE` / `ZCD_JOB_STEP`, `ZCD_HCK_RCSET` | morning report catalog of `config/hck_seed.md` incl. **`B_CLEAR_TODAY` / `B_CLEAR_PRIOR` and cycle `CLEARING` with `<clearing job>`** (§7 of the seed); the reconciliation set of `<BAI account>`'s clearing account |
| `ZCA_OPS_ALRULE`, `ZCA_OPS_ALCHN` (app `ZUI_CA_OPS_CFG`) | rules of `config/alert_seed.md` (`EBS_BLOCK`, `EBS_ERROR`, `FMON_SLA`, `FMON_ACK`, `FMON_FILE`, `FMON_BAIDL`, `HCK_RED`, `HCK_RECON`, `ALL_ABORT`, `RUN_LOCKED`); `BUKRS_PATTERN` blank unless a list serves one company code |
| SO23 | shared lists `ZCD_PAYOPS`, `ZCD_RETOPS`, `ZCD_RTBSUP`, `ZCD_RTBLEAD`, `ZCD_COMPL` with the pilot members (confirm none is scoped to one company code - decision D-CC4) |
| SAP e-mail templates (SMTG) | `ZCA_OPS_ALERT_DEFAULT` and the suite templates named by the rules (`templates/`), created in DV1 and transported |
| Control register (`ZCA_OPS_CONTROL` / `_CTLT` / `_CTLCHK`) | `config/control_register.csv`, `control_guidance.csv`, `control_checks.csv` (52 rows) with **owner, backup and team filled** by the support lead; 9 controls active, 3 gap controls inactive (`config/control_seed.md` §2a) |
| Approved tables (`ZCD_OPS_TABWL`) | HCK READ and FMON SOURCE rows of the pilot's checks, each with its security reviewer |

**3.5 Jobs.** FMON monitor every 5 minutes (`ZCD_FMON_MONITOR_ALL`), EBS validation after the BAI load of `<BAI account>` (Control-M), morning report before 07:00 (`ZCD_MORNING_REPORT`), retention purge weekly in test mode for the pilot. The clearing job and the payment runs stay on their Control-M schedule (operating boundary).

## 4. Daily routine during the pilot (times in `CONTROL_TIME_ZONE`)

| When | Who | What | Evidence recorded |
|---|---|---|---|
| continuously | system | FMON every 5 min; EBS after each BAI load; alert e-mails by rule | `ZCA_OPS_RUN`, `ZCA_OPS_FINDING`, `ZCA_OPS_ALLOG` |
| by 07:00 | system | morning report (HCK) e-mail to `ALERT_MORNING` | run of area CD_HCK, `ZCD_HCK_RESULT` per check |
| shift start | operator | overview page in the order of `Operations_Runbook.md` §0: freshness first (a stale area is reported as stale, never as clean), critical exceptions, controls | - |
| by the cut-off (08:30 / 09:00) | reviewer | daily control review: each flagged control slice opened, evidence checked, **Mark reviewed** with observation / next action where required | `ZCA_OPS_REVIEW` (one row per control slice and date) |
| same shift | operator | exceptions app: assign every open B / E, classify timing items, resolve with a reason when the owning team confirms the fix | `ZCA_OPS_EXC_HIST` |
| end of day | pilot lead | pilot log in the private site: scenarios run, findings raised, alerts received (with SOST status), sign-offs, deviations | screenshots, `ZCA_OPS_ALLOG` extract |

## 5. Scenario tests

Each scenario is run in QA1 on the pilot flows, by provoking the condition without changing production behaviour (a job held in Control-M, a file held at PRISM, test ACK data, a channel switched off) - the provoking step is done by the owning team under its own procedure (operating boundary).

### S1 Missed clearing job

| Item | Content |
|---|---|
| Covered by | `B_CLEAR_TODAY` / `B_CLEAR_PRIOR` (`ZCL_CD_HCK_C_JOB_CYCLE`, cycle `CLEARING`, critical step `<clearing job>`) - **configuration built in this change** (proposal P1; `config/hck_seed.md` §2, §3, §7); control `CLEARING_JOB` (covered checks `GROUP2` = `B_CLEAR_TODAY`, `B_CLEAR_PRIOR`); alert rule `HCK_RED` (severity E, run RAG R) |
| Steps | 1. Control-M team holds `<clearing job>` past the end of its window (or it is not scheduled on a pilot business day). 2. Morning report runs (or run `ZCD_MORNING_REPORT` after the window). 3. Open the overview and the daily control review. |
| Expected SAP evidence | `ZCA_OPS_FINDING`: area `CD_HCK`, `GROUP2` = `B_CLEAR_TODAY` (or `_PRIOR` for a night step), check code `STEP_MISSED` (E, critical step) and the metric finding `THRESHOLD_RED` on `STEPS_NOT_OK` (red at 1); `ZCD_HCK_RESULT` row `RED` for the check; `ZCD_HCK_METRIC` `STEPS_NOT_OK` = 1, DIM1 `CLEARING`; `ZCA_OPS_ALLOG` row of rule `HCK_RED` status S; control *Clearing job* = *Action required*, awaiting review; **no** finding of the clearing step under `B_CYCLE_TODAY` (excluded by its PARAM2) |
| Acceptance | the missed job is reported once, red, by 07:00 (or by the next morning report after the window); the reviewer can sign it off only with observation and next action (076); the restart is done by Control-M, not the suite; the next morning report after the successful run resolves the exception (disposition R, history `RESOLVE` by the run) |

### S2 Partial acknowledgement (count or amount mismatch)

| Item | Content |
|---|---|
| Covered by | `F_ACKMATCH` (`ZCL_CD_FMON_CHK_ACK_MATCH`, tolerance 0.01): `ACK_COUNT_MISMATCH` / `ACK_AMOUNT_MISMATCH` (E); `F_BANKACK` for a missing / late ACK (`NO_BANK_ACK`, `BANK_ACK_LATE`); per payment `A_INFLIGHT` `PAY_STATUS_LAG` (morning); control `PENDING_ACKS`; alert rule `FMON_ACK` (`(NO_)?BANK_ACK(_LATE)?\|ACK_.+MATCH`, `SHOW_AMOUNTS` X) |
| Steps | 1. On `<collections flow>` (ACK per file) load an ACK whose count (or amount) differs from the file's control total (QA1 test ACK data, ACK tables loaded by the existing ACK job). 2. Wait for the next FMON run (5 min). |
| Expected SAP evidence | `ZCA_OPS_FINDING`: area `CD_FMON`, `RULE_ID` `F_ACKMATCH`, check code `ACK_COUNT_MISMATCH` (or `ACK_AMOUNT_MISMATCH`), reference = file ID; file dashboard: flow bucket PARTIAL, ACK count / amount next to the record count / control total; `ZCA_OPS_ALLOG` row of rule `FMON_ACK` (S) and the e-mail with the missing-ACK table (payments and amounts); control *Pending acknowledgements* = *Action required* |
| Acceptance | the mismatch is raised within one FMON cycle after the ACK load; an ACK with matching totals raises nothing; a count the source did not report is never compared (no false finding); the e-mail reaches `ZCD_PAYOPS` only |

### S3 Failed alert delivery (channel down / no recipient)

| Item | Content |
|---|---|
| Covered by | alert router: every routing decision logged in `ZCA_OPS_ALLOG` (status F on failure); `send( )` without recipients or on an inactive channel logs F **and** raises (A45) - the engine records the finding `ALERT_FAILED` (W, with the exception trace) on its run; next morning `E_ALERT_DELIVERY` (`ZCL_CD_HCK_C_ALERT_HEALTH`, metric `ALERT_FAILED` per channel, amber 1 / red 5; `ALERT_CLAIM_STUCK`); runbook §1 step 5 |
| Steps | 1. Deactivate channel `EMAIL` (`ZCA_OPS_ALCHN` ACTIVE blank) **or** empty the SO23 list of one rule's destination in QA1. 2. Provoke an E finding of that rule (e.g. S2). 3. Next morning report. 4. Restore the channel / list. |
| Expected SAP evidence | `ZCA_OPS_ALLOG`: row of the rule with status F and the error text (no e-mail in SOST); `ZCA_OPS_FINDING`: check code `ALERT_FAILED` (W) on the FMON run, owned exception; next morning: `E_ALERT_DELIVERY` amber (metric `ALERT_FAILED` = 1 for channel EMAIL), threshold finding; morning report category E shows the failed delivery |
| Acceptance | the run itself completes (a failing channel never aborts it); nothing is silently dropped (one F row per failed decision, V34); the failure is visible the next morning without anyone having received the original alert; after the restore the next alert is sent (S) |

### S4 Payment file generated without confirmed forwarding (PRISM hand-off / delivery missing)

| Item | Content |
|---|---|
| Covered by | SLA stages of `<disbursement flow>`: `F_PRISM` (stage `SENT_TO_PRISM`: `NO_PRISM_HANDOFF` E / `PRISM_HANDOFF_LATE` W), `F_PRISMRCV` (`PRISM_RECEIVED`: `NO_PRISM_RECEIVED`), `F_PRISMDLV` (`PRISM_DELIVERED`: `NO_PRISM_DELIVERED`, `PRISM_QUEUE_LONG`), `F_PRFILE` (`PRISM_UNKNOWN_FILE` / `PRISM_NOT_LOADED`); controls `OUTBOUND_IFACE` and `PAYMENT_FILES`; alert rule `FMON_SLA` (`F_(SLA\|PRISM.*\|FILERCV)`) |
| Steps | 1. The payment run of `<disbursement flow>` generates its file (`ZCDT_REGUT` / file registry). 2. PRISM team holds the file (no pick-up) - or picks it up but holds delivery to the bank. 3. Wait beyond the SLA minutes of the stage (`ZCD_FMON_SLA`: e.g. 30 min hand-off, 15 min receipt, 5 min + throttle delivery). |
| Expected SAP evidence | `ZCD_FMON_FILE` / `ZCD_FMON_EVENT`: file at stage GENERATED (or SENT_TO_PRISM without PRISM_DELIVERED); `ZCA_OPS_FINDING`: area `CD_FMON`, `RULE_ID` `F_PRISM` check code `NO_PRISM_HANDOFF` (or `F_PRISMDLV` `NO_PRISM_DELIVERED`), reference = file ID; file dashboard: SLA status BREACHED, bucket AT_PRISM / SENT; `ZCA_OPS_ALLOG` row of rule `FMON_SLA`; controls *Outbound ZICD / ZCD* and *Payment files* = *Action required* |
| Acceptance | the breach is raised in the first FMON run after the SLA (≤ 5 min late); a file that reaches the stage late gives `<stage>_LATE` (W) instead, and the open exception is resolved; retransmission is decided and done by PRISM / payment operations, never by the suite |

### S5 Stale monitor (supplementary)

Hold the FMON monitor job for more than 15 minutes (or the morning report beyond 26 h in a test window): the freshness card turns red, every FMON dashboard row shows *as of* with the stale flag, and the morning report's self-check reports `RUN_HUNG` for a run left in status R (`HCK_SELF`). Acceptance: no card of a stale area is green; the operator reports the area as stale (runbook §0 step 1).

### S6 Company-code isolation (supplementary)

The two-user test CC-01 ... CC-24 of `Test_and_Validation_Document.md` §6.16 with `<pilot company code>` / `<second company code>` on the pilot data. Acceptance: all six criteria of §6.16.

### Scenario coverage

| Scenario | Covered by (existing) | Built in this change | Still open |
|---|---|---|---|
| S1 missed clearing job | job cycle check class, morning report, `HCK_RED` | cycle `CLEARING`, checks `B_CLEAR_TODAY` / `B_CLEAR_PRIOR`, thresholds, exclusion in `B_CYCLE_*`, covered-check rows of `CLEARING_JOB` (configuration) | job name / window / calendar of `<clearing job>` (Control-M) |
| S2 partial ACK | `F_ACKMATCH`, `F_BANKACK`, `A_INFLIGHT`, `FMON_ACK` | - | ACK test data in QA1 |
| S3 failed alert delivery | router log F, `ALERT_FAILED`, `E_ALERT_DELIVERY` | - | - |
| S4 file without confirmed forwarding | `F_PRISM`, `F_PRISMRCV`, `F_PRISMDLV`, `F_PRFILE`, `FMON_SLA` | - | SLA minutes of `<disbursement flow>` confirmed with PRISM |
| S5 stale monitor | as-of / stale flags, freshness card, `HCK_SELF` | - | - |
| S6 isolation | DCL rule, slices, write checks | company-code isolation (Part A of this change) | - |

## 6. Evidence map — the 13 controls of the mockup minus IDoc (12 controls)

*IDoc / interface checks* is dropped (no IDocs in use, user decision 2026-11-10; no proposal). Areas: the control's area; findings read from `ZCA_OPS_FINDING`; status derived per business date and company-code slice in `ZUI_CA_OPS_REV` (`ops-framework/docs/CONTROL_REVIEW.md`).

| # | Control | Covered by (check IDs / finding field) | Tables | Apps | Status |
|---|---|---|---|---|---|
| 1 | Payment files `PAYMENT_FILES` (CD_FMON) | `RULE_ID` `F_MISSING`, `F_LATE`, `F_REJECT`, `F_DUP`, `F_SIZE`, `F_REGEN`, `F_SLA`, `F_DEADLINE` | `ZCD_FMON_FILE`, `ZCD_FMON_EVENT`, `ZCD_FMON_CAL`, `ZCD_FMON_SLA` | file monitoring dashboard, exceptions app | active, full |
| 2 | Clearing job `CLEARING_JOB` (CD_HCK) | `GROUP2` `B_CLEAR_TODAY`, `B_CLEAR_PRIOR` | `ZCD_JOB_CYCLE`, `ZCD_JOB_STEP`, `TBTCO` (read), `ZCD_HCK_RESULT`, `ZCD_HCK_METRIC` | health check dashboard, morning report | active, full once `<clearing job>` is filled (P1 built) |
| 3 | Base-rejected items `BASE_REJECTS` | - | - | - | **inactive** - meaning confirmed 2026-11-10 (source reject after `SCHEDULED`; Stripe premium refund), data source open: question P2 (`config/control_seed.md` §2a); pilot scenario once active: a Stripe card premium rejected by BASE must show a refund (R3) |
| 4 | ECT pending items `ECT_PENDING` | - (`C_CHQ_STATUS` covers a status going backwards, not pending) | `ZCD_CHECK_HIST` (read by `C_CHQ_STATUS`) | - | **inactive** - question P3 |
| 5 | Outbound ZICD / ZCD `OUTBOUND_IFACE` (CD_FMON) | `RULE_ID` `F_PRISM`, `F_PRISMRCV`, `F_PRISMDLV`, `F_PRFAIL`, `F_PRFILE` | `ZCD_FMON_FILE`, `ZCD_FMON_PRISM`, `ZCD_FMON_EVENT` | file monitoring dashboard | active, full for configured interfaces |
| 6 | BlackLine `BLACKLINE` (CD_HCK) | `GROUP2` `A_GL_TRANSFER` | `DFKKSUMC`, `DFKKKO`, `BKPF` (read) | health check dashboard | active, partial (P4: extract file not monitored) |
| 7 | BAI exceptions `BAI_EXCEPTIONS` (CD_EBS) | `RULE_ID` `S01`-`S13`, `R18`, `R01`-`R22`, `CB`, `ENG` | `FEBKO`, `FEBEP` (read), `ZCD_EBS_ACCT`, `ZCD_EBS_RULE_DEF` | EBS validation dashboard | active, full |
| 8 | Manual retrievals `MANUAL_RETRIEVALS` (CD_EBS) | `RULE_ID` `R07L` | `ZCD_ACH_RTRV_LOG` (read), `FEBEP` | EBS validation dashboard | active, partial (P5) |
| 9 | Missing check IDs `MISSING_CHECK_IDS` | - | - | - | **inactive** - question P6 (candidate: `CHECK_CODE` `CHEQUE_REGISTER_MISSING` of `A_INFLIGHT`) |
| 10 | Pending acknowledgements `PENDING_ACKS` (CD_FMON) | `RULE_ID` `F_BANKACK`, `F_ACKMATCH` | `ZCD_FMON_FILE`, ACK tables (read) | file monitoring dashboard | active, full per file (per payment: `A_INFLIGHT` `PAY_STATUS_LAG`, add a row once confirmed) |
| 11 | Returns notifications `RETURNS_NOTIF` (CD_FMON) | `RULE_ID` `F_LOT`, `F_NOCAGE` | `DFKKRP`, `DFKKNRK` / `DFKKNRP` (read), `ZCD_FMON_LOTCFG` | file monitoring dashboard, EBS returns / NOC drill-down | active, partial - question P7 |
| 12 | Daily reconciliation `DAILY_RECON` (CD_HCK) | `GROUP2` `A_RECON_3WAY` | `ZCD_HCK_RCSET`, `ACDOCA`, `FEBEP`, `DFKKSUMC` (read), `ZCD_HCK_METRIC` | open variances card, health check dashboard | active, full |

**Gaps and the proposal to close each** (detail and exact questions: `config/control_seed.md` §2 / §2a): P2 Base rejects - generic aggregate row once table / status / meaning are named; P3 ECT pending - generic aggregate or a latest-row check once the pending status values and the `ZCD_CHECK_HIST` fields are confirmed; P6 Missing check IDs - covered-check row `CHEQUE_REGISTER_MISSING` (partial) or a DPAYH / DFKKCR anti-join check once the meaning is confirmed; P7 Returns notifications - FMON outbound interface + deadline, or a status check, once the notification path is known; P4 BlackLine extract file - FMON interface (row `BLACKLINE_OUT` exists in the seed) with a deadline; P5 manual retrievals - generic aggregate on the retrieval log (status field VERIFY-SE11).

## 7. Acceptance criteria per rollout step

| Step | Entry | Acceptance (all) |
|---|---|---|
| 1. DV1 activation | revision pinned (commit SHA in the transport), ZCA_PARAM 1.1.0 active | ZCA_PARAM, ZCA_OPS, suite and `cds/` objects active without errors; DCLs active; service bindings published; SE11 indexes created; ATC company variant: no new errors beyond the documented exemptions (`ATC_Validation.md`) |
| 2. DV1 tests | step 1 | ABAP Unit of the three packages green (coverage recorded in `Coverage_Run_Register.csv`); `ops-framework/docs/VERIFY.md` **V26-V34** (control review, alert audit log) and **V35-V43** (company-code isolation) closed with evidence; suite V44 / V45 confirmed; two-user test §6.16 CC-01 ... CC-24 passed in DV1 with test data |
| 3. QA1 pilot | steps 1-2 transported; preconditions §3 complete; pilot fields filled | 10 consecutive business days of the daily routine (§4) without a missed morning report or an unexplained stale area; S1-S6 executed with the expected evidence; every B / E finding of the pilot flows assigned the same shift; every control slice signed off by its cut-off on ≥ 9 of 10 days; no alert lost (every `ZCA_OPS_ALLOG` F row explained); no finding / count of the other company code visible (S6); zero writes outside the suite's tables (ST05 / table logging sample) |
| 4. PS4 go / no-go | QA1 pilot report | CAB approval (release pack: CAB approval document, this pilot report, `Test_and_Validation_Document.md`), owners of every active control named, SO23 lists and templates in PS4, rollback rehearsed (deactivate jobs; the suite changes no business data), decisions D-CC1 ... D-CC5 and the open gap questions answered or accepted as open, go-live limited to the pilot flows first |

## 8. Exit criteria of the pilot

- **Pass:** all acceptance criteria of step 3 met; no scenario produced a false *Healthy* (a provoked failure always turned its control and its card red / amber); the operators could hand off every finding with area, as-of, object key, check code and owner without opening SE16.
- **Fail / stop:** any company-code leak (S6), a lost alert that was not reported the next morning (S3), a stale area shown as clean (S5), a write by the suite to a business table, or a scenario that needs a code change to be detected - each stops the pilot; the fix goes through DV1 again.
- **Carry-over:** inactive gap controls (P2, P3, P6) and partial ones (P4, P5, P7) stay as documented; they do not block the pilot but are named in the go / no-go.

## 9. VERIFY items of this pack

- **V45 (QA1):** `B_CYCLE_TODAY` / `_PRIOR` with PARAM2 `(?!CLEARING).*` (negative look-ahead in the PCRE list of `ZCL_CD_HCK_PARAM=>PATTERNS`, complete value) still report every other cycle and no longer the clearing step; `B_CLEAR_TODAY` / `_PRIOR` report it once (S1).
- Framework V26-V43 and suite V44 as listed in §7 step 2.
