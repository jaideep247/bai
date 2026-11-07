# Transactions dashboard — requests received and processed in SAP, live

> **First principle:** a transaction is only as far as the last record that proves it — each step (posted, paid, acknowledged, settled, returned) is shown only when its table holds the evidence, and a step whose table is not yet confirmed is shown as not yet available, never as zero.
> **Analogy:** a parcel tracking page — every scan has a place and a time; a scanner that is not installed yet leaves a visible gap in the route, not a "delivered".

Status 2026-11-06: written and statically checked offline (abaplint 0 issues for `src/`, and for the `cds/` request-side views in a separate lint copy). **Not activated in SAP, ABAP Unit not executed.** One of the four area dashboards of `Dashboard_Production_Support.md`.

## 1. Two parts — what lights up when

| Part | Where | Tables | Fields | Lights up |
|---|---|---|---|---|
| **A. SAP side** (service `ZUI_CD_TRX_DASH`) | `src/core` (abapGit) | DFKKOP, T001, TFK042Z, DPAYH, DFKKCR, FEBEP, DFKKRP (+ DFKKRK), DFKKNRP | Confirmed or standard (VERIFY-SE11 list §8) | **At the abapGit pull** (step 1e of `Implementation_Order.md`) |
| **B. Request side** (service `ZUI_CD_TRX_REQ`) | `cds/` (ADT only) | ZCD_PAYM_REQ_LOG, ZCD_ACH_ACK, ZCD_WIRE_ACK, ZCD_CHECK_HIST, ZCD_ACH_RTRV_LOG + part A | Unconfirmed custom-table fields as **VERIFY-SE11 placeholders** | **After SE11 confirmation**: replace the placeholders, activate in ADT (step 1e.6) |

Part A never references part B, so the pull can never fail on an unconfirmed field. Until part B is active:

| Tile / card | Before part B | After part B |
|---|---|---|
| Transactions by flow bucket, funnel posted → paid → settled, returned / reversed, open overdue, payment runs (live status), returns / NOC by reason | **Shown** (part A) | Shown |
| Requested, processed (SUCCESS row), errored, pending, not posted | Not shown — the card "Requests" is not configured | Shown (`PaymentRequest`) |
| Acknowledged / rejected (NACK) per payment | Not shown (the file-level ACK is in the file monitoring dashboard) | Shown |
| Cheque status returned / failed (ZCD_CHECK_HIST), ACH retrieval | Not shown (cheque **encashment** via FEBEP is shown in part A) | Shown |

## 2. What the support team sees (part A)

Fiori elements **analytical list page** (OData V4, main entity `Transaction`):

| Area | Content |
|---|---|
| Header | **Live** — computed at request time; no batch, no as-of (the page is as current as the tables) |
| Filter bar | FIN, company code, posting date, posted today, payment method, direction, payment status, return reason, flow bucket |
| Chart (default) | Transactions by **flow bucket**, stacked by payment method. Alternatives: funnel per posting date (transactions, paid, settled, returned); by company code and direction |
| Table | One row per payment-engine open item with a FIN number posted in the **last 31 days**: FIN (→ payment trace), document, company code, posting date, payment method, direction, amount, clearing document and date, payment status, return reason, bucket |
| Object page | Item; evidence (last payment run date / ID, DPAYH status, cheque number and house bank, settlement / encashment date, return reason, NOC reason); **Payment runs** (DPAYH rows of the payment document); **Returns / NOC lot items** |
| Entity `PaymentRun` | DPAYH rows of 45 days by run date and **ZZ_PAYMENT_STATUS** (live status) |
| Entity `ReturnNoc` | Returns (DFKKRP-**RLGRD**) and NOCs (DFKKNRP-**FLGRD**) by reason, drill to the lot item |

## 3. Flow bucket and funnel

