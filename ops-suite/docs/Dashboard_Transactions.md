# Transactions dashboard — the payment worklist: open payments, open requests and exceptions

> **First principle:** a payment has one outcome, and a person only needs to look at the payments that are not finished or not right. The morning report check A_INFLIGHT, the payment trace and this dashboard show the same verdict because one evaluator decides it (`ZIF_CD_OPS_PAY_OUTCOME`, for requests `ZIF_CD_OPS_PAY_REQUEST`) and one table remembers it (`ZCD_PAY_OUTCOME`, the **worklist**); the dashboard never re-derives an outcome from evidence rows.
> **Analogy:** an airport's "delayed and cancelled" board. Flights that landed on time are not listed - you look them up by flight number (the payment trace) if you need them.

Status 2026-11-08: written and statically checked offline (abaplint 0 issues for `src/`, and for `src/` + `cds/` in a separate lint copy). **Not activated in SAP, ABAP Unit not executed.** One of the four area dashboards of `Dashboard_Production_Support.md`.

## 0. The worklist (user decision 2026-11-08: exceptions only)

| Piece | Object | What it does |
|---|---|---|
| Evaluator | `ZIF_CD_OPS_PAY_OUTCOME` / `ZCL_CD_OPS_PAY_OUTCOME` (core factory `GET_PAY_OUTCOME`) | The A_INFLIGHT rules and evidence plug-ins (`HCK_MORNING_REPORT.md` §7b). Verdict per payment: outcome, deciding evidence kind and reference, finding. A FIN in two sources is **AMBIGUOUS** |
| Request rule | `ZIF_CD_OPS_PAY_REQUEST` / `ZCL_CD_OPS_PAY_REQUEST` (`GET_PAY_REQUEST`) | Payment requests with a SUCCESS attempt (any attempt, never the highest COUNTER): due date, stage, paid on time / late / not paid (§3a) |
| Snapshot | `ZCL_CD_OPS_PAY_SNAPSHOT`, program `ZCD_OPS_PAY_SNAPSHOT` - modes **FAST** (every 5 minutes, step 2 of `ZCD_FMON_MONITOR_ALL`), **NIGHTLY** (once a night, every worklist row re-judged), **SWEEP** (on demand, date range + sources) | Writes the worklist (`Operations_Runbook.md` §5k / §5n) |
| Worklist | `ZCD_PAY_OUTCOME` | **Open** payment or request: one current row, changed in place. **Exception** (a finding): keeps its version history. A payment that ends **clean** (CLEARED, RETURNED, RETRIEVED, VOIDED, REVERSED without finding) is **deleted** - unless it had an exception, then its history is closed with a final version and purged 90 days later |
| Snapshot lag | `ZI_CD_PayOutLagMin` / `ZI_CD_PayOutRunLast` / `ZI_CD_PayOutLag` | Minutes since the oldest instant up to which every FAST evidence source is processed (RECHECK and the NIGHTLY cursors left out); header data point of this dashboard |
| Current row | `ZI_CD_PayOutcome` → **`ZI_CD_PayWorkItem`** | Current rows only (VALID_TO open), with kind, worklist date, payment run values (DPAYH by key, proposal runs excluded) and direction |

**Exceptions** (finding filled): `CLEARING_INCONSISTENT` (outcome INCONSISTENT, severity E), `CLEARING_UNDETERMINED` (UNDETERMINED, W), `PAY_SOURCE_AMBIGUOUS` (AMBIGUOUS, W), `PAY_STATUS_PENDING` (the bank decided, the payment status job has not followed - the morning report's `PAY_STATUS_LAG`), `PAYMENT_NOT_CLEARED` (late beyond the AMBER (W) / RED (E) business-day limit of A_INFLIGHT's `AGE_OLDEST` thresholds, the same ageing as the morning report - `ZCL_CD_HCK_PAY_AGEING`), `PRQ_NOT_PAID` (payment request not paid on its due date, E). **Open:** IN_FLIGHT / PENDING payments within their limits and requests not yet due (`REQ_OPEN`).

