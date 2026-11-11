# What the offline checks cannot prove - the suite's own items

> **First principle:** an item that names a customer's table, field, middleware, bank or scheduler belongs to that customer's delivery, not to the reusable product; the product's list keeps only what every customer must confirm.
> **Analogy:** the car maker's inspection sheet covers the car; the fleet owner's sheet covers its own fittings - the company logo, the radio, the toll tag.

The rows below were moved on 2026-11-11 from the framework's list `ops-framework/docs/VERIFY.md` (customer-neutral product: the framework names no customer object). **IDs are unchanged and never reused**; the framework keeps V01-V43, V46-V54, V57-V66, V70-V79, V94-V99, V110-V114 and V116-V120 (link registry, 2026-11-11). Nothing activated; every row is open. Confirm each item in DV1 / QA1 and record the evidence in the release pack (`Release_Readiness.md`).

## 1. Where the suite's VERIFY items are

| IDs | Topic | Where |
|---|---|---|
| V44, V45 | Company-code isolation (FMON design guard), control proposal P1 | `Release_Readiness.md` |
| V55, V56 | Process onboarding check in the morning report; the example process before activation | `Release_Readiness.md` |
| V67-V69 | SAP job monitor: mass activity workers, payment run, Control-M rows | `Release_Readiness.md` |
| V80, V81 | Operations response features: runbook rows, overview page cards | `Release_Readiness.md` |
| **V82-V93** | **Service health, process flow, missing-volume checks, payment model mapping (build B)** | **this document, §2** |
| V100-V109, V115 | Ledger drill-down, group reconciliation, document changes (build C); V115 released views of the G/L side (D-C8 changed 2026-11-11) | `USAA_Known_Tables.md` §4 |
| V121, V122 | Link registry overlay: the overlay's VERIFY / placeholder fields, parity of the trace and file monitor link definitions with the registry (2026-11-11) | `Link_Registry_Overlay.md` §5 |
| **V123** | **Released views for the suite's G/L / company code reads outside the ledger model (D-C8 extended 2026-11-11)** | **this document, §3** |
| V139-V141, V144 | Build F: break analysis overlay - assignment carries the payment document (overlay links), bank transaction code lists, accounts of the reconciliation sets and PlanViz on the busiest account; pilot baselines and export path (2026-11-11) | `Break_Analysis_Overlay.md` §6 |
| V130, V131 | Process catalogue customer layer: the customer process's table and programs, approval of the activation proposal and the order of the catalogue rows before `CAT_PROCESS` (2026-11-11) | `Process_Catalogue_Overlay.md` §4 |

## 2. Build B (2026-11-11) - service health, process flow, missing-volume checks, payment model mapping

The framework's payment model product layer (contract, templates, generator) is verified by the framework's V94-V99; the rows here are the suite's mapping (`config/payment_model/mapping.json`), its helper views and its own checks.

