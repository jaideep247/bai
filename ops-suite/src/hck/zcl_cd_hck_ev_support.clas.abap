*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_support.clas.abap
*& Purpose:
*& Shared helpers of the evidence plug-ins of the in-flight check: payment
*& reference forms (as stored and without leading zeros), comma lists,
*& document keys, run-date window, required rule parameters, evidence rows
*& the one statement-line read by reference (FEBEP-CHECT through the
*& payment trace repository), the cheque lines (one cheque read, one line
*& read, linked by cheque number suffix AND house bank account through the
*& shared ZCL_CD_OPS_CHEQUE_LINK - ambiguous lines attributed to none) and
*& the one G/L line read by XREF2 (runtime DAO), mapped back to the payment
*& document. No SQL of its own; read-only.
*& Modification log:
*& 2026-11-07 | Initial version (clearing / return evidence as plug-ins, user rule 5).
*& 2026-11-07 | Design review: lines_by_cheque (every eligible cheque kept, number suffix and house
*&            | bank account, CHEQUE_LINK_AMBIGUOUS), add_anomaly; ref_key delegates to the core link.
*& 2026-11-07 | Code review: one DFKKCR read per payment and check run shared by every cheque kind
*&            | (checks_of, memo of the run started by start_collection), cheque lines memo per suffix
*&            | length and payment set, the deciding (live) cheque of a payment, validation helpers of
*&            | the outcome configuration (register state tokens, outcome finding catalogue).
*& 2026-11-08 | status_of: the live payment status (DPAYH-ZZ_PAYMENT_STATUS, newest run row) read once
*&            | per payment and collection, shared by the payment and cheque status kinds and the
*&            | status-lag finding of A_INFLIGHT.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - helpers of the payment evidence plug-ins</p>
CLASS zcl_cd_hck_ev_support DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Statement line of a payment document
    TYPES:
      BEGIN OF ty_doc_line,
        doc1r TYPE zif_cd_hck_runtime_types=>ty_docno,
        line  TYPE zif_cd_ops_trace_types=>ty_bank_line,
        "! Cheque the line belongs to (cheque link; account = the line's statement account)
        ztnum TYPE zif_cd_ops_trace_types=>ty_ref,
      END OF ty_doc_line.
    TYPES tt_doc_line TYPE STANDARD TABLE OF ty_doc_line WITH EMPTY KEY
                      WITH NON-UNIQUE SORTED KEY by_doc COMPONENTS doc1r.
    TYPES:
      BEGIN OF ty_doc_lines,
        lines  TYPE tt_doc_line,
        capped TYPE abap_bool,
      END OF ty_doc_lines.
    "! G/L line of a payment document (found by company code + XREF2 = AUGBL)
    TYPES:
      BEGIN OF ty_gl_doc,
        doc1r TYPE zif_cd_hck_runtime_types=>ty_docno,
        line  TYPE zif_cd_hck_runtime_types=>ty_gl_xref2_line,
      END OF ty_gl_doc.
    TYPES tt_gl_doc TYPE STANDARD TABLE OF ty_gl_doc WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_gl_docs,
        lines  TYPE tt_gl_doc,
        capped TYPE abap_bool,
      END OF ty_gl_docs.

    "! Normalised reference (REF_KEY) and its stored form -> payment document
    TYPES:
      BEGIN OF ty_ref_doc,
        ref   TYPE string,
        raw   TYPE string,
        doc1r TYPE zif_cd_hck_runtime_types=>ty_docno,
      END OF ty_ref_doc.
    TYPES tt_ref_doc TYPE HASHED TABLE OF ty_ref_doc WITH UNIQUE KEY ref.

    "! A payment whose cheque fits a statement line that also fits another cheque of the same
    "! house bank account (the line is attributed to none)
    TYPES:
      BEGIN OF ty_ambiguous,
        doc1r  TYPE zif_cd_hck_runtime_types=>ty_docno,
        detail TYPE string,
      END OF ty_ambiguous.
    TYPES tt_ambiguous TYPE SORTED TABLE OF ty_ambiguous WITH NON-UNIQUE KEY doc1r.
    "! Cheque lines of payments: attributed lines, the cheques read (paying company code in BUKRS)
    "! and the payments of ambiguous lines
    TYPES:
      BEGIN OF ty_cheque_lines,
        lines     TYPE tt_doc_line,
        checks    TYPE zif_cd_ops_trace_types=>tt_check,
        ambiguous TYPE tt_ambiguous,
        capped    TYPE abap_bool,
      END OF ty_cheque_lines.

    "! Live payment status of a payment document (upper case)
    TYPES:
      BEGIN OF ty_pay_status,
        doc1r  TYPE zif_cd_hck_runtime_types=>ty_docno,
        status TYPE string,
      END OF ty_pay_status.
    TYPES tt_pay_status TYPE HASHED TABLE OF ty_pay_status WITH UNIQUE KEY doc1r.

    "! The deciding cheque of each payment document: the newest (house bank, account, number) cheque
    "! not voided; a payment whose cheques are all voided is decided by its newest cheque
    TYPES tt_live TYPE HASHED TABLE OF zif_cd_ops_trace_types=>ty_check WITH UNIQUE KEY doc1r.

    "! Starts the reads of one check run: the memos of an earlier run are dropped. Called by the
    "! in-flight check before its evidence kinds collect (and by their tests before each collect)
    CLASS-METHODS start_collection.

    "! Number of the current collection (evidence kinds compare it with their own memos)
    CLASS-METHODS generation
      RETURNING
        VALUE(rv_generation) TYPE i.

    "! Cheques of the payments (DFKKCR-DOC1R = AUGBL), the paying company code in BUKRS (DPAYH-BUKRS
    "! of the payment); each payment document is read once per collection, shared by every kind
    CLASS-METHODS checks_of
      IMPORTING
        it_payments      TYPE zif_cd_hck_runtime_types=>tt_issued_payment
      RETURNING
        VALUE(rt_checks) TYPE zif_cd_ops_trace_types=>tt_check.

    "! Live payment status DPAYH-ZZ_PAYMENT_STATUS of the newest payment run row of each payment
    "! document (proposal runs excluded; shared EBS read through the payment trace repository), in
    "! upper case; a document without run row has no entry. Each document is read once per
    "! collection, shared by the payment status kinds and the status-lag finding of A_INFLIGHT
    CLASS-METHODS status_of
      IMPORTING
        it_payments      TYPE zif_cd_hck_runtime_types=>tt_issued_payment
      RETURNING
        VALUE(rt_status) TYPE tt_pay_status.

    CLASS-METHODS live_cheques
      IMPORTING
        it_checks      TYPE zif_cd_ops_trace_types=>tt_check
      RETURNING
        VALUE(rt_live) TYPE tt_live.

    "! ZCD_HCK_SEQOUT-REG_STATE: comma list whose every token is BLANK or one register state character
    CLASS-METHODS reg_state_valid
      IMPORTING
        iv_value      TYPE clike
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

    "! ZCD_HCK_SEQOUT-FINDING: blank or a finding code of the in-flight check (catalogue below)
    CLASS-METHODS outcome_finding_valid
      IMPORTING
        iv_value      TYPE clike
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

    "! Finding codes an outcome row may name (each has its triage in Operations_Runbook.md)
    CLASS-METHODS outcome_findings
      RETURNING
        VALUE(rt_codes) TYPE string_table.

    "! Reference without blanks and leading zeros (FEBEP-CHECT, XREF2 and ZTNUM may carry the
    "! number with or without them - VERIFY in QA1)
    CLASS-METHODS ref_key
      IMPORTING
        iv_ref        TYPE clike
      RETURNING
        VALUE(rv_key) TYPE string.

    "! Upper-case tokens of a comma list
    CLASS-METHODS tokens
      IMPORTING
        iv_list          TYPE clike
      RETURNING
        VALUE(rt_tokens) TYPE string_table.

    CLASS-METHODS docnos
      IMPORTING
        it_payments     TYPE zif_cd_hck_runtime_types=>tt_issued_payment
      RETURNING
        VALUE(rt_docno) TYPE zif_cd_ops_trace_types=>tt_docno.

    "! Earliest run date of the payments (statement lines are read from there)
    CLASS-METHODS earliest_run
      IMPORTING
        it_payments    TYPE zif_cd_hck_runtime_types=>tt_issued_payment
      RETURNING
        VALUE(rv_date) TYPE d.

    "! The parameter value of a rule, raising when it is blank
    "! @raising zcx_cd_ops_error | parameter blank (message 665)
    CLASS-METHODS required_param
      IMPORTING
        iv_value        TYPE clike
        iv_name         TYPE clike
        is_rule         TYPE zif_cd_hck_runtime_types=>ty_clr_rule
      RETURNING
        VALUE(rv_value) TYPE string
      RAISING
        zcx_cd_ops_error.

    "! Statement lines whose FEBEP-CHECT is one of the references (as given and normalised),
    "! posted on or after iv_from, with the payment document of the reference; one read
    CLASS-METHODS lines_by_ref
      IMPORTING
        it_ref_doc      TYPE tt_ref_doc
        iv_from         TYPE d
        iv_max_rows     TYPE i
      RETURNING
        VALUE(rs_lines) TYPE ty_doc_lines.

    "! Statement lines of the payment documents (FEBEP-CHECT = AUGBL), from the earliest run
    CLASS-METHODS lines_by_doc
      IMPORTING
        it_payments     TYPE zif_cd_hck_runtime_types=>tt_issued_payment
        iv_max_rows     TYPE i
      RETURNING
        VALUE(rs_lines) TYPE ty_doc_lines.

    "! Statement lines of the payments' cheques (DFKKCR-DOC1R = AUGBL; one cheque read, one line
    "! read from the earliest run): a line belongs to a cheque only when FEBEP-CHECT is the last
    "! iv_length characters of DFKKCR-ZTNUM AND its statement account (FEBKO) is the cheque's paying
    "! house bank account (company code of the payment, DFKKCR-HBKID / HKTID); a line fitting several
    "! cheques of one account is attributed to none and each of their payments is listed as ambiguous
    CLASS-METHODS lines_by_cheque
      IMPORTING
        it_payments     TYPE zif_cd_hck_runtime_types=>tt_issued_payment
        iv_length       TYPE i
        iv_max_rows     TYPE i
      RETURNING
        VALUE(rs_lines) TYPE ty_cheque_lines.

    "! Sets an anomaly (code, severity, detail appended) on the evidence of a payment
    CLASS-METHODS add_anomaly
      IMPORTING
        iv_doc1r    TYPE zif_cd_hck_runtime_types=>ty_docno
        iv_code     TYPE zif_cd_ops_types=>ty_check_code
        iv_severity TYPE zif_cd_ops_types=>ty_severity
        iv_detail   TYPE string
      CHANGING
        ct_evidence TYPE zif_cd_hck_runtime_types=>tt_evidence.

    "! G/L lines (BSEG) of the payment documents by the stable key XREF2 = AUGBL (as stored and
    "! normalised) in the company code, fiscal years of the run dates up to the following year
    "! (calendar fiscal year assumed - VERIFY), optionally only the G/L accounts of iv_accounts
    CLASS-METHODS gl_lines_by_doc
      IMPORTING
        it_payments     TYPE zif_cd_hck_runtime_types=>tt_issued_payment
        iv_accounts     TYPE clike
        iv_max_rows     TYPE i
      RETURNING
        VALUE(rs_lines) TYPE ty_gl_docs.

    "! Adds one hit to the evidence of a payment (found, detail appended)
    CLASS-METHODS add_hit
      IMPORTING
        iv_doc1r    TYPE zif_cd_hck_runtime_types=>ty_docno
        iv_detail   TYPE string
        iv_found    TYPE abap_bool DEFAULT abap_true
      CHANGING
        ct_evidence TYPE zif_cd_hck_runtime_types=>tt_evidence.

    "! Detail text of a statement line (statement / line, BAI code, amount, date)
    CLASS-METHODS line_text
      IMPORTING
        is_line        TYPE zif_cd_ops_trace_types=>ty_bank_line
      RETURNING
        VALUE(rv_text) TYPE string.

  PRIVATE SECTION.
    CONSTANTS gc_detail_sep TYPE string VALUE `; `.
    "! One register state character (DFKKCR-STATE is CHAR 1) or the token for the blank state
    CONSTANTS gc_pcre_state TYPE string VALUE `[A-Z0-9]`.

    TYPES:
      BEGIN OF ty_memo_lines,
        length      TYPE i,
        fingerprint TYPE string,
        lines       TYPE ty_cheque_lines,
      END OF ty_memo_lines.
    TYPES tt_memo_lines TYPE HASHED TABLE OF ty_memo_lines WITH UNIQUE KEY length fingerprint.

    CLASS-DATA gv_generation TYPE i.
    "! Payment documents whose cheques were read in this collection
    CLASS-DATA gt_memo_docs TYPE zif_cd_ops_trace_types=>tt_docno.
    CLASS-DATA gt_memo_checks TYPE SORTED TABLE OF zif_cd_ops_trace_types=>ty_check
                              WITH NON-UNIQUE KEY doc1r.
    CLASS-DATA gt_memo_lines TYPE tt_memo_lines.
    "! Payment documents whose payment status was read in this collection, and the statuses found
    CLASS-DATA gt_memo_status_docs TYPE zif_cd_ops_trace_types=>tt_docno.
    CLASS-DATA gt_memo_status TYPE tt_pay_status.