**Nothing about clean payments is counted here any more** (cleared / returned / retrieved / voided counts, the posting-date driver and the "outcome as of" history are gone). Those payments are in the standard tables; the **payment trace** finds any payment by FIN, payment document, cheque number or payment request (`Payment_Trace.md`).

## 1. Two parts — what lights up when

| Part | Where | Tables | Fields | Lights up |
|---|---|---|---|---|
| **A. SAP side** (service `ZUI_CD_TRX_DASH`) | `src/core` (abapGit) | **ZCD_PAY_OUTCOME**, DPAYH, T001, TFK042Z; returns / NOC: DFKKOP, DFKKRP (+ DFKKRK), DFKKNRP | Confirmed or standard (VERIFY list §10) | **At the abapGit pull** (step 1e of `Implementation_Order.md`); rows after the first snapshot run |
| **B. Request side** (service `ZUI_CD_TRX_REQ`) | `cds/` (ADT only) | ZCD_PAYM_REQ_LOG, ZCD_ACH_ACK, ZCD_WIRE_ACK, ZCD_CHECK_HIST, ZCD_ACH_RTRV_LOG + part A | Unconfirmed custom-table fields as **VERIFY-SE11 placeholders** | **After SE11 confirmation** (step 1e.6) |

Part A never references part B, so the pull can never fail on an unconfirmed field.

## 2. What the support team sees (part A)

Fiori elements **analytical list page** (OData V4, main entity `Transaction`, parameterised):

| Area | Content |
|---|---|
| Parameters | **Date kind** `WORKLIST` (run date of a payment, due date of a request - default), `RUN` (DPAYH-LAUFD of the row), `VALUE` (its DPAYH-VALUT), `DUE` (due date of a request); **date from / to**, default today. No window: the worklist bounds the rows |
| Header | Data point **Outcome snapshot lag (minutes)** with its criticality (red when stale, `MON_STALE_AFTER_MIN_CORE`) |
| Filter bar | Kind (PAYMENT / REQUEST), FIN, source, company code, flow + method class, outcome, finding (code), exception yes / no, payment method, direction, payment status, today |
| Charts | Worklist by **outcome and flow + method class** (default); **exceptions by finding** per worklist date; **requests not paid on their due date** by source and stage; by company code and direction |
| Table | One row per worklist row: FIN (→ payment trace), source, kind, payment document (→ payment trace), run date / ID, due date, outcome, finding, severity, evidence kind / stage, evidence, flow + method class, open since, method, house bank, value date, payment status, direction, amount |
| Object page | Outcome, finding, evidence; **Payment runs** (by payment document); **Returns / NOC lot items** |
| Entity `PaymentRun` | DPAYH rows of 45 days by run date and **ZZ_PAYMENT_STATUS** (live status) |
| Entity `ReturnNoc` | Returns (DFKKRP-**RLGRD**) and NOCs (DFKKNRP-**FLGRD**) of the 45-day evidence window by reason |

## 3. Outcome and kind of a row (`ZI_CD_PayWorkItem`)

| Element | Rule |
|---|---|
| `WorkKind` | `PAYMENT` when the payment document (AUGBL) is filled, else `REQUEST` (FIN + source) |
| `WorklistDate` | Run date of a payment, due date of a request |
| `IsException` | Finding filled |
| `FlowCriticality` | 1 red (severity E), 2 yellow (other exception), 0 open |
| `Direction` | TFK042Z-XEINZ of the company code's country (X collection, else disbursement; method not in TFK042Z = UNKNOWN); a payment request is a disbursement |
| Measures (`ZR_CD_TrxFlow`) | `EntryCount`, `OpenCount`, `ExceptionCount`, `InFlightCount`, `PendingCount`, `UndeterminedCount`, `InconsistentCount`, `AmbiguousCount`, `RequestOpenCount`, `RequestNotPaidCount`, `LateCount` (`PAYMENT_NOT_CLEARED`), `StatusPendingCount` |

### 3a. Payment requests not paid on their due date (2026-11-08)

