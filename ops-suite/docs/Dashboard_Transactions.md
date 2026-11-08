# Transactions dashboard — requests received and processed in SAP, with the canonical payment outcome

> **First principle:** a payment has one outcome. The morning report check A_INFLIGHT, the payment trace and this dashboard show the same verdict for the same payment because one evaluator decides it (`ZIF_CD_OPS_PAY_OUTCOME`) and one table remembers it (`ZCD_PAY_OUTCOME`); the dashboard never re-derives an outcome from evidence rows.
> **Analogy:** a parcel tracking page that shows the courier's own delivery status - not a guess made from "a scan was seen at the depot". Scans (bank lines, returns lots) are still listed as evidence, but the status comes from the courier.

Status 2026-11-07: written and statically checked offline (abaplint 0 issues for `src/`, and for `src/` + `cds/` in a separate lint copy). **Not activated in SAP, ABAP Unit not executed.** One of the four area dashboards of `Dashboard_Production_Support.md`.

## 0. Canonical payment outcome (2026-11-07)

| Piece | Object | What it does |
|---|---|---|
| Evaluator | `ZIF_CD_OPS_PAY_OUTCOME` / `ZCL_CD_OPS_PAY_OUTCOME` (core factory `GET_PAY_OUTCOME`) | The A_INFLIGHT rules and evidence plug-ins (`HCK_MORNING_REPORT.md` §7b, posting areas `ZPMC` (method classes and house-bank calendars) and `ZBTR` (bank code roles) in FQC0, tables / `CLRRULE` / `BTCROLE` / `SEQOUT`, Stripe parameters `HCK_STRIPE_*`, plug-ins `ZCL_CD_HCK_EV_*`) moved unchanged into one shared service. Verdict per payment: outcome, deciding evidence kind and reference, finding. Source attribution: a FIN in two sources is **AMBIGUOUS** |
| 5-minute snapshot | `ZCL_CD_OPS_PAY_SNAPSHOT`, job step `ZCD_OPS_PAY_SNAPSHOT` (step 2 of SM36 `ZCD_FMON_MONITOR_ALL`) | Only payments with new evidence since the watermark of each source; a new version only when the outcome changed |
| History | `ZCD_PAY_OUTCOME` (keys only) + `ZCD_PAY_OUTWM` (watermarks) | Valid from / to; "as of" any instant since go-live; purge after 400 days |
| Views | `ZI_CD_PayOutcome`, `ZI_CD_PayOutcomeTs`, `ZI_CD_PayOutcomeAt`, `ZI_CD_PayOutcomeItm` | The version valid at the instant, per FIN + source (request side) or per FIN + company code + payment (item side) |

**Outcomes:** `CLEARED`, `RETURNED`, `RETRIEVED` (a retrieval is not a return), `VOIDED` (also a **stopped cheque**, DPAYH status STOPPED - user decision 2026-11-08, no own outcome), `PENDING` (consistent purpose of the rules); `IN_FLIGHT` (no purpose decided, the consistent IN_FLIGHT purpose, or - 2026-11-08 - the bank evidence decides RETURNED / RETRIEVED but the hourly payment status job has not updated DPAYH yet: the buckets do not change, the evidence reference of the version says "waiting for the payment status job"; the snapshot never writes a version because of the lag - the status lag is the morning report finding `PAY_STATUS_LAG`); `UNDETERMINED` (a mandatory evidence kind could not be used - fail closed); `INCONSISTENT` (some but not all evidence of a purpose, or an anomaly of an evidence kind); `AMBIGUOUS` (FIN in two or more sources, finding `PAY_SOURCE_AMBIGUOUS`); `REVERSED` (payment document reversed, DFKKKO-STBEL).

**History exists from go-live only.** Before the first snapshot run (and for payments of a method in no watched class) a paid item shows `NOT_EVALUATED`, never a guessed outcome. The first run reads the last `PAYOUT_INITIAL_DAYS` (10) days once. The UI says so in the header ("outcome history from go-live") and in the parameter label.

## 1. Two parts — what lights up when