| Bucket (terminal first) | Evidence | Join (confirmed unless marked) |
|---|---|---|
| RETURNED | Returns lot item | DFKKRP-SELW1 = DFKKOP-AUGBL |
| REVERSED | Clearing reason 05 — the only reversal reason (user 2026-11-07); literal in CDS, equal to `ZIF_CD_OPS_TRACE_TYPES=>GC_REVERSAL_AUGRD` (parity check `cds_abap_parity`) | DFKKOP-AUGRD (VERIFY-SE11) |
| SETTLED | Bank line on the payment document (methods E G H I J K L) or on the cheque number (method C, encashment) | FEBEP-CHECT = AUGBL; DFKKCR-DOC1R = AUGBL and FEBEP-CHECT = DFKKCR-ZTNUM |
| PAID | Payment run row (not a proposal run) or cheque | DPAYH-DOC1R = AUGBL (XVORL VERIFY-SE11); DFKKCR-DOC1R = AUGBL |
| CLEARED | Clearing document without payment evidence in the window (e.g. cleared by offset, or the run is older than 45 days) | DFKKOP-AUGBL |
| POSTED | Open (no clearing document) | — |

**Reached** measures count every step an item got to (`PaidReachedCount` includes settled and returned). **Direction** = TFK042Z-XEINZ (X collection, else disbursement; no payment method = NONE, method not in TFK042Z = UNKNOWN). **Errored / stuck** (`TransactionProblem`): RETURNED, REVERSED, and disbursements still **OPEN_OVERDUE** (posted before yesterday, not cleared — hourly disbursement runs should have paid them). Literals: buckets, `05`, the 1-day overdue rule.

**File generated** is not a per-transaction step here: the link payment → file needs `ZCDT_REGUT` (unconfirmed, `Payment_Trace.md` §9). File counts per day are in the file monitoring dashboard; the overview page shows both side by side.

**Line of business:** DFKKOP carries none and the request log's LOB field is not confirmed — LOB is **not** a dimension (source system is, in part B). Proposed: add it to `ZI_CD_TrxReqLog` once SE11 shows the field.

## 4. Request side (part B, cds/)

`ZR_CD_TrxReqFlow`: one row per payment request (FIN + source, last 31 days) with **RequestStage**: ERRORED, PENDING, NOT_POSTED, RETURNED (returns lot, retrieval, cheque status 9), REJECTED (NACK, cheque status 3 / 4), REVERSED, SETTLED, ACKNOWLEDGED, PAID, POSTED, CLEARED. **SUCCESS row rule** (`ZI_CD_TrxRequest`): a request is processed when **any** attempt has ZZ_STATUS = SUCCESS — never by the highest COUNTER (a failed retry after the success never downgrades it). Cheque status: terminal 3 / 4 / 9, mailed 10 (→ 9 allowed) — as flags, because the status text does not sort numerically. The FIN is matched to DFKKOP without the source (DFKKOP has no source field); the payment trace resolves FIN + source.

Placeholders (replace from SE11 before activation): request log FIN field `zz_fin_trans_num`, request date `zz_created_on`, failure values of ZZ_STATUS; ACK tables payment key `zz_augbl`, status `zz_ack_status`, date `zz_ack_date`; cheque history `zz_check_no`, `zz_check_status`; retrieval log status `zz_rtrvl_status` (candidates ZZ_RTRVL_STATUS / ZZ_RTRV_STATUS / ZZRETRIEVAL_STATUS).

## 5. Tiles, KPI and overview-page cards

| Tile | Request | Red when |
|---|---|---|
| Returned today | `TransactionKpi?$filter=IsToday eq true&$select=ReturnedCount` | > 0 |
| Overdue open disbursements | `TransactionProblem/$count?$filter=ProblemType eq 'OPEN_OVERDUE'` | ≥ 1 |
| Errored requests (part B) | `PaymentRequest/$count?$filter=RequestStage eq 'ERRORED'` on `ZUI_CD_TRX_REQ_O4` | ≥ 1 |
| Transactions dashboard (app tile) | Semantic object `ZCDTransaction`, action `analyze` | — |

**KPI entity `TransactionKpi`** (`ZC_CD_TrxKpi`): per posting date × company code × direction — transactions, distinct FIN numbers, paid / settled reached, returned, reversed, open, with NOC, per bucket, day criticality; chart `Funnel`, selection variant `Today`, data points `Transactions`, `Paid`, `Settled`, `Returned`, `Open`. **List entity `TransactionProblem`**: errored / stuck, newest first, `maxItems` 10.

## 6. Drill-down and payment trace