A request (FIN + source with **any** SUCCESS attempt in `ZCD_PAYM_REQ_LOG`, cancellation per the `C_PRQ_CANCEL` rule) is **due** on its requested payment date (`DUE=` of `TRACE_SRC_REQUEST`, VERIFY-SE11), never before the day it was received; received on the due day after the source's **cut-off** (`PAYOUT_REQ_CUTOFF`, default `*=190000`, time zone `FMON_TIME_ZONE`) it is due the next day; a due date on a non-business day rolls to the next business day (A_INFLIGHT PARAM1 calendar). It is **paid** when its FIN items are cleared by a payment run (DPAYH) on or before the due date. Not paid by the end of the due date → row `REQ_NOT_PAID` with finding `PRQ_NOT_PAID` (E) and the **stage** as evidence kind: `PRQ_NO_ITEM` (no open item with the FIN), `PRQ_PAYMENT_BLOCK` (item with payment lock, DFKKOP-SPZAH VERIFY-SE11), `PRQ_NOT_IN_RUN` (open, unblocked, no run), `PRQ_CLEARED_NO_RUN` (cleared without a payment run). Paid later → a closing version `REQ_PAID_LATE` / `PRQ_PAID_LATE` (history), then the row leaves the worklist. AML hold: open question (§10).

## 4. Request side (part B, cds/)

`ZR_CD_TrxReqFlow` (parameters request date from / to within the 45-day evidence window): one row per **FIN + source + company code + payment document (+ method)**.

1. **SUCCESS row rule first** (`ZI_CD_TrxRequest`): processed when **any** attempt is SUCCESS - never the highest COUNTER.
2. **Then the window** (`ZI_CD_TrxReqWin`): a request is selected when one of its attempts is on the chosen day(s).
3. **SAP side per payment** (`ZI_CD_TrxFinFlow`): FIN + company code + clearing document + method + direction are the GROUP BY identity.
4. **Stage**: ERRORED, PENDING, AMBIGUOUS (FIN in two sources), NOT_POSTED, REVERSED, then the **current worklist row** (`ZI_CD_PayWorkItem`, joined by FIN + source + company code + payment document); without a worklist row REJECTED (NACK, IRIS 3 / 4), ACKNOWLEDGED, PAID, POSTED, OFFSET. A clean final payment has no worklist row: its stage is PAID / ACKNOWLEDGED. A retrieval (ZCD_ACH_RTRV_LOG) is shown in `RetrievalStatus`, never as RETURNED. `ExceptionCount` = the payment is an exception of the worklist.

Placeholders (replace from SE11 before activation): request log FIN field `zz_fin_trans_num`, request date `zz_created_on`, failure values of ZZ_STATUS; ACK tables payment key `zz_augbl`, status `zz_ack_status`, date `zz_ack_date`; cheque history `zz_check_no`, `zz_check_status`; retrieval log status `zz_rtrvl_status`.

## 5. Tiles, KPI and overview-page cards

| Tile | Request | Red when |
|---|---|---|
| Exceptions today | `TransactionKpi?$filter=IsToday eq true&$select=ExceptionCount` | > 0 |
| Late payments | `TransactionKpi?$select=LateCount` | > 0 |
| Requests not paid on their due date | `TransactionProblem/$count?$filter=ProblemType eq 'PRQ_NOT_PAID'` | ≥ 1 |
| Errored requests (part B) | `PaymentRequest(P_DateFrom=…,P_DateTo=…)/Set/$count?$filter=RequestStage eq 'ERRORED'` on `ZUI_CD_TRX_REQ_O4` | ≥ 1 |
| Transactions dashboard (app tile) | Semantic object `ZCDTransaction`, action `analyze` | — |

**KPI entity `TransactionKpi`** (`ZC_CD_TrxKpi`, no parameters): per worklist date (last 30 days, `GC_TRX_DASHBOARD-ITEM_WINDOW_DAYS`, parity check) × company code × direction - entries, distinct FIN numbers, open, exceptions, in flight / pending, late, undetermined / inconsistent / ambiguous, requests open and not paid, day criticality; charts `Worklist`, `ByDay`; selection variant `Today`. **Errored / stuck** (`TransactionProblem`): every exception of the worklist (finding filled), oldest first, no window.

## 6. Drill-down and payment trace

