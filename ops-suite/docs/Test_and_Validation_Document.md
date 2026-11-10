# Payment Engine Operations Suite — Test and Validation Document

| | |
|---|---|
| **Status** | **Draft** — written before execution. Every result is an expected value or pending; nothing here is a passed test |
| **Objects under test** | `ZCL_CD_OPS_*`, `ZCL_CD_EBS_*`, `ZCL_CD_FMON_*`, `ZCL_CD_HCK_*` and their interfaces; reports `ZCD_EBS_VALIDATE`, `ZCD_FMON_MONITOR`, `ZCD_MORNING_REPORT`; tables `ZCD_OPS_*`, `ZCD_BTC_*`, `ZCD_EBS_*`, `ZCD_FMON_*`, `ZCD_HCK_*`, `ZCD_JOB_*` |
| **Comparison** | Legacy BAI validators v4 (`Z_BAI_MASS_VALIDATION`) against `ZCD_EBS_VALIDATE` (shadow run); legacy morning report v1 for coverage of checks |
| **Landscape** | DV1 — ABAP Unit · QA1 — functional, parity, integration, performance |
| **Change / transport / incident** | `<CHG number>` · `<transport numbers>` · `<incident number>` |

Approvals, production execution and post-implementation verification are covered by the CAB document, not here.

---

## 1. Scope

> **First principle:** a change is proven by comparing what it does with what it replaces, on the same input.
> **Analogy:** a new route is judged by driving both routes on the same morning, not by reading the map.

In scope: ABAP Unit tests; EBS validation of imported statements and of bank files before import; BTC mapping and zero-suspense blocking; file registry, event chain, SLA, returns/NOC completeness; health checks, job-cycle monitoring, morning report; configurable alerting; parity with the legacy validators; performance at production volume.

Out of scope: transport import, activation, syntax and ATC (build hygiene); posting enforcement and job retrigger (later phases — the suite is read-only towards production); PRISM and bank internals beyond the file and ack tables.

## 2. What is being compared

| Aspect | Legacy | New |
|---|---|---|
| Codes validated | 10 hard-coded validator classes; any other code unchecked | Every code: mapped (category + configured rules) or blocked (R14) |
| Flow (collection/disbursement) | Configured but not applied | XBLNR pattern or account default; map rows per flow |
| Statement checks | None | S01–S12 (balances, sequence, account, date, duplicates, counts, coverage, completeness) |
| File formats | FEBEP only | BAI2 and CAMT.053/054 files before import, plus FEBKO/FEBEP after import |
| Results | Failed records only, ZBAI_* tables | Every run counted; owned exceptions with SLA in ZCA_OPS_FINDING |
| Alerts | Hard-coded e-mail on failure rate | ZCA_OPS_ALRULE: channels, throttling, quiet hours, escalation, log |
| Morning report | Free-text SQL rules, WRITE list | Whitelisted, DDIC-validated checks A–E, baselines, ALV + HTML e-mail |

## 3. Test approach

Two real inputs instead of the population: one configured case (positive) and an adjacent unconfigured one (negative), so the difference is attributable to one customizing row. Close each negative by adding the row and re-running. Alter one configuration row at a time and restore it between cases.

## 4. Test data and configuration

| Item | Value |
|---|---|
| House bank accounts | One disbursement (JPMC), one collection (BOA) in `ZCD_EBS_ACCT`, each with ACCOUNT_NO = its 10-character payment engine account from FEBEP-XBLNR, plus one inactive row |
| Statements | One BAI2 file per bank (`config/samples/bai2_sample.txt` as layout reference), one CAMT.053 and one CAMT.054 returns file |
| Customizing | `config/*.csv`, `config/*_seed.md` loaded per `Implementation_Order.md` step 3 |
| Reset | Delete test runs from ZCA_OPS_RUN / _FINDING / ZCA_OPS_ALLOG by RUN_ID after each case |

Production data never leaves the system; extracts for evidence are anonymised.

## 5. ABAP Unit tests (DV1)

1095 methods in the 104 package test includes (every class of `src/` has a test path: 104 own includes, 46 covered by another include, 1 exempt - `Coverage_Run_Register.csv`) (plus 8 in the cds/ class `ZCL_CD_TRX_REQ_CDS_TEST`, created in ADT after SE11), listed per object in `TDD_Approach_and_Coverage.md` §4 and `Coverage_Run_Register.csv`. Expected: all green, `RISK LEVEL HARMLESS`, statement coverage ≥ 90 % per object (record actual values in the register).

| Run | Expected | Actual |
|---|---|---|
| Package `ZCD_OPS*` ABAP Unit | 902 / 902 green | pending |
| Coverage per object | ≥ 90 % | pending |

## 6. Functional tests (QA1)

### 6.1 EBS validation

| ID | Scenario | Configuration | Expected result | Actual / status |
|---|---|---|---|---|
| EBS-01 | BAI2 file before import, all codes mapped, balances consistent | Seed map | Run S, no B/E findings | pending |
| EBS-02 | Same file with one detail record changed to an unmapped type code | Seed map | Line blocked, R14 UNMAPPED_BTC (B), S09 BTC_COVERAGE on the statement | pending |
| EBS-03 | Acceptance 3: add a ZBTM entry (FQC0) for the code from EBS-02 + ZCD_BTC_RULE R01/R04 | +1 ZBTM entry, +2 rule rows | Line validated by R01/R04, no R14 | pending |
| EBS-04 | Acceptance 4: opening differs from prior closing by 0.02 | ZCD_BTC_RULE `*`/S01 TOLERANCE 0.01, SEVERITY B, ACTION BLOCK | S01 OPENING_NE_PRIOR_CLOSING (B); with deviation 0.01 no finding | pending |
| EBS-05 | BAI2 file with wrong 49 account control total | — | Parser S06 BAI2_ACCT_CTRL_TOTAL (B) | pending |
| EBS-06 | CAMT.053 with TxsSummry sum not matching entries | — | S06 CAMT_SUM_MISMATCH (B), S12 if counts differ | pending |
| EBS-07 | CAMT.054 returns with RtrInf R01 and an unmapped R99 | ZRSN entry R01 only (no `*` entry) | R05 REASON_UNMAPPED on the R99 line only; with a ZRSN `*` entry the R99 line takes its reason | pending |
| EBS-07a | Imported statement (FEB source, posted): a 168 return whose returns lot item has RLGRD = a configured reason, one with RLGRD blank, one with an unmapped RLGRD, one payment with two items of different RLGRD; a NOC (C01) whose DFKKNRP item carries the AUGBL in INFOF, one carrying the payment reference; one payment without lot | ZRSN entry R01 → return reason, C01 → NOC reason; R05 NEEDS_POSTING = X | Pass; REASON_MISSING; REASON_UNMAPPED; REASON_AMBIGUOUS (once); both NOC lines pass with their FLGRD; no R05 finding for the payment without lot (R07R reports it); an unposted entry is not judged by R05 (S13) — VERIFY-SE11 RLGRD, FLGRD, INFOF content | pending |
| EBS-08 | CAMT line with Prtry code 168 issuer BAI | `EBS_CAMT_BAI_FALLBACK` = X | Maps to BAI2 168 rules; with a value row with blank value (BOOL off in ZCA_PARAM) → R14; without a value row → the default X | pending |
| EBS-09 | Imported statement (FEB source), 168 on disbursement account, payment not RETURNED in DPAYH | Seed group BAI168D | R07 PAYMENT_STATUS | pending |
| EBS-09a | User decision 2026-11-08: imported statement (FEB source), 166 on a disbursement account for (a) a payment whose ACH retrieval is logged AF and whose DPAYH status is RETRIEVED, **no** returns lot (FP09 / DFKKRP empty for the payment); (b) the same with DPAYH status RETURNED; (c) a 195 on a disbursement account for a wire with status RETURNED; (d) the same wire still CONFIRMED | Seed groups BAI166D (R07L AF / AP, no PARAM3; R07 RETRIEVED) and BAI195D (R07 RETURNED) | (a) no finding (no RETURN_ITEM_NOT_FOUND); (b) R07 PAYMENT_STATUS naming RETURNED; (c) no finding; (d) R07 PAYMENT_STATUS. ABAP Unit `bai166d_retrieved_no_lot_ok`, `bai166d_returned_fails`, `bai195d_returned_passes`, `bai195d_status_not_returned` | pending |
| EBS-10 | 581 checks paid with one register amount off by 1.00 | Seed group BAI581D | R08 CHECK_AMOUNT_MISMATCH on that check, R12 CODE_TOTAL_MISMATCH on the statement | pending |
| EBS-11 | Same statement file delivered twice | — | S07 STMT_ALREADY_IMPORTED (B) | pending |
| EBS-13 | Circuit breaker (A104): **FEB source** (`P_FEB`) over ≥ 3 imported statements, each a controlled package, every package > 50 % of its lines unmapped (the statements were imported, posted and cleared before the run — post-posting detective control) | `P_PACK` = 1 (one statement per package); `EBS_CB_MIN_LINES` = 1, `EBS_CB_FAIL_PCT` = 50, `EBS_CB_PACKAGES` = 3; ≥ 3 test statements selected by `S_KUKEY` / date range | Package 3 trips the breaker: run status A (aborted), one CIRCUIT_BREAKER finding (rule CB, E), no further package read, alert per the ON_ABORT rule; with only 2 bad packages followed by a good one: no breaker (counter resets) | pending |
| EBS-13a | Oversized or invalid single file through the **file source** (`P_FILE`) — one file is always one package, so the breaker cannot trip | (a) file not UTF-8; (b) BAI2 file cut off before the 98/99 trailers; (c) production-size file (largest observed day, `<line count, VERIFY with operations>`) | (a) read rejected, message 012, no run results (A69); (b) structural findings S00 / S06 TRAILER missing (B), lines not reported as validated (A86/A95); (c) one package, run completes or fails visibly; record runtime and memory — no size limit exists in code (`VERIFY` in QA1 whether one is needed) | pending |
| EBS-14 | Test mode | P_TEST = X | Findings shown; ZCA_OPS_RUN / ZCA_OPS_FINDING / ZCA_OPS_ALLOG unchanged | pending |
| EBS-16 | Payment engine account scope (user decision 2026-11-06), FEB source: statement A whose lines all carry XBLNRs of the active account (e.g. `JPMC8XX1174412334`, `…335`); statement B with one line of another account; statement C with a line whose XBLNR is blank; statement D of an inactive account; earlier open exception on statement B | ZCD_EBS_ACCT: account active, second account inactive | A validated as before; B, C, D: no rule, no finding (no S04, no R14), not counted as entries, not on the dashboard; run message "3 statements out of scope (lines not all payment engine accounts)"; B's earlier exception stays open; activate D's account and re-run → D validated and shown | pending |
| EBS-17 | XBLNR derivation on production samples (SE16 FEBEP, one statement per bank JPMC / BOA / PNC) | — | Letters removed + first 10 characters = the account Treasury lists for that house bank account (`ZCL_CD_EBS_PE_SCOPE=>PE_ACCOUNT_FROM_XBLNR` and dashboard `PeAccount` agree) | pending |
| EBS-15 | POSTING_INCOMPLETE (operating model 2026-11-06): import a statement with a 466 (BAI466D, R19) and a 275 sweep line; run `ZCD_EBS_VALIDATE` (FEB source) **before** FEBP; then run FEBP and the clearing job and re-run the same variant | SE11 check of FEBEP-VB1OK / VB2OK done; `EBS_FEB_POSTED_FIELDS` default; seed S13 / NEEDS_POSTING | Run 1: one POSTING_INCOMPLETE (S13, W) on the statement counting the 466 line only (the 275 NOT_POSTED line is not counted); no R19 / R18 / S10 finding; run message "1 entries not evaluated (posting not complete)"; RAG amber, not green. Run 2: no POSTING_INCOMPLETE, R19 / R18 / S10 evaluated, the POSTING_INCOMPLETE exception resolved "Passed on re-run"; nothing posted, cleared or changed by either run (ST05 / table compare) | pending |