| Part | Where | Tables | Fields | Lights up |
|---|---|---|---|---|
| **A. SAP side** (service `ZUI_CD_TRX_DASH`) | `src/core` (abapGit) | DFKKOP, T001, TFK042Z, DPAYH, DFKKCR, FEBEP, DFKKRP (+ DFKKRK), DFKKNRP, **ZCD_PAY_OUTCOME** | Confirmed or standard (VERIFY-SE11 list §10) | **At the abapGit pull** (step 1e of `Implementation_Order.md`); outcomes after the first snapshot run |
| **B. Request side** (service `ZUI_CD_TRX_REQ`) | `cds/` (ADT only) | ZCD_PAYM_REQ_LOG, ZCD_ACH_ACK, ZCD_WIRE_ACK, ZCD_CHECK_HIST, ZCD_ACH_RTRV_LOG + part A | Unconfirmed custom-table fields as **VERIFY-SE11 placeholders** | **After SE11 confirmation**: replace the placeholders, activate in ADT (step 1e.6) |

Part A never references part B, so the pull can never fail on an unconfirmed field.

## 2. What the support team sees (part A)

Fiori elements **analytical list page** (OData V4, main entity `Transaction`, parameterised):

| Area | Content |
|---|---|
| Parameters | **Date kind** `POSTING` (DFKKOP-BUDAT), `RUN` (latest DPAYH-LAUFD) or `VALUE` (its DPAYH-VALUT); **date from / to** - any day within the 400-day retention, default today; **outcome as of** date + time (system time zone), default now |
| Header | "Transactions (outcome history from go-live)" |
| Filter bar | FIN, company code, posting date, posted today, payment method, direction, payment status, return reason, flow bucket |
| Chart (default) | Transactions by **flow bucket** (= canonical outcome), stacked by payment method. Alternatives: funnel per posting date (transactions, paid, cleared, returned); by company code and direction |
| Table | One row per payment-engine open item with a FIN number of the chosen day(s): FIN (→ payment trace), document, company code, posting date, payment method, direction, amount, clearing document and date, payment status, return reason, bucket, outcome finding |
| Object page | Item; evidence (latest payment run date / ID / value date, DPAYH status, cheque, settlement / encashment date, return / NOC reason) and the outcome (outcome, finding, deciding evidence kind and reference, valid from, sources of the FIN); **Payment runs**; **Returns / NOC lot items** |
| Entity `PaymentRun` | DPAYH rows of 45 days by run date and **ZZ_PAYMENT_STATUS** (live status) |
| Entity `ReturnNoc` | Returns (DFKKRP-**RLGRD**) and NOCs (DFKKNRP-**FLGRD**) by reason, drill to the lot item |

A day can be chosen at any time during the day: the snapshot runs every 5 minutes, so the outcome of that day's payments is at most 5 minutes behind the evidence (one job interval; `Performance_Review.md` §10).

## 3. Flow bucket (one rule, `ZI_CD_TrxItemFlow`)

| Bucket (first that applies) | Evidence |
|---|---|
| REVERSED | Clearing reason 05 on the item (`ZIF_CD_OPS_TRACE_TYPES=>GC_REVERSAL_AUGRD`, parity check) |
| *canonical outcome* | The version of `ZCD_PAY_OUTCOME` valid at the "as of" instant for FIN + company code + payment document |
| NOT_EVALUATED | Payment run (latest DPAYH row) or cheque, but no valid outcome (before go-live, unwatched method, snapshot not yet run) |
| OFFSET | Clearing document without payment run |
| POSTED | Open (no clearing document) |

A bank line or encashment line alone never makes a payment "settled" (the former SETTLED bucket is gone); they are shown as evidence (settlement / encashment date). Measures: one per outcome (`ClearedCount`, `ReturnedCount`, `RetrievedCount`, `VoidedCount`, `PendingCount`, `InFlightCount`, `UndeterminedCount`, `InconsistentCount`, `AmbiguousCount`), `PaidReachedCount` (payment run or cheque), `NotEvaluatedCount`, `ReversedCount`, `OpenCount`, `NocItemCount`, `ChequeItemCount`. **Errored / stuck** (`TransactionProblem`, current outcome, 31 days): RETURNED, REVERSED, INCONSISTENT, UNDETERMINED, AMBIGUOUS and disbursements still **OPEN_OVERDUE** (posted before yesterday, not cleared).