Bucket (chart) → list of transactions → object page → payment runs / returns and NOC lot items → **payment trace**. FIN numbers carry `@Consumption.semanticObject: 'ZCDPaymentTrace'` with an intent-based navigation button (action `display`). The trace (`ZCD_OPS_PAYMENT_TRACE`, `Payment_Trace.md`) accepts **FIN + source** (`P_FIN`, `P_SRC`) or a clearing document (`P_AUGBL`). **Proposed, not built:** transaction code for the report (e.g. `ZCD_TRACE`, SE93, with the selection-screen parameters) and the target mapping `ZCDPaymentTrace-display` → that transaction, parameter mapping `FinId` → `P_FIN`, `SourceSystem` → `P_SRC` (part B only), `ClearingDoc` → `P_AUGBL`. Without the target mapping the button stays hidden; L2 copies the FIN.

## 7. Performance, bounds and sensitive data

- **Bounded live reads:** open items by **BUDAT ≥ today − 30** and **FIN not blank** (driver of every view); DPAYH rows, FEBEP lines by LAUFD / BUDAT ≥ today − 45; DFKKCR, DFKKRP, DFKKNRP only joined **from** the bounded item set (never aggregated on their own). Aggregation is pushed down (`group by` in CDS, `$apply`).
- **Indexes VERIFY-SE11:** listed with all other index checks in `Performance_Review.md` §8 (DFKKOP-BUDAT / ZZ_FIN_TRANS_NUM, FEBEP-CHECT, DPAYH-DOC1R, DFKKCR-DOC1R, DFKKRP-SELW1, DFKKNRP-INFOF). On HANA the date predicate is a column scan; record ST05 / PlanViz at peak in QA1 (TXD-12).
- Older transactions: the payment trace (per FIN), not the dashboard.
- **No member number, business partner, contract account or bank account** is selected (test `no_partner_or_member_exposed`); the request side never selects ZZ_MEMBER_NO. FIN numbers and document numbers are shown (needed for the trace).
- Amounts: signed as stored (BETRW in WAERS, BETRH in the company code currency); aggregate per currency and direction.

## 8. Authorisation

Area **CORE** with **company code**: `pfcg_auth( ZCD_OPS, ZCD_PE_AREA, BUKRS, ACTVT = '03' )` on transactions, KPI, problems, returns / NOC (DCL `ZC_CD_TRXDASH`); payment run rows by area only. Decision and reason: `config/auth_zcd_ops.md` §3a (same area as the payment trace, which shows the same evidence per FIN; no new domain value).

## 9. Objects

