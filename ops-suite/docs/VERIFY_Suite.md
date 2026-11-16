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
| V150-V152 | Build G: account flow overlay - accounts of the flows by role, values of the stage rules, findings area of the morning report's checks and PlanViz on the busiest account (2026-11-15) | `Account_Flow_Overlay.md` §4 |
| V158 | Build H: customer extensions - the pack's generated extensions of the framework views activate from `src/ext` (worklist state of the payment next to the break groups, query copy), PlanViz of the break list with the association (2026-11-15) | `Extensions_Overlay.md` §4 |
| **V159-V161** (V159, V160 closed) | **Fields the suite's code reads that the reference system does not have (2026-11-15, build I)** | **this document, §4; `ddic/open_fields.csv`** |
| V169 | Build J: licensing - the installation numbers and SIDs of DV1 / QA1 / PS4 sent to the vendor, the vendor's licence installed per system, the modules the suite uses licensed, a module outside the licence refused in QA1 under `X` while the suite's own engines run (2026-11-15) | `Licensing_Overlay.md` §4 |
| **V240-V258** | **Build R: pilot acceptance items of the first customer's five open daily controls - ECT pending, BlackLine extracts, base-rejected items, missing check IDs, returns notification (2026-11-16)** | **this document, §5; `Pilot_Acceptance.md`** |
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
| V87 | VERIFY-SE11 | DPAYH-HKTID (house bank account ID) - mapping `HouseBankAccount` blank until confirmed; FEBKO-HBKID / HKTID for `B_VOL_STMT`. **2026-11-15:** all three fields exist on the reference system S/4HANA 2025, `ddic/a4h`; open: the element of `ZI_CD_PayLifeRun` for HKTID (then map `HouseBankAccount`) |
| V88 | VERIFY-SE11 / PlanViz | DFKKOP secondary index on AUGBL (payment -> requests of the payment page) and the index of pre-check 0.8 on ZZ_FIN_TRANS_NUM (request -> payments); DFKKOP-BUKRS. **2026-11-15:** index HTH on AUGBL and DFKKOP-BUKRS on the reference system S/4HANA 2025, `ddic/a4h`; ZZ_FIN_TRANS_NUM is a customer field (pre-check 0.8 stays) |
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

## 4. Build I (2026-11-15) - field references checked against the reference system

Evidence: the dictionary of 46 SAP standard tables of a reference system (S/4HANA 2025 with FI-CA, client 100) in
`ddic/a4h` (`<T>.fields.csv` DD03L with includes and appends, `<T>.indexes.csv` DD17S). The target release is
S/4HANA 2023: a field present there is used and noted as *seen on the reference system*; a field missing there is
treated as wrong. `tools/abaptools/ddic_export.py compare` now also scans the code (ABAP SQL, typed structures, CDS) -
the check `ddic_fields` of `tools/portable_checks.py` runs it over every export folder of `ddic/`.

**Fixed (2026-11-15):** DPAYH has no `BUKRS` / `PYMET` - the paying company code is `BBUKR` (`BUKRS_PAY`) and the
payment method `RZAWE` (`PYMET_KK`): DAOs of core / hck (`ZCL_CD_OPS_PAY_OUTCOME_DAO`, `ZCL_CD_JOB_DAO`,
`ZCL_CD_HCK_RUNTIME_DAO`, `_RECON_DAO`, `_DOCCHG_DAO`), CDS `ZI_CD_PayLifeRun` / `ZI_CD_PayWorkItem` (and through them
the payment model), test doubles, `config/hck_seed.md` `B_VOL_PAYRUN`. `DFKKSUMC` is the reconciliation key and its
status; the totals per company code, account and currency are `DFKKSUM` (signed by `SHKZG`): `ZCL_CD_HCK_DAO` (G/L
transfer gaps), `ZCL_CD_HCK_RECON_DAO=>GET_FICA_DAYS`, `ZCL_CD_OPS_TRACE_DAO=>GET_SUMMARY_KEYS`, the batch adapter
`ZI_CD_LedgBatch` (mapping `ledger_batch`), message 732. `DFKKRK` (returns lot) is joined on its key `KEYR1`, not on
`OPBEL` (`ZCL_CD_EBS_SAP_DAO=>GET_RETURN_ITEMS`, `ZI_CD_ReturnItem`). Test doubles of DPAYH set the key field `PAYNO`
(they set `PYORD` / `PYKEY`, which DPAYH does not have). `TFK033D-FUN08` is no longer read.