| ID | Kind | Item |
|---|---|---|
| V82 | VERIFY-SE11 | `ZCD_PAYM_REQ_LOG`: FIN-number field, received date / time stamp, company code, currency and amount fields - names for the pending request / attempt adapters of the payment model (the suite's `config/payment_model/mapping.json`, sections `request`, `request_attempt`); then status `active` and regenerate |
| V83 | VERIFY-SE11 | `ZCD_PAYM_REQ_LOG` transaction field (the field exists - user 2026-11-11; name and values / texts): mapping `TransactionType`, dimension texts `TRANSACTION` in `ZCA_OPS_PMDIM`, volume rows grouped by it |
| V84 | VERIFY-SE11 | Business request lifecycle status (PENDING / SCHEDULED / SRCPOSTED / source reject): table and field (control_seed.md section 2a P2) - mapping `RequestStatus` stays blank until named |
| V85 | VERIFY-SE11 | Received date (DATS) and time (TIMS) of `ZCD_PAYM_REQ_LOG` for `B_VOL_PRQ` (inactive) and its hour bands; index for the day read (with pre-check 0.8) |
| V86 | VERIFY (Control-M) | Payment run ID convention per day-part (LAUFI) for the day-part rows of `B_VOL_PAYRUN` |
| V87 | VERIFY-SE11 | DPAYH-HKTID (house bank account ID) - mapping `HouseBankAccount` blank until confirmed; FEBKO-HBKID / HKTID for `B_VOL_STMT` |
| V88 | VERIFY-SE11 / PlanViz | DFKKOP secondary index on AUGBL (payment -> requests of the payment page) and the index of pre-check 0.8 on ZZ_FIN_TRANS_NUM (request -> payments); DFKKOP-BUKRS |
| V89 | VERIFY-SE11 / business | Feeder business reference field (claim / policy / invoice) of the request log, its sensitivity (masked by default) and the feeder URL templates (`ZCA_OPS_FEEDER`) |
| V90 | VERIFY-SE11 | Timeline hops of a request: link request -> PRISM file / message (FMON event), `ZCD_SPE_EXCP_LOG` fields of the status sent back - union view `ZI_CD_PaymHops` before the `request_event` section can be active |
| V91 | VERIFY-ADT | Service health CDS (`ZI_CD_SvcRule` UNION ALL, `ZI_CD_SvcFind` OR in the ON condition, `ZI_CD_SvcSlice` CROSS JOIN + UNION, `ZR_CD_SvcHealth` arithmetic in CASE) and process flow CDS (`>=` / `<` in ON conditions, `dats_days_between` with the session date); ABAP Unit `ZCL_CD_OPS_SVC_CDS_TEST` (4 methods) |
| V92 | ABAP Unit | Seasonal baseline: `ZCL_CD_HCK_THRESHOLD` (`weekday_season_steps_weeks`, `day_season_steps_days`, `season_needs_a_day_series`), `ZCL_CD_HCK_DAO` (`season_latest_point_per_day`: range on DIM2 inside a CTE with ROW_NUMBER, 7.58), `ZCL_CD_HCK_ENGINE` (`volume_below_same_weekday`) |
| V93 | VERIFY-ADT / PlanViz | Payment model of the suite: `ZI_CD_PayMethodCls` over TFK033D with the parameter tables (`ZI_CD_PostAreaCfg`, MAX of CASE), `ZI_CD_PaymFact` on a 2 million payment day (DPAYH key range LAUFD + worklist by AUGBL), `ZR_CD_PaymCube` / `ZR_CD_PaymTrend` response time < 5 s; ABAP Unit `ZCL_CD_PAYM_CDS_TEST` |

The suite-specific parts of the framework's product rows: the custom process-flow card of V97 is the suite's `ui/cards/processflow`; the intents of V98 are the suite's `ZCDPaymentTrace-display` and `ZCDJobFailure-display` (job app of build J, placeholder until merged); the binding of V99 is `ZUI_CD_PAYM_O4`.

## 3. G/L and company code reads of the suite on released views (D-C8 extended, 2026-11-11)

Decision D-C8 (`Dashboard_Production_Support.md` §9b) now covers every G/L / company code read of the suite, not only the ledger model. The reads that moved, the reads kept on the tables and their pre-checks: `Performance_Review.md` §14.

| ID | Kind | Item |
|---|---|---|
| V123 | VERIFY-ADT / QA1 / PlanViz / ABAP Unit | (a) **Release state C1** on S/4HANA 2023 (7.58) of `I_CompanyCode`, `I_JournalEntry`, `I_OperationalAcctgDocItem`, `I_JournalEntryItem`, and the **element names** the suite's helper views read: `I_CompanyCode` CompanyCode, Country, Currency (= T001 BUKRS, LAND1, WAERS); `I_JournalEntry` CompanyCode, FiscalYear, AccountingDocument, ReferenceDocumentType, OriginalReferenceDocument, PostingDate, AccountingDocumentCreationDate, CreationTime, ReverseDocument (= BKPF AWTYP, AWKEY, BUDAT, CPUDT, CPUTM, STBLG - as V110); `I_OperationalAcctgDocItem` CompanyCode, AccountingDocument, FiscalYear, AccountingDocumentItem, GLAccount, **Reference2IDByBusinessPartner** (= BSEG-XREF2), **ClearingAccountingDocument** (= AUGBL), ClearingDate (= AUGDT); `I_JournalEntryItem` SourceLedger, Ledger, CompanyCode, FiscalYear, AccountingDocument, LedgerGLLineItem, GLAccount, PostingDate, **BalanceTransactionCurrency** / **AmountInBalanceTransacCrcy** (= ACDOCA RTCUR / TSL). Fallback if an element is missing or named differently: rename it in the helper view only (`ZI_CD_OpsCompanyCode`, `ZI_CD_OpsJrnlEntry`, `ZI_CD_OpsGlItem`, `ZI_CD_EbsGlLine` - the DAOs read the helper's names); if XREF2 or the balance transaction currency pair is not exposed on the release, `ZCL_CD_OPS_TRACE_DAO=>GET_GL_CLEARING_LINES` / `ZCL_CD_EBS_SAP_DAO=>GET_GL_BALANCES` go back to the table read (the SQL before 2026-11-11, git history) - never a substitute field (the transaction currency pair WSL / RWCUR is a different amount). (b) **Same rows as the tables** (QA1, old statement vs new on the same keys / window): every BKPF row is a row of `I_JournalEntry`, every BSEG line of a document a row of `I_OperationalAcctgDocItem` (no filter on document status or line type), the bank G/L balance per closing statement equal to the ACDOCA sum (also over balance carry-forward and archived / extracted periods of the bank account), the A_GL_TRANSFER gap count equal, the method direction (TFK042Z via the company code's country) equal. (c) **No DCL evaluated**: the four helper views have `#NOT_REQUIRED`; a job user without `F_BKPF_BUK` reads the same rows; the CDS views `ZI_CD_PayWorkItem` / `ZI_CD_TrxItem` join `I_CompanyCode` directly and their consumers keep their own DCL. (d) **PlanViz GLV-PV1 ... GLV-PV6** (`Performance_Review.md` §14) before gate 2. (e) **ABAP Unit**: the OSQL tests on the helper-view doubles - `ZCL_CD_EBS_SAP_DAO` (`gl_balances_per_request`, `fi_lines_by_document_key`), `ZCL_CD_HCK_DAO` (`gl_gap_per_company_and_type`), `ZCL_CD_HCK_RUNTIME_DAO` (`payments_window_and_flow`, `payments_by_document_all_runs`), `ZCL_CD_OPS_PAY_OUTCOME_DAO` (company code double of the versions / groups / examples / rows reads), `ZCL_CD_OPS_TRACE_DAO` (`gl_document_by_awtyp_awkey`, `gl_line_by_key_and_xref2`, `method_kind_from_tfk042z`); the CDS tests `ZCL_CD_TRX_DASH_CDS_TEST` / `ZCL_CD_TRX_REQ_CDS_TEST` with base dependencies (T001 is the base table under `I_CompanyCode` - if the release's `I_CompanyCode` inner-joins another table, add its row or double `I_COMPANYCODE`). (f) **ATC clean-core**: the reads kept on tables (`Performance_Review.md` §14: XREF2 search, GL watermark, clearing-document search, the three reconciliation assignment reads) and the subledger tables are accepted findings with the recorded reason |