| Object | Folder | Type | Role |
|---|---|---|---|
| `ZI_CD_TrxItem` | src/core | view | Driver: DFKKOP with FIN, 31 days, + T001, TFK042Z |
| `ZI_CD_TrxItemPay`, `…Chq`, `…Bank`, `…Enc`, `…Ret`, `…Noc` | src/core | views (grouped per item) | Payment run, cheque, bank line, cheque encashment, return, NOC per item |
| `ZI_CD_ReturnItem`, `ZI_CD_NocItem` | src/core | views | DFKKRP (RLGRD) / DFKKNRP (FLGRD, normalised INFOF), shared with EBS |
| `ZI_CD_TrxRetNocU` | src/core | view (UNION) | Item × lot items |
| `ZR_CD_TrxFlow` / `ZC_` | src/core | root / projection (ALP) | Transactions, bucket, measures, associations |
| `ZR_CD_TrxPayRun`, `ZR_CD_TrxRetNoc`, `ZR_CD_TrxKpi`, `ZR_CD_TrxProblem` (+ `ZC_`) | src/core | roots / projections | Payment runs, returns / NOC, KPI, errored / stuck |
| 5 metadata extensions `ZC_CD_TRX*` | src/core | DDLX | UI |
| `ZC_CD_TRXDASH` | src/core | DCL | CORE + BUKRS |
| `ZUI_CD_TRX_DASH` | src/core | SRVD | `Transaction`, `PaymentRun`, `ReturnNoc`, `TransactionKpi`, `TransactionProblem` |
| `ZCL_CD_TRX_DASH_CDS_TEST` | src/core | class (test holder) | §11 |
| `ZI_CD_TrxReqLog`, `ZI_CD_TrxRequest`, `ZI_CD_TrxAckU`, `ZI_CD_TrxAck`, `ZI_CD_TrxChqStat`, `ZI_CD_TrxRtrv`, `ZI_CD_TrxFinFlow` | **cds/** | views | Request side with placeholders |
| `ZR_CD_TrxReqFlow` / `ZC_CD_TrxReqFlow` (+ DDLX), `ZC_CD_TRXREQ` (DCL), `ZUI_CD_TRX_REQ` (SRVD) | **cds/** | root / projection / DCL / SRVD | Request funnel |
| `ZCL_CD_TRX_REQ_CDS_TEST` | **cds/** | class (test holder, ADT) | SUCCESS row rule |

## 10. VERIFY-ADT / VERIFY-SE11

| Item | Fallback |
|---|---|
| DFKKOP OPUPW / OPUPK / OPUPZ / PYMET / AUGST / AUGRD / AUGDT / BETRW / BETRH, T001-LAND1 / WAERS, TFK042Z key LAND1 + ZLSCH | Fields as `ZCL_CD_OPS_TRACE_DAO`; if TFK042Z has another key, Direction = UNKNOWN until fixed |
| DPAYH XVORL and key (LAUFD + LAUFI + DOC1R unique?) | Add the DPAYH key fields to `ZR_CD_TrxPayRun` |
| DFKKRP-RLGRD, DFKKNRP-FLGRD, DFKKRP key | Remove the reason element (bucket stays) |
| `LTRIM` normalisation of AUGBL / INFOF; INFOF holding a payment reference instead of AUGBL | Extend `ZI_CD_NocItem` with the reference format once known |
| Two-field `pfcg_auth` (ZCD_PE_AREA, BUKRS) | Area-only grant + BUKRS restriction in the role |
| `COUNT( DISTINCT )`, UNION, `$apply` on transactional_query | As the other dashboards |
| Part B placeholders (§4) | Activate part B only after SE11 |

## 11. Tests

`ZCL_CD_TRX_DASH_CDS_TEST` (`ltc_flow`, doubles of DFKKOP, T001, TFK042Z, DPAYH, DFKKCR, FEBEP, DFKKRP, DFKKRK, DFKKNRP): `bucket_follows_evidence`, `proposal_run_is_not_payment`, `window_and_fin_bound_rows`, `direction_from_tfk042z`, `kpi_counts_distinct_fin`, `problems_list_errored_stuck`, `reasons_from_lot_items`, `no_partner_or_member_exposed`.
`cds/ZCL_CD_TRX_REQ_CDS_TEST` (`ltc_request`, ADT after SE11): `success_row_wins_over_counter`, `errored_without_success_row`, `pending_without_outcome`, `member_number_not_exposed`.

## 12. QA1 cases

| ID | Case | Expected |
|---|---|---|
| TXD-01 | PCLM ACH disbursement: request → posting → payment run → bank line | Buckets POSTED → PAID → SETTLED across refreshes; DPAYH status shown |
| TXD-02 | Cheque payment, then encashment on the bank statement | PAID (cheque) → SETTLED (FEBEP-CHECT = ZTNUM) |
| TXD-03 | ACH return (returns lot with RLGRD) | RETURNED; reason = DFKKRP-RLGRD; `ReturnNoc` row; problems list |
| TXD-04 | NOC on a payment (DFKKNRP, INFOF with leading zeros) | `ReturnNoc` NOC row with FLGRD; bucket unchanged |
| TXD-05 | Reversal (clearing reason 05) | REVERSED |
| TXD-06 | Disbursement posted 2 days ago, not paid | OPEN_OVERDUE in the problems list |
| TXD-07 | Proposal run only (XVORL) | Not PAID |
| TXD-08 | Item without FIN; item posted 40 days ago | Not listed |
| TXD-09 | User with ZCD_OPS CORE / 03 for US01 only | Only US01 rows; payment run rows visible (area only) |
| TXD-10 | FIN → *Payment trace* (after the target mapping) | Trace opens with the FIN (and source in part B) |
| TXD-11 | Part B after SE11: a request with SUCCESS at counter 1 and FAILED at counter 2 | PROCESSED, never ERRORED; tile *Errored requests* unchanged |
| TXD-12 | ST05 / PlanViz at peak volume (31 days) | SELECT only; DFKKOP read by BUDAT + FIN; response < 5 s for chart and KPI; record plan |
| TXD-13 | Display role only | No write, no lock, no job |
