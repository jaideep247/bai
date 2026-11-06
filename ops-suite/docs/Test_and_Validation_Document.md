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

Out of scope: transport import, activation, syntax and ATC (build hygiene); the BAdI FIEB_CHANGE_BS_DATA implementation (not delivered — signature from SE18 first); job retrigger (next phase); PRISM and bank internals beyond the file and ack tables.

## 2. What is being compared

| Aspect | Legacy | New |
|---|---|---|
| Codes validated | 10 hard-coded validator classes; any other code unchecked | Every code: mapped (category + configured rules) or blocked (R14) |
| Flow (collection/disbursement) | Configured but not applied | XBLNR pattern or account default; map rows per flow |
| Statement checks | None | S01–S12 (balances, sequence, account, date, duplicates, counts, coverage, completeness) |
| File formats | FEBEP only | BAI2 and CAMT.053/054 files before import, plus FEBKO/FEBEP after import |
| Results | Failed records only, ZBAI_* tables | Every run counted; owned exceptions with SLA in ZCD_OPS_FINDING |
| Alerts | Hard-coded e-mail on failure rate | ZCD_OPS_ALERT_RULE: channels, throttling, quiet hours, escalation, log |
| Morning report | Free-text SQL rules, WRITE list | Whitelisted, DDIC-validated checks A–E, baselines, ALV + HTML e-mail |

## 3. Test approach

Two real inputs instead of the population: one configured case (positive) and an adjacent unconfigured one (negative), so the difference is attributable to one customizing row. Close each negative by adding the row and re-running. Alter one configuration row at a time and restore it between cases.

## 4. Test data and configuration

| Item | Value |
|---|---|
| House bank accounts | One disbursement (JPMC), one collection (BOA) in `ZCD_EBS_ACCT` |
| Statements | One BAI2 file per bank (`config/samples/bai2_sample.txt` as layout reference), one CAMT.053 and one CAMT.054 returns file |
| Customizing | `config/*.csv`, `config/*_seed.md` loaded per `Implementation_Order.md` step 3 |
| Kill switch | TVARVC `ZCD_EBS_VALIDATION_MODE` = M unless a case says otherwise |
| Reset | Delete test runs from ZCD_OPS_RUN / _FINDING / _ALERT_LOG by RUN_ID after each case |

Production data never leaves the system; extracts for evidence are anonymised.

## 5. ABAP Unit tests (DV1)

856 methods in the package test includes (plus 4 in the cds/ class `ZCL_CD_TRX_REQ_CDS_TEST`, created in ADT after SE11), listed per object in `TDD_Approach_and_Coverage.md` §4 and `Coverage_Run_Register.csv`. Expected: all green, `RISK LEVEL HARMLESS`, statement coverage ≥ 90 % per object (record actual values in the register).

| Run | Expected | Actual |
|---|---|---|
| Package `ZCD_OPS*` ABAP Unit | 856 / 856 green | pending |
| Coverage per object | ≥ 90 % | pending |

## 6. Functional tests (QA1)

### 6.1 EBS validation