### 6.2 File monitoring
Twenty-four cases FMON-01 … FMON-24 (FMON-20 … 24 added 2026-11-07 for **regenerated files** — facts confirmed by the user 2026-11-07: PRISM rejects a file name it already has; a file PRISM could not deliver is regenerated by SAP with a new name for the same payments, also the cheque print file to IRIS — failed file replaced, regeneration overdue, regeneration although the first file did not fail (critical), re-send of a known name rejected by PRISM, no generation group = unchanged; FMON-15 … 19 added 2026-11-07: BAI processing deadline at 10:00 US Central (`FMON_TIME_ZONE` = CST; statement date = previous business day and a statement for every payment engine account every business day — both confirmed 2026-11-07) — not received, received but not imported (some accounts), imported but not posted, processed in time, holiday; outbound ACH end to end, re-run idempotency, no PRISM handoff, wire ack beyond 30 min, NACK, ack count mismatch, BAI statement missing/late, holiday calendar, **returns file partially processed then completed — acceptance 8**, wrong field name in customizing, NOC aging day 6 vs day 7, test mode, **new source and LOB by customizing — acceptance 2**, duplicate file). Configuration and expected results: `FMON_FILE_MONITORING.md` §B5.

### 6.3 Health checks and morning report
Fourteen cases HCK-QA-01 … HCK-QA-14 plus HCK-QA-18 … 20 (2026-11-07: number ranges, queues, payments in flight - detail below) and HCK-QA-40 … 49 (2026-11-07: three-way reconciliation `A_RECON_3WAY`) (**return debits aging > 10 days by company code — acceptance 1**, customizing-only threshold change, **new job-cycle step — acceptance 5**, each job-cycle state, config drift and baseline, plug-in failure, stale payment engine area (health of health), e-mail, background run with export, dashboard). Configuration and expected results: `HCK_MORNING_REPORT.md` §14.

### 6.4 Alerting

| ID | Scenario | Configuration | Expected result | Actual / status |
|---|---|---|---|---|
| ALR-01 | EBS run with a B finding at 23:00 | Rule EBS_BLOCK with quiet 22:00–06:00 | Delivered (B overrides quiet hours), log S | pending |
| ALR-02 | EBS run with E findings at 23:00 | Rule EBS_ERROR with quiet hours | Not delivered, log Q | pending |
| ALR-03 | Two runs 10 minutes apart | THROTTLE_MIN 30 | Second run logged T | pending |
| ALR-04 | Third consecutive alerting run | ESCALATE_AFTER 3 | Escalation list added | pending |
| ALR-05 | E-mail rule naming an SO23 list deleted after the rule was saved | — | Log F with 027, nothing sent; morning report alert-delivery check amber/red; run itself unaffected | pending |
| ALR-05a | Save an alert rule with DESTINATION `ZCD_NOLIST` (no such shared list) or a name longer than 12 | Configuration app | Refused with 419 naming the list | pending |
| ALR-05b | Add a user to SO23 list `ZCD_RTBSUP`, trigger ALL_ABORT (test run stopped on the circuit breaker) | No rule change | The new member receives the e-mail (SOST shows the list expanded) | pending |
| ALR-07 | Application log channel | ZCD_OPS/ALERT | Messages visible in SLG1 | pending |
| ALR-08 | BAI deadline alert, no repeat spam (2026-11-07) | Rule FMON_BAIDL, deadline BAI_JPMC_IN 10:00, statement not imported | 10:00–10:05 one e-mail to ZCD_PAYOPS (log S); runs 10:05 … 10:25 log R, no mail; 10:30 escalation to ZCD_RTBLEAD; after import and posting the exception is resolved | pending |
| ALR-09 | Deadline and alert rule: no create in production, existing rows editable (user decision 2026-11-07) | QA1 (production-like client, no changes): key user opens the FMON and alerting configuration apps; edits due time and ACTIVE of an existing ZCD_FMON_SLA DEADLINE row and the SO23 list of an existing alert rule; tries to create a ZCD_FMON_SLA row and an alert rule, and to delete a row | Edits saved without a request, visible in SCU3 with the user; *Create* and *Delete* greyed out for every table (also deadlines and alert rules); a user without ZCA_OPS 02 FMON cannot edit; next morning report CONFIG_DRIFT (E) for the drift-controlled table until the change is transported from DV1 and the baseline is retaken | pending |

### 6.5 Core controls (authorisation, run lock, exception carry-forward, purge)