Chart → worklist rows → object page → payment runs / returns and NOC lot items → **payment trace**. FIN numbers and payment documents carry `@Consumption.semanticObject: 'ZCDPaymentTrace'` (action `display`). The trace shows the same outcome (stage `OUTCOME`) and, for a request, its due date (stage `REQUEST_DUE`, `Payment_Trace.md` §2). **Proposed, not built:** transaction code for the report (e.g. `ZCD_TRACE`) and the target mapping `ZCDPaymentTrace-display`.

## 7. Performance, bounds and sensitive data

- **Bound = the worklist**: about 2-5 million current rows in steady state (open payments of the last days, open requests, exceptions; `Performance_Review.md` §10 / VOL-01) instead of the former 400-day item driver (~60 million). No date window on `ZR_CD_TrxFlow`; the date kind selects the day(s) (one OR branch per kind - VERIFY in PlanViz, TXD-12).
- **Payment run by key:** `ZI_CD_PayWorkItem` joins DPAYH by LAUFD + LAUFI + DOC1R of the row (no "latest run" search; the snapshot already judged the latest run). Indexes of `ZCD_PAY_OUTCOME`: FIN (FIN_ID, SOURCE), DAT (BUKRS, LAUFD), OUT (OUTCOME, VALID_TO), **DUE (DUE_DATE)**.
- **Aggregation on HANA:** `$apply` on the projections and `GROUP BY` in the CDS views; no row is aggregated in ABAP.
- **No member number, business partner, contract account or bank account** is selected (test `no_partner_or_member_exposed`).
- Amounts: DPAYH-RWBTR (absolute) in DPAYH-WAERS; a request row has no amount on the dashboard (the morning report sums request amounts from the request log, `AMOUNT=` VERIFY-SE11).

## 8. Authorisation (applied on the base rows, before aggregation)

Area **CORE** with **company code**: `pfcg_auth( ZCD_OPS, ZCD_PE_AREA, BUKRS, ACTVT = '03' )` on transactions, KPI, problems, returns / NOC (DCL `ZC_CD_TRXDASH`); payment run rows by area only; request funnel DCL `ZC_CD_TRXREQ`. On `ZC_CD_TrxKpi` the company code is a GROUP BY key passed through from the base rows (test `kpi_never_mixes_company`). **Request rows carry no company code** (the request log has none; the item may not exist yet): a role must grant BUKRS blank (or `*`) to see them - open point in `Release_Readiness.md` §5.

## 9. Objects