| ID | Kind | Item |
|---|---|---|
| V159 | Closed 2026-11-15 | `DFKKCR` has no `CRSTATUS` (user, 2026-11-15; also absent on the reference system). The cheque status is `DFKKCR-STATE` (`CHKSTATE`, CHAR 1: B cashed, V voided, blank open - user 2026-11-07): `ZCL_CD_EBS_SAP_DAO`, `ZCL_CD_OPS_TRACE_DAO` and the trace engine read it; rule R07C forbids `V` by default (legacy 255D: status 99 = cancelled), BTC rule `BAI255D` PARAM1 `V`. |
| V160 | Closed 2026-11-15 | The returned amount of a returns lot item is `DFKKRP-BETRR` (`BETRR_KK`, currency `WAERS`; user, 2026-11-15) - `DFKKRP` has no `BETRW`. Read by `ZCL_CD_EBS_SAP_DAO=>GET_RETURN_ITEMS` for the morning report check `A_INFLIGHT` and the payment trace. |
| V161 | VERIFY-SE11 / design | `TFK033D` has `FUN01`-`FUN06` (CHAR 12) only - the ZBTM layout has 7 results (`FUN07` = DISPOSITION, audit A26); keys and results are CHAR 12, shorter than the layouts of `FICA_Posting_Areas.md` assume. Decide the ZBTM layout (e.g. disposition combined with another result, or kept in a parameter) before gate 1; `ZCL_CD_OPS_POSTAREA_DAO` reads `FUN07` until then |

The three stay read in the code and are listed in `ddic/open_fields.csv`, so the comparison names them instead of
failing; they block the activation of the reading class in a system without the field. Other facts of the reference
system (index lists, the sign of `DFKKSUM-BETRW`, field lengths) are recorded where the items live:
`Performance_Review.md` §17, `USAA_Known_Tables.md` V101 / V102 / V107 / V108, `Release_Readiness.md`,
`HCK_MORNING_REPORT.md` §15, `Payment_Trace.md` §9, `FICA_Posting_Areas.md`.

## 5. Build R (2026-11-16) - pilot acceptance items of the first customer's daily controls

Answer to finding 5 of the product review (`docs/Pilot_Acceptance.md`). Every check is built and delivered inactive;
each row is the fact still open and who answers it. A row is closed only with the answer recorded in the release pack.