| ID | Scenario | Configuration | Expected result | Actual / status |
|---|---|---|---|---|
| EBS-01 | BAI2 file before import, all codes mapped, balances consistent | Seed map | Run S, no B/E findings | pending |
| EBS-02 | Same file with one detail record changed to an unmapped type code | Seed map | Line blocked, R14 UNMAPPED_BTC (B), S09 BTC_COVERAGE on the statement, no posting in enforce mode | pending |
| EBS-03 | Acceptance 3: add a ZCD_BTC_MAP row for the code from EBS-02 + ZCD_BTC_RULE R01/R04 | +1 map row, +2 rule rows | Line validated by R01/R04, no R14 | pending |
| EBS-04 | Acceptance 4: opening differs from prior closing by 0.02 | ZCD_BTC_RULE `*`/S01 TOLERANCE 0.01, SEVERITY B, ACTION BLOCK | S01 OPENING_NE_PRIOR_CLOSING (B); with deviation 0.01 no finding | pending |
| EBS-05 | BAI2 file with wrong 49 account control total | — | Parser S06 BAI2_ACCT_CTRL_TOTAL (B) | pending |
| EBS-06 | CAMT.053 with TxsSummry sum not matching entries | — | S06 CAMT_SUM_MISMATCH (B), S12 if counts differ | pending |
| EBS-07 | CAMT.054 returns with RtrInf R01 and an unmapped R99 | ZCD_EBS_RSN_MAP R01 only | R05 REASON_UNMAPPED on the R99 line only | pending |
| EBS-08 | CAMT line with Prtry code 168 issuer BAI | `EBS_CAMT_BAI_FALLBACK` = X | Maps to BAI2 168 rules; with blank parameter → R14 | pending |
| EBS-09 | Imported statement (FEB source), 168 on disbursement account, payment not RETURNED in DPAYH | Seed group BAI168D | R07 PAYMENT_STATUS | pending |
| EBS-10 | 581 checks paid with one register amount off by 1.00 | Seed group BAI581D | R08 CHECK_AMOUNT_MISMATCH on that check, R12 CODE_TOTAL_MISMATCH on the statement | pending |
| EBS-11 | Same statement file delivered twice | — | S07 STMT_ALREADY_IMPORTED (B) | pending |
| EBS-12 | Kill switch E / M / O on a file with one unmapped code (pre-posting entry) | TVARVC row | **Out of scope for this release:** the pre-posting path (`VALIDATE_FOR_POSTING` / BAdI `FIEB_CHANGE_BS_DATA`, enforce mode, blocked-line release) stays switched off; case moves with A02 to the future enforcement phase | not in this release |
| EBS-13 | Circuit breaker (A104): **FEB source** (`P_FEB`) over ≥ 3 imported statements, each a controlled package, every package > 50 % of its lines unmapped (the statements were imported, posted and cleared before the run — post-posting detective control) | `P_PACK` = 1 (one statement per package); `EBS_CB_MIN_LINES` = 1, `EBS_CB_FAIL_PCT` = 50, `EBS_CB_PACKAGES` = 3; ≥ 3 test statements selected by `S_KUKEY` / date range | Package 3 trips the breaker: run status A (aborted), one CIRCUIT_BREAKER finding (rule CB, E), no further package read, alert per the ON_ABORT rule; with only 2 bad packages followed by a good one: no breaker (counter resets) | pending |
| EBS-13a | Oversized or invalid single file through the **file source** (`P_FILE`) — one file is always one package, so the breaker cannot trip | (a) file not UTF-8; (b) BAI2 file cut off before the 98/99 trailers; (c) production-size file (largest observed day, `<line count, VERIFY with operations>`) | (a) read rejected, message 012, no run results (A69); (b) structural findings S00 / S06 TRAILER missing (B), lines not reported as validated (A86/A95); (c) one package, run completes or fails visibly; record runtime and memory — no size limit exists in code (`VERIFY` in QA1 whether one is needed) | pending |
| EBS-14 | Test mode | P_TEST = X | Findings shown; ZCD_OPS_RUN/FINDING/ALERT_LOG unchanged | pending |
| EBS-15 | POSTING_INCOMPLETE (operating model 2026-11-06): import a statement with a 466 (BAI466D, R19) and a 275 sweep line; run `ZCD_EBS_VALIDATE` (FEB source) **before** FEBP; then run FEBP and the clearing job and re-run the same variant | SE11 check of FEBEP-VB1OK / VB2OK done; `EBS_FEB_POSTED_FIELDS` default; seed S13 / NEEDS_POSTING | Run 1: one POSTING_INCOMPLETE (S13, W) on the statement counting the 466 line only (the 275 NOT_POSTED line is not counted); no R19 / R18 / S10 finding; run message "1 entries not evaluated (posting not complete)"; RAG amber, not green. Run 2: no POSTING_INCOMPLETE, R19 / R18 / S10 evaluated, the POSTING_INCOMPLETE exception resolved "Passed on re-run"; nothing posted, cleared or changed by either run (ST05 / table compare) | pending |

### 6.2 File monitoring
Fourteen cases FMON-01 … FMON-14 (outbound ACH end to end, re-run idempotency, no PRISM handoff, wire ack beyond 30 min, NACK, ack count mismatch, BAI statement missing/late, holiday calendar, **returns file partially processed then completed — acceptance 8**, wrong field name in customizing, NOC aging day 6 vs day 7, test mode, **new source and LOB by customizing — acceptance 2**, duplicate file). Configuration and expected results: `FMON_FILE_MONITORING.md` §B5.