| Object | Folder | Type | Role |
|---|---|---|---|
| `ZCD_PAY_OUTCOME`, `ZCD_PAY_OUTWM`, `ZCD_PAY_OUTPKG` | ddic/core | tables (A) | Worklist (open rows, exception history; FLOW_CLASS, DUE_DATE), watermarks / cursors per source, parallel package rows of a run |
| `ZIF_CD_OPS_PAY_SNAP_QUEUE`, `ZCL_CD_OPS_PAY_SNAP_QUEUE`, `ZCL_CD_OPS_PAY_SNAP_OP` | src/core | interface, bgPF queue, bgPF operation | Parallel snapshot packages |
| `ZI_CD_PayOutLagMin`, `ZI_CD_PayOutRunLast`, `ZI_CD_PayOutLag` | src/core | views | Snapshot lag |
| `ZIF_CD_OPS_PAYOUT_TYPES`, `ZIF_CD_OPS_PAY_OUTCOME`, `ZCL_CD_OPS_PAY_OUTCOME` | src/core | types, interface, class | Canonical evaluator |
| `ZIF_CD_OPS_PAY_REQUEST`, `ZCL_CD_OPS_PAY_REQUEST` | src/core | interface, class | Request rule (due date, cut-off, stage) |
| `ZIF_CD_OPS_PAY_OUTCOME_DAO`, `ZCL_CD_OPS_PAY_OUTCOME_DAO`, `ZCL_CD_OPS_PAY_SNAPSHOT`, `ZCD_OPS_PAY_SNAPSHOT` | src/core | DAO, class, program | Snapshot (FAST / NIGHTLY / SWEEP) |
| `ZCL_CD_OPS_PAY_FIXTURE` | src/core | class (test support) | Shared negative fixtures; `OUTCOME_ROWS` = the worklist rows the snapshot writes |
| `ZI_CD_PayOutcome`, `ZI_CD_PayWorkItem` | src/core | views | All rows; current rows with run values, kind, worklist date, direction |
| `ZR_CD_TrxFlow` / `ZC_` | src/core | root / projection (ALP, parameters) | Worklist rows by date kind |
| `ZR_CD_TrxKpi`, `ZR_CD_TrxProblem` (+ `ZC_`) | src/core | roots / projections | KPI per worklist date, exceptions |
| `ZI_CD_TrxItem`, `ZI_CD_TrxRetNocU`, `ZR_CD_TrxRetNoc` (+ `ZC_`), `ZR_CD_TrxPayRun` (+ `ZC_`) | src/core | views | Returns / NOC and payment runs of the 45-day evidence window |
| `ZI_CD_TrxItemPay`, `ZI_CD_TrxItemChq` | src/core | views | Payment run / cheque per item (used by the request side) |
| `ZC_CD_TRXDASH` | src/core | DCL | CORE + BUKRS |
| `ZUI_CD_TRX_DASH` | src/core | SRVD | `Transaction`, `PaymentRun`, `ReturnNoc`, `TransactionKpi`, `TransactionProblem` |
| `ZCL_CD_TRX_DASH_CDS_TEST` | src/core | class (test holder) | §11 |
| `ZI_CD_TrxReqLog`, `ZI_CD_TrxRequest`, `ZI_CD_TrxReqWin`, `ZI_CD_TrxFinSrc`, `ZI_CD_TrxFinFlow`, `ZI_CD_TrxReqSap`, `ZI_CD_TrxChqPay`, `ZI_CD_TrxAckU`, `ZI_CD_TrxAck`, `ZI_CD_TrxChqStat`, `ZI_CD_TrxRtrv` | **cds/** | views | Request side with placeholders |
| `ZR_CD_TrxReqFlow` / `ZC_CD_TrxReqFlow` (+ DDLX), `ZC_CD_TRXREQ` (DCL), `ZUI_CD_TRX_REQ` (SRVD) | **cds/** | root / projection / DCL / SRVD | Request funnel |
| `ZCL_CD_TRX_REQ_CDS_TEST` | **cds/** | class (test holder, ADT) | §11 |

**Removed 2026-11-08** (they only served the 400-day driver, the "as of" history or counts of clean payments): `ZI_CD_PayOutcomeTs`, `ZI_CD_PayOutcomeAt`, `ZI_CD_PayOutcomeItm`, `ZI_CD_TrxItemFlow`, `ZI_CD_TrxItemBank`, `ZI_CD_TrxItemEnc`, `ZI_CD_TrxItemRet`, `ZI_CD_TrxItemNoc`; constant `GC_TRX_DASHBOARD-RETENTION_DAYS`, date kind `POSTING`.

## 10. VERIFY-ADT / VERIFY-SE11

| Item | Fallback |
|---|---|
| DPAYH key (LAUFD + LAUFI + DOC1R unique without proposal runs), XVORL, VALUT, HBKID, RWBTR, WAERS | Add the DPAYH key fields to the join of `ZI_CD_PayWorkItem` |
| T001-LAND1, TFK042Z key LAND1 + ZLSCH | Direction = UNKNOWN until fixed |
| VERIFY-ADT: HANA prunes the OR branches of `P_DateKind` (PlanViz, TXD-12) | One root view per date kind |
| VERIFY-ADT: `case … when … then cast( 'X' as abap_boolean )` for `IsToday` / `IsException` | A `char(1)` cast |
| DFKKRP-RLGRD, DFKKNRP-FLGRD, DFKKRP key | Remove the reason element |
| Two-field `pfcg_auth` (ZCD_PE_AREA, BUKRS); request rows with blank BUKRS | Area-only grant + BUKRS restriction in the role; grant blank BUKRS for request rows |
| `COUNT( DISTINCT )`, `$apply` on transactional_query | As the other dashboards |
| AML hold of a request (no SAP indicator known) | Open question - shown as `PRQ_NOT_IN_RUN` / `PRQ_PAYMENT_BLOCK` until a field is named |
| Part B placeholders (§4) | Activate part B only after SE11 |

## 11. Tests

`ZCL_CD_TRX_DASH_CDS_TEST` (`ltc_flow`, doubles of ZCD_PAY_OUTCOME, DPAYH, T001, TFK042Z, DFKKOP, DFKKRP, DFKKNRP): `current_rows_only`, `kind_and_worklist_date`, `date_kinds_select_rows`, `proposal_run_not_joined`, `direction_from_tfk042z`, `open_and_exception_counts`, `kpi_counts_distinct_fin`, `kpi_never_mixes_company`, `problems_are_exceptions`, `reasons_from_lot_items`, `no_partner_or_member_exposed`; shared fixtures (`ZCL_CD_OPS_PAY_FIXTURE`): `fixture_retrieval_no_row`, `fixture_line_inconsistent`, `fixture_two_sources_rows`.
`cds/ZCL_CD_TRX_REQ_CDS_TEST` (`ltc_request`, ADT after SE11): `success_row_wins_over_counter`, `errored_without_success_row`, `pending_without_outcome`, `member_number_not_exposed`, `success_older_than_window`, `retrieval_is_not_returned`, `fin_two_sources_ambiguous`, `one_row_per_company_code`.
The same fixtures run through the evaluator, A_INFLIGHT (`fixture_*`), the trace (`ltc_outcome`) and the snapshot: same data, same expected outcome.

## 12. QA1 cases

| ID | Case | Expected |
|---|---|---|
| TXD-01 | PCLM ACH disbursement: request → posting → payment run → 466 on the statement, DPAYH status CLEARED | Row IN_FLIGHT after the run → **row gone** after the status CLEARED (within one FAST interval); trace shows CLEARED |
| TXD-02 | Cheque payment, then 581 on the statement, register state B | IN_FLIGHT → row gone |
| TXD-03 | ACH return (466, 168, returns lot with RLGRD), status RETURNED | Row gone (RETURNED is final); `ReturnNoc` RETURN row with RLGRD |
| TXD-03a | ACH return, status job not run yet | Row IN_FLIGHT with `PAY_STATUS_PENDING` (exception), then gone with a closed history (purged after 90 days) |
| TXD-04 | NOC on a payment (DFKKNRP, INFOF with leading zeros) | `ReturnNoc` NOC row with FLGRD |
| TXD-05 | Payment open beyond RED of its class | Row with `PAYMENT_NOT_CLEARED` (E) after the NIGHTLY run at the latest; on the problems list |
| TXD-06 | Request due yesterday, item with payment lock | `REQ_NOT_PAID`, stage `PRQ_PAYMENT_BLOCK`; morning report A_PRQ_NOT_PAID RED |
| TXD-07 | Request received at 19:30 CST on its due day (cut-off 19:00) | Due the next business day; not overdue today |
| TXD-08 | Request paid one day late | Closing version `REQ_PAID_LATE` (history), row gone from the worklist |
| TXD-09 | User with ZCD_OPS CORE / 03 for US01 only | Only US01 rows and counts; request rows only with BUKRS blank granted |
| TXD-10 | FIN / payment document → *Payment trace* | Trace opens; trace outcome = row outcome |
| TXD-11 | Part B after SE11: SUCCESS 40 days ago, FAILED today | PROCESSED, never ERRORED |
| TXD-12 | ST05 / PlanViz at peak volume, each date kind | SELECT only; worklist by index; response < 5 s for chart and KPI; record plan |
| TXD-13 | Display role only | No write, no lock, no job |
| TXD-14 | Wire on the statement, DPAYH status not CLEARED | INCONSISTENT (problems list), A_INFLIGHT `CLEARING_INCONSISTENT` |
| TXD-15 | FIN with SUCCESS in two sources | One AMBIGUOUS row per source, finding `PAY_SOURCE_AMBIGUOUS` |
| TXD-16 | SWEEP over last week, source RETURNS | Only changed rows written; watermarks unchanged |