| ID | Scenario | Configuration | Expected | Result |
|---|---|---|---|---|
| CORE-01 | User without ZCA_OPS 16 for EBS starts `ZCD_EBS_VALIDATE` (same for CD_FMON / CD_HCK; the retention purge `ZCA_OPS_RETENTION` checks CA_OPS) | Role without the payment engine area | Message ZCA_OPS 041, nothing runs | pending |
| CORE-02 | Second `ZCD_EBS_VALIDATE` with the same variant while the first runs | Two jobs | Second: no run row, RUN_LOCKED alert (rule RUN_LOCKED), job ends in error with message 040; first unaffected | pending |
| CORE-03 | Lock released after a run that dumps (SM50 cancel) | — | Lock gone in SM12 when the job ends; next run starts | pending |
| CORE-04 | Same EBS file validated twice with the same unmapped code | Exception assigned to a user after run 1 | Run 2 row: disposition A, same owner and due date, OCCURRENCES 2; run 1 row disposition S | pending |
| CORE-05 | Fix the map entry from CORE-04 and re-run | +1 ZBTM entry | Exception resolved "Passed on re-run"; open list on the morning report no longer shows it | pending |
| CORE-06 | Waived exception raised again | Disposition W, WAIVER_UNTIL in the future | New row stays W | pending |
| CORE-07 | `ZCA_OPS_RETENTION` test mode, then productive with RETENTION_DAYS_RUN 30 on a copy of QA1 data | — | Test mode counts only; productive deletes old closed runs with findings, keeps runs with open / assigned / validly waived exceptions; target PAY_OUTCOME listed (POC-11) | pending |
| OPS-01 … OPS-08 | Operations apps: assign / resolve, waiver four-eyes, suppression (short / long), manual file status forward / backward, PRISM request handled manually | `RAP_Ops_Apps.md` §5 | As listed in `RAP_Ops_Apps.md` §5 | pending |
| HCK-QA-15 | `C_PRQ_NO_SPE` with one failed request without SPE row and one with SUCCESS after the failure | `config/hck_seed.md` rows, SE11 names filled | One finding (the first request); the second is not failed | pending |
| HCK-QA-16 | `C_CHQ_STATUS` with a cheque history 10 → 2 and one 10 → 9 | — | One finding (10 → 2); 10 → 9 allowed | pending |
| HCK-QA-17 | `C_PRQ_CANCEL` with a PCLM request CANCELLED whose open item is cleared | — | One finding PRQ_PAID_CANCELLED | pending |
| HCK-QA-18 | `E_NUMRANGE` (QA1): test number range object (SNRO copy of a payment engine object, VERIFY the real names) with one internal interval 1 … 101 of the current year at NRLEVEL 86, then 96; a second object with only an external interval; PARAM1 = both objects | Seed rows `E_NUMRANGE` (ZCD_HCK_DEF, ZCD_HCK_THRESH `NR_USED_PCT` 85 / 95) | NRLEVEL 86: `NR_USAGE_HIGH` W "… 85 % used, 15 numbers left", check AMBER; NRLEVEL 96: E, check RED, `HCK_RED` e-mail to ZCD_RTBSUP; external-only object `NR_NO_INTERVAL` W; NRIV unchanged (table compare) | pending |
| HCK-QA-19 | `E_QUEUES` (QA1): outbound qRFC queue `ZCD_TEST*` to an unreachable RFC destination (SYSFAIL / CPICERR); a second test queue stopped in SMQ1; an inbound test queue left READY for 35 min with the QIN scheduler deregistered; PARAM1 = `ZCD_TEST.*` | Seed row `E_QUEUES`, thresholds `Q_*`; `HCK_QUEUE_*_STATES` defaults | `QUEUE_ERROR` E naming SMQ1, `QUEUE_HOLD` W, `QUEUE_STUCK` W naming SMQ2 with entries and oldest age; metrics per QOUT / QIN; other queues not counted; no queue restarted or unlocked (SMQ1 / SMQ2 unchanged after the run); PARAM4 blank → `QUEUE_NOT_MONITORED` I; after a misspelt field in PARAM4 → `QUEUE_CONFIG_INVALID` W, qRFC still measured. VERIFY-DDIC of TRFCQOUT / TRFCQIN names first | pending |
| HCK-QA-20 | `A_INFLIGHT` (QA1), factory calendar of PARAM1 with a holiday: (a) disbursement wire, value date yesterday, no bank line; (b) wire, value date today; (c) disbursement ACH, value date three business days back with the holiday in between; (d) collection ACH (XEINZ = X), value date four business days back, clearing-account line not cleared; (e) wire without value date in DPAYH; (f) cheque issued 61 days ago, not cashed; (g) cheque 60 days; (h) returned wire (returns lot item SELW1 = AUGBL); (i) wire with a statement line CHECT = AUGBL | ZPMC entries (FQC0) with the QA1 methods (seed, `config/hck_seed.md` §8a); seed thresholds `AGE_OLDEST` DWIR 1 / 2, DACH / CACH / CCRD 2 / 3, DCHQ 61 / 91; the CLEARED rules of §8c | (a) DWIR late (W); (b) not late; (c) DACH: age counts business days only (holiday excluded) - critical at 3; (d) CACH critical, reported apart from DACH; (e) aged from the run date, detail "(no value date: run date used)", `VALUE_DATE_MISSING` I; (f) DCHQ late (W); (g) not late; (h), (i) not listed; detail lists payment document, method, run date, aged-from date, age, amount - no account data; nothing posted or cleared | pending |
| HCK-QA-21 | `A_INFLIGHT` rule 1 (QA1): three wire and three ACH disbursements: (a) 495 / 466 line and DPAYH status CLEARED; (b) line, status not CLEARED; (c) status CLEARED, no line | Seed rules §8c | (a) excluded, `PAY_EXCLUDED` CLEARED; (b), (c) `CLEARING_INCONSISTENT` (E) naming the held and the missing evidence; not aged | pending |
| HCK-QA-22 | Rule 2: six cheques: B + line (CHECT = last 13 of ZTNUM); V without line; blank without line (61 days); B without line; blank with line; V with line | Seed rules; DFKKCR-STATE | B + line cleared; V voided (counted apart, `PAY_EXCLUDED` VOIDED); blank aged (`PAYMENT_NOT_CLEARED` DCHQ); the other three `CLEARING_INCONSISTENT` | pending |
| HCK-QA-23 | Rule 3: ACH collection 166 with the XREF2 line cleared by F.13; same with the line open; ZUONR changed on an ACH line; Stripe card: payout processed + descriptor + F.13 cleared / not yet cleared / payout row but ZUONR still AUGBL / cleared without payout row | Seed rules; Stripe settings maintained after SE11 (else: information "not configured", BSEG alone decides) | Cleared; `CLEARING_INCONSISTENT` (line open after 166); "assignment changed"; Stripe: cleared / in flight (aged) / "payout processed but descriptor not set" / inconsistent | pending |
| HCK-QA-24 | Rule 4 ACH disbursement sequences: 466,168 + lot; 466,168 without lot; 466,166; 466,468; 466,166,168,468 + lot; 466,466; wire 495,195 + lot with a different amount | Seed roles / outcomes §8e / §8f | RETURNED excluded; `RETURN_INCONSISTENT` (missing lot); RETRIEVED excluded (no DFKKRP); RETRIEVAL_FAILED = stays cleared (with DPAYH CLEARED); RETURNED; `UNEXPECTED_SEQUENCE` with codes and dates; `RETURN_INCONSISTENT` (amount differs) | pending |
| HCK-QA-25 | Collections delayed redeposit: one 468 five days ago; one 468 twelve days ago; 468,166; 468,468 + lot; 468,468 without lot | Seed outcomes (max age 10 days) | Pending (not late); `PENDING_OUTCOME_MISSING`; cleared (with XREF2 cleared); RETURNED; `RETURN_INCONSISTENT` | pending |
| HCK-QA-26 | Configuration: rule with a class that does not implement `ZIF_CD_HCK_EVIDENCE` (rejected on save in the app; forced in a test client: `CLEARING_RULE_INVALID`); new class by rows only (e.g. collection cheque C / CHQ with its rules and limits); house-bank calendar row (UK) for a test bank | HCK configuration app | Save refused (message 410) / finding E and payments stay in flight; the new class is measured with its own key; business days follow the bank calendar | pending |
| HCK-QA-28 | Design review 1 (QA1): ACH disbursement with 466 and a line of an unknown monetary code on the same reference; same with the code in `HCK_BTC_INFO_BAI2`; same with an unknown code of amount 0 | Seed §8e; ZCA_PARAM `HCK_BTC_INFO_BAI2` | `BTC_ROLE_MISSING` (E) with scheme, code, date, amount, DACH, payment not cleared (INDETERMINATE); with the exclusion: cleared; zero amount: cleared. ABAP Unit `unknown_monetary_indeterminate`, `unknown_excluded_code_ignored`, `unknown_zero_amount_ignored` | pending |
| HCK-QA-29 | Design review 2: card collection with the BSEG XREF2 line cleared while the Stripe settings are not maintained (seed REQUIRED C); then REQUIRED of the Stripe CLEARED row set to blank | Seed §8c / §8d | C: not cleared, `CLEARING_UNDETERMINED` "Stripe evidence not configured", `INFLIGHT_CONFIG` W, payment aged; blank: cleared by BSEG, `INFLIGHT_CONFIG` I. ABAP Unit `mandatory_unconfig_no_clear`, `stripe_unconfigured_no_clear`, `stripe_info_switch_bseg_decide`, `invalid_indicator_blocks_later` | pending |
| HCK-QA-30 | Design review 3: two cheques on two house bank accounts whose last 13 characters are equal, one 581 on each account; then two cheques of the same account with the same suffix and one 581 | DFKKCR / FEBKO test data in QA1 | Each cheque cleared only by the line of its own account; same account: both `CHEQUE_LINK_AMBIGUOUS`, neither cleared. Payment trace of the cheque: the line of the other account is not its encashment. ABAP Unit `other_account_never_fits`, `same_account_two_ambiguous`, `two_accounts_same_suffix`, `same_account_ambiguous`, `cheque_other_account_missing` | pending |
| HCK-QA-31 | Design review 4: morning report run (a) with a check that has no metric and no finding; (b) with a variant restricted to category A; (c) with a baseline check in warm-up next to a fixed limit; (d) with a check class that raises | `ZCD_HCK_RESULT` (SE16) and the health dashboard | (a) GREEN on both; (b) scope stored on every row, other active checks SKIPPED; (c) GREEN on both, baseline mode ZSCORE; (d) FAILED, completion FAILED, never green. ABAP Unit `result_green_without_metric`, `result_filtered_run_scope`, `result_warmup_fixed_limit`, `result_failed_never_green`; CDS `ltc_verdict` | pending |
| HCK-QA-32 | Cheque lifecycle code review: (a) 581 for 250.00 against a payment of 1000.00, then 399, cleared in FPCHR (B); (b) two cheques on one payment document - one voided after a 255, a newer one 581 + B (defensive path: a stop and reissue creates a new payment document, user 2026-11-08 - build the case with register data only); (c) correction without B and a returns lot; (d) outcome row with REG_STATE on a rule without cheque link; (e) REG_STATE `B,VX` and FINDING `cheque_typo` entered in the configuration app | Seed §8e (399 / 699 compare C) / §8f | (a) CLEARED_MANUAL, no `CHEQUE_AMOUNT_MISMATCH`; (b) cleared by the live cheque, the voided cheque shown with RETURNED_VOIDED, not VOIDED; (c) `MANUAL_CLEARING_REQUIRED` and `RETURN_INCONSISTENT` both listed; (d) `CHEQUE_REGISTER_MISSING`; (e) save refused (messages 420 / 421). ABAP Unit `correction_skips_amount`, `two_cheques_live_decides`, `finding_keeps_every_anomaly`, `reg_state_needs_register`, `cheque_read_shared`, `one_evaluation_per_link`, `reg_state_tokens_validated`, `outcome_finding_catalogue`, `every_anomaly_listed` | pending |
| HCK-QA-50 | Confirmed DPAYH status values (user 2026-11-08), QA1: (a) wire 495 → 195 with the returns lot, DPAYH status RETURNED; (b) the same while DPAYH still says CONFIRMED (before the hourly status job); (c) DPAYH status RETURNED without a 195; (d) ACH 466 → 166 with status RETRIEVED; (e) the same with status CONFIRMED | Seed §8c status rows (PARAM2 `ISSUED,CONFIRMED`) | (a) excluded RETURNED; (b) in flight (aged), not listed, dashboard IN_FLIGHT with "waiting for the payment status job", no new outcome version; (c) `RETURN_INCONSISTENT`; (d) excluded RETRIEVED; (e) in flight. ABAP Unit `returned_with_status_returned`, `return_status_lag_in_flight`, `returned_status_without_line`, `retrieval_is_not_a_return`, `fixture_returned_excluded`, `fixture_return_lag_in_flight`, `status_lag_no_new_version`, `return_creates_version`, `pending_not_missing`, `status_read_once` | pending |
| HCK-QA-51 | Stopped cheques (user decision 2026-11-08), QA1: (a) cheque voided (DFKKCR state V), DPAYH status ISSUED; (b) stop payment: DPAYH status STOPPED, register state still blank; (c) STOPPED and V; (d) STOPPED, then the bank pays it anyway (581, state B); (e) STOPPED, state B without a 581 line; (f) stop and reissue: the stopped payment (STOPPED) and its reissue under a new payment document and cheque number, cashed (581, B) | Seed §8c D CHQ VOIDED 010 (PARAM2 `STOPPED`), 020, 030 | (a)-(c) excluded VOIDED, no finding; (d), (e) `CLEARING_INCONSISTENT` (E) naming "stopped cheque cashed" (runbook §5l); never CLEARED; (f) the stopped payment VOIDED, the reissue CLEARED, no "stopped cheque cashed" (confirmed by the user 2026-11-08: new payment document and cheque number). ABAP Unit `voided_cheque_without_stop`, `stopped_cheque_blank_voided`, `stopped_and_voided_cheque`, `stopped_cheque_cashed`, `fixture_cheques_voided`, `fixture_stopped_cashed`, `stopped_status_holds_alone`, `status_list_blank_no_read`, `stop_reissue_judged_apart` | pending |
| HCK-QA-52 | `PAY_STATUS_LAG` (QA1, morning report in test mode): (a) wire returned on yesterday's statement (495 → 195, returns lot), DPAYH still CONFIRMED, report at 08:00; (b) the same with `HCK_PAY_STATUS_LAG_MIN` 600; (c) a wire in flight with DPAYH ISSUED and a payment-level ACK row of yesterday 10:00 (`TRACE_SRC_ACK` maintained with the SE11 field names); (d) the same ACK today 07:30; (e) status CONFIRMED with an ACK; (f) `TRACE_SRC_ACK` blank | Parameters default; seed status rows | (a) one `PAY_STATUS_LAG` W for the payment (message 683), metric DWIR 1, no alert e-mail; (b) none; (c) one (684); (d), (e) none; (f) `INFLIGHT_CONFIG` I once, no lag; ST05: one DPAYH read and one ACK read for the run. ABAP Unit `lag_after_grace_reported`, `lag_within_grace_silent`, `ack_lag_after_grace`, `ack_source_unconfigured` | pending |
| HCK-QA-53 | `PAY_STATUS_LAG` after a **file-level** ACK (2026-11-08, QA1, morning report in test mode; `GROUP_FIELDS` of `REGUT` maintained with the SE11 run fields LAUFD,LAUFI,HBKID; `ACH_COLL_OUT` ACK_LEVEL FILE): (a) ACH collection run of yesterday, its file ACK_RECEIVED yesterday 10:00, DPAYH ISSUED, report at 08:00; (b) the ACK today 07:30; (c) status CONFIRMED; (d) the first file PRISM_FAILED, regenerated, the regenerated file acknowledged yesterday; a second run whose regenerated file has no ACK yet; (e) `GROUP_FIELDS` blank; (f) two runs, one ACK old, one new; (g) a wire (per payment, `TRACE_SRC_ACK`) and a collection (per file) in flight in one run | Parameters default (`HCK_PAY_ACK_FILE_CLASSES` CACH,CCRD; `HCK_PAY_ACK_FILE_SRC` REGUT) | (a) one `PAY_STATUS_LAG` W (message 688 naming the file), metric CACH 1; (b), (c) none; (d) run 1: one lag naming the regenerated file; run 2: none (FMON `NO_BANK_ACK` / `REGENERATION_MISSING` only); (e) one `INFLIGHT_CONFIG` W per run (301), no lag; (f) one lag (old run); (g) two lags (DWIR, CACH); ST05: one ZCD_FMON_FILE / ZCD_FMON_EVENT join by index GRP for the run, no per-payment SELECT. ABAP Unit `file_ack_lag_after_grace`, `file_ack_within_grace`, `file_ack_confirmed_silent`, `file_ack_replaced_ignored`, `file_ack_group_unconfigured`, `file_ack_two_runs_apart`, `ack_levels_in_one_run`, FMON `group_acks_with_events` | pending |
| HCK-QA-27 | Disbursement cheques (QA1), cheque register rows with ZTNUM longer than 13 characters: (a) 581, state B; (b) 581 then 255, state blank; (c) 255, state V; (d) 581, 255, state B; (e) 581, 581; (f) 581, 255, 255; (g) 581, 399, state blank; (h) 581, 699 after manual clearing in FPCHR (state B); (i) 581 with an amount different from the payment; (j) 255 then 581; (k) a returns lot for a cheque | Seed §8c / §8e / §8f (cheque rows) | (a) cleared; (b) returned, not aged; (c) voided after return; (d) `RETURN_INCONSISTENT` "register still shows cashed"; (e), (f) `CHEQUE_CLARIFICATION` (E); (g) `MANUAL_CLEARING_REQUIRED` naming cheque number, codes, dates, FPCHR; (h) cleared, no finding; (i) `CHEQUE_AMOUNT_MISMATCH`; (j) `UNEXPECTED_SEQUENCE`; (k) `RETURN_INCONSISTENT`; lines found only via CHECT = last 13 characters of ZTNUM | pending |
| HCK-QA-40 | `A_RECON_3WAY` balanced day (QA1): one ACH collection set (`config/hck_seed.md` §10, house bank account with its `ZCD_EBS_ACCT` row), a day whose 166 lines, transfer postings (FKKSU) on the clearing account and DFKKSUMC totals agree | Seed sets / roles §10; `HCK_RECON_*` defaults | No break, variance or no-data finding; metric `RC_DIFF_BANK_GL` 0 for the group and day; `RC_DAYS` BALANCED counted; nothing posted | pending |
| HCK-QA-41 | Break: same set, a day where one statement line (166) is posted to another account and the transfer posting stays alone | As 40 | `RECON_BREAK` E for the group and day, amount = unexplained difference, currency of the set; alert `HCK_RECON` to ZCD_RTBSUP; second run → escalation to ZCD_RTBLEAD | pending |
| HCK-QA-42 | Timing next day: payment run on day D, the bank statement of D posted with booking date D+1; and the statement of yesterday not yet imported at report time | As 40, `HCK_RECON_TIMING_DAYS` 3 | Both days `RECON_TIMING` I (no alert); after the import the next report shows the day balanced; four days later without the statement → `RECON_BREAK` | pending |
| HCK-QA-43 | 468 within 10 days without a returns lot (collections): one 468 five days ago, none in FP09; the same 468 after 11 days; a 468 with a returns lot | Role REDEPOSIT on 468, `HCK_RECON_REDEPOSIT_DAYS` 10 | Five days: `RECON_TIMING` naming REDEPOSIT; eleven days: `RECON_BREAK`; with lot: part of the leg (no bucket) | pending |
| HCK-QA-44 | Stripe group balanced and off by the fees: one payout (charges 1 000.00, fees 30.00, BAI 195 deposit 970.00 on the JPMC account ending 16650, descriptor on the clearing lines); then the same payout without the fee posting | Set `STRIPE_US`, role DEPOSIT 195, the JPMC account row in `ZCD_EBS_ACCT` | Balanced: `RC_STRIPE_DIFF` 0, no finding; without fees: `STRIPE_GROUP_BREAK` E with charges / fees / deposit, amount 30.00; deposit not posted: timing for 3 days, then break | pending |
| HCK-QA-45 | Unmapped bank code: a line with a code that has no ZBTR RECON entry on the set's account | As 40 | `RECON_VARIANCE` W "bank code(s) without reconciliation role" naming the code and its amount; the day `RECON_VARIANCE` (bucket UNMAPPED); after the ZBTR entry is transported the code is part of its role | pending |
| HCK-QA-46 | Multi-currency and two company codes: a USD and a CAD set on one account, a second company code with its own set; a difference only in CAD and only in the second company code | Three sets | One `RECON_BREAK` per affected group (CAD / second company code), no amount summed across currencies; USD and the first company code balanced | pending |
| HCK-QA-47 | Tolerance boundary: difference of exactly `HCK_RECON_TOLERANCE` (e.g. 1.00), then 1.01; then the set's TOLERANCE 0.50 | Parameter value row 1.00 | 1.00 balanced; 1.01 `RECON_BREAK`; with the set tolerance 0.50 the 1.00 difference is a break (set wins) | pending |
| HCK-QA-48 | Empty window: a set whose account had no statement, no posting and no transfer in the look-back days; then every set without data | As 40 | `RECON_NO_DATA` I for the set; with no data at all the check is GREY in the report and in `ZCD_HCK_RESULT` (evidence NONE) - never GREEN | pending |
| HCK-QA-49 | Subledger and ACH one-to-one: a reconciliation key transferred to another clearing account; an ACH collection payment line whose bank clearing did not come (open assignment older than the timing days) | LEG_FICA X on the set; kind ACH_ZUONR | `RECON_SUBLEDGER_BREAK` E with G/L and control total; `RECON_BREAK` key `…/ACH` with the count of unmatched groups and the first assignment; runtime of the run (ST05 trace of the six reads, `Performance_Review.md`) recorded | pending |