### 6.3 Health checks and morning report
Fourteen cases HCK-QA-01 … HCK-QA-14 (**return debits aging > 10 days by company code — acceptance 1**, customizing-only threshold change, **new job-cycle step — acceptance 5**, each job-cycle state, config drift and baseline, plug-in failure, stale payment engine area (health of health), e-mail, background run with export, dashboard). Configuration and expected results: `HCK_MORNING_REPORT.md` §14.

### 6.4 Alerting

| ID | Scenario | Configuration | Expected result | Actual / status |
|---|---|---|---|---|
| ALR-01 | EBS run with a B finding at 23:00 | Rule EBS_BLOCK with quiet 22:00–06:00 | Delivered (B overrides quiet hours), log S | pending |
| ALR-02 | EBS run with E findings at 23:00 | Rule EBS_ERROR with quiet hours | Not delivered, log Q | pending |
| ALR-03 | Two runs 10 minutes apart | THROTTLE_MIN 30 | Second run logged T | pending |
| ALR-04 | Third consecutive alerting run | ESCALATE_AFTER 3 | Escalation list added | pending |
| ALR-05 | E-mail channel with invalid address | — | Log F; morning report alert-delivery check amber/red; run itself unaffected | pending |
| ALR-06 | HTTP channel to SM59 test endpoint | Destination by Basis | JSON body received, log S; non-2xx → log F | pending |
| ALR-07 | Application log channel | ZCD_OPS/ALERT | Messages visible in SLG1 | pending |

### 6.5 Core controls (authorisation, run lock, exception carry-forward, purge)

| ID | Scenario | Configuration | Expected | Result |
|---|---|---|---|---|
| CORE-01 | User without ZCD_OPS 16 for EBS starts `ZCD_EBS_VALIDATE` (same for FMON / HCK / CORE purge) | Role without the payment engine area | Message 041, nothing runs | pending |
| CORE-02 | Second `ZCD_EBS_VALIDATE` with the same variant while the first runs | Two jobs | Second: no run row, RUN_LOCKED alert (rule RUN_LOCKED), job ends in error with message 040; first unaffected | pending |
| CORE-03 | Lock released after a run that dumps (SM50 cancel) | — | Lock gone in SM12 when the job ends; next run starts | pending |
| CORE-04 | Same EBS file validated twice with the same unmapped code | Exception assigned to a user after run 1 | Run 2 row: disposition A, same owner and due date, OCCURRENCES 2; run 1 row disposition S | pending |
| CORE-05 | Fix the map row from CORE-04 and re-run | +1 ZCD_BTC_MAP row | Exception resolved "Passed on re-run"; open list on the morning report no longer shows it | pending |
| CORE-06 | Waived exception raised again | Disposition W, WAIVER_UNTIL in the future | New row stays W | pending |
| CORE-07 | `ZCD_OPS_PURGE` test mode, then productive with RETENTION_DAYS_RUN 30 on a copy of QA1 data | — | Test mode counts only; productive deletes old closed runs with findings, keeps runs with open / assigned / validly waived exceptions | pending |
| OPS-01 … OPS-10 | Operations apps: assign / resolve, waiver four-eyes, blocked-line release and posting gate, suppression (short / long), manual file status forward / backward, PRISM request handled manually | `RAP_Ops_Apps.md` §5 | As listed in `RAP_Ops_Apps.md` §5 | pending |
| HCK-QA-15 | `C_PRQ_NO_SPE` with one failed request without SPE row and one with SUCCESS after the failure | `config/hck_seed.md` rows, SE11 names filled | One finding (the first request); the second is not failed | pending |
| HCK-QA-16 | `C_CHQ_STATUS` with a cheque history 10 → 2 and one 10 → 9 | — | One finding (10 → 2); 10 → 9 allowed | pending |
| HCK-QA-17 | `C_PRQ_CANCEL` with a PCLM request CANCELLED whose open item is cleared | — | One finding PRQ_PAID_CANCELLED | pending |

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
| TRC-08 | User without ZCD_OPS 03 for the item's company code | Role | Item row NOT_AUTHORISED, no key shown, nothing MISSING | pending |
| TRC-09 | Side effects | ST05 during TRC-01..08 | SELECT only; no change in any business table, job, lock, file or interface; nothing written to ZCD_OPS_* | pending |
| TRC-10 | Performance | 20 traces at peak | Each trace < 5 s; FEBEP / DFKKOP / BUT000 reads use an index | pending |