ENDCLASS.



CLASS zcl_cd_hck_ev_support IMPLEMENTATION.

  METHOD ref_key.
    " One comparable form for every reference of the suite (shared with the cheque link)
    rv_key = zcl_cd_ops_cheque_link=>ref_key( iv_ref ).
  ENDMETHOD.


  METHOD tokens.
    LOOP AT zcl_cd_ops_util=>split_list( iv_list ) ASSIGNING FIELD-SYMBOL(<lv_token>).
      INSERT to_upper( condense( <lv_token> ) ) INTO TABLE rt_tokens.
    ENDLOOP.
  ENDMETHOD.


  METHOD docnos.
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      INSERT <ls_payment>-doc1r INTO TABLE rt_docno.
    ENDLOOP.
  ENDMETHOD.


  METHOD earliest_run.
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      IF rv_date IS INITIAL OR <ls_payment>-laufd < rv_date.
        rv_date = <ls_payment>-laufd.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD required_param.
    rv_value = condense( CONV string( iv_value ) ).
    IF rv_value IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e665(zcd_ops) WITH is_rule-evidence_class iv_name |{ is_rule-flow }{ is_rule-method_class }|
                                   is_rule-purpose.
    ENDIF.
  ENDMETHOD.


  METHOD lines_by_ref.
    DATA lt_refs TYPE zif_cd_ops_trace_types=>tt_ref.
    IF it_ref_doc IS INITIAL OR iv_max_rows <= 0.
      RETURN.
    ENDIF.
    LOOP AT it_ref_doc ASSIGNING FIELD-SYMBOL(<ls_ref>).
      INSERT CONV #( <ls_ref>-ref ) INTO TABLE lt_refs.
      " The stored form (e.g. the CHAR 12 document number with leading zeros)
      INSERT CONV #( <ls_ref>-raw ) INTO TABLE lt_refs.
    ENDLOOP.
    DATA(lt_lines) = zcl_cd_ops_factory=>get_trace_dao( )->get_bank_lines( it_ref      = lt_refs
                                                                         iv_from     = iv_from
                                                                         iv_max_rows = iv_max_rows ).
    rs_lines-capped = xsdbool( lines( lt_lines ) >= iv_max_rows ).
    LOOP AT lt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      READ TABLE it_ref_doc ASSIGNING FIELD-SYMBOL(<ls_doc>) WITH TABLE KEY ref = ref_key( <ls_line>-chect ).
      IF sy-subrc = 0.
        INSERT VALUE #( doc1r = <ls_doc>-doc1r line = <ls_line> ) INTO TABLE rs_lines-lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD lines_by_doc.
    DATA lt_ref_doc TYPE tt_ref_doc.
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      INSERT VALUE #( ref   = ref_key( <ls_payment>-doc1r )
                      raw   = <ls_payment>-doc1r
                      doc1r = <ls_payment>-doc1r ) INTO TABLE lt_ref_doc.
    ENDLOOP.
    rs_lines = lines_by_ref( it_ref_doc  = lt_ref_doc
                             iv_from     = earliest_run( it_payments )
                             iv_max_rows = iv_max_rows ).
  ENDMETHOD.


  METHOD start_collection.
    gv_generation = gv_generation + 1.
    CLEAR: gt_memo_docs, gt_memo_checks, gt_memo_lines, gt_memo_status_docs, gt_memo_status.
  ENDMETHOD.


  METHOD generation.
    rv_generation = gv_generation.
  ENDMETHOD.


  METHOD checks_of.
    TYPES:
      BEGIN OF ty_doc_bukrs,
        doc1r TYPE zif_cd_hck_runtime_types=>ty_docno,
        bukrs TYPE zif_cd_ops_trace_types=>ty_bukrs,
      END OF ty_doc_bukrs.
    DATA lt_bukrs TYPE HASHED TABLE OF ty_doc_bukrs WITH UNIQUE KEY doc1r.
    DATA lt_missing TYPE zif_cd_ops_trace_types=>tt_docno.
    DATA ls_check TYPE zif_cd_ops_trace_types=>ty_check.
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      INSERT VALUE #( doc1r = <ls_payment>-doc1r bukrs = <ls_payment>-bukrs ) INTO TABLE lt_bukrs.
      IF NOT line_exists( gt_memo_docs[ table_line = <ls_payment>-doc1r ] ).
        INSERT <ls_payment>-doc1r INTO TABLE lt_missing.
      ENDIF.
    ENDLOOP.
    " One read for the documents not read yet in this collection
    IF lt_missing IS NOT INITIAL.
      LOOP AT zcl_cd_ops_factory=>get_trace_dao( )->get_checks_by_doc( lt_missing ) ASSIGNING FIELD-SYMBOL(<ls_read>).
        ls_check = <ls_read>.
        " The paying company code of a cheque is the company code of its payment (DPAYH-BUKRS)
        IF ls_check-bukrs IS INITIAL.
          ls_check-bukrs = VALUE #( lt_bukrs[ doc1r = ls_check-doc1r ]-bukrs OPTIONAL ).
        ENDIF.
        INSERT ls_check INTO TABLE gt_memo_checks.
      ENDLOOP.
      INSERT LINES OF lt_missing INTO TABLE gt_memo_docs.
    ENDIF.
    LOOP AT lt_bukrs ASSIGNING FIELD-SYMBOL(<ls_doc>).
      LOOP AT gt_memo_checks ASSIGNING FIELD-SYMBOL(<ls_memo>) WHERE doc1r = <ls_doc>-doc1r.
        INSERT <ls_memo> INTO TABLE rt_checks.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD status_of.
    DATA lt_missing TYPE zif_cd_ops_trace_types=>tt_docno.
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      IF NOT line_exists( gt_memo_status_docs[ table_line = <ls_payment>-doc1r ] ).
        INSERT <ls_payment>-doc1r INTO TABLE lt_missing.
      ENDIF.
    ENDLOOP.
    " One read for the documents not read yet in this collection; newest run first per document:
    " the first row of a document is its live status
    IF lt_missing IS NOT INITIAL.
      LOOP AT zcl_cd_ops_factory=>get_trace_dao( )->get_payment_runs( lt_missing ) ASSIGNING FIELD-SYMBOL(<ls_run>).
        IF NOT line_exists( gt_memo_status[ doc1r = <ls_run>-doc1r ] ).
          INSERT VALUE #( doc1r  = <ls_run>-doc1r
                          status = to_upper( condense( CONV string( <ls_run>-status ) ) ) ) INTO TABLE gt_memo_status.
        ENDIF.
      ENDLOOP.
      INSERT LINES OF lt_missing INTO TABLE gt_memo_status_docs.
    ENDIF.
    LOOP AT it_payments ASSIGNING <ls_payment>.
      READ TABLE gt_memo_status ASSIGNING FIELD-SYMBOL(<ls_status>) WITH TABLE KEY doc1r = <ls_payment>-doc1r.
      IF sy-subrc = 0 AND NOT line_exists( rt_status[ doc1r = <ls_status>-doc1r ] ).
        INSERT <ls_status> INTO TABLE rt_status.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD live_cheques.
    DATA(lt_sorted) = it_checks.
    SORT lt_sorted BY doc1r hbkid hktid ztnum.
    " Newest last: a cheque not voided replaces any earlier one, a voided one only a voided one
    LOOP AT lt_sorted ASSIGNING FIELD-SYMBOL(<ls_check>).
      DATA(lv_voided) = xsdbool( to_upper( condense( CONV string( <ls_check>-state ) ) )
                                 = zif_cd_hck_runtime_types=>gc_state_voided ).
      READ TABLE rt_live ASSIGNING FIELD-SYMBOL(<ls_live>) WITH TABLE KEY doc1r = <ls_check>-doc1r.
      IF sy-subrc <> 0.
        INSERT <ls_check> INTO TABLE rt_live.
      ELSEIF lv_voided = abap_false
          OR to_upper( condense( CONV string( <ls_live>-state ) ) ) = zif_cd_hck_runtime_types=>gc_state_voided.
        <ls_live> = <ls_check>.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD reg_state_valid.
    rv_yes = abap_true.
    LOOP AT zcl_cd_ops_util=>split_list( iv_value ) ASSIGNING FIELD-SYMBOL(<lv_token>).
      DATA(lv_token) = condense( <lv_token> ).
      IF lv_token <> zif_cd_hck_runtime_types=>gc_state_blank
         AND zcl_cd_ops_util=>pcre_match( iv_value = lv_token iv_pattern = gc_pcre_state ) = abap_false.
        rv_yes = abap_false.
        RETURN.
      ENDIF.
      " Upper case only (the match ignores case)
      IF lv_token <> to_upper( lv_token ).
        rv_yes = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD outcome_finding_valid.
    DATA(lv_value) = condense( CONV string( iv_value ) ).
    DATA(lt_codes) = outcome_findings( ).
    rv_yes = xsdbool( lv_value IS INITIAL OR line_exists( lt_codes[ table_line = lv_value ] ) ).
  ENDMETHOD.


  METHOD outcome_findings.
    rt_codes = VALUE #( ( CONV #( zif_cd_hck_runtime_types=>gc_code-cheque_clarify ) )
                        ( CONV #( zif_cd_hck_runtime_types=>gc_code-manual_clearing ) )
                        ( CONV #( zif_cd_hck_runtime_types=>gc_code-return_inconsist ) )
                        ( CONV #( zif_cd_hck_runtime_types=>gc_code-clearing_inconsist ) )
                        ( CONV #( zif_cd_hck_runtime_types=>gc_code-cheque_amount ) )
                        ( CONV #( zif_cd_hck_runtime_types=>gc_code-unexpected_seq ) )
                        ( CONV #( zif_cd_hck_runtime_types=>gc_code-pending_overdue ) ) ).
  ENDMETHOD.


  METHOD lines_by_cheque.
    DATA(lt_docno) = docnos( it_payments ).
    IF lt_docno IS INITIAL OR iv_max_rows <= 0.
      RETURN.
    ENDIF.
    " The same payments and suffix length (e.g. two kinds of one class) are linked once per collection
    DATA(lv_fingerprint) = concat_lines_of( table = lt_docno ).
    READ TABLE gt_memo_lines ASSIGNING FIELD-SYMBOL(<ls_memo>)
         WITH TABLE KEY length = iv_length fingerprint = lv_fingerprint.
    IF sy-subrc = 0.
      rs_lines = <ls_memo>-lines.
      RETURN.
    ENDIF.
    LOOP AT checks_of( it_payments ) ASSIGNING FIELD-SYMBOL(<ls_read>) WHERE ztnum IS NOT INITIAL.
      INSERT <ls_read> INTO TABLE rs_lines-checks.
    ENDLOOP.
    DATA(lt_refs) = zcl_cd_ops_cheque_link=>query_refs( it_checks = rs_lines-checks iv_length = iv_length ).
    IF lt_refs IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_lines) = zcl_cd_ops_factory=>get_trace_dao( )->get_bank_lines( it_ref      = lt_refs
                                                                         iv_from     = earliest_run( it_payments )
                                                                         iv_max_rows = iv_max_rows ).
    rs_lines-capped = xsdbool( lines( lt_lines ) >= iv_max_rows ).
    LOOP AT zcl_cd_ops_cheque_link=>link( it_checks = rs_lines-checks
                                          it_lines  = lt_lines
                                          iv_length = iv_length ) ASSIGNING FIELD-SYMBOL(<ls_link>).
      IF <ls_link>-candidates = 1.
        INSERT VALUE #( doc1r = <ls_link>-doc1r line = <ls_link>-line ztnum = <ls_link>-ztnum ) INTO TABLE rs_lines-lines.
        CONTINUE.
      ENDIF.
      " Several eligible cheques: no cashing evidence is inherited, every payment is told
      LOOP AT <ls_link>-docs ASSIGNING FIELD-SYMBOL(<lv_doc>).
        INSERT VALUE #( doc1r = <lv_doc> detail = <ls_link>-detail ) INTO TABLE rs_lines-ambiguous.
      ENDLOOP.
    ENDLOOP.
    INSERT VALUE #( length = iv_length fingerprint = lv_fingerprint lines = rs_lines ) INTO TABLE gt_memo_lines.
  ENDMETHOD.


  METHOD add_anomaly.
    READ TABLE ct_evidence ASSIGNING FIELD-SYMBOL(<ls_evidence>) WITH TABLE KEY doc1r = iv_doc1r.
    IF sy-subrc <> 0.
      INSERT VALUE #( doc1r = iv_doc1r ) INTO TABLE ct_evidence ASSIGNING <ls_evidence>.
    ENDIF.
    <ls_evidence>-anomaly  = iv_code.
    <ls_evidence>-severity = iv_severity.
    IF iv_detail IS NOT INITIAL.
      <ls_evidence>-detail = COND #( WHEN <ls_evidence>-detail IS INITIAL THEN iv_detail
                                     ELSE |{ <ls_evidence>-detail }{ gc_detail_sep }{ iv_detail }| ).
    ENDIF.
  ENDMETHOD.


  METHOD gl_lines_by_doc.
    TYPES:
      BEGIN OF ty_key_doc,
        bukrs TYPE c LENGTH 4,
        ref   TYPE string,
        doc1r TYPE zif_cd_hck_runtime_types=>ty_docno,
      END OF ty_key_doc.
    DATA lt_key_doc TYPE HASHED TABLE OF ty_key_doc WITH UNIQUE KEY bukrs ref.
    DATA lt_keys TYPE zif_cd_hck_runtime_types=>tt_xref2_key.
    DATA lt_hkont TYPE zif_cd_hck_runtime_types=>tt_hkont.
    DATA lv_last TYPE d.
    IF it_payments IS INITIAL OR iv_max_rows <= 0.
      RETURN.
    ENDIF.
    LOOP AT tokens( iv_accounts ) ASSIGNING FIELD-SYMBOL(<lv_account>).
      INSERT CONV #( |{ <lv_account> ALPHA = IN WIDTH = 10 }| ) INTO TABLE lt_hkont.
    ENDLOOP.
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      DATA(lv_ref) = ref_key( <ls_payment>-doc1r ).
      INSERT VALUE #( bukrs = <ls_payment>-bukrs xref2 = <ls_payment>-doc1r ) INTO TABLE lt_keys.
      INSERT VALUE #( bukrs = <ls_payment>-bukrs xref2 = lv_ref ) INTO TABLE lt_keys.
      INSERT VALUE #( bukrs = <ls_payment>-bukrs ref = lv_ref doc1r = <ls_payment>-doc1r ) INTO TABLE lt_key_doc.
      lv_last = nmax( val1 = lv_last val2 = <ls_payment>-laufd ).
    ENDLOOP.
    DATA(lv_first) = earliest_run( it_payments ).
    DATA(lt_lines) = zcl_cd_hck_factory=>get_runtime_dao( )->get_gl_lines_by_xref2(
                       it_keys       = lt_keys
                       iv_gjahr_from = CONV #( lv_first(4) )
                       iv_gjahr_to   = CONV #( lv_last(4) + 1 )
                       it_hkont      = lt_hkont
                       iv_max_rows   = iv_max_rows ).
    rs_lines-capped = xsdbool( lines( lt_lines ) >= iv_max_rows ).
    LOOP AT lt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      READ TABLE lt_key_doc ASSIGNING FIELD-SYMBOL(<ls_doc>)
           WITH TABLE KEY bukrs = <ls_line>-bukrs ref = ref_key( <ls_line>-xref2 ).
      IF sy-subrc = 0.
        INSERT VALUE #( doc1r = <ls_doc>-doc1r line = <ls_line> ) INTO TABLE rs_lines-lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD add_hit.
    READ TABLE ct_evidence ASSIGNING FIELD-SYMBOL(<ls_evidence>) WITH TABLE KEY doc1r = iv_doc1r.
    IF sy-subrc <> 0.
      INSERT VALUE #( doc1r = iv_doc1r ) INTO TABLE ct_evidence ASSIGNING <ls_evidence>.
    ENDIF.
    IF iv_found = abap_true.
      <ls_evidence>-found = abap_true.
      <ls_evidence>-hits  = <ls_evidence>-hits + 1.
    ENDIF.
    IF iv_detail IS NOT INITIAL.
      <ls_evidence>-detail = COND #( WHEN <ls_evidence>-detail IS INITIAL THEN iv_detail
                                     ELSE |{ <ls_evidence>-detail }{ gc_detail_sep }{ iv_detail }| ).
    ENDIF.
  ENDMETHOD.


  METHOD line_text.
    rv_text = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_bank_line
                                     iv_v1    = |{ is_line-kukey }/{ is_line-esnum }|
                                     iv_v2    = is_line-vorgc
                                     iv_v3    = |{ is_line-kwbtr STYLE = SIMPLE }|
                                     iv_v4    = |{ is_line-budat DATE = ISO }| ).
  ENDMETHOD.

ENDCLASS.