### 6.6 Payment trace (`ZCD_OPS_PAYMENT_TRACE`, `Payment_Trace.md`)

| ID | Scenario | Configuration | Expected | Result |
|---|---|---|---|---|
| TRC-01 | PCLM claims ACH payment, FIN + source | `TRACE_SRC_*` filled (VERIFY-SE11 done) | Every stage VERIFIED with table, key and time; verdict COMPLETE; matches FPL9 / FEBAN / FPG1 | pending |
| TRC-02 | Cheque mailed and encashed, by cheque number | `TRACE_SRC_CHQ_HIST` | DFKKCR, cheque status, FEBEP by ZTNUM VERIFIED | pending |
| TRC-03 | One collection (direct debit) | — | BANK_ACK at file level (FMON); collection path end to end | pending |
| TRC-04 | Payment returned and reissued | DFKKRAPT history fields confirmed | Two attempts; return and bank line under the original clearing reference; current attempt drives the verdict | pending |
| TRC-05 | Reversed item whose history row is absent / history not configured | — | REVERSAL_HISTORY_MISSING (MISSING / UNAVAILABLE); never COMPLETE | pending |
| TRC-06 | FIN with two SUCCESS rows; FEBEP with two lines for one reference | — | AMBIGUOUS, all candidates listed | pending |
| TRC-07 | File sent to PRISM, no ACK; ACK without statement line | — | First gap BANK_ACK resp. SETTLEMENT; INCOMPLETE | pending |
| TRC-08 | User without ZCA_OPS 03 for the item's company code | Role | Item row NOT_AUTHORISED, no key shown, nothing MISSING | pending |
| TRC-04a | Returned payment (current clearing) and a reversed item whose return sits under the historical clearing reference; one clearing with two returns lot items of different reasons | DFKKRP-RLGRD confirmed in SE11 | Each return row shows its RLGRD; the two-reason clearing shows one AMBIGUOUS row listing both | pending |
| TRC-04b | Payment with a NOC (C01) whose DFKKNRP item carries the AUGBL in INFOF; one whose INFOF carries the payment reference; one without NOC | DFKKNRP-INFOF / FLGRD confirmed in SE11 | NOC row VERIFIED with lot, item, FLGRD (both forms); NOT_APPLICABLE without NOC; the verdict is the same as without the NOC rows | pending |
| TRC-09 | Side effects | ST05 during TRC-01..08 | SELECT only; no change in any business table, job, lock, file or interface; nothing written to ZCD_OPS_* | pending |
| TRC-10 | Performance | 20 traces at peak | Each trace < 5 s; FEBEP / DFKKOP / BUT000 reads use an index | pending |

### 6.7 File monitoring dashboard (`ZUI_CD_FMON_FLOW_O4`, `Dashboard_File_Monitoring.md`)

Read-only analytical list page, tiles and OVP-ready KPI / failure entities. ABAP Unit: `ZCL_CD_FMON_FLOW_CDS_TEST` (19 CDS tests: bucket of every stage incl. PRISM status API stages, success for ACK / no-ACK / inbound / unregistered interfaces, measures per source / LOB / method, SLA status, as-of from the last completed full run, stale flag, KPI per day, latest failures). QA1:

| ID | Case | Expected |
|---|---|---|
| FMD-01 | Monitor run (test mode off), open the dashboard | As of = end of that run; age < 30 min; not stale |
| FMD-02 | No monitor run for > 15 min | Header, rows and tile *Stale monitor* red — never shown as a quiet day |
| FMD-03 | Single-interface run and test-mode run | As of unchanged |
| FMD-04 | Outbound ACH file generated → sent → ACK | RECEIVED → SENT → ACKNOWLEDGED; successful only after the ACK |
| FMD-05 | BlackLine file (no ACK) sent to PRISM | SENT, successful |
| FMD-06 | Returns file with open lot items | PARTIAL, unprocessed items; tile *Unprocessed*; in *Latest failures* |
| FMD-07 | Open NO_BANK_ACK, resolve, re-run | SLA BREACHED → NO_FINDINGS |
| FMD-08 | User with ZCD_OPS FMON missing (HCK only) | No rows in any entity; with FMON 03 rows visible |
| FMD-09 | Filters source / LOB / method / bank / date | Totals equal SE16 sums on ZCD_FMON_FILE for the same filter |
| FMD-10 | Drill-down file → events → open exceptions | Equal to ZCD_FMON_EVENT / open ZCA_OPS_FINDING rows of the file |
| FMD-11 | Expected file not received | Tile *Missing files* = 1; no file row |
| FMD-12 | ST05 during use | SELECT only on the FMON / ops store tables; no write, lock or job |
| FMD-14 | Monitor freshness: value row `MON_STALE_AFTER_MIN_FMON` = 600 (ZCA_PARAM area CD_OPS, app *Parameter areas*; was `ZCD_OPS_MONCFG`), stop the SM36 job for 30 min | Dashboard, overview row and morning report self-check all **not** stale (600 min); delete the value row → definition default 15 → all three stale; value `ABC` refused by the framework (`D_PARAM_INVALID`), self-check falls back to `HCK_MAX_AGE_H_FMON` |
| CFG-MON-01 | App *Parameter areas*, area CD_OPS: value 0 or `ABC` for `MON_STALE_AFTER_MIN_FMON`; a parameter `MON_STALE_AFTER_MIN_XYZ` without definition | Refused by the framework (INT, MIN 1; unknown name) - the core app no longer has a *Monitor freshness* entity |
| CFG-EBS-FC | App *EBS rules and mapping* → Rule: FINDING_CLASS XYZ; then R09 blank | XYZ refused (413); with R09 blank the EBS dashboard no longer counts R09 findings as duplicates (EBD-07a) |
| FMD-13 | PRISM status API live: PRISM_RECEIVED / _DELIVERED / _FAILED | AT_PRISM; SENT (out) / RECEIVED (in); REJECTED |

### 6.8 PRISM status API (`POST /sap/zcd_ops/prism_status`, `PRISM_Status_API.md`)

Own approved change (switch S-PRISM); QA1 with the SICF node active for the test user only. ABAP Unit: `ZCL_CD_FMON_PRISM_EVENT` (20), `_API` (11), `_DAO` (5, OSQL), `_PROC` (11, real engine, incl. 4 PRISM-throttle cases), `ZCL_CD_FMON_ADAPTER_PRISM` (5), `ZCL_CD_FMON_CHK_PRISM_FILE` (5), `ZCL_CD_FMON_CHK_REJECT` (2), PRISM tests of `ZCL_CD_FMON_STATUS` (9) and `ZCL_CD_FMON_ENGINE` (2 + 6 file generation identity), PRISM throttle `ZCL_CD_FMON_RULES` / ltc_throttle (14), file generation identity `ZCL_CD_FMON_RULES` / ltc_instance (12). **Release boundary: integration addition — separate CAB approval, SICF node inactive until switch S-PRISM; not part of the read-only monitoring release sign-off.** Harness: Postman / curl over HTTPS with the QA1 technical user's certificate.

