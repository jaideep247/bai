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
    END OF gc_outcome.

  CONSTANTS:
    BEGIN OF gc_status,
      open         TYPE ty_status VALUE 'O',
      excluded     TYPE ty_status VALUE 'X',
      inconsistent TYPE ty_status VALUE 'I',
      reversed     TYPE ty_status VALUE 'R',
    END OF gc_status.

  "! Open end of a version: VALID_TO of the current version
  CONSTANTS gc_valid_to_open TYPE ty_timestamp VALUE '99991231235959'.

  "! A payment listed in a finding of the evaluator (anomaly, inconsistency, undetermined)
  TYPES:
    BEGIN OF ty_listing,
      code     TYPE zif_cd_ops_types=>ty_check_code,
      severity TYPE zif_cd_ops_types=>ty_severity,
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
      outcome       TYPE ty_outcome,
      status        TYPE ty_status,
      "! Purpose of the rules that decided (blank: none)
      purpose       TYPE zif_cd_hck_runtime_types=>ty_purpose,
      "! Deciding evidence kind (ZCD_HCK_CLRRULE-EVIDENCE_CLASS) and its short reference
      evidence_kind TYPE zif_cd_ops_types=>ty_class_name,
      evidence_ref  TYPE ty_evidence_ref,
      "! Primary finding code of the payment (blank: none)
      finding       TYPE zif_cd_ops_types=>ty_check_code,
      severity      TYPE zif_cd_ops_types=>ty_severity,
      "! Every listing of the payment (anomalies first, then the purpose), for the findings
      listings      TYPE tt_listing,
    END OF ty_verdict.
  "! One verdict per payment, in the order of the payments evaluated
  TYPES tt_verdict TYPE STANDARD TABLE OF ty_verdict WITH EMPTY KEY
                   WITH NON-UNIQUE SORTED KEY by_doc COMPONENTS doc1r.

  "! Method of a flow mapped to its method class (ZCD_HCK_PMCLASS)
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
      banks    TYPE zif_cd_hck_runtime_types=>tt_pm_bank,
      rules    TYPE zif_cd_hck_runtime_types=>tt_clr_rule,
      methods  TYPE tt_method,
      watched  TYPE tt_flow_class,
      findings TYPE zif_cd_ops_types=>tt_finding,
    END OF ty_config.

  TYPES:
    BEGIN OF ty_evaluation,
      verdicts         TYPE tt_verdict,
      "! Configuration, unusable-kind and capped-read findings of the evaluation
      findings         TYPE zif_cd_ops_types=>tt_finding,
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
    END OF gc_source.

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
    END OF ty_watermark.
  TYPES tt_watermark TYPE SORTED TABLE OF ty_watermark WITH UNIQUE KEY source.

  "! Payment documents with new evidence of one source and the watermark after them
  TYPES:
    BEGIN OF ty_changes,
      docno     TYPE zif_cd_ops_trace_types=>tt_docno,
      "! Statement references (FEBEP-CHECT) of new lines: payment documents and cheque numbers
      refs      TYPE zif_cd_ops_trace_types=>tt_ref,
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
      evidence_kind TYPE zif_cd_ops_types=>ty_class_name,
      evidence_ref  TYPE ty_evidence_ref,
      finding       TYPE zif_cd_ops_types=>ty_check_code,
      evaluated_at  TYPE ty_timestamp,
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
    END OF gc_table.

  "! Run lock variant and evaluation context of the snapshot (object keys of its findings)
  CONSTANTS gc_variant TYPE zif_cd_ops_types=>ty_variant VALUE 'PAY_OUTCOME'.
  CONSTANTS gc_context TYPE zif_cd_hck_types=>ty_check_id VALUE 'PAY_OUTCOME'.
  "! Object type of the snapshot's findings (ZCD_OPS_FINDING-OBJECT_TYPE)
  CONSTANTS gc_object_type TYPE zif_cd_ops_types=>ty_object_type VALUE 'PAYMENT'.

  " ------------------------------------------------------------ check codes
  CONSTANTS:
    BEGIN OF gc_code,
      "! The FIN number is in two or more sources: outcome AMBIGUOUS, never attributed to one
      source_ambiguous TYPE zif_cd_ops_types=>ty_check_code VALUE 'PAY_SOURCE_AMBIGUOUS',
      "! A snapshot package could not be evaluated (configuration, read): nothing written for it
      snapshot_failed  TYPE zif_cd_ops_types=>ty_check_code VALUE 'PAY_OUTCOME_FAILED',
    END OF gc_code.

  " ------------------------------------------------------------ parameters (ZCA_PARAM, CD_OPS)
  CONSTANTS:
    BEGIN OF gc_param,
      "! Payment documents per package of the snapshot [5000]
      package_size TYPE zif_cd_ops_types=>ty_param_name VALUE 'PAYOUT_PACKAGE_SIZE',
      "! Packages per source and run (bounds the 5-minute step) [20]
      max_packages TYPE zif_cd_ops_types=>ty_param_name VALUE 'PAYOUT_MAX_PACKAGES',
      "! First run (no watermark): days before today read once [10]
      initial_days TYPE zif_cd_ops_types=>ty_param_name VALUE 'PAYOUT_INITIAL_DAYS',
    END OF gc_param.

  CONSTANTS:
    BEGIN OF gc_param_default,
      package_size TYPE i VALUE 5000,
      max_packages TYPE i VALUE 20,
      initial_days TYPE i VALUE 10,
    END OF gc_param_default.

  "! Hard ceiling of the package size (one FOR ALL ENTRIES / IN list per package)
  CONSTANTS gc_max_package TYPE i VALUE 50000.
  "! Width of a payment document (AUGBL / DOC1R): a longer statement reference is a cheque number
  CONSTANTS gc_docno_length TYPE i VALUE 12.
  "! Request log rows read per FIN at most (attempts of all sources); reaching it = fail closed
  CONSTANTS gc_max_attempts TYPE i VALUE 50.

  " ------------------------------------------------------------ messages (ZCD_OPS 750-769)
  CONSTANTS:
    BEGIN OF gc_msg,
      "! &1 is in &2 sources (&3): outcome AMBIGUOUS, evaluated &4
      source_ambiguous TYPE zif_cd_ops_types=>ty_msgno VALUE '750',
      "! Payment outcome snapshot: source &1 package failed: &2
      snapshot_failed  TYPE zif_cd_ops_types=>ty_msgno VALUE '751',
      "! Source &1: &2 documents, &3 evaluated, &4 versions
      source_result    TYPE zif_cd_ops_types=>ty_msgno VALUE '752',
      "! Outcome &1 of payment &2 run &3 &4
      trace_outcome    TYPE zif_cd_ops_types=>ty_msgno VALUE '753',
      "! Payment &1: method not in a watched method class - no outcome
      trace_not_watched TYPE zif_cd_ops_types=>ty_msgno VALUE '754',
      "! Outcome of payment &1 could not be evaluated:
      trace_unavailable TYPE zif_cd_ops_types=>ty_msgno VALUE '755',
      "! evidence &1: &2
      evidence_text    TYPE zif_cd_ops_types=>ty_msgno VALUE '756',
    END OF gc_msg.

ENDINTERFACE.