### 6.7 File monitoring dashboard (`ZUI_CD_FMON_FLOW_O4`, `Dashboard_File_Monitoring.md`)

Read-only analytical list page, tiles and OVP-ready KPI / failure entities. ABAP Unit: `ZCL_CD_FMON_FLOW_CDS_TEST` (19 CDS tests: bucket of every stage incl. PRISM status API stages, success for ACK / no-ACK / inbound / unregistered interfaces, measures per source / LOB / method, SLA status, as-of from the last completed full run, stale flag, KPI per day, latest failures). QA1:

| ID | Case | Expected |
|---|---|---|
| FMD-01 | Monitor run (test mode off), open the dashboard | As of = end of that run; age < 30 min; not stale |
| FMD-02 | No monitor run for > 45 min | Header, rows and tile *Stale monitor* red — never shown as a quiet day |
| FMD-03 | Single-interface run and test-mode run | As of unchanged |
| FMD-04 | Outbound ACH file generated → sent → ACK | RECEIVED → SENT → ACKNOWLEDGED; successful only after the ACK |
| FMD-05 | BlackLine file (no ACK) sent to PRISM | SENT, successful |
| FMD-06 | Returns file with open lot items | PARTIAL, unprocessed items; tile *Unprocessed*; in *Latest failures* |
| FMD-07 | Open NO_BANK_ACK, resolve, re-run | SLA BREACHED → NO_FINDINGS |
| FMD-08 | User with ZCD_OPS FMON missing (HCK only) | No rows in any entity; with FMON 03 rows visible |
| FMD-09 | Filters source / LOB / method / bank / date | Totals equal SE16 sums on ZCD_FMON_FILE for the same filter |
| FMD-10 | Drill-down file → events → open exceptions | Equal to ZCD_FMON_EVENT / open ZCD_OPS_FINDING rows of the file |
| FMD-11 | Expected file not received | Tile *Missing files* = 1; no file row |
| FMD-12 | ST05 during use | SELECT only on the FMON / ops store tables; no write, lock or job |
| FMD-13 | PRISM status API live: PRISM_RECEIVED / _DELIVERED / _FAILED | AT_PRISM; SENT (out) / RECEIVED (in); REJECTED |

### 6.8 PRISM status API (`POST /sap/zcd_ops/prism_status`, `PRISM_Status_API.md`)

Own approved change (switch S-PRISM); QA1 with the SICF node active for the test user only. ABAP Unit: `ZCL_CD_FMON_PRISM_EVENT` (20), `_API` (11), `_DAO` (5, OSQL), `_PROC` (7, real engine), `ZCL_CD_FMON_ADAPTER_PRISM` (4), `ZCL_CD_FMON_CHK_PRISM_FILE` (5), `ZCL_CD_FMON_CHK_REJECT` (2), PRISM tests of `ZCL_CD_FMON_STATUS` (9) and `ZCL_CD_FMON_ENGINE` (2). Harness: Postman / curl over HTTPS with the QA1 technical user's certificate.

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
| PRISM-15 | ST05 / SAT during PRISM-01 | Writes only `ZCD_FMON_PRISM`, `ZCD_FMON_FILE`, `ZCD_FMON_EVENT`, `ZCD_OPS_RUN`, `ZCD_OPS_FINDING`, alert log; no business table, file, job or routing touched |

### 6.9 EBS validation dashboard (`ZUI_CD_EBS_DASH_O4`, `Dashboard_EBS_Validation.md`)

