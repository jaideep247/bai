*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_payout_types.intf.abap
*& Purpose:
*& Types and constants of the canonical payment outcome: the outcome
*& values every consumer shows (morning report check A_INFLIGHT, payment
*& trace, transactions dashboard), the verdict of one payment with its
*& deciding evidence and finding, the evaluation of a set of payments, the
*& source attribution of a FIN number, the evidence sources of the
*& incremental 5-minute snapshot with their watermarks, the open end of a
*& version (ZCD_PAY_OUTCOME-VALID_TO), parameters, check codes and message
*& numbers. Read-only towards business tables: nothing here posts.
*& Modification log:
*& 2026-11-07 | Initial version (one canonical payment outcome model).
*& 2026-11-08 | Verdict STATUS_PENDING (bank evidence decides, the payment status job has not caught up:
*&            | in flight) and EVIDENCE_DATE (basis of the morning report's status-lag finding).
*& 2026-11-08 | Table consolidation: TY_CONFIG-BANKS are the house-bank rows of ZCD_HCK_PMCLASS
*&            | (ZCD_HCK_PMBANK merged).
*& 2026-11-08 | TT_OUTCOME_RANGE: the final outcomes (ZCL_CD_OPS_PAY_OUTCOME=>FINAL_OUTCOMES) as a range
*&            | for the recheck, the purge and A_INFLIGHT.
*& 2026-11-08 | Scale (2 million payments a peak day): parallel snapshot packages (TY_PACKAGE, status
*&            | GC_PKG_STATUS, PAYOUT_PARALLEL, PAYOUT_PARALLEL_WAIT_SEC), CURRENT_TO of a watermark and
*&            | the snapshot lag (TY_LAG, threshold MON_STALE_AFTER_MIN_CORE), SEVERITY of a version,
*&            | marker PAY_STATUS_PENDING, aggregated findings (PAYOUT_EXAMPLES, messages 757-765).
*& 2026-11-08 | Comments: method classes / house-bank calendars are posting area ZPMC, bank code roles ZBTR
*&            | (were ZCD_HCK_PMCLASS / ZCD_HCK_BTCROLE, customer posting areas); no code change.
*& 2026-11-08 | Exceptions-only worklist (user decision 2026-11-08): modes FAST / NIGHTLY / SWEEP (TY_SELECTION, own
*&            | run lock variants), sources REQUESTS / NIGHTLY / NIGHTLYREQ, payment requests (TY_REQ_KEY,
*&            | TY_REQUEST, stages GC_REQ_STAGE, outcomes REQ_OPEN / REQ_NOT_PAID / REQ_PAID_LATE, items
*&            | TY_REQ_ITEM), FLOW_CLASS and DUE_DATE of a row, VALUT / HBKID of a verdict, codes PRQ_NOT_PAID /
*&            | PAY_BATCH_INCOMPLETE / PAY_NIGHTLY_MISSING, parameters PAYOUT_BATCH_MAX_PACKAGES /
*&            | PAYOUT_REQ_CUTOFF, messages 766-780, reused check configuration GC_CHECK.
*& 2026-11-10 | Concurrency review: FAIL_COUNT of a watermark (consecutive failed runs of a source), MODE of a
*&            | package (rows of earlier runs deleted per mode), TY_PKG_KEY (a bgPF unit carries keys only,
*&            | members ZCD_PAY_OUTPKGM), package status C (configuration error), guard row GC_GUARD_SOURCE,
*&            | configuration messages GC_CONFIG_MSG, codes PAY_OUTCOME_CONFIG / PAY_EVIDENCE_FAILED, parameter
*&            | PAYOUT_FAIL_ESCALATE, messages 780-785.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment outcome - types and constants</p>
"! Shared by ZIF_CD_OPS_PAY_OUTCOME (evaluator), ZIF_CD_OPS_PAY_OUTCOME_DAO (snapshot SQL),
"! ZCL_CD_OPS_PAY_SNAPSHOT (5-minute job step) and the consumers (HCK A_INFLIGHT, trace).
INTERFACE zif_cd_ops_payout_types
  PUBLIC.

  "! Outcome of a payment (ZCD_PAY_OUTCOME-OUTCOME); the CDS views show the same values
  TYPES ty_outcome TYPE c LENGTH 20.
  "! Decision status of the evaluator: O open (in flight, aged by A_INFLIGHT), X excluded by a
  "! consistent purpose, I inconsistent or anomalous (listed, not aged), R reversed (left out)
  TYPES ty_status TYPE c LENGTH 1.
  "! Short text of the deciding evidence (ZCD_PAY_OUTCOME-EVIDENCE_REF)
  TYPES ty_evidence_ref TYPE c LENGTH 100.
  "! Evidence source of the incremental snapshot (ZCD_PAY_OUTWM-SOURCE)
  TYPES ty_source_id TYPE c LENGTH 10.
  "! Watermark key of a source (statement short key, recheck cursor)
  TYPES ty_wm_key TYPE c LENGTH 70.
  "! UTC time stamp (DEC 15) of a version (ZCD_PAY_OUTCOME-VALID_FROM / VALID_TO)
  TYPES ty_timestamp TYPE p LENGTH 8 DECIMALS 0.

  "! Canonical outcomes. CLEARED / RETURNED / RETRIEVED / VOIDED / PENDING: a consistent purpose
  "! of the rules (ZCD_HCK_CLRRULE) holds; IN_FLIGHT: no purpose decided (or the consistent
  "! IN_FLIGHT purpose); UNDETERMINED: mandatory evidence could not be evaluated (fail closed);
  "! INCONSISTENT: some but not all evidence of a purpose, or an anomaly of an evidence kind;
  "! AMBIGUOUS: the FIN number is in two or more sources - never attributed to one; REVERSED:
  "! the payment document is reversed (DFKKKO-STBEL)
  CONSTANTS:
    BEGIN OF gc_outcome,
      in_flight    TYPE ty_outcome VALUE 'IN_FLIGHT',
      cleared      TYPE ty_outcome VALUE 'CLEARED',
      returned     TYPE ty_outcome VALUE 'RETURNED',
      retrieved    TYPE ty_outcome VALUE 'RETRIEVED',
      voided       TYPE ty_outcome VALUE 'VOIDED',
      pending      TYPE ty_outcome VALUE 'PENDING',
      undetermined TYPE ty_outcome VALUE 'UNDETERMINED',
      inconsistent TYPE ty_outcome VALUE 'INCONSISTENT',
      ambiguous    TYPE ty_outcome VALUE 'AMBIGUOUS',
      reversed     TYPE ty_outcome VALUE 'REVERSED',
      "! Payment request of the worklist (row without payment document, 2026-11-08): received with a
      "! SUCCESS attempt, not yet paid and not yet due (open)
      req_open     TYPE ty_outcome VALUE 'REQ_OPEN',
      "! Not paid in a payment run by the end of its due date (exception, finding PRQ_NOT_PAID; the stage
      "! reached is the evidence kind of the row)
      req_not_paid TYPE ty_outcome VALUE 'REQ_NOT_PAID',
      "! Closing version of a request exception: paid in a payment run after the due date (history only)
      req_paid_late TYPE ty_outcome VALUE 'REQ_PAID_LATE',
    END OF gc_outcome.

  CONSTANTS:
    BEGIN OF gc_status,
      open         TYPE ty_status VALUE 'O',
      excluded     TYPE ty_status VALUE 'X',
      inconsistent TYPE ty_status VALUE 'I',
      reversed     TYPE ty_status VALUE 'R',
    END OF gc_status.

  "! A set of outcomes for SQL (sign I, option EQ), e.g. the final outcomes
  TYPES tt_outcome_range TYPE RANGE OF ty_outcome.

  "! Open end of a version: VALID_TO of the current version
  CONSTANTS gc_valid_to_open TYPE ty_timestamp VALUE '99991231235959'.

  "! A payment listed in a finding of the evaluator (anomaly, inconsistency, undetermined)
  TYPES:
    BEGIN OF ty_listing,
      code     TYPE zif_ca_ops_types=>ty_check_code,
      severity TYPE zif_ca_ops_types=>ty_severity,
      line     TYPE string,
    END OF ty_listing.
  TYPES tt_listing TYPE STANDARD TABLE OF ty_listing WITH EMPTY KEY.

  "! Verdict of one payment (one DPAYH row of a payment document). Values of amounts, dates,
  "! partner and method stay in DPAYH / DFKKOP: the outcome table keeps only the keys
  TYPES:
    BEGIN OF ty_verdict,
      doc1r         TYPE zif_cd_hck_runtime_types=>ty_docno,
      laufd         TYPE d,
      laufi         TYPE c LENGTH 6,
      bukrs         TYPE c LENGTH 4,
      flow          TYPE zif_cd_hck_runtime_types=>ty_flow,
      class         TYPE zif_cd_hck_runtime_types=>ty_method_class,
      "! Value date and house bank of the payment run (age of a payment in flight, worklist lateness)
      valut         TYPE d,
      hbkid         TYPE zif_cd_hck_runtime_types=>ty_hbkid,
      outcome       TYPE ty_outcome,
      status        TYPE ty_status,
      "! Purpose of the rules that decided (blank: none)
      purpose       TYPE zif_cd_hck_runtime_types=>ty_purpose,
      "! Deciding evidence kind (ZCD_HCK_CLRRULE-EVIDENCE_CLASS) and its short reference
      evidence_kind TYPE zif_ca_ops_types=>ty_class_name,
      evidence_ref  TYPE ty_evidence_ref,
      "! Primary finding code of the payment (blank: none)
      finding       TYPE zif_ca_ops_types=>ty_check_code,
      severity      TYPE zif_ca_ops_types=>ty_severity,
      "! Every listing of the payment (anomalies first, then the purpose), for the findings
      listings      TYPE tt_listing,
      "! The evidence of the purpose holds but a mandatory payment status row waits for the hourly
      "! payment status job (status still in its PARAM2): outcome IN_FLIGHT, never inconsistent;
      "! A_INFLIGHT reports PAY_STATUS_LAG once the grace period has passed. Not stored (no version)
      status_pending TYPE abap_bool,
      "! Date of the deciding evidence (posting date of the newest statement line of the lifecycle)
      evidence_date  TYPE d,
    END OF ty_verdict.
  "! One verdict per payment, in the order of the payments evaluated
  TYPES tt_verdict TYPE STANDARD TABLE OF ty_verdict WITH EMPTY KEY
                   WITH NON-UNIQUE SORTED KEY by_doc COMPONENTS doc1r.

  "! Method of a flow mapped to its method class (posting area ZPMC)
  TYPES:
    BEGIN OF ty_method,
      flow  TYPE zif_cd_hck_runtime_types=>ty_flow,
      pymet TYPE zif_cd_hck_runtime_types=>ty_pymet,
      class TYPE zif_cd_hck_runtime_types=>ty_method_class,
    END OF ty_method.
  TYPES tt_method TYPE HASHED TABLE OF ty_method WITH UNIQUE KEY flow pymet.
  TYPES tt_flow_class TYPE SORTED TABLE OF zif_cd_hck_runtime_types=>ty_flow_class WITH UNIQUE KEY table_line.

  "! Configuration of the evaluation: watched method classes (methods and a CLEARED rule), house
  "! bank calendars, rules, method map, configuration findings
  TYPES:
    BEGIN OF ty_config,
      classes  TYPE zif_cd_hck_runtime_types=>tt_pm_class,
      "! House-bank calendar entries of posting area ZPMC (HBKID filled; the class rows are CLASSES)
      banks    TYPE zif_cd_hck_runtime_types=>tt_pm_class,
      rules    TYPE zif_cd_hck_runtime_types=>tt_clr_rule,
      methods  TYPE tt_method,
      watched  TYPE tt_flow_class,
      findings TYPE zif_ca_ops_types=>tt_finding,
    END OF ty_config.

  TYPES:
    BEGIN OF ty_evaluation,
      verdicts         TYPE tt_verdict,
      "! Configuration, unusable-kind and capped-read findings of the evaluation
      findings         TYPE zif_ca_ops_types=>tt_finding,
      "! An evidence kind of a mandatory row could not be used (persisted verdict: PARTIAL)
      evidence_partial TYPE abap_bool,
    END OF ty_evaluation.

  "! Source of a FIN number: request log rows (SUCCESS row rule first, then any row)
  TYPES:
    BEGIN OF ty_fin_source,
      fin       TYPE zif_cd_ops_trace_types=>ty_fin,
      source    TYPE zif_cd_ops_trace_types=>ty_source,
      "! Number of sources of the FIN (more than one = AMBIGUOUS, never one picked)
      sources   TYPE i,
    END OF ty_fin_source.
  TYPES tt_fin_source TYPE SORTED TABLE OF ty_fin_source WITH UNIQUE KEY fin source.
  TYPES tt_fin TYPE SORTED TABLE OF zif_cd_ops_trace_types=>ty_fin WITH UNIQUE KEY table_line.

  " ------------------------------------------------------------ incremental snapshot
  "! Evidence sources of the 5-minute snapshot, each with its own watermark (ZCD_PAY_OUTWM)
  CONSTANTS:
    BEGIN OF gc_source,
      "! Payment and clearing documents posted since the watermark (DFKKKO entry date / time of
      "! DFKKOP-AUGBL): new payment runs (DPAYH-DOC1R) and new or changed DFKKOP clearing
      documents TYPE ty_source_id VALUE 'DOCUMENTS',
      "! Payment documents reversed since the watermark (entry date / time of the reversal document
      "! DFKKKO-STBEL): a changed clearing of a payment already judged
      reversals TYPE ty_source_id VALUE 'REVERSALS',
      "! Statement lines imported since the watermark (FEBEP-KUKEY ascending)
      statement TYPE ty_source_id VALUE 'STATEMENT',
      "! Returns lots created since the watermark (DFKKRK creation date, DFKKRP-SELW1 = AUGBL)
      returns   TYPE ty_source_id VALUE 'RETURNS',
      "! G/L clearing of the XREF2 line since the watermark (BKPF entry date / time of the
      "! clearing document, BSEG-AUGBL / XREF2 = AUGBL)
      gl        TYPE ty_source_id VALUE 'GL',
      "! State without change stamp (DPAYH-ZZ_PAYMENT_STATUS, DFKKCR-STATE): open versions of
      "! payments not final, a package per run after the cursor (key order)
      recheck   TYPE ty_source_id VALUE 'RECHECK',
      "! Payment requests with a SUCCESS attempt received since the watermark (request log, keyset on
      "! received date / time / FIN): new requests enter the worklist (2026-11-08)
      requests  TYPE ty_source_id VALUE 'REQUESTS',
      "! NIGHTLY mode: every current worklist row of a payment, by AUGBL after the cursor (time passing:
      "! a payment becomes late without new evidence)
      nightly   TYPE ty_source_id VALUE 'NIGHTLY',
      "! NIGHTLY mode: every current worklist row of a payment request, by FIN after the cursor (a request
      "! passes its due date without new evidence)
      nightly_req TYPE ty_source_id VALUE 'NIGHTLYREQ',
    END OF gc_source.

  "! Modes of the snapshot program ZCD_OPS_PAY_SNAPSHOT (2026-11-08). FAST: every 5 minutes, watermark
  "! driven - new payments, requests and evidence only. NIGHTLY: once a night, every open and exception
  "! row of the worklist re-evaluated (lateness, due dates). SWEEP: on demand, the evidence sources
  "! chosen re-read for a date range (no watermark moved) - catches what FAST missed
  TYPES ty_mode TYPE c LENGTH 7.
  CONSTANTS:
    BEGIN OF gc_mode,
      fast    TYPE ty_mode VALUE 'FAST',
      nightly TYPE ty_mode VALUE 'NIGHTLY',
      sweep   TYPE ty_mode VALUE 'SWEEP',
    END OF gc_mode.
  TYPES tt_source_id TYPE SORTED TABLE OF ty_source_id WITH UNIQUE KEY table_line.

  "! What one run of the snapshot does: the mode and, for SWEEP, the date range and evidence sources
  TYPES:
    BEGIN OF ty_selection,
      mode    TYPE ty_mode,
      "! SWEEP: entry / posting / received dates of the evidence read (both required)
      date_from TYPE d,
      date_to   TYPE d,
      "! SWEEP: evidence sources re-read (DOCUMENTS, REVERSALS, STATEMENT, RETURNS, GL, REQUESTS)
      sources TYPE tt_source_id,
    END OF ty_selection.

  "! Kind of a worklist row: a payment (payment document filled) or a payment request (row without
  "! payment document, FIN + source)
  TYPES:
    BEGIN OF ty_req_key,
      fin    TYPE zif_cd_ops_trace_types=>ty_fin,
      source TYPE zif_cd_ops_trace_types=>ty_source,
    END OF ty_req_key.
  TYPES tt_req_key TYPE SORTED TABLE OF ty_req_key WITH UNIQUE KEY fin source.

  "! Stage a payment request reached (ZCD_PAY_OUTCOME-EVIDENCE_KIND of a request row): no payment engine
  "! item for the FIN, item with a payment block, item open and not in a payment run, item cleared
  "! without a payment run, paid in a payment run (on time = clean, after the due date = paid late)
  TYPES ty_req_stage TYPE c LENGTH 30.
  CONSTANTS:
    BEGIN OF gc_req_stage,
      no_item        TYPE ty_req_stage VALUE 'PRQ_NO_ITEM',
      payment_block  TYPE ty_req_stage VALUE 'PRQ_PAYMENT_BLOCK',
      not_in_run     TYPE ty_req_stage VALUE 'PRQ_NOT_IN_RUN',
      cleared_no_run TYPE ty_req_stage VALUE 'PRQ_CLEARED_NO_RUN',
      paid_late      TYPE ty_req_stage VALUE 'PRQ_PAID_LATE',
      paid           TYPE ty_req_stage VALUE 'PRQ_PAID',
      cancelled      TYPE ty_req_stage VALUE 'PRQ_CANCELLED',
    END OF gc_req_stage.

  "! Verdict of one payment request (SUCCESS attempt of FIN + source, ZCD_PAYM_REQ_LOG): due date by the
  "! per-source cut-off and the business-day calendar, stage, whether it is finished (paid on time,
  "! cancelled after SUCCESS: clean), overdue (not paid by the end of the due date) or paid late
  TYPES:
    BEGIN OF ty_request,
      fin           TYPE zif_cd_ops_trace_types=>ty_fin,
      source        TYPE zif_cd_ops_trace_types=>ty_source,
      "! Requested payment date (request log DUE=, VERIFY-SE11) and the receipt (DATE= / TIME=)
      requested     TYPE d,
      received_date TYPE d,
      received_time TYPE t,
      cutoff        TYPE t,
      due_date      TYPE d,
      stage         TYPE ty_req_stage,
      "! Payment run date and payment document when paid in a payment run
      paid_date     TYPE d,
      augbl         TYPE zif_cd_ops_trace_types=>ty_docno,
      bukrs         TYPE zif_cd_ops_trace_types=>ty_bukrs,
      "! Item amount (DFKKOP-BETRW of the FIN) or, without item, the request amount (AMOUNT=, VERIFY-SE11)
      amount        TYPE zif_ca_ops_types=>ty_amount,
      currency      TYPE zif_ca_ops_types=>ty_currency,
      "! Finished: paid on time or cancelled after SUCCESS (no worklist row); overdue: due date passed
      "! without payment (exception)
      finished      TYPE abap_bool,
      overdue       TYPE abap_bool,
      "! Short text of the stage for the worklist row and the trace
      text          TYPE ty_evidence_ref,
    END OF ty_request.
  TYPES tt_request TYPE STANDARD TABLE OF ty_request WITH EMPTY KEY
                   WITH NON-UNIQUE SORTED KEY by_key COMPONENTS fin source.

  "! Item of a FIN of a payment request (DFKKOP by ZZ_FIN_TRANS_NUM) with the payment run of its clearing
  "! document (DPAYH, no proposal run) - the stage of the request
  TYPES:
    BEGIN OF ty_req_item,
      fin      TYPE zif_cd_ops_trace_types=>ty_fin,
      opbel    TYPE zif_cd_ops_trace_types=>ty_docno,
      bukrs    TYPE zif_cd_ops_trace_types=>ty_bukrs,
      augbl    TYPE zif_cd_ops_trace_types=>ty_docno,
      "! Payment block of the item (DFKKOP-SPZAH, VERIFY-SE11)
      spzah    TYPE c LENGTH 1,
      amount   TYPE zif_ca_ops_types=>ty_amount,
      currency TYPE zif_ca_ops_types=>ty_currency,
      "! Run date of the payment run of AUGBL (initial: cleared without payment run, or open)
      laufd    TYPE d,
    END OF ty_req_item.
  TYPES tt_req_item TYPE STANDARD TABLE OF ty_req_item WITH EMPTY KEY.

  "! A current request row of the worklist due before a date (A_PRQ_NOT_PAID) with the sum of the
  "! items of its FIN in one currency (no item: currency and amount initial)
  TYPES:
    BEGIN OF ty_due_request,
      fin_id       TYPE zif_cd_ops_trace_types=>ty_fin,
      source       TYPE zif_cd_ops_trace_types=>ty_source,
      outcome      TYPE ty_outcome,
      "! Stage reached (row's evidence kind)
      stage        TYPE ty_req_stage,
      due_date     TYPE d,
      evidence_ref TYPE ty_evidence_ref,
      currency     TYPE zif_ca_ops_types=>ty_currency,
      amount       TYPE zif_ca_ops_types=>ty_amount,
    END OF ty_due_request.
  TYPES tt_due_request TYPE STANDARD TABLE OF ty_due_request WITH EMPTY KEY.

  "! A source's watermark (ZCD_PAY_OUTWM)
  TYPES:
    BEGIN OF ty_watermark,
      source     TYPE ty_source_id,
      wm_date    TYPE d,
      wm_time    TYPE t,
      wm_key     TYPE ty_wm_key,
      "! Sequence within the key (statement line number ESNUM)
      wm_seq     TYPE i,
      updated_at TYPE ty_timestamp,
      last_rows  TYPE i,
      "! Evidence of the source processed completely up to this instant (UTC): the run time when the
      "! run caught up, else the watermark's own entry time; basis of the snapshot lag
      current_to TYPE timestampl,
      "! Consecutive runs (FAST / NIGHTLY) in which a package of the source failed; 0 after a run without
      "! failure (2026-11-10). Not written by SAVE_WATERMARK (SAVE_FAILURES)
      fail_count TYPE i,
    END OF ty_watermark.
  TYPES tt_watermark TYPE SORTED TABLE OF ty_watermark WITH UNIQUE KEY source.

  "! Row of ZCD_PAY_OUTWM that is no evidence source: the guard every worklist write locks (SELECT SINGLE
  "! FOR UPDATE) from its re-read of the current rows to its commit (2026-11-10) - FAST, NIGHTLY, SWEEP and
  "! the parallel units validate and write one after the other, never on a stale judgement
  CONSTANTS gc_guard_source TYPE ty_source_id VALUE 'WORKLIST'.

  "! Payment documents with new evidence of one source and the watermark after them
  TYPES:
    BEGIN OF ty_changes,
      docno     TYPE zif_cd_ops_trace_types=>tt_docno,
      "! Statement references (FEBEP-CHECT) of new lines: payment documents and cheque numbers
      refs      TYPE zif_cd_ops_trace_types=>tt_ref,
      "! Payment requests (FIN + source) of the REQUESTS / NIGHTLYREQ sources
      requests  TYPE tt_req_key,
      watermark TYPE ty_watermark,
      "! The read reached its package size: more changes wait for the next package
      more      TYPE abap_bool,
    END OF ty_changes.

  "! Item of a payment document with its FIN number (DFKKOP-AUGBL / ZZ_FIN_TRANS_NUM / BUKRS)
  TYPES:
    BEGIN OF ty_fin_item,
      augbl TYPE zif_cd_ops_trace_types=>ty_docno,
      bukrs TYPE zif_cd_ops_trace_types=>ty_bukrs,
      fin   TYPE zif_cd_ops_trace_types=>ty_fin,
    END OF ty_fin_item.
  TYPES tt_fin_item TYPE SORTED TABLE OF ty_fin_item WITH UNIQUE KEY augbl bukrs fin.

  "! One version of ZCD_PAY_OUTCOME (keys and the verdict; no amount, date, partner or method)
  TYPES:
    BEGIN OF ty_version,
      fin_id        TYPE zif_cd_ops_trace_types=>ty_fin,
      source        TYPE zif_cd_ops_trace_types=>ty_source,
      bukrs         TYPE zif_cd_ops_trace_types=>ty_bukrs,
      augbl         TYPE zif_cd_ops_trace_types=>ty_docno,
      laufd         TYPE d,
      laufi         TYPE c LENGTH 6,
      valid_from    TYPE ty_timestamp,
      valid_to      TYPE ty_timestamp,
      outcome       TYPE ty_outcome,
      evidence_kind TYPE zif_ca_ops_types=>ty_class_name,
      evidence_ref  TYPE ty_evidence_ref,
      finding       TYPE zif_ca_ops_types=>ty_check_code,
      "! Severity of the primary finding as the evaluator listed it (blank: no finding)
      severity      TYPE zif_ca_ops_types=>ty_severity,
      evaluated_at  TYPE ty_timestamp,
      "! Flow + method class of the payment (e.g. DWIR; blank for a payment request) and the due date of a
      "! payment request (2026-11-08: worklist filters of the transactions dashboard)
      flow_class    TYPE zif_cd_hck_runtime_types=>ty_flow_class,
      due_date      TYPE d,
    END OF ty_version.
  TYPES tt_version TYPE STANDARD TABLE OF ty_version WITH EMPTY KEY.

  "! Result of one snapshot run (job log, dialog list)
  TYPES:
    BEGIN OF ty_source_result,
      source    TYPE ty_source_id,
      documents TYPE i,
      packages  TYPE i,
      evaluated TYPE i,
      inserted  TYPE i,
      closed    TYPE i,
      more      TYPE abap_bool,
    END OF ty_source_result.
  TYPES tt_source_result TYPE STANDARD TABLE OF ty_source_result WITH EMPTY KEY.

  "! Tables of the snapshot (named in write errors)
  CONSTANTS:
    BEGIN OF gc_table,
      outcome   TYPE zif_cd_ops_trace_types=>ty_tabname VALUE 'ZCD_PAY_OUTCOME',
      watermark TYPE zif_cd_ops_trace_types=>ty_tabname VALUE 'ZCD_PAY_OUTWM',
      package   TYPE zif_cd_ops_trace_types=>ty_tabname VALUE 'ZCD_PAY_OUTPKG',
      member    TYPE zif_cd_ops_trace_types=>ty_tabname VALUE 'ZCD_PAY_OUTPKGM',
    END OF gc_table.

  "! Run lock variant and evaluation context of the snapshot (object keys of its findings)
  CONSTANTS gc_variant TYPE zif_ca_ops_types=>ty_variant VALUE 'PAY_OUTCOME'.
  "! Run lock variants of the NIGHTLY and SWEEP modes (own locks: the 5-minute FAST run is never
  "! refused while a nightly or sweep run works; a duplicate current row of a race is closed by the
  "! next evaluation of the payment - PLAN_WORKLIST keeps the newest)
  CONSTANTS gc_variant_nightly TYPE zif_ca_ops_types=>ty_variant VALUE 'PAY_OUTCOME_NIGHTLY'.
  CONSTANTS gc_variant_sweep TYPE zif_ca_ops_types=>ty_variant VALUE 'PAY_OUTCOME_SWEEP'.
  "! Morning report checks whose configuration the worklist reuses (one definition): A_INFLIGHT - the
  "! AGE_OLDEST limits (late payments) and PARAM1, the payment engine's factory calendar (due dates of
  "! requests); C_PRQ_CANCEL - its PARAM2 (cancelled status value and sources) decides that a request
  "! cancelled after SUCCESS is not expected to be paid
  CONSTANTS:
    BEGIN OF gc_check,
      inflight   TYPE zif_cd_hck_types=>ty_check_id VALUE 'A_INFLIGHT',
      prq_cancel TYPE zif_cd_hck_types=>ty_check_id VALUE 'C_PRQ_CANCEL',
    END OF gc_check.
  CONSTANTS gc_context TYPE zif_cd_hck_types=>ty_check_id VALUE 'PAY_OUTCOME'.
  "! Object type of the snapshot's findings (ZCA_OPS_FINDING-OBJECT_TYPE)
  CONSTANTS gc_object_type TYPE zif_ca_ops_types=>ty_object_type VALUE 'PAYMENT'.

  " ------------------------------------------------------------ check codes
  CONSTANTS:
    BEGIN OF gc_code,
      "! The FIN number is in two or more sources: outcome AMBIGUOUS, never attributed to one
      source_ambiguous TYPE zif_ca_ops_types=>ty_check_code VALUE 'PAY_SOURCE_AMBIGUOUS',
      "! A snapshot package could not be evaluated (configuration, read): nothing written for it
      snapshot_failed  TYPE zif_ca_ops_types=>ty_check_code VALUE 'PAY_OUTCOME_FAILED',
      "! Marker of a version (ZCD_PAY_OUTCOME-FINDING, outcome IN_FLIGHT), not a finding of its own:
      "! the bank evidence decides the purpose but the payment status job has not followed yet; the
      "! morning report reports PAY_STATUS_LAG once HCK_PAY_STATUS_LAG_MIN has passed since VALID_FROM
      status_pending   TYPE zif_ca_ops_types=>ty_check_code VALUE 'PAY_STATUS_PENDING',
      "! Parallel packages could not be dispatched (bgPF): the packages of the run were judged one by one
      parallel_off     TYPE zif_ca_ops_types=>ty_check_code VALUE 'PAY_OUTCOME_SERIAL',
      "! Payment request not paid in a payment run by the end of its due date (worklist row, morning
      "! report check A_PRQ_NOT_PAID: one finding per source + stage + due date)
      request_not_paid TYPE zif_ca_ops_types=>ty_check_code VALUE 'PRQ_NOT_PAID',
      "! A NIGHTLY or SWEEP run stopped at PAYOUT_BATCH_MAX_PACKAGES: the next run continues (NIGHTLY from
      "! its cursor)
      batch_incomplete TYPE zif_ca_ops_types=>ty_check_code VALUE 'PAY_BATCH_INCOMPLETE',
      "! The nightly re-evaluation of the worklist has not completed since the start of the day: requests
      "! due yesterday may not be judged yet (A_PRQ_NOT_PAID evidence PARTIAL)
      nightly_missing  TYPE zif_ca_ops_types=>ty_check_code VALUE 'PAY_NIGHTLY_MISSING',
      "! A snapshot package failed on a configuration error (GC_CONFIG_MSG): nothing written, the source
      "! waits for a fix by transport - a retry alone never helps (2026-11-10)
      config_failed    TYPE zif_ca_ops_types=>ty_check_code VALUE 'PAY_OUTCOME_CONFIG',
      "! An evidence kind could not be read for a technical reason (not a configuration error): its purposes
      "! are not judged, the payments stay in flight (fail closed, 2026-11-10)
      evidence_failed  TYPE zif_ca_ops_types=>ty_check_code VALUE 'PAY_EVIDENCE_FAILED',
    END OF gc_code.

  "! ZCD_OPS messages that mean a configuration error (fix by transport, a retry never helps): plug-in
  "! class missing / not instantiable / without its interface, plug-in interface missing, configuration
  "! missing / invalid, configured table not in the DDIC, invalid PCRE in check parameters / sequence
  "! outcomes / a pattern, evidence parameter required, evidence expectation invalid, no or two method
  "! classes of a payment method, request source not configured
  CONSTANTS:
    BEGIN OF gc_config_msg,
      class_missing    TYPE zif_ca_ops_types=>ty_msgno VALUE '030',
      class_no_plugin  TYPE zif_ca_ops_types=>ty_msgno VALUE '031',
      class_no_intf    TYPE zif_ca_ops_types=>ty_msgno VALUE '032',
      intf_missing     TYPE zif_ca_ops_types=>ty_msgno VALUE '033',
      config_missing   TYPE zif_ca_ops_types=>ty_msgno VALUE '050',
      config_invalid   TYPE zif_ca_ops_types=>ty_msgno VALUE '051',
      table_missing    TYPE zif_ca_ops_types=>ty_msgno VALUE '303',
      param_pcre       TYPE zif_ca_ops_types=>ty_msgno VALUE '373',
      no_method_class  TYPE zif_ca_ops_types=>ty_msgno VALUE '384',
      two_classes      TYPE zif_ca_ops_types=>ty_msgno VALUE '385',
      evidence_param   TYPE zif_ca_ops_types=>ty_msgno VALUE '665',
      seqout_pcre      TYPE zif_ca_ops_types=>ty_msgno VALUE '666',
      expectation      TYPE zif_ca_ops_types=>ty_msgno VALUE '671',
      source_unconfig  TYPE zif_ca_ops_types=>ty_msgno VALUE '703',
      pattern_pcre     TYPE zif_ca_ops_types=>ty_msgno VALUE '743',
    END OF gc_config_msg.

  " ------------------------------------------------------------ parallel packages (ZCD_PAY_OUTPKG)
  "! Status of a parallel package: P planned (dispatched), D done (its versions committed), F failed
  "! (nothing written), C failed on a configuration error (nothing written, reported as configuration,
  "! 2026-11-10), A abandoned (not finished within PAYOUT_PARALLEL_WAIT_SEC - the unit writes nothing any
  "! more)
  TYPES ty_pkg_status TYPE c LENGTH 1.
  CONSTANTS:
    BEGIN OF gc_pkg_status,
      planned   TYPE ty_pkg_status VALUE 'P',
      done      TYPE ty_pkg_status VALUE 'D',
      failed    TYPE ty_pkg_status VALUE 'F',
      config    TYPE ty_pkg_status VALUE 'C',
      abandoned TYPE ty_pkg_status VALUE 'A',
    END OF gc_pkg_status.

  "! One package of a snapshot run: the payment documents to judge and, once the unit ran, its
  "! status and counts (ZCD_PAY_OUTPKG). The watermark after the package stays with the run
  TYPES:
    BEGIN OF ty_package,
      run_id    TYPE zif_ca_ops_types=>ty_run_id,
      source    TYPE ty_source_id,
      pkg_no    TYPE i,
      "! Mode of the run that planned the package (its rows are deleted by the next run of that mode)
      mode      TYPE ty_mode,
      status    TYPE ty_pkg_status,
      "! Time of the run: VALID_FROM / VALID_TO of the versions the package writes
      run_at    TYPE ty_timestamp,
      docno     TYPE zif_cd_ops_trace_types=>tt_docno,
      "! Payment requests of the package (FIN + source)
      requests  TYPE tt_req_key,
      documents TYPE i,
      evaluated TYPE i,
      inserted  TYPE i,
      closed    TYPE i,
      message   TYPE zif_ca_ops_types=>ty_message,
    END OF ty_package.
  TYPES tt_package TYPE STANDARD TABLE OF ty_package WITH EMPTY KEY.

  "! What the bgPF unit of a package carries (2026-11-10): the package key and the run time only - the
  "! unit re-reads the documents and requests of the package (ZCD_PAY_OUTPKGM), never a payload
  TYPES:
    BEGIN OF ty_pkg_key,
      run_id TYPE zif_ca_ops_types=>ty_run_id,
      source TYPE ty_source_id,
      pkg_no TYPE i,
      run_at TYPE ty_timestamp,
    END OF ty_pkg_key.

  "! Snapshot lag: minutes between now and the oldest instant up to which an evidence source is
  "! processed completely (MIN of CURRENT_TO, RECHECK excluded). KNOWN = blank: no source has run
  "! yet - the snapshot is treated as stale
  TYPES:
    BEGIN OF ty_lag,
      minutes    TYPE i,
      known      TYPE abap_bool,
      "! The source furthest behind and its CURRENT_TO
      source     TYPE ty_source_id,
      current_to TYPE timestampl,
    END OF ty_lag.

  "! A version written by this run with the payment's method and flow indicator (aggregated
  "! findings of the snapshot per flow + method class + run date)
  TYPES:
    BEGIN OF ty_new_version,
      version TYPE ty_version,
      pymet   TYPE zif_cd_hck_runtime_types=>ty_pymet,
      xeinz   TYPE abap_bool,
    END OF ty_new_version.
  TYPES tt_new_version TYPE STANDARD TABLE OF ty_new_version WITH EMPTY KEY.

  " ------------------------------------------------------------ A_INFLIGHT aggregate reads
  "! Live payment status DPAYH-ZZ_PAYMENT_STATUS (confirmed values ISSUED, CONFIRMED, CLEARED,
  "! RETURNED, RETRIEVED, STOPPED; field length VERIFY-SE11)
  TYPES ty_pay_status TYPE c LENGTH 20.
  TYPES tt_pay_status_range TYPE RANGE OF ty_pay_status.
  TYPES tt_check_code_range TYPE RANGE OF zif_ca_ops_types=>ty_check_code.
  TYPES tt_date_range TYPE RANGE OF d.
  TYPES tt_pymet_range TYPE RANGE OF zif_cd_hck_runtime_types=>ty_pymet.
  "! FINAL_FROM of a query that counts no final outcome (no run date reaches it)
  CONSTANTS gc_no_final_from TYPE d VALUE '99991231'.

  "! Which current versions an aggregate read covers
  TYPES:
    BEGIN OF ty_group_query,
      "! Payment methods of the watched method classes (DPAYH-PYMET)
      methods     TYPE zif_cd_hck_runtime_types=>tt_pymet,
      "! Outcomes counted however old the payment is (in flight, undetermined, inconsistent)
      all_ages    TYPE tt_outcome_range,
      "! Outcomes counted only for payment runs on or after FINAL_FROM (excluded purposes)
      recent      TYPE tt_outcome_range,
      final_from  TYPE d,
      "! Optional filters (empty = any): primary finding, live payment status, run dates
      findings    TYPE tt_check_code_range,
      statuses    TYPE tt_pay_status_range,
      days        TYPE tt_date_range,
      "! A version valid from at or before this instant is DUE (grace of PAY_STATUS_PENDING passed)
      lag_limit   TYPE ty_timestamp,
    END OF ty_group_query.

  "! Payments of current versions grouped on HANA (each payment counted once)
  TYPES:
    BEGIN OF ty_outcome_group,
      xeinz      TYPE abap_bool,
      pymet      TYPE zif_cd_hck_runtime_types=>ty_pymet,
      hbkid      TYPE zif_cd_hck_runtime_types=>ty_hbkid,
      laufd      TYPE d,
      laufi      TYPE c LENGTH 6,
      valut      TYPE d,
      currency   TYPE zif_ca_ops_types=>ty_currency,
      outcome    TYPE ty_outcome,
      finding    TYPE zif_ca_ops_types=>ty_check_code,
      severity   TYPE zif_ca_ops_types=>ty_severity,
      pay_status TYPE ty_pay_status,
      due        TYPE abap_bool,
      payments   TYPE i,
      "! Sum of the absolute payment amounts (DPAYH-RWBTR) in the currency
      amount     TYPE zif_ca_ops_types=>ty_amount,
    END OF ty_outcome_group.
  TYPES tt_outcome_group TYPE STANDARD TABLE OF ty_outcome_group WITH EMPTY KEY.

  "! One payment of the current versions with its DPAYH values (example of a finding, candidate)
  TYPES:
    BEGIN OF ty_outcome_example,
      doc1r        TYPE zif_cd_hck_runtime_types=>ty_docno,
      laufd        TYPE d,
      laufi        TYPE c LENGTH 6,
      bukrs        TYPE c LENGTH 4,
      xeinz        TYPE abap_bool,
      pymet        TYPE zif_cd_hck_runtime_types=>ty_pymet,
      hbkid        TYPE zif_cd_hck_runtime_types=>ty_hbkid,
      valut        TYPE d,
      currency     TYPE zif_ca_ops_types=>ty_currency,
      amount       TYPE zif_ca_ops_types=>ty_amount,
      outcome      TYPE ty_outcome,
      finding      TYPE zif_ca_ops_types=>ty_check_code,
      severity     TYPE zif_ca_ops_types=>ty_severity,
      pay_status   TYPE ty_pay_status,
      due          TYPE abap_bool,
      evidence_ref TYPE ty_evidence_ref,
    END OF ty_outcome_example.
  TYPES tt_outcome_example TYPE STANDARD TABLE OF ty_outcome_example WITH EMPTY KEY.

  " ------------------------------------------------------------ parameters (ZCA_PARAM, CD_OPS)
  CONSTANTS:
    BEGIN OF gc_param,
      "! Payment documents per package of the snapshot [5000]
      package_size TYPE zif_ca_ops_types=>ty_param_name VALUE 'PAYOUT_PACKAGE_SIZE',
      "! Packages per source and run (bounds the 5-minute step) [20]
      max_packages TYPE zif_ca_ops_types=>ty_param_name VALUE 'PAYOUT_MAX_PACKAGES',
      "! First run (no watermark): days before today read once [10]
      initial_days TYPE zif_ca_ops_types=>ty_param_name VALUE 'PAYOUT_INITIAL_DAYS',
      "! Packages judged at the same time as bgPF units [4]; 1 = one by one in the job step, as before
      parallel     TYPE zif_ca_ops_types=>ty_param_name VALUE 'PAYOUT_PARALLEL',
      "! Seconds a wave of parallel packages may take before its unfinished packages are abandoned [600]
      wait_sec     TYPE zif_ca_ops_types=>ty_param_name VALUE 'PAYOUT_PARALLEL_WAIT_SEC',
      "! Payment documents listed as examples in an aggregated finding (oldest first) [10]; also read
      "! by A_INFLIGHT
      examples     TYPE zif_ca_ops_types=>ty_param_name VALUE 'PAYOUT_EXAMPLES',
      "! Consecutive runs with a failed package of a source after which its failure finding is an error [3];
      "! before, a warning (the next run retries) - FAST / NIGHTLY (2026-11-10)
      fail_escalate TYPE zif_ca_ops_types=>ty_param_name VALUE 'PAYOUT_FAIL_ESCALATE',
      "! Packages per run of the NIGHTLY and SWEEP modes [1000]; NIGHTLY continues from its cursor
      batch_max_packages TYPE zif_ca_ops_types=>ty_param_name VALUE 'PAYOUT_BATCH_MAX_PACKAGES',
      "! Cut-off of a payment request per source (LIST SOURCE=HHMMSS, * = every other source) in the
      "! time zone FMON_TIME_ZONE [*=190000 - the last hourly disbursement run]: received after it on its
      "! due date = due the next business day
      req_cutoff   TYPE zif_ca_ops_types=>ty_param_name VALUE 'PAYOUT_REQ_CUTOFF',
    END OF gc_param.

  CONSTANTS:
    BEGIN OF gc_param_default,
      package_size TYPE i VALUE 5000,
      max_packages TYPE i VALUE 20,
      initial_days TYPE i VALUE 10,
      parallel     TYPE i VALUE 4,
      wait_sec     TYPE i VALUE 600,
      examples     TYPE i VALUE 10,
      fail_escalate TYPE i VALUE 3,
      batch_max_packages TYPE i VALUE 1000,
      req_cutoff   TYPE string VALUE `*=190000`,
      "! Snapshot lag (minutes) above which it is stale: MON_STALE_AFTER_MIN_CORE (core freshness row of
      "! the production-support overview, A_INFLIGHT evidence PARTIAL); 6 x the 5-minute cadence
      stale_after_min TYPE i VALUE 30,
    END OF gc_param_default.

  "! Cut-off list: source of every other source and the separator of SOURCE=HHMMSS
  CONSTANTS gc_cutoff_any TYPE c LENGTH 1 VALUE '*'.
  CONSTANTS gc_cutoff_sep TYPE c LENGTH 1 VALUE '='.

  "! Hard ceiling of the parallel packages of one wave (bgPF units at the same time)
  CONSTANTS gc_max_parallel TYPE i VALUE 20.
  "! Seconds between two looks at the packages of a wave
  CONSTANTS gc_poll_seconds TYPE i VALUE 5.
  "! bgPF process name of a parallel package (SBGRFCMON)
  CONSTANTS gc_process_name TYPE c LENGTH 30 VALUE 'ZCD_PAY_SNAPSHOT_PACKAGE'.

  "! Hard ceiling of the package size (one FOR ALL ENTRIES / IN list per package)
  CONSTANTS gc_max_package TYPE i VALUE 50000.
  "! Width of a payment document (AUGBL / DOC1R): a longer statement reference is a cheque number
  CONSTANTS gc_docno_length TYPE i VALUE 12.
  "! Request log rows read per FIN at most (attempts of all sources); reaching it = fail closed
  CONSTANTS gc_max_attempts TYPE i VALUE 50.

  " ------------------------------------------------------------ messages (ZCD_OPS 750-785)
  CONSTANTS:
    BEGIN OF gc_msg,
      "! &1 is in &2 sources (&3): outcome AMBIGUOUS, evaluated &4
      source_ambiguous TYPE zif_ca_ops_types=>ty_msgno VALUE '750',
      "! Payment outcome snapshot: source &1 package failed: &2
      snapshot_failed  TYPE zif_ca_ops_types=>ty_msgno VALUE '751',
      "! Source &1: &2 documents, &3 evaluated, &4 versions
      source_result    TYPE zif_ca_ops_types=>ty_msgno VALUE '752',
      "! Outcome &1 of payment &2 run &3 &4
      trace_outcome    TYPE zif_ca_ops_types=>ty_msgno VALUE '753',
      "! Payment &1: method not in a watched method class - no outcome
      trace_not_watched TYPE zif_ca_ops_types=>ty_msgno VALUE '754',
      "! Outcome of payment &1 could not be evaluated:
      trace_unavailable TYPE zif_ca_ops_types=>ty_msgno VALUE '755',
      "! evidence &1: &2
      evidence_text    TYPE zif_ca_ops_types=>ty_msgno VALUE '756',
      "! &1 run date &2: &3 payment(s) - &4
      aggregated       TYPE zif_ca_ops_types=>ty_msgno VALUE '757',
      "! Amount &1 &2
      amount_currency  TYPE zif_ca_ops_types=>ty_msgno VALUE '758',
      "! First &1 of &2 payment(s), oldest first:
      examples_head    TYPE zif_ca_ops_types=>ty_msgno VALUE '759',
      "! Full list: transactions dashboard or ZCD_PAY_OUTCOME current versions, finding &1, run date &2
      drill_down       TYPE zif_ca_ops_types=>ty_msgno VALUE '760',
      "! Payment outcome snapshot &1 minute(s) behind (limit &2): &3 processed up to &4
      snapshot_lag     TYPE zif_ca_ops_types=>ty_msgno VALUE '761',
      "! Payment outcome snapshot has not run yet: no outcome of &1 is current
      snapshot_never   TYPE zif_ca_ops_types=>ty_msgno VALUE '762',
      "! Package &1 / &2 not finished within &3 seconds: abandoned, the watermark stays before it
      pkg_abandoned    TYPE zif_ca_ops_types=>ty_msgno VALUE '763',
      "! Parallel packages not available (bgPF), judged one by one:
      parallel_off     TYPE zif_ca_ops_types=>ty_msgno VALUE '764',
      "! FIN &1 source &2 payment &3: &4
      ambiguous_line   TYPE zif_ca_ops_types=>ty_msgno VALUE '765',
      "! Requested &1, received &2 &3, due &4:
      req_evidence     TYPE zif_ca_ops_types=>ty_msgno VALUE '766',
      "! No payment engine item for the FIN
      req_no_item      TYPE zif_ca_ops_types=>ty_msgno VALUE '767',
      "! Item &1 has payment block &2
      req_block        TYPE zif_ca_ops_types=>ty_msgno VALUE '768',
      "! Item &1 open, not in a payment run
      req_not_in_run   TYPE zif_ca_ops_types=>ty_msgno VALUE '769',
      "! Item &1 cleared by &2 without payment run
      req_cleared      TYPE zif_ca_ops_types=>ty_msgno VALUE '770',
      "! Paid by &1 in the payment run of &2
      req_paid         TYPE zif_ca_ops_types=>ty_msgno VALUE '771',
      "! &1 &2 due &3: &4 request(s) not paid in a payment run
      req_not_paid     TYPE zif_ca_ops_types=>ty_msgno VALUE '772',
      "! FIN &1 source &2 due &3:
      req_example      TYPE zif_ca_ops_types=>ty_msgno VALUE '773',
      "! Full list: transactions dashboard, request &1 &2 due &3
      req_drill_down   TYPE zif_ca_ops_types=>ty_msgno VALUE '774',
      "! Sweep needs a date range and evidence sources of: &1
      sweep_selection  TYPE zif_ca_ops_types=>ty_msgno VALUE '775',
      "! &1 stopped after &2 package(s); the next run continues
      batch_stopped    TYPE zif_ca_ops_types=>ty_msgno VALUE '776',
      "! Worklist re-check &1 not completed today (&2): requests unchecked
      nightly_missing  TYPE zif_ca_ops_types=>ty_msgno VALUE '777',
      "! Cancelled after SUCCESS (&1): not expected to be paid
      req_cancelled    TYPE zif_ca_ops_types=>ty_msgno VALUE '778',
      "! Request &1 &2: stage &3, &4
      trace_request    TYPE zif_ca_ops_types=>ty_msgno VALUE '779',
      "! &1 worklist entities changed by a concurrent run since judged (first &2)
      worklist_changed TYPE zif_ca_ops_types=>ty_msgno VALUE '780',
      "! A second current worklist row of &1 prevented
      second_current   TYPE zif_ca_ops_types=>ty_msgno VALUE '781',
      "! Database error in source &1 - package rolled back:
      db_error         TYPE zif_ca_ops_types=>ty_msgno VALUE '782',
      "! Source &1 not judged in &2 runs in a row (limit &3):
      failed_escalated TYPE zif_ca_ops_types=>ty_msgno VALUE '783',
      "! Source &1 stopped by a configuration error (&2 runs) - fix by transport:
      config_failed    TYPE zif_ca_ops_types=>ty_msgno VALUE '784',
      "! Evidence &1 (&2) could not be read - its purposes are not judged:
      evidence_failed  TYPE zif_ca_ops_types=>ty_msgno VALUE '785',
    END OF gc_msg.

ENDINTERFACE.