**Direction** = TFK042Z-XEINZ (X collection, else disbursement; no payment method = NONE, method not in TFK042Z = UNKNOWN). **Line of business:** not a dimension (DFKKOP carries none; the request log's LOB field is not confirmed).

## 4. Request side (part B, cds/)

`ZR_CD_TrxReqFlow` (parameters request date from / to within 400 days and outcome as of): one row per **FIN + source + company code + payment document (+ method)** - the identity, so the company-code authorisation applies to exactly the items of the row.

1. **SUCCESS row rule first** (`ZI_CD_TrxRequest`): a request is processed when **any** attempt has ZZ_STATUS = SUCCESS - never the highest COUNTER, however old the SUCCESS attempt is.
2. **Then the window** (`ZI_CD_TrxReqWin`): a request is selected when one of its attempts is on the chosen day(s). (Review defect: the old 30-day window on `zz_created_on` ran before the rule and turned a request with an older SUCCESS and a recent failed retry into ERRORED.)
3. **SAP side per payment** (`ZI_CD_TrxFinFlow`): FIN + company code + clearing document + method + direction are the GROUP BY identity; no independent MAX of clearing document / cheque / company code / method / direction.
4. **Stage**: ERRORED, PENDING, AMBIGUOUS (FIN in two sources, `ZI_CD_TrxFinSrc` - the evaluator's rule mirrored in CDS, proven equal by the shared fixture), NOT_POSTED, REVERSED, then the **canonical outcome** joined by FIN + source + company code + payment document; only without an outcome REJECTED (NACK, IRIS 3 / 4), ACKNOWLEDGED, PAID, POSTED, OFFSET. A retrieval (ZCD_ACH_RTRV_LOG) is shown in `RetrievalStatus` and counted as `RetrievedCount` only through the outcome RETRIEVED - never as RETURNED.

Placeholders (replace from SE11 before activation): request log FIN field `zz_fin_trans_num`, request date `zz_created_on`, failure values of ZZ_STATUS; ACK tables payment key `zz_augbl`, status `zz_ack_status`, date `zz_ack_date`; cheque history `zz_check_no`, `zz_check_status`; retrieval log status `zz_rtrvl_status`.

## 5. Tiles, KPI and overview-page cards

| Tile | Request | Red when |
|---|---|---|
| Returned today | `TransactionKpi?$filter=IsToday eq true&$select=ReturnedCount` | > 0 |
| Problems today | `TransactionKpi?$filter=IsToday eq true&$select=ProblemCount` | > 0 |
| Overdue open disbursements | `TransactionProblem/$count?$filter=ProblemType eq 'OPEN_OVERDUE'` | ≥ 1 |
| Errored requests (part B) | `PaymentRequest(P_DateFrom=…,P_DateTo=…)/Set/$count?$filter=RequestStage eq 'ERRORED'` on `ZUI_CD_TRX_REQ_O4` | ≥ 1 |
| Transactions dashboard (app tile) | Semantic object `ZCDTransaction`, action `analyze` | — |

**KPI entity `TransactionKpi`** (`ZC_CD_TrxKpi`, no parameters, current outcome): per posting date (31 days) × company code × direction - transactions, distinct FIN numbers, paid, cleared, returned, retrieved, voided, in flight / pending, problems, reversed, open, NOC, not evaluated, day criticality; chart `Funnel`, `ByOutcome`; selection variant `Today`. The KPI and problem entities read the outcome as of today 23:59:59 - no version starts in the future, so this is the current version (literal under the parity check, `ZIF_CD_OPS_TYPES=>GC_TIME-DAY_END`).

## 6. Drill-down and payment trace

Bucket (chart) → list of transactions → object page → payment runs / returns and NOC lot items → **payment trace**. FIN numbers carry `@Consumption.semanticObject: 'ZCDPaymentTrace'` with an intent-based navigation button (action `display`). The trace shows the same outcome (stage `OUTCOME`, `Payment_Trace.md` §2). **Proposed, not built:** transaction code for the report (e.g. `ZCD_TRACE`) and the target mapping `ZCDPaymentTrace-display`.

## 7. Performance, bounds and sensitive data

- **Driver bound:** open items with FIN and **BUDAT ≥ today − 400** (the outcome retention; `ZIF_CD_OPS_TYPES=>GC_TRX_DASHBOARD-RETENTION_DAYS`, parity check). The date kind selects the day(s) in `ZR_CD_TrxFlow` (one OR branch per kind on a parameter comparison - HANA folds the branches of the other kinds; VERIFY in PlanViz, TXD-12). KPI / problem cards keep 31 days.
- **Outcome join by key:** `ZI_CD_PayOutcomeItm` per FIN + company code + payment document; index FIN (FIN_ID, SOURCE) serves the request side, DAT (BUKRS, LAUFD) the run-date filter, OUT (OUTCOME, VALID_TO) the current-outcome cards and the snapshot recheck (`Performance_Review.md` §10).
- **Aggregation on HANA:** `$apply` on the projections and `GROUP BY` in the CDS views; no row is aggregated in ABAP.
- **Latest payment run, one row** (`ZI_CD_TrxItemPay`): anti-join on a newer run of the same document - run date, run ID, value date and status from one DPAYH row (review defect: independent MAX per column mixed two runs).
- **No member number, business partner, contract account or bank account** is selected (test `no_partner_or_member_exposed`). FIN numbers and document numbers are shown (needed for the trace).
- Amounts: signed as stored (BETRW in WAERS, BETRH in the company code currency); aggregate per currency and direction.

## 8. Authorisation (applied on the base rows, before aggregation)

Area **CORE** with **company code**: `pfcg_auth( ZCD_OPS, ZCD_PE_AREA, BUKRS, ACTVT = '03' )` on transactions, KPI, problems, returns / NOC (DCL `ZC_CD_TRXDASH`); payment run rows by area only; request funnel DCL `ZC_CD_TRXREQ`. **Order checked (review 2026-11-07):** on `ZC_CD_TrxFlow` the condition is on the open item's own company code and the `$apply` GROUP BY runs after the DCL WHERE; on `ZC_CD_TrxKpi` the company code is a GROUP BY key passed through from the base rows, so filtering the aggregated rows equals filtering the base rows (test `kpi_never_mixes_company`). The leak was on the request side: `ZI_CD_TrxFinFlow` grouped by FIN only and the DCL checked `MAX( CompanyCode )` - a user of one company code saw counts of another company's items. Now the company code is part of the row identity (test `one_row_per_company_code`).

## 9. Objects

| Object | Folder | Type | Role |
|---|---|---|---|
| `ZCD_PAY_OUTCOME`, `ZCD_PAY_OUTWM` | ddic/core | tables (A) | Outcome versions (keys only), watermarks per evidence source |
| `ZIF_CD_OPS_PAYOUT_TYPES`, `ZIF_CD_OPS_PAY_OUTCOME`, `ZCL_CD_OPS_PAY_OUTCOME` | src/core | types, interface, class | Canonical evaluator |
| `ZIF_CD_OPS_PAY_OUTCOME_DAO`, `ZCL_CD_OPS_PAY_OUTCOME_DAO`, `ZCL_CD_OPS_PAY_SNAPSHOT`, `ZCD_OPS_PAY_SNAPSHOT` | src/core | DAO, class, program | 5-minute snapshot |
| `ZCL_CD_OPS_PAY_FIXTURE` | src/core | class (test support) | Shared negative fixtures of every consumer's tests |
| `ZI_CD_PayOutcome`, `…Ts`, `…At`, `…Itm` | src/core | views | Versions, as-of instant, valid version per FIN + source, per FIN + company code + payment |
| `ZI_CD_TrxItem` | src/core | view | Driver: DFKKOP with FIN, 400 days, + T001, TFK042Z |
| `ZI_CD_TrxItemPay` (latest run), `…Chq`, `…Bank`, `…Enc`, `…Ret`, `…Noc` | src/core | views | Evidence per item |
| `ZI_CD_TrxItemFlow` | src/core | view (as of) | Item + canonical outcome: the one bucket rule and the measures |
| `ZR_CD_TrxFlow` / `ZC_` | src/core | root / projection (ALP, parameters) | Transactions by date kind, as of |
| `ZR_CD_TrxPayRun`, `ZR_CD_TrxRetNoc`, `ZR_CD_TrxKpi`, `ZR_CD_TrxProblem` (+ `ZC_`) | src/core | roots / projections | Payment runs, returns / NOC, KPI and problems (current outcome) |
| `ZC_CD_TRXDASH` | src/core | DCL | CORE + BUKRS |
| `ZUI_CD_TRX_DASH` | src/core | SRVD | `Transaction`, `PaymentRun`, `ReturnNoc`, `TransactionKpi`, `TransactionProblem` |
| `ZCL_CD_TRX_DASH_CDS_TEST` | src/core | class (test holder) | §11 |
| `ZI_CD_TrxReqLog`, `ZI_CD_TrxRequest`, `ZI_CD_TrxReqWin`, `ZI_CD_TrxFinSrc`, `ZI_CD_TrxFinFlow`, `ZI_CD_TrxReqSap`, `ZI_CD_TrxChqPay`, `ZI_CD_TrxAckU`, `ZI_CD_TrxAck`, `ZI_CD_TrxChqStat`, `ZI_CD_TrxRtrv` | **cds/** | views | Request side with placeholders |
| `ZR_CD_TrxReqFlow` / `ZC_CD_TrxReqFlow` (+ DDLX), `ZC_CD_TRXREQ` (DCL), `ZUI_CD_TRX_REQ` (SRVD) | **cds/** | root / projection / DCL / SRVD | Request funnel |
| `ZCL_CD_TRX_REQ_CDS_TEST` | **cds/** | class (test holder, ADT) | §11 |

## 10. VERIFY-ADT / VERIFY-SE11

| Item | Fallback |
|---|---|
| DFKKOP OPUPW / OPUPK / OPUPZ / PYMET / AUGST / AUGRD / AUGDT / BETRW / BETRH, T001-LAND1 / WAERS, TFK042Z key LAND1 + ZLSCH | Fields as `ZCL_CD_OPS_TRACE_DAO`; if TFK042Z has another key, Direction = UNKNOWN until fixed |
| DPAYH XVORL, VALUT and key (LAUFD + LAUFI + DOC1R unique?) | Add the DPAYH key fields to `ZR_CD_TrxPayRun` and to the anti-join of `ZI_CD_TrxItemPay` |
| VERIFY-ADT: comparison operators and OR in the ON condition of `ZI_CD_TrxItemPay` (anti-join) | Two views: max of LAUFD + LAUFI per DOC1R, joined back |
| VERIFY-ADT: `dats_tims_to_tstmp` with `abap_system_timezone` in `ZI_CD_PayOutcomeTs`; field-to-field comparison in the WHERE of `ZI_CD_PayOutcomeAt` | A timestamp parameter instead of date + time |
| VERIFY-ADT: parameters of a `transactional_query` projection in an ALP and in the overview page; a character literal as TIMS actual parameter (KPI / problem) | KPI / problem with the same parameters, defaults from `@Environment.systemField` |
| VERIFY-ADT: HANA prunes the OR branches of `P_DateKind` (PlanViz, TXD-12) | Three root views, one per date kind |
| DFKKRP-RLGRD, DFKKNRP-FLGRD, DFKKRP key | Remove the reason element |
| Two-field `pfcg_auth` (ZCD_PE_AREA, BUKRS) | Area-only grant + BUKRS restriction in the role |
| `COUNT( DISTINCT )`, UNION, `$apply` on transactional_query | As the other dashboards |
| VERIFY-ADT: `coalesce( … )` as key elements of `ZI_CD_TrxReqSap` (request not posted: blank company code / payment document / method) | Coalesce in `ZI_CD_TrxFinFlow`'s consumer one level up and declare the keys there |
| Part B placeholders (§4) | Activate part B only after SE11 |

## 11. Tests

`ZCL_CD_TRX_DASH_CDS_TEST` (`ltc_flow`, doubles of DFKKOP, T001, TFK042Z, DPAYH, DFKKCR, FEBEP, DFKKRP, DFKKRK, DFKKNRP, ZCD_PAY_OUTCOME): `bucket_is_canonical_outcome`, `bank_line_alone_not_settled`, `proposal_run_is_not_payment`, `retention_and_fin_bound`, `direction_from_tfk042z`, `kpi_counts_distinct_fin`, `kpi_never_mixes_company`, `problems_list_errored_stuck`, `reasons_from_lot_items`, `no_partner_or_member_exposed`; shared fixtures (`ZCL_CD_OPS_PAY_FIXTURE`): `fixture_retrieval_not_return`, `fixture_line_inconsistent`, `fixture_two_runs_one_row`, `fixture_two_sources_one_row`, `as_of_between_versions`, `date_kind_run_and_value`.
`cds/ZCL_CD_TRX_REQ_CDS_TEST` (`ltc_request`, ADT after SE11): `success_row_wins_over_counter`, `errored_without_success_row`, `pending_without_outcome`, `member_number_not_exposed`, `success_older_than_window`, `retrieval_is_not_returned`, `fin_two_sources_ambiguous`, `one_row_per_company_code`.
The same fixtures run through the evaluator (`ZCL_CD_OPS_PAY_OUTCOME`), A_INFLIGHT (`ZCL_CD_HCK_C_INFLIGHT`, `fixture_*`), the trace (`ltc_outcome`) and the snapshot (`ZCL_CD_OPS_PAY_SNAPSHOT`): same data, same expected outcome.

## 12. QA1 cases

| ID | Case | Expected |
|---|---|---|
| TXD-01 | PCLM ACH disbursement: request → posting → payment run → 466 on the statement, DPAYH status CLEARED | POSTED → NOT_EVALUATED / IN_FLIGHT → CLEARED within one snapshot interval of the status |
| TXD-02 | Cheque payment, then 581 on the statement, register state B | IN_FLIGHT → CLEARED (the encashment line alone is not a verdict) |
| TXD-03 | ACH return (466, 168, returns lot with RLGRD) | RETURNED; reason = DFKKRP-RLGRD; problems list |
| TXD-03a | ACH manual retrieval (466 → 166, no returns lot) | RETRIEVED, never RETURNED; not on the problems list as a return |
| TXD-04 | NOC on a payment (DFKKNRP, INFOF with leading zeros) | `ReturnNoc` NOC row with FLGRD; bucket unchanged |
| TXD-05 | Reversal (clearing reason 05) | REVERSED |
| TXD-06 | Disbursement posted 2 days ago, not paid | OPEN_OVERDUE in the problems list |
| TXD-07 | Proposal run only (XVORL) | OFFSET (no payment) |
| TXD-08 | Item without FIN; item posted 401 days ago | Not listed for any date |
| TXD-09 | User with ZCD_OPS CORE / 03 for US01 only, FIN with items in US01 and US02 | Only US01 rows and US01 counts; payment run rows visible (area only) |
| TXD-10 | FIN → *Payment trace* (after the target mapping) | Trace opens with the FIN; trace outcome = bucket |
| TXD-11 | Part B after SE11: SUCCESS 40 days ago, FAILED today, window today | PROCESSED, never ERRORED |
| TXD-12 | ST05 / PlanViz at peak volume, each date kind, as of now and as of last week | SELECT only; driver by BUDAT / LAUFD / VALUT; outcome by index; response < 5 s for chart and KPI; record plan |
| TXD-13 | Display role only | No write, no lock, no job |
| TXD-14 | Wire on the statement, DPAYH status not CLEARED | INCONSISTENT (problems list), A_INFLIGHT `CLEARING_INCONSISTENT`, trace outcome FAILED row |
| TXD-15 | Re-run of a payment (two DPAYH runs) | One row; run date, run ID, value date, status of the latest run |
| TXD-16 | FIN with SUCCESS in two sources | AMBIGUOUS (one item row, two sources; request side two rows), finding `PAY_SOURCE_AMBIGUOUS` |
| TXD-17 | As of yesterday 08:00 for a payment cleared today | The version valid then (e.g. IN_FLIGHT); before go-live NOT_EVALUATED |