| ID | Case | Expected |
|---|---|---|
| PRISM-01 | Outbound ACH file generated and sent by SAP; PRISM posts RECEIVED, then DELIVERED (`occurredAt` = PRISM's times) | 202 each; `ZCD_FMON_PRISM` 2 rows; within seconds the board shows PRISM_RECEIVED then PRISM_DELIVERED with PRISM's times; `PROCESSED_AT` set; SBGRFCMON units ended |
| PRISM-02 | Same call again (PRISM retry) | 200 DUPLICATE; no second row, no second unit, no new event |
| PRISM-03 | Same `eventId`, other milestone | 409 CONFLICT; the first event unchanged |
| PRISM-04 | FAILED with `errorCode` / `errorText` containing a 16-digit number | 202; text stored masked (`****` + last 4); finding PRISM_FAILED (E) and alert via the router; a later DELIVERED supersedes the outcome, the next 5-minute run resolves the exception |
| PRISM-05 | Inbound BAI2: PRISM RECEIVED and DELIVERED before the statement import | Board: file instance opened by PRISM (PRISM_DELIVERED), FILE_RECEIVED / LOADED from SAP's evidence attach to it; without SAP receipt after GRACE_MIN → PRISM_NOT_LOADED |
| PRISM-06 | Missing `eventId`, `fileReference`, `milestone`; bad `occurredAt`; local-time offset | 400 REJECTED listing every error; nothing stored |
| PRISM-07 | GET; `text/plain`; charset ISO-8859-1 | 405 (`Allow: POST`); 415; 415 |
| PRISM-08 | User without `Z_CD_OPS_PRISM`; no / wrong certificate; plain HTTP | 403; 401 (ICF); refused (SSL required) |
| PRISM-09 | Body above `FMON_PRISM_MAX_BYTES` | 413; nothing stored |
| PRISM-10 | Event for an outbound file SAP never generated (`interfaceId` or matching pattern) | Unit defers (row stays unprocessed); the 5-minute run opens the file; after GRACE_MIN PRISM_UNKNOWN_FILE (W) |
| PRISM-11 | Event whose reference matches no interface and has no `interfaceId` | 202; UNMAPPED_FILE (W) every 5-minute run; applied after the interface row is transported |
| PRISM-12 | bgPF: destination locked in SBGRFCCONF, post an event, unlock | 202; unit waits / fails in SBGRFCMON; the 5-minute run applies the event (safety net); after unlock no double event |
| PRISM-13 | Concurrency: post events while the 5-minute run is active on the same file | No RUN_LOCKED for either; no stale overwrite (at most PERSIST_CONFLICT, then the next run converges); one event per milestone |
| PRISM-14 | SLA: SENT_TO_PRISM, PRISM_RECEIVED after 25 min (SLA 15) | PRISM_RECEIVED_LATE (W) at once from the unit; on time → no finding; never received → NO_PRISM_RECEIVED (E) from the 5-minute run |
| PRISM-16 | **PRISM throttle** (user 2026-11-06: ACH and wire files 2 min per file): 5 ACH files of `ACH_PNC_DISB_OUT` sent together; PRISM posts RECEIVED for all five within a minute, then DELIVERED one every 2 minutes; SLA `PRISM_DELIVERED` 5 P, `FMON_PRISM_THROTTLE_MIN` 2 | The 5th file, DELIVERED about 10 min after its RECEIVED, is on time (allowed 5 + 4 × 2 = 13 min): no PRISM_DELIVERED_LATE for any of the five; a DELIVERED of the 5th file after 14 min → PRISM_DELIVERED_LATE (W), text "SLA 13 min incl. PRISM queue allowance" |
| PRISM-17 | Queue of 31 ACH files (`FMON_PRISM_QUEUE_MAX` 30): RECEIVED for all, DELIVERED withheld | PRISM_QUEUE_LONG (W) on the 31st file (once, from check `F_PRISMDLV`); its delivery allowance stops at 29 files ahead (5 + 58 min); NO_PRISM_DELIVERED only after that |
| PRISM-18 | Not throttled: an IRIS cheque print file and a positive pay file (`CHECK_POSPAY_OUT`) sent in the same cycle as 5 ACH files | Their delivery SLA has no allowance (base minutes only) and they are not counted in the ACH queue (the 5th ACH file keeps 4 files ahead) |
| PRISM-19 | Scope and switch: repeat PRISM-16 with ACH files to PNC, a wire to JPMC and an ACH file to BOA, `FMON_PRISM_THROTTLE_SCOPE` C (delivered default), then A as a value row; then `FMON_PRISM_THROTTLE_MIN` 0 | C: the JPMC wire and the BOA file have nobody ahead (no PNC / JPMC file counts in the BOA queue), the PNC files keep their own queue; A: the wire and the BOA file wait behind the ACH files; 0: no allowance, results as before 2026-11-06 (ABAP Unit `bank_queues_do_not_wait`, `scope_a_one_queue_when_set`) |
| PRISM-20 | **Midnight, inbound** (design review 2026-11-07): PRISM posts `DELIVERED` for a statement at 23:58 CST (`occurredAt` 05:58Z of the next day); SAP's import records FILE_RECEIVED at 00:03 CST | **One** registry row (SE16 `ZCD_FMON_FILE`, IFACE_ID + FILE_REF): `BUSINESS_DATE` = the day of the delivery, stage FILE_RECEIVED; no NO_FILE_RECEIVED, no PRISM_NOT_LOADED; the next 5-minute runs add no second row (re-read) — ABAP Unit `inbound_midnight_one_instance`, `reread_receipt_no_new_instance` |
| PRISM-21 | **Midnight, outbound**: an ACH file generated and handed to PRISM at 23:50 / 23:55 CST, PRISM `RECEIVED` 23:58, `DELIVERED` 00:03, bank ACK 00:20 | One row of the generation date, ACK_RECEIVED; every event in `ZCD_FMON_EVENT` under the same FILE_ID — `outbound_midnight_one_instance` |
| PRISM-22 | **Fall back** (first Sunday of November): PRISM `RECEIVED` 01:30 CDT, `DELIVERED` 01:10 CST (40 minutes later), SAP receipt 01:25 CST; SLA PRISM_DELIVERED 30 P | One row of that Sunday; PRISM_DELIVERED_LATE "after 40 min" (UTC minutes — the local clock shows −20); receipt on time — `dst_fall_back_one_instance`, `sla_utc_minutes_fall_back`, `central_dates_midnight_dst` |
| PRISM-23 | **Spring forward** (second Sunday of March): PRISM `DELIVERED` 01:50 CST, SAP receipt 03:15 CDT; SLA FILE_RECEIVED 30 P | One row of that Sunday; no FILE_RECEIVED_LATE (25 UTC minutes, the local clock shows 85) — `dst_spring_forward_one_inst`, `sla_utc_minutes_spring` |
| PRISM-24 | **Same name, consecutive days**: an inbound file whose name does not change (`…_DAILY.TXT`) on two business days, each with PRISM `RECEIVED` and SAP receipt | **Two** rows, one per business date, each with its own receipt; no FILE_REF_AMBIGUOUS — `same_name_two_days_two_files`, `next_day_file_is_new`; outbound counterpart `same_name_next_day_new_file`, `next_day_generation_is_new` |
| PRISM-25 | PRISM `FAILED` at 23:58 CST, retry `DELIVERED` at 00:03 CST | The failed file's row: PRISM_FAILED superseded, the exception resolved by the next 5-minute run — `retry_after_failure_joins` |
| PRISM-26 | **Regenerated file to the bank** (user 2026-11-07): `ZCD_FMON_SRC` row REGUT with `GROUP_FIELDS` (payment run fields, SE11); PRISM `FAILED` for ACH file 1; SAP regenerates the payment run (file 2, new name); PRISM `RECEIVED` / `DELIVERED` file 2 | File 1: FILE_REPLACED (information, names file 2) and its PRISM_FAILED exception resolved by the next 5-minute run (`ZCA_OPS_FINDING` disposition R); file 2 with its own SLA; SE16 `ZCD_FMON_FILE`: both rows carry the same `GEN_GROUP`, nothing else copied — `regen_replaces_failed_file`, `unit_failure_replaced_is_info` |
| PRISM-27 | **Regenerated cheque print file to IRIS**: PRISM `FAILED` (counterparty IRIS, the PRISM → IRIS call failed); SAP regenerates the print file | As PRISM-26 for the IRIS print-file interface (`CHECK_PRINT_IRIS_OUT`) |
| PRISM-28 | **Regeneration overdue**: PRISM `FAILED`, no regeneration for `FMON_REGEN_WAIT_MIN` (60) minutes | At minute 60 nothing new; at minute 61 REGENERATION_MISSING (E) next to the open PRISM_FAILED, alerted once (rule `FMON_REGEN`); after the regeneration both are resolved — `wait_end_not_missing`, `wait_passed_is_missing` |
| PRISM-29 | **Regeneration although the first file did not fail**: file 1 `DELIVERED` (or still in flight), SAP regenerates the run (file 2); PRISM `RECEIVED` file 2 | FILE_REGENERATED_NOT_FAILED (B) on file 2 from the instant unit within seconds, naming file 1 and its state; alert `FMON_REGEN` — `unit_flags_regen_not_failed`, `regen_peer_in_registry_found` |
| PRISM-30 | **Re-send of a known name**: `FMON_PRISM_DUP_NAME_CODES` = PRISM's code (to confirm with PRISM); file 1 `FAILED`; SAP re-sends file 1; PRISM `FAILED` with the duplicate-name code | PRISM_DUPLICATE_NAME instead of PRISM_FAILED; after the regeneration FILE_REPLACED; with the parameter empty PRISM_FAILED as before — `unit_dup_name_not_failed`, `empty_code_list_stays_failed` |
| PRISM-15 | ST05 / SAT during PRISM-01 | Writes only `ZCD_FMON_PRISM`, `ZCD_FMON_FILE`, `ZCD_FMON_EVENT`, `ZCA_OPS_RUN`, `ZCA_OPS_FINDING`, alert log; no business table, file, job or routing touched |

### 6.9 EBS validation dashboard (`ZUI_CD_EBS_DASH_O4`, `Dashboard_EBS_Validation.md`)

ABAP Unit: `ZCL_CD_EBS_DASH_CDS_TEST` (21 CDS tests: validation status from open findings, closed findings ignored, lines per statement, line status, as of on every row, payment engine scope from XBLNR (all-PE statement shown with PE and G/L account; mixed, blank XBLNR, no line and inactive account hidden), totals by BAI code + XBLNR and per PE account, account masked, bank-file messages hidden, line key, unevaluated lines, S13 / duplicates per run, KPI = last completed run of the day, as of / stale 26 h, returns by DFKKRP-RLGRD, NOCs by DFKKNRP-FLGRD via INFOF). QA1: cases **EBD-01 … EBD-12** (incl. EBD-04b / EBD-04c: XBLNR scope, totals by BAI code + XBLNR) of the dashboard doc §11 (stale, test / aborted runs, BLOCKED / POSTING_INCOMPLETE / NO_FINDINGS, duplicates, bank-file findings, returns / NOC, two runs a day, DCL, ST05).

### 6.10 Health check dashboard (`ZUI_CD_HCK_DASH_O4`, `Dashboard_Health_Check.md`)

ABAP Unit: `ZCL_CD_HCK_DASH_CDS_TEST` (6 CDS tests: status RED / AMBER / GREEN / WARMUP / NO_RESULT of the last completed run, older-run exceptions open but not the status, category = worst check, KPI counts, stale without completed run, 31-day metric history with DIM2 series). QA1: **HCD-01 … HCD-09** (doc §10).

### 6.11 Transactions dashboard (`ZUI_CD_TRX_DASH_O4`; request side `ZUI_CD_TRX_REQ_O4` after SE11; `Dashboard_Transactions.md`)

ABAP Unit: `ZCL_CD_TRX_DASH_CDS_TEST` (14 CDS tests on the payment worklist, 2026-11-08: current rows only, kind and worklist date (run date / due date), date kinds RUN / VALUE / DUE, proposal run not joined, direction from TFK042Z-XEINZ, open / exception counts and criticality, KPI with distinct FIN numbers, KPI never mixes company codes, problems = exceptions, return / NOC reasons, no partner or member element; shared fixtures: retrieval final - no row, bank line without clearing an INCONSISTENT exception, FIN in two sources one AMBIGUOUS row per source). After SE11, in ADT: `ZCL_CD_TRX_REQ_CDS_TEST` (8 tests: **SUCCESS row rule** — a SUCCESS attempt wins over a later failed COUNTER —, errored, pending, member number not exposed, SUCCESS older than the request date window still PROCESSED, retrieval shown, never RETURNED, FIN in two sources AMBIGUOUS, one row per company code). QA1: **TXD-01 … TXD-16** (doc §12, rewritten 2026-11-08 for the worklist), incl. the peak-volume ST05 / PlanViz run TXD-12.

#### 6.11b Exceptions-only payment worklist and requests not paid on their due date (2026-11-08)

ABAP Unit: `ZCL_CD_OPS_PAY_SNAPSHOT` (29 tests: clean payment deletes its open row, an exception closes its history, an open change in place, no change writes nothing, late payment is an exception, RETURNS / REVERSALS bring a deleted payment back, watermark, newer run, FIN in two sources, test mode, capped read fails closed, return is finished, status pending marked, payment without FIN, request open then overdue, paid on time gone, paid late with history, request re-judged with its payment, NIGHTLY re-judges rows, SWEEP moves no watermark, SWEEP needs a range, duplicate current rows retired, ordered watermarks, lag); `ZCL_CD_OPS_PAY_REQUEST` (13 tests: any SUCCESS attempt, cut-off to the next day, weekend to the next business day, cut-off per source, future request not overdue, stages no item / payment block / not in run / cleared without run, paid on time / late, cancelled after SUCCESS, new requests after the keyset mark); `ZCL_CD_HCK_PAY_AGEING` (7); `ZCL_CD_HCK_C_PRQ_NOT_PAID` (6: one finding per source + stage + due date, a request counted once, request amount without item, nothing due measures zero, nightly missing PARTIAL, capped read PARTIAL); `ZCL_CD_OPS_PAY_OUTCOME_DAO` (OSQL, new: first-run window, worklist delete and update, NIGHTLY cursors, request items with run, due requests with amount, SWEEP upper date, packages of another mode kept); `ZCL_CD_FMON_QUERY` (keyset seek); `ZCL_CD_OPS_TRACE_ENGINE` (`request_due_shown_as_info`, `reference_finds_cheque`, `reference_is_payment_doc`); `ZCL_CD_HCK_C_INFLIGHT` (PAY_EXCLUDED retired: the purposes asserted on the shared evaluator).

| ID | Scenario | Configuration | Expected | Result |
|---|---|---|---|---|
| WL-01 | Wire paid, status CLEARED after the statement | FAST | Row IN_FLIGHT after the run, row deleted after CLEARED (SE16 `ZCD_PAY_OUTCOME` by AUGBL: none); trace shows CLEARED | pending |
| WL-02 | Wire on the statement, status still CONFIRMED (inconsistent), then CLEARED | FAST | INCONSISTENT row (exception), then closed history + closing version CLEARED; purged by `ZCA_OPS_RETENTION` 90 days after it closed | pending |
| WL-03 | ACH beyond AMBER, then RED, without new evidence | NIGHTLY job | `PAYMENT_NOT_CLEARED` W, next night E (A_INFLIGHT `AGE_OLDEST`); morning report and dashboard agree | pending |
| WL-04 | Cleared payment returned later (returns lot) | FAST | Payment re-enters through RETURNS: IN_FLIGHT / status pending row, then deleted when RETURNED | pending |
| WL-05 | Request received 18:59 and 19:01 CST on its due day; due date a Saturday | `PAYOUT_REQ_CUTOFF` `*=190000`, PARAM1 calendar | 18:59: due that day (rolled to Monday); 19:01: next business day | pending |
| WL-06 | Request due yesterday: no item / payment lock / open not in run / cleared without run | `TRACE_SRC_REQUEST` `DUE=` | `REQ_NOT_PAID` with the stage; A_PRQ_NOT_PAID one finding per source + stage + due date, RED, examples; dashboard date kind DUE | pending |
| WL-07 | Request paid one day late | — | Closing version `REQ_PAID_LATE`, row gone; trace REQUEST_DUE FAILED (paid late) | pending |
| WL-08 | NIGHTLY not run | Job held | A_PRQ_NOT_PAID `PAY_NIGHTLY_MISSING` W, evidence PARTIAL | pending |
| WL-09 | SWEEP of one day, sources DOCUMENTS and RETURNS, twice | Test mode, then update | Only changed rows written; second run writes nothing; `ZCD_PAY_OUTWM` unchanged | pending |
| WL-10 | NIGHTLY stopped by `PAYOUT_BATCH_MAX_PACKAGES` 2 | ZCA_PARAM value row | `PAY_BATCH_INCOMPLETE` W; next run continues at the cursor | pending |
| WL-11 | Trace by payment reference: AUGBL without leading zeros; cheque last 13 digits | — | Payment found and traced; ZTNUM layout recorded | pending |
| WL-12 | FAST and NIGHTLY running at the same time | — | Both run (own run locks); no duplicate current row (SQL: one current row per key) | pending |

#### 6.11a Canonical payment outcome and the 5-minute snapshot (2026-11-07)

ABAP Unit: `ZCL_CD_OPS_PAY_OUTCOME` (16 tests on the shared fixtures with the delivered evidence plug-ins: retrieval is not a return, line without clearing, latest run decides, FIN in two sources, old SUCCESS one source, every fixture as expected (with the pending status), reversed document, unwatched method no verdict, request source fails closed; 2026-11-08: returned with status RETURNED, return whose status is not updated yet in flight, status RETURNED without the line, cheque voided without stop / stopped with state blank / stopped and voided = VOIDED, stopped cheque cashed = INCONSISTENT); `ZCL_CD_HCK_C_INFLIGHT` (every earlier test unchanged + `fixture_retrieval_not_return`, `fixture_line_not_cleared`, `fixture_two_runs_cleared`, `fixture_agrees_with_outcome`); `ZCL_CD_OPS_TRACE_ENGINE` (`ltc_outcome`, 5 tests); `ZCL_CD_OPS_PAY_SNAPSHOT` (7 tests: outcome change creates a version, no change writes nothing, watermark picks up only new evidence, newer run closes the older run's version, FIN in two sources AMBIGUOUS for both with findings, test mode writes nothing, capped read fails closed); `ZCL_CD_OPS_PAY_OUTCOME_DAO` (OSQL, 10 tests: each source after its watermark, package size, recheck only open not final, cheque of a statement reference, versions closed / inserted, watermark round trip); `ZCL_CD_HCK_RUNTIME_DAO` (`payments_by_document_all_runs`); `ZCL_CA_OPS_PURGE_DAO` (`old_outcome_version_deleted`).

| ID | Scenario | Configuration | Expected | Result |
|---|---|---|---|---|
| POC-01 | Activate step 2 `ZCD_OPS_PAY_SNAPSHOT` in `ZCD_FMON_MONITOR_ALL`; first run | No `ZCD_PAY_OUTWM` row | Watermarks start `PAYOUT_INITIAL_DAYS` (10) days back; payments of those days get one version each; runtime recorded | pending |
| POC-02 | Next run with no new evidence | — | No version written (SE16 count unchanged), watermarks' UPDATED_AT advanced | pending |
| POC-03 | A wire's DPAYH status set to CLEARED after its 495 line was judged INCONSISTENT | — | Within the recheck round: version INCONSISTENT closed, CLEARED inserted; dashboard, trace and morning report agree | pending |
| POC-04 | New 495 / 466 line on the statement import | — | Only the payments of the new lines are evaluated (ALV documents per source in test mode) | pending |
| POC-05 | Re-run of a payment (second DPAYH run) | — | The older run's version closed, the latest run's inserted | pending |
| POC-06 | FIN with SUCCESS in PCLM and ORCI | Request log rows | Two versions AMBIGUOUS, findings `PAY_SOURCE_AMBIGUOUS` | pending |
| POC-07 | `PAYOUT_PACKAGE_SIZE` 100, 1 000 evidence documents | ZCA_PARAM value row | Ten packages, each committed with its watermark; a cancel in the middle loses nothing (rerun continues at the watermark) | pending |
| POC-08 | Capped evidence read (`HCK_INFLIGHT_MAX_ROWS` 10) | ZCA_PARAM value row | `PAY_OUTCOME_FAILED`, nothing written for the package, watermark kept | pending |
| POC-09 | Test mode | `P_TEST` = X | Counts per source, no version, no watermark, no commit | pending |
| POC-10 | Overlapping start | Two starts | Second refused RUN_LOCKED | pending |
| POC-11 | Purge PAY_OUTCOME on a QA1 copy, `RETENTION_DAYS_PAY_OUTCOME` 90 (2026-11-08) | — | Closed versions before the cutoff deleted; current versions of final outcomes (CLEARED, RETURNED, RETRIEVED, VOIDED, REVERSED) of runs before the cutoff deleted; the current version of every payment not final kept however old (an open cheque of 120 days stays); unit tests `open_cheque_keeps_current`, `cleared_old_payment_purged`, `closed_old_version_purged` | pending |
| POC-13 | `PAYOUT_PARALLEL` 4, bgPF configured; 3 packages of DOCUMENTS, the unit of package 2 cancelled | `PAYOUT_PACKAGE_SIZE` 100 | Package rows D / F / D; DOCUMENTS watermark at the end of package 1, never past package 2; next run judges 2 and 3 again (unit tests `failed_middle_holds_wm`, `unfinished_package_holds`, `contiguous_done_rule`) | pending |
| POC-14 | bgPF execution of `ZCL_CD_OPS_PAY_SNAP_OP` (SBGRFCMON process `ZCD_PAY_SNAPSHOT_PACKAGE`); bgPF not configured | — | Units run, rows D; without bgPF the run judges the packages one by one with `PAY_OUTCOME_SERIAL` W; `PAYOUT_PARALLEL` 1 dispatches nothing (`serial_never_dispatches`) | pending |
| POC-15 | Snapshot lag: stop step 2 for 40 minutes | — | Freshness row CORE red (`ZI_CD_PayOutLag`, threshold `MON_STALE_AFTER_MIN_CORE` 30), transactions dashboard header red, job log message 761 after the restart; `lag_oldest_source`, `snapshot_lag_row` | pending |
| POC-16 | A_INFLIGHT on the snapshot: a wire 30 business days in flight, 100 000 payments with one inconsistency, a document not yet snapshotted | — | Wire counted and critical (`agg_old_wire_still_counted`); one finding with count 100 000 and 10 examples (`agg_100k_one_finding`); PAY_NOT_SNAPSHOT 1 (`snapshotted_not_live`); drill-down to the full list from the dashboard / `ZCD_PAY_OUTCOME` | pending |
| POC-12 | Runtime at peak (gate 3) | Production-like volume | Step 2 well within 5 minutes; ST05: no SELECT per payment, indexes DAT / OUT / FIN used | pending |

### 6.12 Production-support overview page (`ZUI_CD_OPS_OVERVIEW_O4`, `Dashboard_Production_Support.md`)

ABAP Unit: `ZCL_CD_OPS_OVW_CDS_TEST` (10 CDS tests: one freshness row per monitor, stale by the area's threshold, open B / E exceptions only, overdue days, hidden bank-file message; control center 2026-11-10: counters of the daily controls, newest non-proposal run per payment document, lifecycle stages from configuration, latest variance beyond tolerance with expected / actual, variance disposition from the exception workflow). QA1: **OVP-01 … OVP-15** (doc §7).

**Control center - daily control review (framework `ZUI_CA_OPS_REV`, 2026-11-10).** ABAP Unit in ZCA_OPS: `ZCL_CA_OPS_REVIEW_POLICY` (11), `ZCL_CA_OPS_REVIEW_DAO` (3), `ZCL_CA_OPS_CTL_CDS_TEST` (3), `ZCL_CA_OPS_CFG_CHECKS` `ltc_control_check` (6), `ZCL_CA_OPS_EXC_POLICY` classification (2), `ZCL_CA_OPS_PURGE_DAO` `old_review_is_deleted`. QA1:

| ID | Case | Expected | Result |
|---|---|---|---|
| CTL-01 | Control with an open E finding today | Status *Action required*, exceptions = open B / E / W of its checks | pending |
| CTL-02 | Health check red at 07:00, green in the 09:00 rerun | Status *Healthy* after 09:00 (07:00 exception resolved by the rerun) | pending |
| CTL-03 | *Mark reviewed* on *Action required* without next action | Refused 076; with observation and next action: one `ZCA_OPS_REVIEW` row, checked by = user, evidence = latest run | pending |
| CTL-04 | Reviewer enters *Healthy* for a *Watch* control without observation | Refused 077; with observation saved, result H, status at sign-off W | pending |
| CTL-05 | New W finding after the sign-off | *Awaiting review* again; signing off again replaces the row of the date | pending |
| CTL-06 | Two reviewers sign off the same control and date in parallel | One saves; the other gets 079 or HTTP 412, refreshes and sees the first sign-off | pending |
| CTL-07 | 09:15 local, control with cut-off 08:30 not signed off | *Review overdue*; tile *Review overdue* counts it | pending |
| CTL-08 | ST05 / PlanViz of the review list and the control cards | Runs by STARTED_AT, findings by RUN_ID, open exceptions by index OPN; no scan of ZCA_OPS_FINDING | pending |
| CTL-09 | Control register: unknown owner, team NIGHT, link without http | Refused on save (437, 438, 439) | pending |
| CTL-10 | Display role (03 only) | Review list visible, *Mark reviewed* not allowed | pending |
| CTL-11 | *Classify* a RECON3 break as TIMING, next morning report re-raises it | Reason code kept (carry-forward); variance disposition TIMING | pending |

### 6.13 Patterns — PCRE, complete value (`ZCD_OPS_PATTERN_CHECK`, `ZCD_OPS_PATTERN_MIGRATE`)

| ID | Scenario | Configuration | Expected result | Actual / status |
|---|---|---|---|---|
| PAT-01 | Whole-value match | Job step `ZCD_PAYM_WIRE` (no `.*`); jobs ZCD_PAYM_WIRE and ZCD_PAYM_WIRE_CORP ran | Only ZCD_PAYM_WIRE is the step's instance; pattern check shows ZCD_PAYM_WIRE_CORP as NO_MATCH | pending |
| PAT-02 | Case ignored | FMON pattern `ach_pnc_.*` | File ACH_PNC_20261106_01 resolved to the interface | pending |
| PAT-03 | Invalid pattern refused on save | Alerting app: CHECK_PATTERN `(SLA` | Message 418 on the field, not saved | pending |
| PAT-04 | Invalid pattern at runtime | ZCD_EBS_FLOW_PAT row `.*(COLL` inserted directly (SE16, test client) | Lines with XBLNR blocked FLOW_PATTERN_INVALID (B); FMON / HCK / alert equivalents: PATTERN_INVALID, E373, alert log F with 742 | pending |
| PAT-05 | Pattern check | Area HCK_JOB, window last 7 days, ad-hoc `ZCD_PAYM_.*` | INVALID / NO_MATCH / UNUSED rows first, MATCHED rows with source; summary message 746 | pending |
| PAT-06 | Migration test mode | CP rows `ACH*`, `ZCD_*`, `*SLA*`, `A*B*C*D*` in a 10-character field | Old → new: `ACH.*`, `ZCD_.*`, `.*SLA.*`; TOO_LONG for the last; nothing written | pending |
| PAT-07 | Migration update mode | As PAT-06 with a customizing request | CONVERT rows WRITTEN, flow pattern re-keyed, change stamps, request holds the rows; rerun shows ALREADY_PCRE | pending |
| PAT-08 | Capped value read | Pattern check with P_MAX 10 | Message 747; list from 10 values | pending |

ABAP Unit (DV1): `ZCL_CD_OPS_UTIL` (whole value, part of value no match, case, trailing blanks, invalid, blank, literal count), `ZCL_CD_OPS_PATTERN_CHECK` (matched / no match / unused / invalid / overlap, conversion rule: wildcards, metacharacters, escapes, blank; plan), `ZCL_CD_OPS_PATTERN_DAO` (OSQL), and the converted call sites (resolver, FMON rules / engine, alert policy / router, HCK param / DAO / job checks / cycle / suppression). Offline: `tools/tests/test_no_cp_patterns.py`, `test_pattern_dao_fields.py`, `test_rap_generate.py`.

### 6.14 Parameters in the framework ZCA_PARAM (areas CD_OPS / CD_EBS / CD_FMON / CD_HCK)

| ID | Scenario | Setup | Expected | Result |
|---|---|---|---|---|
| PRM-01 | Definitions imported | Step 3.0 of `Implementation_Order.md` done (4 areas + CA_OPS, 140 + 15 framework definitions) | Morning report `D_PARAM_INVALID` GREEN, metric PARAM_INVALID 0 | pending |
| PRM-02 | Definition default wins | No value row for `HCK_TOP_N` | Morning report lists 20 open exceptions (definition default), whatever the code passes as default | pending |
| PRM-03 | Invalid value | `HCK_TOP_N` value row `many` (enter in DV1 sandbox through EML / test client — the app refuses it) | Run uses 20; no SLG1 entry; next morning report `PARAM_INVALID` E with key `CD_HCK/HCK_TOP_N` | pending |
| PRM-04 | BOOL off | `FMON_PRISM_INSTANT` value row blank | PRISM unit updates the registry only, findings come from the 5-minute run | pending |
| PRM-05 | Definition missing | Delete the definition `EBS_GL_LEDGER` in a sandbox | EBS run uses ledger 0L (no SLG1 entry); `PARAM_INVALID` names `CD_EBS/EBS_GL_LEDGER` | pending |
| PRM-06 | Production change | PS4 / QA1: change the value row of `HCK_SCORE_GREEN_MIN`; try to create a value row and to change `EBS_PARSER_BAI2` | Value change saved without request, visible in SCU3 (`ZCA_PARAM_VAL`); create refused; developer-owned change refused (ZCA_PARAM 045) | pending |
| PRM-07 | Snapshot per run (A64) | Change `FMON_LOOKBACK_DAYS` while a 5-minute run is running | The running run keeps its value; the next run reads the new one | pending |

### 6.15 Table consolidation 2026-11-08 (`Implementation_Order.md`, section *Table consolidation 2026-11-08*)

| ID | Scenario | Setup | Expected | Result |
|---|---|---|---|---|
| CONS-01 | One approved-table list, filtered by reader | `ZCD_OPS_TABWL`: `ZCDT_REGUT` only as HCK / READ | FMON source REGUT refused (244); HCK aggregate on the table allowed; adding FMON / SOURCE allows the FMON read. App refuses purpose READ for FMON (413) and a field on an HCK row (423) | pending |
| CONS-02 | Drift rows | `ZCD_OPS_TABWL` HCK / DRIFT `ZCD_HCK_DEF`; take baseline, change a check row | `CONFIG_DRIFT` for ZCD_HCK_DEF; a READ row of another table is not hashed | pending |
| CONS-03 | Bank code role usages | ZBTR (FQC0): LIFECYCLE `DACH` 166 RETRIEVED and RECON `DISB_ACH` 166 CUTOFF | `A_INFLIGHT` sees RETRIEVED, `A_RECON_3WAY` CUTOFF; `D_POSTAREA_INVALID` reports role LEG on a LIFECYCLE entry (424), scope `XACH` (425), role ORIGINAL or scheme ISO on a RECON entry (413) | pending |
| CONS-04 | Duration and deadline of one stage | `ZCD_FMON_SLA` BAI_JPMC_IN FULLY_PROCESSED: DURATION 60 P and DEADLINE `*` 10:00 | Both evaluated by their own check; 10:00 BAI rule `FMON_BAIDL` unchanged (FMON-QA-15..19). App refuses DURATION without minutes (417) or with a due time (423), DEADLINE without due time (422) | pending |
| CONS-05 | Stripe settings as parameters | Definitions `HCK_STRIPE_*` imported, no value rows | Card payments `CLEARING_UNDETERMINED` ("Stripe evidence not configured"); after maintaining table / intent fields: evidence read | pending |
| CONS-06 | Expected groups list | `ZCD_HCK_AGG` A_RET_AGED `EXPECTED_GROUPS` = two company codes, one without aged items | Silent company measures 0; app refuses `US01,,US02`, a repeat (426) and a list without group field (423) | pending |
| CONS-07 | House-bank calendar entry | ZPMC (FQC0) D / ACI method / Barclays → ACI, CALENDAR GB | Barclays payments aged in GB, other banks in the class / PARAM1 calendar; `D_POSTAREA_INVALID` reports an ageing basis on the bank entry (423), a bank entry without calendar (422) or with another class (385) | pending |
| PA-01 | Customer posting areas defined (DV1) | SE11 TFK033D lengths; SPRO definitions ZRSN / ZPMC / ZBTM / ZBTR (`FICA_Posting_Areas.md` §4) | FQC0 offers the four areas with the key / result fields of the guide; definitions on their own request | pending |
| PA-02 | Seed entries in FQC0 | `config/postarea_zbtm.csv`, `postarea_zrsn.csv`, `hck_seed.md` §8a / §8b / §8e / §10b | `D_POSTAREA_INVALID` reports nothing; EBS run on a sample statement as before the move (same categories / R14) | pending |
| PA-03 | FQC0 precedence | Guide §4.5 test entries in ZBTM | FQC0 / FKK_ACCOUNT_DETERMINE picks the entry `ZCL_CD_OPS_POSTAREA=>FIND` picks (left-most exact key) | pending |
| PA-04 | Invalid entries | ZBTM scheme `*`, ZPMC house-bank entry without calendar, ZBTR LIFECYCLE role LEG | One `POSTAREA_INVALID` finding each (427 / 422 / 424) | pending |
| AUTH-01 | ZCA_OPS per child (configuration apps) | Users with 02 only / 01 only / 06 only for HCK | 02: change yes, create / delete refused; 01: create yes, change refused; 06: delete yes; none: no Edit | pending |

### 6.16 Company-code isolation - two-user test (DV1, repeated in QA1; 2026-11-10)

> **First principle:** a user scoped to one company code proves the isolation only if the same data shows a different, predictable picture to a user of the other company code.
> **Analogy:** two tenants with keys to the same corridor but different flats - each walks every door and writes down which ones open.

Rule under test: area authorised AND ( company code blank OR ( area, company code ) authorised ) - `config/auth_zcd_ops.md` §3d, `ops-framework/docs/auth_zca_ops.md` §3c.

**Users (PFCG, DV1 / QA1 only).**

| User | ZCA_OPS ZCA_PARAR | ACTVT | BUKRS | Also |
|---|---|---|---|---|
| **A** | CD_EBS, CD_FMON, CD_HCK, CD_OPS | 02, 03, 85 | **1000** | `S_SERVICE` of the bindings, launchpad catalogs |
| **B** | CD_EBS, CD_FMON, CD_HCK, CD_OPS | 02, 03, 85 | **2000** | same |
| **C** (control) | same areas | 03 | * | display role `Z_CD_OPS_DISPLAY` |

**Data (DV1, created by real runs where possible, else inserted by the test lead with SE16N in DV1 only; record the run IDs).**

| # | Object | Company code | How |
|---|---|---|---|
| D1 | EBS statement with an open E finding (e.g. S02 balance) and a line finding R05 | 1000 | EBS run on a test statement of a house bank of 1000 |
| D2 | EBS statement with an open B finding (R14 unmapped code) | 2000 | EBS run on a test statement of a house bank of 2000 |
| D3 | EBS run-level finding (`ENG` / plug-in error) | blank | the same EBS run (or a run with an invalid rule) |
| D4 | HCK generic aggregate grouped by BUKRS over its red threshold for 1000 and for 2000 | 1000, 2000 | `ZCD_HCK_AGG` row with `GROUP_FIELD` = BUKRS, thresholds per company code (`ZCD_HCK_THRESH`) |
| D5 | `A_RECON_3WAY` break of a set of 1000 and of a set of 2000 | 1000, 2000 | two reconciliation sets (`ZCD_HCK_RCSET`) with a known difference |
| D6 | HCK job-cycle finding (`B_CYCLE_TODAY`) | blank | job cycle with a missing step |
| D7 | FMON missing file (`F_MISSING`) | blank | expected file not delivered |
| D8 | Flagged payments (`PAY_SOURCE_AMBIGUOUS`) of 1000 and of 2000 | 1000, 2000 | payments of both company codes in two sources |
| D9 | Overdue exceptions of 1000 and 2000 (due date in the past) | 1000, 2000 | D1 / D2 with SLA 0 days, next morning report |
| D10 | Controls `BAI_EXCEPTIONS` (D1, D2, D3), `DAILY_RECON` (D5), `CLEARING_JOB` (D6) active in the control register | slices: blank, 1000, 2000 | `config/control_register.csv` |
| D11 | Suppression of the D4 check for 2000 | 2000 | created by user B |

**Read cases (each as A, B and C; "own" = the user's company code).**

| ID | App / card / count / drill-down | Expected for A | Expected for B | Result |
|---|---|---|---|---|
| CC-01 | Exceptions app `ZUI_CA_OPS_EXC`, list without filter | D1, D3, D4-1000, D5-1000, D6, D7, D8-1000 (+ area-level rows) - no row of 2000 | D2, D3, D4-2000, D5-2000, D6, D7, D8-2000 - no row of 1000 | pending |
| CC-02 | Exceptions app: object page of D2 by URL (key typed by A) | not found / no authorisation (no data shown) | shown with history | pending |
| CC-03 | Exceptions app: history of D1 after an *Assign* by A | visible to A; not to B | D2's history only | pending |
| CC-04 | Exceptions app: value help / filter *Company code* | values 1000 and blank only (no 2000 appears in the result) | 2000 and blank | pending |
| CC-05 | EBS dashboard: statements, lines, findings, problems list card | statements and lines of 1000; findings D1, D3 | of 2000; D2, D3 | pending |
| CC-06 | EBS dashboard: run history (one run), KPI tile of the day | run listed once with its line counters; finding counts = D1 + D3 only; KPI tile counts D1 + D3 | run once; D2 + D3 | pending |
| CC-07 | EBS drill-down run -> findings, statement -> findings | D1, D3 / D1 only | D2, D3 / D2 only | pending |
| CC-08 | HCK dashboard: check list, red / amber card, categories, KPI | check of D4 with 1 open exception (1000), recon check with 1 (1000), cycle check with D6; verdict counters once; KPI open count = own + area-level | same with 2000 | pending |
| CC-09 | HCK metric history of D4 (drill-down check -> metrics) | metric of 1000 and metrics without company code; never the 2000 value | 2000 | pending |
| CC-10 | HCK run list | each run once; finding count = own + area-level | same | pending |
| CC-11 | Suppressions app | D11 not listed | D11 listed | pending |
| CC-12 | FMON dashboard (files, KPI, open exceptions) | D7 and all files (area-level) | same | pending |
| CC-13 | Overview: open critical exceptions card + its count | D1, D3, D5-1000 ... (B / E only) - count without 2000 | 2000 counterpart | pending |
| CC-14 | Overview: daily controls (checks reviewed n / m, flagged, attention queue) | slices blank and 1000 of each control; *BAI exceptions* 1000 slice shows status of D1 only (Action required), never D2's B | blank and 2000; *BAI exceptions* 2000 slice from D2 | pending |
| CC-15 | Overview: open variances card | D5-1000 only | D5-2000 only | pending |
| CC-16 | Daily control review `ZUI_CA_OPS_REV` | slices blank and 1000; counters sum these | blank and 2000 | pending |
| CC-17 | Analytics queries (findings, metrics) in a query browser / RSRT | totals without any 2000 finding / metric | without 1000 | pending |
| CC-18 | User C (BUKRS *) on CC-01 ... CC-17 | every row of both company codes and area-level; totals = A + B - area-level counted once | - | pending |

**Write cases (refused across company codes).**

| ID | Action | Expected for A on 2000 objects | Expected for A on 1000 / area-level objects | Result |
|---|---|---|---|---|
| CC-20 | Exceptions app: assign, resolve, request waiver, classify on D2 (by key, e.g. OData request) | refused (HTTP 403 / action not allowed); no `ZCA_OPS_EXC_HIST` row | allowed on D1 and D3, one history row each | pending |
| CC-21 | Approve waiver on D2 requested by B | refused (85 for 2000 missing) | allowed on a waiver of D1 requested by another user of 1000 | pending |
| CC-22 | Daily control review: *Mark reviewed* on the 2000 slice of *BAI exceptions* | refused | allowed on blank and 1000 slices; one `ZCA_OPS_REVIEW` row per slice (`BUKRS` 1000 / blank) | pending |
| CC-23 | Suppression: create for 2000, end D11, approve a 2000 request | refused with message 840 | allowed for 1000 / blank | pending |
| CC-24 | Alert rule with `BUKRS_PATTERN` 1000 and its own SO23 list | the list receives D1 / D4-1000 / D5-1000 findings only; D2 never; area-level only with pattern `1000\|` (`ZCA_OPS_ALLOG`, e-mail) | - | pending |

**Acceptance criteria (all must hold; a single violation stops the pilot):**
1. No row, count, sum, card value, value-help value or drill-down target of company code 2000 is visible to A, and none of 1000 to B (CC-01 ... CC-17).
2. Area-level rows (blank company code) are visible to A, B and C with the area authorisation; run and verdict counters appear once per run / check for every user (CC-06, CC-08, CC-10).
3. C sees everything; for every count, A's value + B's value - the area-level part = C's value.
4. Every write case CC-20 ... CC-23 is refused across company codes and leaves no row in `ZCA_OPS_FINDING` (changed fields), `ZCA_OPS_EXC_HIST`, `ZCA_OPS_REVIEW` or `ZCD_HCK_SUPPRESS`; the same action on the own company code succeeds.
5. CC-24: no alert e-mail of a list scoped to 1000 contains a finding of 2000.
6. Offline evidence before DV1: `ZCL_CA_OPS_DCL_TEST`, `ZCL_CD_OPS_DCL_TEST`, `ZCL_CA_OPS_EXC_POLICY` `ltc_isolation`, `ZCL_CD_HCK_SUPPRESSION` `ltc_company_code`, `ZCL_CA_OPS_CTL_CDS_TEST` `ltc_slice` / `ltc_day`, `ZCL_CD_EBS_DASH_CDS_TEST` `run_sliced_by_company_code` green (VERIFY V38, V39).

## 7. Behaviour comparison — legacy against new (shadow run, QA1)

Procedure: `Legacy_Parity_Comparison.md` §4. Every difference must map to D1–D11 of that document.

| BAI code / flow | Legacy failures | New findings | Differences explained by | Status |
|---|---|---|---|---|
| 166 D / 166 C / 143 C / 168 D / 195 D / 255 D / 466 D / 468 D / 452 D / 581 D (275 / 575: sweeps, no validation — D14); R21 lookup with one ZCD_EBS_LOOKUP row (missing key, wrong status, unknown lookup → PLUGIN_ERROR) | pending | pending | pending | pending |
| **PAR-195** (A105): 195 D, three lines of one payment run — existing payment, same LAUFD / LAUFI with a missing DOC1R, unknown run | COMPLETE 4 (run-level LAUFD / LAUFI): fails only the unknown run | R07 `PAYMENT_NOT_FOUND` on the missing payment **and** the unknown run (payment-level DOC1R, as v4) | Deliberate: run-level vs payment-level match (`Legacy_Parity_Comparison.md` §3 and §4 PAR-195) | pending |

## 8. Integration (QA1)
PRISM file hand-off and ack tables populated by the real interfaces; registry events derived from them in the right order (FMON-01, FMON-05). BCS and SLG1 channels (ALR-05, ALR-07).

## 9. Transaction and crash boundaries (QA1)
Cancel `ZCD_EBS_VALIDATE` (SM50) between packages: findings of committed packages remain, run stays status R, the morning report's health-of-health check flags it. Re-run produces a new run; no duplicate events in ZCD_FMON_EVENT (unique index).

## 10. Concurrency (QA1)
Two `ZCD_FMON_MONITOR` jobs started together: the second is refused (run lock for the whole FMON payment engine area, CORE-02 pattern). Two EBS or HCK runs of the same variant: the second is refused; different variants run in parallel. Two FMON writers of the same file's events (no lock, e.g. a manual event): EVENT_NO collision retried, every event recorded once.

## 11. Performance (QA1, acceptance 6)

| Metric | Target | Tool | Result |
|---|---|---|---|
| Aggregate health check runtime | < 2 min | ST12 / SAT | pending |
| Detail check runtime | < 10 min | ST12 | pending |
| DB load during peak (FPY1 window) | < 5 % | ST04 / DBACOCKPIT | pending |
| EBS validation of 50k statement lines | to be baselined | Run runtime in ZCA_OPS_RUN | pending |

### 11a. QA1 volume test — a 2 000 000-payment day (2026-11-08)

Volume confirmed by the user: 200 000-400 000 payments a normal day (2026-11-10; was about 200 000), two peak days of about 2 000 000, the exceptions-only worklist (≈ 2-6 million rows, `Performance_Review.md` §10a; was 90 days of outcome history, ≈ 60 million versions). Set-up on QA1: a client copy or mass test data with one day of 2 000 000 payments (payment runs FPY1 over generated open items, all watched methods, both flows, several house banks and currencies), statement lines for about 70 % of them, and `ZCD_PAY_OUTCOME` pre-filled to about 60 million rows (89 earlier days at the normal volume plus one earlier peak day). Snapshot step 2 of `ZCD_FMON_MONITOR_ALL` every 5 minutes; record the parameter values of each run.

| ID | Scenario | Measure | Pass criterion | Result |
|---|---|---|---|---|
| VOL-01 | Snapshot catch-up after the last payment run of the 2 million day; `PAYOUT_PARALLEL` 4, 8 (delivered), 12 and `PAYOUT_MAX_PACKAGES` 40 / 60 (delivered) / 80 | Minutes from the end of the last payment run until the freshness row CORE is green (lag < `MON_STALE_AFTER_MIN_CORE`); runtime of each 5-minute run (SM37); bgRFC units (SBGRFCMON); work processes used | Snapshot back within **60 minutes** after the last payment run with the chosen values; no run longer than 15 minutes; no `PAY_OUTCOME_FAILED`; the chosen `PAYOUT_PARALLEL` × package size within the bgRFC / work process budget agreed with Basis | pending |
| VOL-02 | Morning report the next morning with the 2 million day in flight (snapshot current) | `A_INFLIGHT` runtime (ZCD_HCK_RESULT RUNTIME_MS, SAT), memory peak (SAT / ST02), ST05: one aggregate, one examples read, no SELECT per payment; whole morning report runtime | `A_INFLIGHT` < **5 minutes** and < 500 MB extended memory; the morning report finishes inside its window (by 07:00, `Operations_Runbook.md` §1); counts equal an independent SQL count of the current versions not final (± 0) | pending |
| VOL-03 | Transactions dashboard during and after the peak | Response time of the ALP (main entity, date kind RUN = the peak day), the KPI tile and the header snapshot lag (browser network trace, ST05 / PlanViz) | Every request **< 3 seconds** (p95) | pending |
| VOL-04 | Stale snapshot: stop step 2 for 45 minutes during the peak, run the morning report | `PAY_SNAPSHOT_STALE` W, evidence PARTIAL, freshness row CORE red, dashboard header red; live evaluation capped (`TECH_READ_CAPPED`) | Never GREEN on stale data; after the restart the lag is green within the VOL-01 time | pending |
| VOL-01b | NIGHTLY run over the worklist after the 2 million day (`PAYOUT_PARALLEL` 8, `PAYOUT_BATCH_MAX_PACKAGES` 1 500, ≈ 1 200 packages) | Runtime, packages, rows written | Done before the morning report (< **3 hours**), no `PAY_BATCH_INCOMPLETE` | pending |
| VOL-05 | Size of `ZCD_PAY_OUTCOME` at ≈ 2-5 million worklist rows (after the peak) | Memory (M_CS_TABLES), indexes OUT / DOC / FIN / DAT | Within the sizing of `Performance_Review.md` §10a or partitioning decided | pending |
| VOL-06 | Purge of PAY_OUTCOME with `RETENTION_DAYS_PAY_OUTCOME` 90 (exception history closed > 90 days) | Runtime of `ZCA_OPS_RETENTION` target PAY_OUTCOME, rows deleted, locks / log volume | The monthly purge < **30 minutes**; no current version of a payment not final deleted (SQL check before / after) | pending |
| VOL-07 | Failed middle package: cancel the bgRFC unit of package 2 of a source (SBGRFCMON) during VOL-01 | `ZCD_PAY_OUTPKG` statuses, `ZCD_PAY_OUTWM` of the source | Watermark stops at the end of package 1; the next run judges packages 2 … again; no duplicate current version (SQL: one row per FIN / source / company code / payment with VALID_TO open) | pending |
| VOL-08 | Concurrency of the modes (review 2026-11-10): during VOL-01 (`PAYOUT_PARALLEL` 8) start a NIGHTLY run (`ZCD_PAY_NIGHTLY`) and a SWEEP of the same day | Findings 780 / 781 (`PAY_OUTCOME_FAILED` W), lock waits on the guard row `ZCD_PAY_OUTWM` / `WORKLIST` (DBACOCKPIT), package write time, `ZCD_PAY_OUTPKG` rows of each mode | No payment with two current rows of one key and no cleared payment with an open exception (SE16H on `ZCD_PAY_OUTCOME`); a 780 heals with the next run (FAIL_COUNT back to 0); FAST runtime within its 5 minutes; the SWEEP rows survive the FAST runs | pending |
| VOL-09 | Exceptions app while a run carries forward (review 2026-11-10): open the exception, start the morning report, approve a waiver while the run works; then act on a row the run superseded after the screen was loaded | Disposition and LAST_CHANGED_AT of both rows, run findings, app message | The waiver is kept (new row W, or the earlier row W and `EXC_CHANGED_DEFERRED` I); the stale action is refused by the ETag; never a waived row superseded without the new row inheriting the waiver | pending |
| VOL-10 | PRISM handled manually while the exception changes (review 2026-11-10): record a request whose FMON exception is assigned in the exceptions app between opening and saving | Record, exception, history (ZCA_OPS_EXC_HIST), ST22 | Either record + resolved exception + history, or nothing (short dump 787) - never a record without its closure | pending |

## 12. Operations and recovery
Runbook `Operations_Runbook.md` walked through by IT support on QA1 findings (one per triage row).

## 13. Defensive checks with no executable test
- `ZCL_CD_EBS_ENGINE=>READ_MODE` fallback to monitor when TVARVC cannot be read — requires a database error.
- `ZCL_CA_OPS_ALERT_ROUTER=>NEW_ID` UUID failure branch — `cl_system_uuid` does not fail in practice.
- `ZCL_CD_OPS_UTIL=>ELAPSED_MS` invalid-time-stamp branch — inputs come from `GET TIME STAMP`.

## 14. Evidence index
| # | Evidence | File |
|---|---|---|
| E1 | ABAP Unit result (package) | pending |
| E2 | Coverage per object | `Coverage_Run_Register.csv` (to update) |
| E3 | Portable checks (offline) | `portable_checks.json` — 12/12 passed, abaplint 0 issues (not SAP evidence) |
| E4 | Shadow-run comparison extract | pending |
| E5 | Performance traces | pending |

## 15. Pre-submission checklist
- [ ] Every `VERIFY-DDIC` marker answered (`Implementation_Order.md` step 0)
- [ ] Real object names, change, transport and incident numbers filled in
- [ ] ABAP Unit and coverage executed and recorded
- [ ] QA1 cases executed; status column filled; screenshots in the evidence index
- [ ] Shadow run differences all explained by D1–D11
- [ ] Status changed from Draft to Final only after execution


## Framework extraction ZCA_OPS (2026-11-10)

The unit tests of the moved classes moved with them to `ops-framework/src` (store, exception DAO / policy, alert router / policy / DAO / channels, lock, run guard, configuration gate / client / transport / auth / policy / field checks, purge engine and DAO, utilities, clock, file path, auth, parameters adapter, factory incl. the version check, configuration app permission tests); the suite keeps the tests of its own objects and gains `ZCL_CD_OPS_FACTORY` (suite services, prefixes, `ZCX_CD_OPS_ERROR=>CLASSIFY`), `ZCL_CD_OPS_PURGE_TARGET` (OSQL: the suite's purge targets and keep rules) and `ZCL_CD_OPS_ACK_MAIL` as alert section. Offline evidence per folder: abaplint 0 issues (suite, framework, parameter framework), suite portable checks 28/28, framework `tools/checks.py` 14/14, parameter framework `tools/checks.py` 9/9, tool tests green. Nothing has run in an SAP system: ABAP Unit, activation and ATC are VERIFY items (`Release_Readiness.md`, `ops-framework/docs/VERIFY.md`).