| ID | Kind | Item |
|---|---|---|
| V240 | Business | `ECT_PENDING`: the `ZECT_STATUS` values that mean *pending* (sent to IRIS, not yet mailed; status 1?), written exactly as stored (leading zeros) - PARAM2 `PENDING=` of `C_ECT_PENDING`. Payment operations (disbursements) with the IRIS / PRISM owner |
| V241 | VERIFY-SE11 | `ZCD_CHECK_HIST`: the cheque number field (= `DFKKCR-ZTNUM`, padding as on the register), the status field, the date and time of the status change; one row per cheque or per change (both are read correctly: latest by date / time) - PARAM1 of `C_ECT_PENDING` |
| V242 | Business | `ECT_PENDING`: amber / red limits of `ECT_PENDING` (count) and `ECT_PENDING_AGE` (days; red = the deadline of a pending cheque); `DAYS` (180) covers the oldest pending cheque that matters - an older one is not seen |
| V243 | Business | `MISSING_CHECK_IDS`: a *missing check ID* is a cheque payment of a run without a cheque number on the register (not a health check that did not run). The reference system's test tool treats a run payment without `DFKKCR` row as an error; the business meaning stays the user's answer |
| V244 | VERIFY / configuration | `MISSING_CHECK_IDS`: the cheque payment methods (`DPAYH-RZAWE`; the CHQ class of posting area ZPMC is the likely list) - PARAM1 `METHODS=` of `C_CHQ_NO_ID` |
| V245 | Business | `MISSING_CHECK_IDS`: when a cheque number is due - the print run of the run day, so the runs of the day before the review (`OFFSET=1`, `DAYS=1`) |
| V246 | PlanViz / ST05 | `DFKKCR` has no index on `ZTNUM` alone, `DOC1R` or `LAUFD` on the reference system: the register read of `C_ECT_PENDING` (by cheque number) and the anti-join of `C_CHQ_NO_ID` (DPAYH run-date window, `ZCL_CD_HCK_CHEQUE_DAO`) on the busiest run day in QA1 |
| V247 | VERIFY / interface | BlackLine: how the extracts of `ZCD_FI_BLACKLINE_EXTRACT_COLL` and `ZCD_BLACKLINE_RECON` are evidenced (PRISM status event with interface ID / file name, or a log table as an FMON source) and their file name patterns - rows `BLACKLINE_COLL_OUT`, `BLACKLINE_DISB_OUT` |
| V248 | Business | BlackLine: the due time on the 2nd business day and the factory calendar (`CAL=` of `F_BLKLINE`); whether an extract may legitimately be empty (no postings in the month) |
| V249 | QA1 | BlackLine: `FMON_LOOKBACK_DAYS` covers the days from the 1st of the month to the 2nd business day (an extract generated early counts); the operator closes a due-file exception once the file is in (outside the reconciliation scope of the 5-minute run) |
| V250 | VERIFY-SE11 | `BASE_REJECTS`: the request status table and its fields - request key, company code, status, date and time of the change, amount - and the value of a source reject; one row per request or per change (`COLL_SRC_REQUEST`, `COLL_REJECT_VALUE`; aggregate rows R1 / R4) |
| V251 | VERIFY-SE11 | `BASE_REJECTS`: SAP's Stripe refund log - key back to the request, status field, success and failure values, time stamp (`COLL_SRC_REFUND`, `COLL_REFUND_OK`, `COLL_REFUND_FAILED`) |
| V252 | Business | `BASE_REJECTS`: hours for R2 and R3 (`COLL_R2_*_H`, `COLL_R3_*_H`), the currency of the request amounts (`COLL_CURRENCY`), and that the change date / time are local time (`FMON_TIME_ZONE`) |
| V253 | Configuration | `BASE_REJECTS`: area `CD_COLL`, role `Z_CD_OPS_COLL`, SO23 list of rule `COLL_LIFE`, `ZCD_OPS_TABWL` rows FMON / SOURCE for the status table and the refund log (read through the configured-source reader), `S_TABU_NAM` of the job user |
| V254 | Business | `RETURNS_NOTIF`: how the source (PCLM, DIS) is told about a return / NOC - an outbound file, the payment status update runs to the source (`PSU_PCLM`, `PSU_DIS`; **do these runs report returns?**), or a status row of the request log |
| V255 | VERIFY / interface | `RETURNS_NOTIF`: for a file - name pattern, evidence source, due time (`RETURNS_NOTIF_OUT`, `F_RETNOTIF`); for the PSU runs - job names and window of the job-cycle step |
| V256 | ABAP Unit (DV1) | `ltc_ect_pending`, `ltc_chq_no_id`, `ltc_cheque_dao` (OSQL), `ltc_exposure`, `ltc_due_file`, `ltc_check` of `ZCL_CD_COLL_C_NO_ANSWER` / `_C_REFUND` - doubles only, offline |
| V257 | QA1 | The tests ECT-1/2, BL-1/2/3, BR-1/2, MC-1, RN-1/2/3 of `Pilot_Acceptance.md` with their expected results |
| V258 | QA1 | *Not evaluated* is never green: a check with a placeholder left (HCK `PLUGIN_ERROR`, runner `CHECK_FAILED`, FMON `DUE_FILE_NOT_EVALUATED`) leaves a finding under the control's check, so the daily review never shows the control *Healthy* (the framework-wide evaluation state of build O shows it as *not evaluated* once merged) |