ABAP Unit: `ZCL_CD_EBS_DASH_CDS_TEST` (16 CDS tests: validation status from open findings, closed findings ignored, lines per statement, line status, as of on every row, account masked, bank-file messages hidden, line key, unevaluated lines, S13 / duplicates per run, KPI = last completed run of the day, as of / stale 26 h, returns by DFKKRP-RLGRD, NOCs by DFKKNRP-FLGRD via INFOF). QA1: cases **EBD-01 … EBD-12** of the dashboard doc §11 (stale, test / aborted runs, BLOCKED / POSTING_INCOMPLETE / NO_FINDINGS, duplicates, bank-file findings, returns / NOC, two runs a day, DCL, ST05).

### 6.10 Health check dashboard (`ZUI_CD_HCK_DASH_O4`, `Dashboard_Health_Check.md`)

ABAP Unit: `ZCL_CD_HCK_DASH_CDS_TEST` (6 CDS tests: status RED / AMBER / GREEN / WARMUP / NO_RESULT of the last completed run, older-run exceptions open but not the status, category = worst check, KPI counts, stale without completed run, 31-day metric history with DIM2 series). QA1: **HCD-01 … HCD-09** (doc §10).

### 6.11 Transactions dashboard (`ZUI_CD_TRX_DASH_O4`; request side `ZUI_CD_TRX_REQ_O4` after SE11; `Dashboard_Transactions.md`)

ABAP Unit: `ZCL_CD_TRX_DASH_CDS_TEST` (8 CDS tests: flow bucket per evidence, proposal runs ignored, 31-day window and FIN filter, direction from TFK042Z-XEINZ, KPI with distinct FIN numbers, errored / stuck list, return / NOC reasons from the lot items, no partner or member element). After SE11, in ADT: `ZCL_CD_TRX_REQ_CDS_TEST` (4 tests: **SUCCESS row rule** — a SUCCESS attempt wins over a later failed COUNTER —, errored, pending, member number not exposed). QA1: **TXD-01 … TXD-13** (doc §12), incl. the peak-volume ST05 / PlanViz run TXD-12.

### 6.12 Production-support overview page (`ZUI_CD_OPS_OVERVIEW_O4`, `Dashboard_Production_Support.md`)

ABAP Unit: `ZCL_CD_OPS_OVW_CDS_TEST` (5 CDS tests: one freshness row per monitor, stale by the area's threshold, open B / E exceptions only, overdue days, hidden bank-file message). QA1: **OVP-01 … OVP-08** (doc §7).

## 7. Behaviour comparison — legacy against new (shadow run, QA1)

Procedure: `Legacy_Parity_Comparison.md` §4. Every difference must map to D1–D11 of that document.

| BAI code / flow | Legacy failures | New findings | Differences explained by | Status |
|---|---|---|---|---|
| 166 D / 166 C / 143 C / 168 D / 195 D / 255 D / 466 D / 468 D / 452 D / 581 D (275 / 575: sweeps, no validation — D14); R21 lookup with one ZCD_EBS_LOOKUP row (missing key, wrong status, unknown lookup → PLUGIN_ERROR) | pending | pending | pending | pending |
| **PAR-195** (A105): 195 D, three lines of one payment run — existing payment, same LAUFD / LAUFI with a missing DOC1R, unknown run | COMPLETE 4 (run-level LAUFD / LAUFI): fails only the unknown run | R07 `PAYMENT_NOT_FOUND` on the missing payment **and** the unknown run (payment-level DOC1R, as v4) | Deliberate: run-level vs payment-level match (`Legacy_Parity_Comparison.md` §3 and §4 PAR-195) | pending |

## 8. Integration (QA1)
PRISM file hand-off and ack tables populated by the real interfaces; registry events derived from them in the right order (FMON-01, FMON-05). BCS, SLG1 and SM59 channels (ALR-05 … 07).

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
| EBS validation of 50k statement lines | to be baselined | Run runtime in ZCD_OPS_RUN | pending |

## 12. Operations and recovery
Runbook `Operations_Runbook.md` walked through by IT support on QA1 findings (one per triage row).

## 13. Defensive checks with no executable test
- `ZCL_CD_EBS_ENGINE=>READ_MODE` fallback to monitor when TVARVC cannot be read — requires a database error.
- `ZCL_CD_OPS_ALERT_ROUTER=>NEW_ID` UUID failure branch — `cl_system_uuid` does not fail in practice.
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
