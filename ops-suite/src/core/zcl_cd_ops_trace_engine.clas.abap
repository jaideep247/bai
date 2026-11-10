*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_trace_engine.clas.abap
*& Purpose:
*& Read-only 360 degree payment trace: from FIN ID + source (or clearing
*& document / cheque number) through the payment request, open item,
*& clearing-reset history, payment run or cheque, generated file, PRISM
*& handoff, bank ACK, bank line / return, payment engine clearing and G/L
*& transfer. Every payment attempt (current and historical clearing
*& reference) is traced separately. Each stage is VERIFIED (source, key,
*& time), MISSING, AMBIGUOUS (all candidates), UNAVAILABLE (not configured,
*& not readable, not authorised), FAILED or NOT_APPLICABLE; incomplete
*& evidence never yields COMPLETE. Pure logic: reads only through
*& ZIF_CD_OPS_TRACE_DAO, writes nothing, posts nothing, starts no job.
*& Modification log:
*& 2026-11-06 | Initial version (360 degree payment trace).
*& 2026-11-06 | Partner mismatch, history unavailable on reversal, FMON digest references and
*&            | file date window, cheque history unavailable, test-first review fixes.
*& 2026-11-06 | Sorted/hashed sweep: keyed lookups by sorted secondary keys / hashed tables (Performance_Review.md).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Return / NOC reasons: return rows show DFKKRP-RLGRD (different reasons = AMBIGUOUS row);
*&            | NOC evidence row per attempt (DFKKNRP by INFOF), informational - never decides the verdict.
*& 2026-11-06 | stage_file returns the file links (RETURNING instead of a single EXPORTING parameter).
*& 2026-11-07 | Reversal = clearing reason ZIF_CD_OPS_TRACE_TYPES=>GC_REVERSAL_AUGRD (05, the only
*&            | reversal reason); parameter TRACE_REVERSAL_AUGRD removed.
*& 2026-11-07 | Parameters through ZCL_CD_OPS_FACTORY=>GET_PARAMS (ZIF_CD_OPS_PARAMS).
*& 2026-11-07 | Cheque settlement lines through the shared link ZCL_CD_OPS_CHEQUE_LINK (cheque number
*&            | AND statement house bank account = the cheque's; a line of another account is not the
*&            | cheque's, a line fitting several cheques of the attempt is one AMBIGUOUS row).
*& 2026-11-07 | Stage OUTCOME: the canonical outcome of each current attempt by the shared evaluator
*&            | ZIF_CD_OPS_PAY_OUTCOME (the verdict of A_INFLIGHT and the transactions dashboard), FIN in
*&            | two sources = AMBIGUOUS; informational for the evidence verdict (as NOC); result outcome.
*& 2026-11-08 | TO_DATE / TO_TIME public: the status-lag finding of A_INFLIGHT reads the ACK time of the
*&            | same configured ACK source (TRACE_SRC_ACK) with the same conversion; no behaviour change.
*& 2026-11-08 | Source spec keys DUE and AMOUNT (request log: requested payment date, amount).
*& 2026-11-08 | Search by payment reference / cheque number (REFERENCE_DOCUMENTS: the payment document, the cheque
*&            | number full or its last 13 characters - keyed DFKKCR reads only); stage REQUEST_DUE: due date and
*&            | stage of every request seen (one rule with the payment worklist, information only).
*& 2026-11-10 | A BP_SOURCE_FIELD the partner read refuses is a CONFIGURATION row (815), no longer cleared
*&            | silently; the row never decides the verdict.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment trace - evidence timeline engine</p>
CLASS zcl_cd_ops_trace_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Trace one payment. Never raises: a source that cannot be read is an UNAVAILABLE row
    METHODS trace
      IMPORTING
        is_input         TYPE zif_cd_ops_trace_types=>ty_trace_input
      RETURNING
        VALUE(rs_result) TYPE zif_cd_ops_trace_types=>ty_trace_result.

    "! 'TABLE=X;KEY=Y;...' of a TRACE_SRC_* parameter -> source configuration (upper case)
    CLASS-METHODS parse_source
      IMPORTING
        iv_param      TYPE zif_cd_ops_types=>ty_param_name
        iv_spec       TYPE clike
      RETURNING
        VALUE(rs_cfg) TYPE zif_cd_ops_trace_types=>ty_source_cfg.

    "! Keeps the last four characters, masks the rest (member numbers, bank data)
    CLASS-METHODS mask
      IMPORTING
        iv_value         TYPE clike
      RETURNING
        VALUE(rv_masked) TYPE string.

    "! Date of a configured source value: YYYYMMDD, or the date part of a time stamp; else blank
    CLASS-METHODS to_date
      IMPORTING
        iv_value       TYPE clike
      RETURNING
        VALUE(rv_date) TYPE d.

    "! Time of a configured source value: hhmmss, or the time part of a time stamp; else blank
    CLASS-METHODS to_time
      IMPORTING
        iv_value       TYPE clike
      RETURNING
        VALUE(rv_time) TYPE t.

  PRIVATE SECTION.
    CONSTANTS gc_digits TYPE string VALUE `0123456789`.
    CONSTANTS gc_date_length TYPE i VALUE 8.
    CONSTANTS gc_time_length TYPE i VALUE 6.

    TYPES:
      BEGIN OF ty_config,
        max_rows        TYPE i,
        request         TYPE zif_cd_ops_trace_types=>ty_source_cfg,
        history         TYPE zif_cd_ops_trace_types=>ty_source_cfg,
        regut           TYPE zif_cd_ops_trace_types=>ty_source_cfg,
        ack             TYPE zif_cd_ops_trace_types=>ty_source_cfg,
        chq_hist        TYPE zif_cd_ops_trace_types=>ty_source_cfg,
        bp_source_field TYPE zif_cd_ops_trace_types=>ty_fieldname,
        success         TYPE string,
        awtyp           TYPE zif_cd_ops_trace_types=>ty_key_value,
        cheque_methods  TYPE string,
        no_ack_methods  TYPE string,
        nack_values     TYPE string,
        chq_failed      TYPE string,
        lookback        TYPE i,
      END OF ty_config.

    TYPES:
      BEGIN OF ty_attempt,
        no         TYPE i,
        kind       TYPE zif_cd_ops_trace_types=>ty_attempt_kind,
        ref        TYPE zif_cd_ops_trace_types=>ty_docno,
        item_opbel TYPE zif_cd_ops_trace_types=>ty_docno,
        bukrs      TYPE zif_cd_ops_trace_types=>ty_bukrs,
        pymet      TYPE zif_cd_ops_trace_types=>ty_pymet,
        "! Clearing date (current attempt); initial for a historical attempt
        augdt      TYPE d,
        "! Reset date / time of a historical clearing (history source)
        hist_date  TYPE d,
        hist_time  TYPE t,
        hist_table TYPE zif_cd_ops_trace_types=>ty_tabname,
      END OF ty_attempt.
    TYPES tt_attempt TYPE STANDARD TABLE OF ty_attempt WITH EMPTY KEY.

    "! Outcome of a configured-source read
    TYPES:
      BEGIN OF ty_read,
        rows   TYPE zif_cd_ops_trace_types=>tt_cfg_row,
        status TYPE zif_cd_ops_trace_types=>ty_status,
        reason TYPE zif_cd_ops_trace_types=>ty_reason,
        text   TYPE string,
      END OF ty_read.

    "! Generated file: correlation key as file monitoring stores it + full reference (A100)
    TYPES:
      BEGIN OF ty_file_link,
        ref  TYPE zif_cd_ops_trace_types=>ty_file_ref,
        name TYPE string,
      END OF ty_file_link.
    TYPES tt_file_link TYPE SORTED TABLE OF ty_file_link WITH UNIQUE KEY ref name.

    "! Row template: stage, status, reason and evidence of one row
    TYPES ty_row TYPE zif_cd_ops_trace_types=>ty_trace_row.

    DATA mo_dao TYPE REF TO zif_cd_ops_trace_dao.
    DATA ms_cfg TYPE ty_config.
    "! Requests (FIN + source) with a SUCCESS row seen by the trace: their due date and stage are shown
    DATA mt_req_keys TYPE zif_cd_ops_payout_types=>tt_req_key.
    DATA mt_rows TYPE zif_cd_ops_trace_types=>tt_trace_row.
    DATA mt_items TYPE zif_cd_ops_trace_types=>tt_item.
    DATA mt_headers TYPE zif_cd_ops_trace_types=>tt_doc_header.
    DATA mt_attempts TYPE tt_attempt.
    DATA mv_found TYPE abap_bool.

    METHODS load_config.

    METHODS read_source
      IMPORTING
        is_source      TYPE zif_cd_ops_trace_types=>ty_source_cfg
        is_key         TYPE zif_cd_ops_trace_types=>ty_cfg_key
        iv_match_key2  TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rs_read) TYPE ty_read.

    METHODS find_items
      IMPORTING
        is_input TYPE zif_cd_ops_trace_types=>ty_trace_input.

    METHODS trace_request
      IMPORTING
        iv_fin           TYPE zif_cd_ops_trace_types=>ty_fin
        iv_source        TYPE zif_cd_ops_trace_types=>ty_source
      RETURNING
        VALUE(rv_member) TYPE zif_cd_ops_trace_types=>ty_key_value.

    "! Partner of the member number: with source first, then without (legacy PCLM)
    METHODS resolve_partner
      IMPORTING
        iv_member         TYPE zif_cd_ops_trace_types=>ty_key_value
        iv_source         TYPE zif_cd_ops_trace_types=>ty_source
      EXPORTING
        ev_partner        TYPE zif_cd_ops_trace_types=>ty_partner
        ev_without_source TYPE abap_bool.

    METHODS check_items
      IMPORTING
        iv_partner        TYPE zif_cd_ops_trace_types=>ty_partner
        iv_without_source TYPE abap_bool
        iv_fin            TYPE zif_cd_ops_trace_types=>ty_fin.

    METHODS trace_history.

    METHODS build_attempts
      IMPORTING
        it_history TYPE tt_attempt.

    METHODS trace_attempt
      IMPORTING
        is_attempt TYPE ty_attempt.

    METHODS stage_payment
      IMPORTING
        is_attempt TYPE ty_attempt
        iv_cheque  TYPE abap_bool
      EXPORTING
        et_runs    TYPE zif_cd_ops_trace_types=>tt_payment_run
        et_checks  TYPE zif_cd_ops_trace_types=>tt_check.

    METHODS stage_file
      IMPORTING
        is_attempt      TYPE ty_attempt
        it_runs         TYPE zif_cd_ops_trace_types=>tt_payment_run
      RETURNING
        VALUE(rt_links) TYPE tt_file_link.

    METHODS stage_prism
      IMPORTING
        is_attempt   TYPE ty_attempt
        it_runs      TYPE zif_cd_ops_trace_types=>tt_payment_run
        it_links     TYPE tt_file_link
      EXPORTING
        et_files     TYPE zif_cd_ops_trace_types=>tt_fmon_file
        et_events    TYPE zif_cd_ops_trace_types=>tt_fmon_event.

    METHODS stage_bank_ack
      IMPORTING
        is_attempt TYPE ty_attempt
        it_files   TYPE zif_cd_ops_trace_types=>tt_fmon_file
        it_events  TYPE zif_cd_ops_trace_types=>tt_fmon_event.

    METHODS stage_settlement
      IMPORTING
        is_attempt TYPE ty_attempt
        iv_cheque  TYPE abap_bool
        it_checks  TYPE zif_cd_ops_trace_types=>tt_check.

    METHODS stage_clearing_and_gl
      IMPORTING
        is_attempt TYPE ty_attempt
        iv_cheque  TYPE abap_bool.

    "! NOC (notification of change) of the attempt: DFKKNRP items whose INFOF holds the
    "! clearing document or a payment reference of the attempt (FIN, cheque number).
    "! Informational: VERIFIED / AMBIGUOUS / NOT_APPLICABLE, never MISSING, no verdict impact
    METHODS stage_noc
      IMPORTING
        is_attempt TYPE ty_attempt
        it_checks  TYPE zif_cd_ops_trace_types=>tt_check.

    "! Canonical outcome of every current attempt (one evaluation for all attempts): the same
    "! evaluator as A_INFLIGHT and the 5-minute snapshot; informational for the evidence verdict
    METHODS stage_outcome
      CHANGING
        cs_result TYPE zif_cd_ops_trace_types=>ty_trace_result.

    "! Due date and stage of every request seen (the one rule of the payment worklist): information
    "! like the outcome - VERIFIED paid on time, open and not due or cancelled; FAILED not paid by the end
    "! of its due date or paid late; UNAVAILABLE when the request rule cannot be evaluated
    METHODS stage_request_due.

    "! Payment documents of a payment reference: the document itself (as given and zero-padded) and the
    "! payment documents of the cheques whose number is the reference, full or its last 13 characters
    "! (as given, without leading zeros, zero-padded) - keyed reads of DFKKCR-ZTNUM only, capped
    METHODS reference_documents
      IMPORTING
        iv_ref          TYPE zif_cd_ops_trace_types=>ty_ref
      RETURNING
        VALUE(rt_docno) TYPE zif_cd_ops_trace_types=>tt_docno.

    "! Evidence status of an outcome row: VERIFIED (outcome known), AMBIGUOUS, FAILED
    "! (inconsistent evidence), UNAVAILABLE (undetermined)
    CLASS-METHODS outcome_status
      IMPORTING
        iv_outcome       TYPE zif_cd_ops_payout_types=>ty_outcome
      RETURNING
        VALUE(rv_status) TYPE zif_cd_ops_trace_types=>ty_status.

    "! Comparable form of a document number / reference: condensed, leading zeros of an
    "! all-digit value removed
    CLASS-METHODS canonical
      IMPORTING
        iv_value        TYPE clike
      RETURNING
        VALUE(rv_value) TYPE string.

    "! One row per candidate: 0 = MISSING, 1 = VERIFIED, more or row cap = AMBIGUOUS
    METHODS candidate_status
      IMPORTING
        iv_count         TYPE i
      EXPORTING
        ev_status        TYPE zif_cd_ops_trace_types=>ty_status
        ev_reason        TYPE zif_cd_ops_trace_types=>ty_reason.

    METHODS add_row
      IMPORTING
        is_attempt TYPE ty_attempt OPTIONAL
        is_row     TYPE ty_row.

    "! Row for a stage that could not be evaluated (no link key from an earlier stage)
    METHODS add_no_link
      IMPORTING
        is_attempt   TYPE ty_attempt
        iv_stage     TYPE zif_cd_ops_trace_types=>ty_stage
        iv_after     TYPE zif_cd_ops_trace_types=>ty_stage.

    METHODS finish
      CHANGING
        cs_result TYPE zif_cd_ops_trace_types=>ty_trace_result.

    METHODS is_allowed
      IMPORTING
        iv_bukrs          TYPE zif_cd_ops_trace_types=>ty_bukrs
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

    CLASS-METHODS stage_seq
      IMPORTING
        iv_stage      TYPE zif_cd_ops_trace_types=>ty_stage
      RETURNING
        VALUE(rv_seq) TYPE i.

    CLASS-METHODS light
      IMPORTING
        iv_status       TYPE zif_cd_ops_trace_types=>ty_status
      RETURNING
        VALUE(rv_light) TYPE char1.

    CLASS-METHODS in_list
      IMPORTING
        iv_value     TYPE clike
        iv_list      TYPE string
      RETURNING
        VALUE(rv_in) TYPE abap_bool.

    "! Positive whole number of a parameter, else the default
    CLASS-METHODS to_int
      IMPORTING
        iv_value      TYPE string
        iv_default    TYPE i
      RETURNING
        VALUE(rv_int) TYPE i.

    CLASS-METHODS is_gap
      IMPORTING
        iv_status     TYPE zif_cd_ops_trace_types=>ty_status
      RETURNING
        VALUE(rv_gap) TYPE abap_bool.

    CLASS-METHODS key_text
      IMPORTING
        iv_part1       TYPE clike
        iv_part2       TYPE clike OPTIONAL
        iv_part3       TYPE clike OPTIONAL
      RETURNING
        VALUE(rv_text) TYPE zif_cd_ops_trace_types=>ty_record_key.

ENDCLASS.



CLASS zcl_cd_ops_trace_engine IMPLEMENTATION.

  METHOD trace.
    CLEAR: mt_rows, mt_items, mt_headers, mt_attempts, mv_found, mt_req_keys.
    rs_result-input = is_input.
    mo_dao = zcl_cd_ops_factory=>get_trace_dao( ).
    load_config( ).

    find_items( is_input ).
    stage_request_due( ).
    IF mt_items IS NOT INITIAL.
      trace_history( ).
      LOOP AT mt_attempts INTO DATA(ls_attempt).
        trace_attempt( ls_attempt ).
      ENDLOOP.
      stage_outcome( CHANGING cs_result = rs_result ).
    ENDIF.
    finish( CHANGING cs_result = rs_result ).
  ENDMETHOD.


  METHOD load_config.
    DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
    ms_cfg-max_rows = to_int( iv_value   = lo_params->get_param( zif_cd_ops_trace_types=>gc_param-max_rows )
                              iv_default = zif_cd_ops_trace_types=>gc_default-max_rows ).
    ms_cfg-request  = parse_source( iv_param = zif_cd_ops_trace_types=>gc_param-src_request
                                    iv_spec  = lo_params->get_param( zif_cd_ops_trace_types=>gc_param-src_request ) ).
    ms_cfg-history  = parse_source( iv_param = zif_cd_ops_trace_types=>gc_param-src_history
                                    iv_spec  = lo_params->get_param( zif_cd_ops_trace_types=>gc_param-src_history ) ).
    ms_cfg-regut    = parse_source( iv_param = zif_cd_ops_trace_types=>gc_param-src_regut
                                    iv_spec  = lo_params->get_param( zif_cd_ops_trace_types=>gc_param-src_regut ) ).
    ms_cfg-ack      = parse_source( iv_param = zif_cd_ops_trace_types=>gc_param-src_ack
                                    iv_spec  = lo_params->get_param( zif_cd_ops_trace_types=>gc_param-src_ack ) ).
    ms_cfg-chq_hist = parse_source( iv_param = zif_cd_ops_trace_types=>gc_param-src_chq_hist
                                    iv_spec  = lo_params->get_param( zif_cd_ops_trace_types=>gc_param-src_chq_hist ) ).
    ms_cfg-bp_source_field = to_upper( condense( lo_params->get_param( zif_cd_ops_trace_types=>gc_param-bp_source_field ) ) ).
    ms_cfg-success = lo_params->get_param( iv_name    = zif_cd_ops_trace_types=>gc_param-success_value
                                          iv_default = zif_cd_ops_trace_types=>gc_default-success_value ).
    ms_cfg-awtyp = lo_params->get_param( iv_name    = zif_cd_ops_trace_types=>gc_param-gl_awtyp
                                        iv_default = zif_cd_ops_trace_types=>gc_default-gl_awtyp ).
    ms_cfg-cheque_methods = lo_params->get_param( iv_name    = zif_cd_ops_trace_types=>gc_param-cheque_methods
                                                 iv_default = zif_cd_ops_trace_types=>gc_default-cheque_methods ).
    ms_cfg-no_ack_methods = lo_params->get_param( zif_cd_ops_trace_types=>gc_param-no_ack_methods ).
    ms_cfg-nack_values = lo_params->get_param( iv_name    = zif_cd_ops_trace_types=>gc_param-ack_nack_values
                                              iv_default = zif_cd_ops_trace_types=>gc_default-ack_nack_values ).
    ms_cfg-chq_failed = lo_params->get_param( iv_name    = zif_cd_ops_trace_types=>gc_param-chq_failed_values
                                             iv_default = zif_cd_ops_trace_types=>gc_default-chq_failed_values ).
    ms_cfg-lookback = to_int( iv_value   = lo_params->get_param( zif_cd_ops_trace_types=>gc_param-bank_lookback )
                              iv_default = zif_cd_ops_trace_types=>gc_default-bank_lookback ).
  ENDMETHOD.


  METHOD parse_source.
    rs_cfg-param = iv_param.
    SPLIT iv_spec AT zif_cd_ops_trace_types=>gc_spec_pair_sep INTO TABLE DATA(lt_pairs).
    LOOP AT lt_pairs INTO DATA(lv_pair).
      SPLIT lv_pair AT zif_cd_ops_trace_types=>gc_spec_value_sep INTO DATA(lv_name) DATA(lv_value).
      lv_name  = to_upper( condense( lv_name ) ).
      lv_value = to_upper( condense( lv_value ) ).
      CASE lv_name.
        WHEN zif_cd_ops_trace_types=>gc_spec-table.
          rs_cfg-table_name = lv_value.
        WHEN zif_cd_ops_trace_types=>gc_spec-key.
          rs_cfg-key_field = lv_value.
        WHEN zif_cd_ops_trace_types=>gc_spec-key2.
          rs_cfg-key2_field = lv_value.
        WHEN zif_cd_ops_trace_types=>gc_spec-ref.
          rs_cfg-ref_field = lv_value.
        WHEN zif_cd_ops_trace_types=>gc_spec-status.
          rs_cfg-status_field = lv_value.
        WHEN zif_cd_ops_trace_types=>gc_spec-date.
          rs_cfg-date_field = lv_value.
        WHEN zif_cd_ops_trace_types=>gc_spec-time.
          rs_cfg-time_field = lv_value.
        WHEN zif_cd_ops_trace_types=>gc_spec-info.
          rs_cfg-info_field = lv_value.
        WHEN zif_cd_ops_trace_types=>gc_spec-due.
          rs_cfg-due_field = lv_value.
        WHEN zif_cd_ops_trace_types=>gc_spec-amount.
          rs_cfg-amount_field = lv_value.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD mask.
    DATA(lv_value) = condense( CONV string( iv_value ) ).
    DATA(lv_len) = strlen( lv_value ).
    IF lv_len <= zif_cd_ops_trace_types=>gc_mask_keep.
      rv_masked = repeat( val = zif_cd_ops_trace_types=>gc_mask_char occ = lv_len ).
      RETURN.
    ENDIF.
    DATA(lv_hidden) = lv_len - zif_cd_ops_trace_types=>gc_mask_keep.
    rv_masked = repeat( val = zif_cd_ops_trace_types=>gc_mask_char occ = lv_hidden )
             && substring( val = lv_value off = lv_hidden ).
  ENDMETHOD.


  METHOD read_source.
    IF is_source-table_name IS INITIAL OR is_source-key_field IS INITIAL.
      rs_read-status = zif_cd_ops_trace_types=>gc_status-unavailable.
      rs_read-reason = zif_cd_ops_trace_types=>gc_reason-not_configured.
      rs_read-text   = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-not_configured
                                              iv_v1    = is_source-param ).
      RETURN.
    ENDIF.
    TRY.
        rs_read-rows = mo_dao->read_configured( is_source     = is_source
                                                is_key        = is_key
                                                iv_match_key2 = iv_match_key2
                                                iv_max_rows   = ms_cfg-max_rows ).
        rs_read-status = zif_cd_ops_trace_types=>gc_status-verified.
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        rs_read-status = zif_cd_ops_trace_types=>gc_status-unavailable.
        rs_read-reason = zif_cd_ops_trace_types=>gc_reason-not_readable.
        rs_read-text   = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-not_readable
                                                iv_v1    = is_source-table_name
                                                iv_tail  = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD find_items.
    DATA lv_partner TYPE zif_cd_ops_trace_types=>ty_partner.
    DATA lv_without_source TYPE abap_bool.
    DATA lt_fins TYPE SORTED TABLE OF zif_cd_ops_trace_types=>ty_fin WITH UNIQUE KEY table_line.

    IF is_input-fin IS NOT INITIAL.
      DATA(lv_member) = trace_request( iv_fin = is_input-fin iv_source = is_input-source ).
      IF lv_member IS NOT INITIAL.
        resolve_partner( EXPORTING iv_member         = lv_member
                                   iv_source         = is_input-source
                         IMPORTING ev_partner        = lv_partner
                                   ev_without_source = lv_without_source ).
      ENDIF.
      mt_items = mo_dao->get_items_by_fin( iv_fin = is_input-fin iv_max_rows = ms_cfg-max_rows ).
    ELSE.
      DATA(lt_docno) = VALUE zif_cd_ops_trace_types=>tt_docno( ).
      IF is_input-clearing_doc IS NOT INITIAL.
        INSERT is_input-clearing_doc INTO TABLE lt_docno.
      ELSEIF is_input-check_no IS NOT INITIAL.
        lt_docno = reference_documents( is_input-check_no ).
      ENDIF.
      LOOP AT lt_docno ASSIGNING FIELD-SYMBOL(<lv_docno>).
        INSERT LINES OF mo_dao->get_items_by_clearing( iv_augbl = <lv_docno> iv_max_rows = ms_cfg-max_rows )
          INTO TABLE mt_items.
      ENDLOOP.
      " The request of each FIN on the items (source unknown: every source is a candidate)
      LOOP AT mt_items ASSIGNING FIELD-SYMBOL(<ls_item>) WHERE fin IS NOT INITIAL.
        INSERT <ls_item>-fin INTO TABLE lt_fins.
      ENDLOOP.
      LOOP AT lt_fins ASSIGNING FIELD-SYMBOL(<lv_fin>).
        trace_request( iv_fin = <lv_fin> iv_source = space ).
      ENDLOOP.
    ENDIF.
    check_items( iv_partner = lv_partner iv_without_source = lv_without_source iv_fin = is_input-fin ).
  ENDMETHOD.


  METHOD trace_request.
    DATA lt_success TYPE zif_cd_ops_trace_types=>tt_cfg_row.

    DATA(ls_read) = read_source( is_source    = ms_cfg-request
                                 is_key       = VALUE #( key1 = iv_fin key2 = iv_source )
                                 iv_match_key2 = xsdbool( iv_source IS NOT INITIAL
                                                          AND ms_cfg-request-key2_field IS NOT INITIAL ) ).
    IF ls_read-status <> zif_cd_ops_trace_types=>gc_status-verified.
      add_row( is_row = VALUE #( stage = zif_cd_ops_trace_types=>gc_stage-request status = ls_read-status
                                 reason = ls_read-reason source_table = ms_cfg-request-table_name detail = ls_read-text ) ).
      RETURN.
    ENDIF.
    IF ls_read-rows IS NOT INITIAL.
      mv_found = abap_true.
    ENDIF.

    " Rule: the SUCCESS row counts, never the highest COUNTER (a failed retry can follow it)
    LOOP AT ls_read-rows INTO DATA(ls_row).
      IF condense( ls_row-status ) = ms_cfg-success.
        INSERT ls_row INTO TABLE lt_success.
        INSERT VALUE #( fin = iv_fin source = to_upper( condense( ls_row-key2 ) ) ) INTO TABLE mt_req_keys.
      ENDIF.
    ENDLOOP.
    candidate_status( EXPORTING iv_count  = COND #( WHEN lines( ls_read-rows ) >= ms_cfg-max_rows
                                                    THEN ms_cfg-max_rows ELSE lines( lt_success ) )
                      IMPORTING ev_status = DATA(lv_status)
                                ev_reason = DATA(lv_reason) ).
    IF lt_success IS INITIAL.
      add_row( is_row = VALUE #( stage        = zif_cd_ops_trace_types=>gc_stage-request
                                 status       = lv_status
                                 reason       = zif_cd_ops_trace_types=>gc_reason-no_success
                                 source_table = ms_cfg-request-table_name
                                 record_key   = key_text( iv_part1 = iv_fin iv_part2 = iv_source )
                                 detail       = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-no_success_row
                                                                       iv_v1    = iv_fin
                                                                       iv_v2    = iv_source
                                                                       iv_v3    = lines( ls_read-rows ) ) ) ).
      RETURN.
    ENDIF.
    LOOP AT lt_success INTO ls_row.
      add_row( is_row = VALUE #( stage         = zif_cd_ops_trace_types=>gc_stage-request
                                 status        = lv_status
                                 reason        = COND #( WHEN lv_reason IS INITIAL
                                                         THEN zif_cd_ops_trace_types=>gc_reason-success_row ELSE lv_reason )
                                 source_table  = ms_cfg-request-table_name
                                 record_key    = key_text( iv_part1 = ls_row-key1 iv_part2 = ls_row-key2 iv_part3 = ls_row-ref )
                                 evidence_date = to_date( ls_row-ev_date )
                                 evidence_time = to_time( ls_row-ev_time )
                                 detail        = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-request_row
                                                                        iv_v1    = ls_row-key1
                                                                        iv_v2    = ls_row-key2
                                                                        iv_v3    = ls_row-ref
                                                                        iv_v4    = ls_row-status
                                                                        iv_tail  = mask( ls_row-info ) ) ) ).
    ENDLOOP.
    " The member number is used only when exactly one SUCCESS row exists
    IF lines( lt_success ) = 1.
      rv_member = lt_success[ 1 ]-info.
    ENDIF.
  ENDMETHOD.


  METHOD resolve_partner.
    CLEAR: ev_partner, ev_without_source.
    TRY.
        DATA(lt_partners) = VALUE zif_cd_ops_trace_types=>tt_partner( ).
        IF ms_cfg-bp_source_field IS NOT INITIAL AND iv_source IS NOT INITIAL.
          lt_partners = mo_dao->get_partners( iv_bpext        = iv_member
                                              iv_source_field = ms_cfg-bp_source_field
                                              iv_source       = iv_source
                                              iv_max_rows     = ms_cfg-max_rows ).
        ENDIF.
        IF lt_partners IS INITIAL.
          " Legacy PCLM partners pre-date SOURCE: read without it
          lt_partners = mo_dao->get_partners( iv_bpext = iv_member iv_max_rows = ms_cfg-max_rows ).
          ev_without_source = abap_true.
        ENDIF.
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        " A wrong source field only loses the partner filter; the items still show - and the
        " trace says so in a configuration row (never silently)
        CLEAR lt_partners.
        add_row( is_row = VALUE #( stage  = zif_cd_ops_trace_types=>gc_stage-config
                                   status = zif_cd_ops_trace_types=>gc_status-unavailable
                                   reason = zif_cd_ops_trace_types=>gc_reason-not_configured
                                   detail = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-partner_filter_off
                                                                   iv_v1    = ms_cfg-bp_source_field
                                                                   iv_tail  = lx_error->get_text( ) ) ) ).
    ENDTRY.
    " More than one partner is never silently picked: no filter, the items decide
    IF lines( lt_partners ) = 1.
      ev_partner = lt_partners[ 1 ].
    ELSE.
      CLEAR ev_without_source.
    ENDIF.
  ENDMETHOD.


  METHOD check_items.
    DATA lt_partners TYPE SORTED TABLE OF zif_cd_ops_trace_types=>ty_partner WITH UNIQUE KEY table_line.

    " The request's partner narrows the items; when it owns none of them the link is broken
    DATA(lv_mismatch) = xsdbool( iv_partner IS NOT INITIAL AND mt_items IS NOT INITIAL
                                 AND NOT line_exists( mt_items[ gpart = iv_partner ] ) ).
    IF iv_partner IS NOT INITIAL AND lv_mismatch = abap_false.
      DELETE mt_items WHERE gpart <> iv_partner.
    ENDIF.
    IF mt_items IS INITIAL.
      add_row( is_row = VALUE #( stage        = zif_cd_ops_trace_types=>gc_stage-sap_item
                                 status       = zif_cd_ops_trace_types=>gc_status-missing
                                 reason       = zif_cd_ops_trace_types=>gc_reason-no_record
                                 source_table = zif_cd_ops_trace_types=>gc_table-dfkkop
                                 detail       = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-stage_missing
                                                                       iv_v1    = zif_cd_ops_trace_types=>gc_table-dfkkop ) ) ).
      RETURN.
    ENDIF.
    mv_found = abap_true.
    LOOP AT mt_items INTO DATA(ls_item).
      INSERT ls_item-gpart INTO TABLE lt_partners.
    ENDLOOP.
    candidate_status( EXPORTING iv_count  = COND #( WHEN lines( mt_items ) >= ms_cfg-max_rows THEN ms_cfg-max_rows
                                                    ELSE lines( lt_partners ) )
                      IMPORTING ev_status = DATA(lv_status)
                                ev_reason = DATA(lv_reason) ).
    IF lv_mismatch = abap_true.
      lv_status = zif_cd_ops_trace_types=>gc_status-ambiguous.
      lv_reason = zif_cd_ops_trace_types=>gc_reason-partner_mismatch.
    ENDIF.

    DATA(lt_allowed) = VALUE zif_cd_ops_trace_types=>tt_item( ).
    LOOP AT mt_items INTO ls_item.
      IF is_allowed( ls_item-bukrs ) = abap_false.
        " Not shown, not traced further - and never reported as missing
        add_row( is_row = VALUE #( stage  = zif_cd_ops_trace_types=>gc_stage-sap_item
                                   status = zif_cd_ops_trace_types=>gc_status-unavailable
                                   reason = zif_cd_ops_trace_types=>gc_reason-not_authorised
                                   bukrs  = ls_item-bukrs
                                   detail = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-not_authorised
                                                                   iv_v1    = ls_item-bukrs ) ) ).
        CONTINUE.
      ENDIF.
      INSERT ls_item INTO TABLE lt_allowed.
      add_row( is_row = VALUE #(
        stage         = zif_cd_ops_trace_types=>gc_stage-sap_item
        status        = lv_status
        reason        = COND #( WHEN lv_reason IS NOT INITIAL THEN lv_reason
                                WHEN iv_without_source = abap_true THEN zif_cd_ops_trace_types=>gc_reason-partner_legacy
                                ELSE zif_cd_ops_trace_types=>gc_reason-open_item )
        source_table  = zif_cd_ops_trace_types=>gc_table-dfkkop
        record_key    = key_text( iv_part1 = ls_item-opbel iv_part2 = ls_item-opupk iv_part3 = ls_item-fin )
        bukrs         = ls_item-bukrs
        evidence_date = ls_item-budat
        detail        = COND #( WHEN lv_mismatch = abap_true
                                THEN zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-partner_mismatch
                                                            iv_v1    = iv_partner
                                                            iv_v2    = iv_fin )
                                WHEN lv_status = zif_cd_ops_trace_types=>gc_status-ambiguous
                                THEN zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-partner_ambiguous
                                                            iv_v1    = ls_item-fin
                                                            iv_v2    = lines( lt_partners ) )
                                WHEN iv_without_source = abap_true
                                THEN zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-partner_legacy
                                                            iv_v1    = ls_item-gpart )
                                ELSE zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-item_row
                                                            iv_v1    = ls_item-opbel
                                                            iv_v2    = ls_item-gpart
                                                            iv_v3    = ls_item-bukrs
                                                            iv_v4    = |{ ls_item-betrh } { ls_item-waers }| ) ) ) ).
    ENDLOOP.
    " Competing partners: shown for review, not traced further
    mt_items = COND #( WHEN lv_status = zif_cd_ops_trace_types=>gc_status-ambiguous THEN VALUE #( )
                       ELSE lt_allowed ).
  ENDMETHOD.


  METHOD trace_history.
    DATA lt_docno TYPE zif_cd_ops_trace_types=>tt_docno.
    DATA lt_history TYPE tt_attempt.

    LOOP AT mt_items INTO DATA(ls_item).
      INSERT ls_item-opbel INTO TABLE lt_docno.
      IF ls_item-augbl IS NOT INITIAL.
        INSERT ls_item-augbl INTO TABLE lt_docno.
      ENDIF.
    ENDLOOP.
    mt_headers = mo_dao->get_doc_headers( lt_docno ).

    LOOP AT mt_items INTO ls_item.
      " Reversal / reset evidence: cleared by a reversal (AUGRD), or the clearing document
      " itself was reversed (DFKKKO-STBEL) - both VERIFY-SE11
      DATA(lv_reversed) = xsdbool( ls_item-augrd = zif_cd_ops_trace_types=>gc_reversal_augrd
                                   OR VALUE zif_cd_ops_trace_types=>ty_docno( mt_headers[ KEY by_opbel opbel = ls_item-augbl ]-stbel
                                                                              OPTIONAL ) IS NOT INITIAL ).
      DATA(ls_read) = read_source( is_source = ms_cfg-history is_key = VALUE #( key1 = ls_item-opbel ) ).
      DATA(ls_base) = VALUE ty_row( stage        = zif_cd_ops_trace_types=>gc_stage-history
                                    source_table = ms_cfg-history-table_name
                                    bukrs        = ls_item-bukrs ).
      IF ls_read-status <> zif_cd_ops_trace_types=>gc_status-verified.
        " Reversal / reset evidence while the history cannot be read: named explicitly
        ls_base-status = ls_read-status.
        ls_base-reason = COND #( WHEN lv_reversed = abap_true THEN zif_cd_ops_trace_types=>gc_reason-history_missing
                                 ELSE ls_read-reason ).
        ls_base-record_key = key_text( iv_part1 = ls_item-opbel iv_part2 = ls_item-augbl iv_part3 = ls_item-augrd ).
        ls_base-detail = ls_read-text.
        add_row( is_row = ls_base ).
      ELSEIF ls_read-rows IS INITIAL AND lv_reversed = abap_true.
        ls_base-status     = zif_cd_ops_trace_types=>gc_status-missing.
        ls_base-reason     = zif_cd_ops_trace_types=>gc_reason-history_missing.
        ls_base-record_key = key_text( iv_part1 = ls_item-opbel iv_part2 = ls_item-augbl iv_part3 = ls_item-augrd ).
        ls_base-detail     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-history_missing
                                                    iv_v1    = ls_item-opbel
                                                    iv_v2    = key_text( iv_part1 = ls_item-augbl iv_part2 = ls_item-augrd )
                                                    iv_v3    = ms_cfg-history-table_name ).
        add_row( is_row = ls_base ).
      ELSEIF ls_read-rows IS INITIAL.
        ls_base-status     = zif_cd_ops_trace_types=>gc_status-verified.
        ls_base-reason     = zif_cd_ops_trace_types=>gc_reason-no_earlier.
        ls_base-record_key = ls_item-opbel.
        ls_base-detail     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-no_earlier
                                                    iv_v1    = ls_item-opbel
                                                    iv_v2    = ms_cfg-history-table_name ).
        add_row( is_row = ls_base ).
      ENDIF.
      LOOP AT ls_read-rows ASSIGNING FIELD-SYMBOL(<ls_hist>).
        ls_base-status        = zif_cd_ops_trace_types=>gc_status-verified.
        ls_base-reason        = zif_cd_ops_trace_types=>gc_reason-earlier_found.
        ls_base-record_key    = key_text( iv_part1 = <ls_hist>-key1 iv_part2 = <ls_hist>-ref ).
        ls_base-evidence_date = to_date( <ls_hist>-ev_date ).
        ls_base-evidence_time = to_time( <ls_hist>-ev_time ).
        ls_base-detail        = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-history_found
                                                       iv_v1    = <ls_hist>-ref
                                                       iv_v2    = ls_item-opbel
                                                       iv_v3    = ls_base-evidence_date
                                                       iv_v4    = ms_cfg-history-table_name ).
        add_row( is_row = ls_base ).
        INSERT VALUE #( kind       = zif_cd_ops_trace_types=>gc_attempt-historical
                        ref        = CONV #( <ls_hist>-ref )
                        item_opbel = ls_item-opbel
                        bukrs      = ls_item-bukrs
                        pymet      = ls_item-pymet
                        hist_date  = ls_base-evidence_date
                        hist_time  = ls_base-evidence_time
                        hist_table = ms_cfg-history-table_name ) INTO TABLE lt_history.
      ENDLOOP.
      " The current clearing is a payment attempt unless it is the reversal itself
      IF ls_item-augbl IS NOT INITIAL
         AND ls_item-augrd <> zif_cd_ops_trace_types=>gc_reversal_augrd.
        INSERT VALUE #( kind       = zif_cd_ops_trace_types=>gc_attempt-current
                        ref        = ls_item-augbl
                        item_opbel = ls_item-opbel
                        bukrs      = ls_item-bukrs
                        pymet      = ls_item-pymet
                        augdt      = ls_item-augdt ) INTO TABLE lt_history.
      ELSEIF ls_item-augbl IS INITIAL AND lv_reversed = abap_false AND ls_read-rows IS INITIAL.
        INSERT VALUE #( kind       = zif_cd_ops_trace_types=>gc_attempt-unpaid
                        item_opbel = ls_item-opbel
                        bukrs      = ls_item-bukrs
                        pymet      = ls_item-pymet ) INTO TABLE lt_history.
      ENDIF.
    ENDLOOP.
    build_attempts( lt_history ).
  ENDMETHOD.


  METHOD build_attempts.
    DATA(lt_sorted) = it_history.
    " Historical attempts first (by reset date / time), then current, then unpaid
    LOOP AT lt_sorted ASSIGNING FIELD-SYMBOL(<ls_attempt>).
      <ls_attempt>-no = COND #( WHEN <ls_attempt>-kind = zif_cd_ops_trace_types=>gc_attempt-historical THEN 1
                                WHEN <ls_attempt>-kind = zif_cd_ops_trace_types=>gc_attempt-current THEN 2
                                ELSE 3 ).
    ENDLOOP.
    " A history row that names the current clearing again is the current attempt
    DATA lt_current TYPE STANDARD TABLE OF zif_cd_ops_trace_types=>ty_docno WITH EMPTY KEY.
    lt_current = VALUE #( FOR ls_cur IN lt_sorted WHERE ( kind = zif_cd_ops_trace_types=>gc_attempt-current )
                          ( ls_cur-ref ) ).
    LOOP AT lt_current INTO DATA(lv_current).
      DELETE lt_sorted WHERE kind = zif_cd_ops_trace_types=>gc_attempt-historical AND ref = lv_current.
    ENDLOOP.
    " Split items cleared by the same payment document are one attempt (unpaid: one per item)
    SORT lt_sorted BY no ref item_opbel.
    DATA(ls_previous) = VALUE ty_attempt( ).
    LOOP AT lt_sorted INTO DATA(ls_attempt).
      IF ls_attempt-ref IS NOT INITIAL AND ls_attempt-no = ls_previous-no AND ls_attempt-ref = ls_previous-ref.
        DELETE lt_sorted.
        CONTINUE.
      ENDIF.
      ls_previous = ls_attempt.
    ENDLOOP.
    SORT lt_sorted BY no hist_date hist_time ref.
    LOOP AT lt_sorted ASSIGNING <ls_attempt>.
      <ls_attempt>-no = sy-tabix.
    ENDLOOP.
    mt_attempts = lt_sorted.
  ENDMETHOD.


  METHOD trace_attempt.
    DATA(lv_cheque) = xsdbool( is_attempt-pymet IS NOT INITIAL
                               AND in_list( iv_value = is_attempt-pymet iv_list = ms_cfg-cheque_methods ) = abap_true ).
    stage_payment( EXPORTING is_attempt = is_attempt
                             iv_cheque  = lv_cheque
                   IMPORTING et_runs    = DATA(lt_runs)
                             et_checks  = DATA(lt_checks) ).
    IF is_attempt-ref IS INITIAL.
      add_no_link( is_attempt = is_attempt iv_stage = zif_cd_ops_trace_types=>gc_stage-file
                   iv_after = zif_cd_ops_trace_types=>gc_stage-payment ).
      add_no_link( is_attempt = is_attempt iv_stage = zif_cd_ops_trace_types=>gc_stage-prism
                   iv_after = zif_cd_ops_trace_types=>gc_stage-payment ).
      add_no_link( is_attempt = is_attempt iv_stage = zif_cd_ops_trace_types=>gc_stage-bank_ack
                   iv_after = zif_cd_ops_trace_types=>gc_stage-payment ).
      add_no_link( is_attempt = is_attempt iv_stage = zif_cd_ops_trace_types=>gc_stage-settlement
                   iv_after = zif_cd_ops_trace_types=>gc_stage-payment ).
      add_no_link( is_attempt = is_attempt iv_stage = zif_cd_ops_trace_types=>gc_stage-gl
                   iv_after = zif_cd_ops_trace_types=>gc_stage-payment ).
      stage_clearing_and_gl( is_attempt = is_attempt iv_cheque = lv_cheque ).
      RETURN.
    ENDIF.
    DATA(lt_links) = stage_file( is_attempt = is_attempt
                                 it_runs    = lt_runs ).
    stage_prism( EXPORTING is_attempt = is_attempt
                           it_runs    = lt_runs
                           it_links   = lt_links
                 IMPORTING et_files   = DATA(lt_files)
                           et_events  = DATA(lt_events) ).
    stage_bank_ack( is_attempt = is_attempt it_files = lt_files it_events = lt_events ).
    stage_settlement( is_attempt = is_attempt iv_cheque = lv_cheque it_checks = lt_checks ).
    stage_noc( is_attempt = is_attempt it_checks = lt_checks ).
    stage_clearing_and_gl( is_attempt = is_attempt iv_cheque = lv_cheque ).
  ENDMETHOD.


  METHOD stage_payment.
    CLEAR: et_runs, et_checks.
    DATA(ls_base) = VALUE ty_row( stage = zif_cd_ops_trace_types=>gc_stage-payment bukrs = is_attempt-bukrs ).
    IF is_attempt-ref IS INITIAL.
      ls_base-status       = zif_cd_ops_trace_types=>gc_status-missing.
      ls_base-reason       = zif_cd_ops_trace_types=>gc_reason-no_record.
      ls_base-source_table = zif_cd_ops_trace_types=>gc_table-dfkkop.
      ls_base-record_key   = is_attempt-item_opbel.
      ls_base-detail       = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-stage_missing
                                                    iv_v1    = zif_cd_ops_trace_types=>gc_stage-payment
                                                    iv_v2    = is_attempt-item_opbel ).
      add_row( is_attempt = is_attempt is_row = ls_base ).
      RETURN.
    ENDIF.
    DATA(lt_docno) = VALUE zif_cd_ops_trace_types=>tt_docno( ( is_attempt-ref ) ).
    et_runs = mo_dao->get_payment_runs( lt_docno ).

    IF iv_cheque = abap_true.
      " Method C: DFKKCR-DOC1R = DFKKOP-AUGBL
      et_checks = mo_dao->get_checks_by_doc( lt_docno ).
      candidate_status( EXPORTING iv_count  = lines( et_checks )
                        IMPORTING ev_status = ls_base-status
                                  ev_reason = ls_base-reason ).
      ls_base-source_table = zif_cd_ops_trace_types=>gc_table-dfkkcr.
      ls_base-reason = COND #( WHEN ls_base-reason IS INITIAL
                               THEN zif_cd_ops_trace_types=>gc_reason-cheque_issued ELSE ls_base-reason ).
      LOOP AT et_checks ASSIGNING FIELD-SYMBOL(<ls_check>).
        ls_base-record_key    = key_text( iv_part1 = <ls_check>-ztnum iv_part2 = <ls_check>-hbkid iv_part3 = <ls_check>-hktid ).
        ls_base-evidence_date = VALUE #( et_runs[ 1 ]-laufd OPTIONAL ).
        ls_base-detail        = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-cheque_row
                                                       iv_v1    = <ls_check>-ztnum
                                                       iv_v2    = <ls_check>-hbkid
                                                       iv_v3    = <ls_check>-hktid
                                                       iv_v4    = <ls_check>-crstatus ).
        add_row( is_attempt = is_attempt is_row = ls_base ).
      ENDLOOP.
    ELSE.
      " DPAYH by DOC1R (proposal runs excluded); several runs for one document are listed
      candidate_status( EXPORTING iv_count  = lines( et_runs )
                        IMPORTING ev_status = ls_base-status
                                  ev_reason = ls_base-reason ).
      ls_base-source_table = zif_cd_ops_trace_types=>gc_table-dpayh.
      ls_base-reason = COND #( WHEN ls_base-reason IS INITIAL
                               THEN zif_cd_ops_trace_types=>gc_reason-payment_run ELSE ls_base-reason ).
      LOOP AT et_runs ASSIGNING FIELD-SYMBOL(<ls_run>).
        ls_base-record_key    = key_text( iv_part1 = <ls_run>-laufd iv_part2 = <ls_run>-laufi iv_part3 = <ls_run>-doc1r ).
        ls_base-evidence_date = <ls_run>-laufd.
        ls_base-detail        = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-payment_run
                                                       iv_v1    = <ls_run>-laufd
                                                       iv_v2    = <ls_run>-laufi
                                                       iv_v3    = <ls_run>-status
                                                       iv_v4    = <ls_run>-doc1r ).
        add_row( is_attempt = is_attempt is_row = ls_base ).
      ENDLOOP.
    ENDIF.
    IF ls_base-status = zif_cd_ops_trace_types=>gc_status-missing.
      ls_base-record_key = is_attempt-ref.
      ls_base-detail     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-stage_missing
                                                  iv_v1    = ls_base-source_table
                                                  iv_v2    = is_attempt-ref ).
      add_row( is_attempt = is_attempt is_row = ls_base ).
    ENDIF.
  ENDMETHOD.


  METHOD stage_file.
    IF it_runs IS INITIAL.
      add_no_link( is_attempt = is_attempt iv_stage = zif_cd_ops_trace_types=>gc_stage-file
                   iv_after = zif_cd_ops_trace_types=>gc_stage-payment ).
      RETURN.
    ENDIF.
    DATA(ls_base) = VALUE ty_row( stage = zif_cd_ops_trace_types=>gc_stage-file bukrs = is_attempt-bukrs
                                  source_table = ms_cfg-regut-table_name ).
    DATA(lt_rows) = VALUE zif_cd_ops_trace_types=>tt_cfg_row( ).
    " Payment run LAUFD / LAUFI -> generated file, only through the configured register
    " (ZCDT_REGUT field names VERIFY-SE11); not configured = UNAVAILABLE, never VERIFIED
    LOOP AT it_runs ASSIGNING FIELD-SYMBOL(<ls_run>).
      DATA(ls_read) = read_source( is_source = ms_cfg-regut
                                   is_key    = VALUE #( key1 = <ls_run>-laufd key2 = <ls_run>-laufi ) ).
      IF ls_read-status <> zif_cd_ops_trace_types=>gc_status-verified.
        ls_base-status = ls_read-status.
        ls_base-reason = ls_read-reason.
        ls_base-detail = ls_read-text.
        add_row( is_attempt = is_attempt is_row = ls_base ).
        RETURN.
      ENDIF.
      INSERT LINES OF ls_read-rows INTO TABLE lt_rows.
    ENDLOOP.
    candidate_status( EXPORTING iv_count  = lines( lt_rows )
                      IMPORTING ev_status = ls_base-status
                                ev_reason = ls_base-reason ).
    IF lt_rows IS INITIAL.
      ls_base-record_key = key_text( iv_part1 = it_runs[ 1 ]-laufd iv_part2 = it_runs[ 1 ]-laufi ).
      ls_base-detail     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-stage_missing
                                                  iv_v1    = zif_cd_ops_trace_types=>gc_stage-file
                                                  iv_v2    = ls_base-record_key ).
      add_row( is_attempt = is_attempt is_row = ls_base ).
      RETURN.
    ENDIF.
    ls_base-reason = COND #( WHEN ls_base-reason IS INITIAL
                             THEN zif_cd_ops_trace_types=>gc_reason-file_generated ELSE ls_base-reason ).
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      " Same correlation key as file monitoring (long references: digest, audit A100)
      INSERT VALUE #( ref  = zcl_cd_fmon_util=>normalize_ref( <ls_row>-ref )
                      name = zcl_cd_fmon_util=>canonical_name( <ls_row>-ref ) ) INTO TABLE rt_links.
      ls_base-record_key    = key_text( iv_part1 = <ls_row>-ref iv_part2 = <ls_row>-key1 iv_part3 = <ls_row>-key2 ).
      ls_base-evidence_date = to_date( <ls_row>-ev_date ).
      ls_base-evidence_time = to_time( <ls_row>-ev_time ).
      ls_base-detail        = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-file_row
                                                     iv_v1    = <ls_row>-ref
                                                     iv_v2    = <ls_row>-key1
                                                     iv_v3    = <ls_row>-key2 ).
      add_row( is_attempt = is_attempt is_row = ls_base ).
    ENDLOOP.
  ENDMETHOD.


  METHOD stage_prism.
    DATA lt_refs TYPE zif_cd_ops_trace_types=>tt_file_ref.
    DATA lv_from TYPE d.
    DATA lv_to TYPE d.

    CLEAR: et_files, et_events.
    LOOP AT it_links ASSIGNING FIELD-SYMBOL(<ls_link>) WHERE ref IS NOT INITIAL.
      INSERT <ls_link>-ref INTO TABLE lt_refs.
    ENDLOOP.
    IF lt_refs IS INITIAL.
      add_no_link( is_attempt = is_attempt iv_stage = zif_cd_ops_trace_types=>gc_stage-prism
                   iv_after = zif_cd_ops_trace_types=>gc_stage-file ).
      RETURN.
    ENDIF.
    DATA(ls_base) = VALUE ty_row( stage = zif_cd_ops_trace_types=>gc_stage-prism bukrs = is_attempt-bukrs
                                  source_table = zif_cd_ops_trace_types=>gc_table-fmon time_zone = zif_cd_ops_trace_types=>gc_utc ).
    " Business date of the file around the payment run date (index BDT)
    LOOP AT it_runs ASSIGNING FIELD-SYMBOL(<ls_run>).
      lv_from = COND #( WHEN lv_from IS INITIAL OR <ls_run>-laufd < lv_from THEN <ls_run>-laufd ELSE lv_from ).
      lv_to   = COND #( WHEN <ls_run>-laufd > lv_to THEN <ls_run>-laufd ELSE lv_to ).
    ENDLOOP.
    lv_from = lv_from - ms_cfg-lookback.
    lv_to   = lv_to + ms_cfg-lookback.
    et_files = mo_dao->get_fmon_files( it_file_ref = lt_refs iv_from = lv_from iv_to = lv_to ).
    " A digest reference matches only the file with the same full name (audit A100)
    LOOP AT et_files INTO DATA(ls_candidate).
      IF zcl_cd_fmon_util=>is_digest_ref( ls_candidate-file_ref ) = abap_true
         AND NOT line_exists( it_links[ ref  = ls_candidate-file_ref
                                        name = zcl_cd_fmon_util=>canonical_name( ls_candidate-file_name ) ] ).
        DELETE et_files.
      ENDIF.
    ENDLOOP.
    IF et_files IS INITIAL.
      " The monitor never saw the file: not proof that PRISM did not receive it
      ls_base-status     = zif_cd_ops_trace_types=>gc_status-unavailable.
      ls_base-reason     = zif_cd_ops_trace_types=>gc_reason-not_monitored.
      ls_base-record_key = lt_refs[ 1 ].
      ls_base-detail     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-not_monitored
                                                  iv_v1    = lt_refs[ 1 ] ).
      add_row( is_attempt = is_attempt is_row = ls_base ).
      RETURN.
    ENDIF.
    DATA(lt_ids) = VALUE zif_cd_ops_trace_types=>tt_file_id( FOR ls_f IN et_files ( ls_f-file_id ) ).
    et_events = mo_dao->get_fmon_events( lt_ids ).
    DATA(lt_sent) = VALUE zif_cd_ops_trace_types=>tt_fmon_event(
      FOR ls_e IN et_events WHERE ( stage = zif_cd_fmon_types=>gc_stage-sent OR stage = zif_cd_fmon_types=>gc_stage-forwarded )
      ( ls_e ) ).
    candidate_status( EXPORTING iv_count  = COND #( WHEN lt_sent IS INITIAL THEN 0 ELSE lines( et_files ) )
                      IMPORTING ev_status = ls_base-status
                                ev_reason = ls_base-reason ).
    IF lt_sent IS INITIAL.
      ls_base-record_key = et_files[ 1 ]-file_ref.
      ls_base-detail     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-stage_missing
                                                  iv_v1    = zif_cd_fmon_types=>gc_stage-sent
                                                  iv_v2    = et_files[ 1 ]-file_ref ).
      add_row( is_attempt = is_attempt is_row = ls_base ).
      RETURN.
    ENDIF.
    ls_base-reason = COND #( WHEN ls_base-reason IS INITIAL
                             THEN zif_cd_ops_trace_types=>gc_reason-sent_to_prism ELSE ls_base-reason ).
    LOOP AT lt_sent ASSIGNING FIELD-SYMBOL(<ls_event>).
      DATA(ls_file) = VALUE zif_cd_ops_trace_types=>ty_fmon_file( et_files[ file_id = <ls_event>-file_id ] OPTIONAL ).
      CONVERT TIME STAMP <ls_event>-event_at TIME ZONE zif_cd_ops_trace_types=>gc_utc
        INTO DATE ls_base-evidence_date TIME ls_base-evidence_time.
      ls_base-record_key = key_text( iv_part1 = ls_file-file_ref iv_part2 = <ls_event>-stage iv_part3 = <ls_event>-src_id ).
      ls_base-detail     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-fmon_event
                                                  iv_v1    = ls_file-file_ref
                                                  iv_v2    = ls_file-iface_id
                                                  iv_v3    = <ls_event>-stage
                                                  iv_v4    = <ls_event>-event_at ).
      add_row( is_attempt = is_attempt is_row = ls_base ).
    ENDLOOP.
  ENDMETHOD.


  METHOD stage_bank_ack.
    DATA(ls_base) = VALUE ty_row( stage = zif_cd_ops_trace_types=>gc_stage-bank_ack bukrs = is_attempt-bukrs ).
    IF is_attempt-pymet IS NOT INITIAL
       AND in_list( iv_value = is_attempt-pymet iv_list = ms_cfg-no_ack_methods ) = abap_true.
      ls_base-status = zif_cd_ops_trace_types=>gc_status-not_applicable.
      ls_base-reason = zif_cd_ops_trace_types=>gc_reason-no_ack_method.
      ls_base-detail = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-not_applicable
                                              iv_v1    = ls_base-reason
                                              iv_v2    = is_attempt-pymet ).
      add_row( is_attempt = is_attempt is_row = ls_base ).
      RETURN.
    ENDIF.

    " Disbursements are acknowledged per payment (configured ACK source by clearing
    " reference); collections per file - their payment-level read is skipped
    DATA(lv_kind) = mo_dao->get_method_kind( iv_bukrs = is_attempt-bukrs iv_pymet = is_attempt-pymet ).
    IF lv_kind <> zif_cd_ops_trace_types=>gc_kind-collection AND ms_cfg-ack-table_name IS NOT INITIAL.
      DATA(ls_read) = read_source( is_source = ms_cfg-ack is_key = VALUE #( key1 = is_attempt-ref ) ).
      ls_base-source_table = ms_cfg-ack-table_name.
      IF ls_read-status <> zif_cd_ops_trace_types=>gc_status-verified.
        ls_base-status = ls_read-status.
        ls_base-reason = ls_read-reason.
        ls_base-detail = ls_read-text.
        add_row( is_attempt = is_attempt is_row = ls_base ).
        RETURN.
      ENDIF.
      LOOP AT ls_read-rows ASSIGNING FIELD-SYMBOL(<ls_ack>).
        DATA(lv_nack) = in_list( iv_value = <ls_ack>-status iv_list = ms_cfg-nack_values ).
        ls_base-status        = COND #( WHEN lv_nack = abap_true THEN zif_cd_ops_trace_types=>gc_status-failed
                                        ELSE zif_cd_ops_trace_types=>gc_status-verified ).
        ls_base-reason        = COND #( WHEN lv_nack = abap_true THEN zif_cd_ops_trace_types=>gc_reason-nack
                                        ELSE zif_cd_ops_trace_types=>gc_reason-ack_payment ).
        ls_base-record_key    = key_text( iv_part1 = <ls_ack>-key1 iv_part2 = <ls_ack>-ref ).
        ls_base-evidence_date = to_date( <ls_ack>-ev_date ).
        ls_base-evidence_time = to_time( <ls_ack>-ev_time ).
        ls_base-detail        = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-ack_row
                                                       iv_v1    = <ls_ack>-key1
                                                       iv_v2    = <ls_ack>-status ).
        add_row( is_attempt = is_attempt is_row = ls_base ).
      ENDLOOP.
      IF ls_read-rows IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    " File-level evidence from file monitoring (ACK_RECEIVED / NACK_REJECTED events)
    ls_base-source_table = zif_cd_ops_trace_types=>gc_table-fmon.
    ls_base-time_zone    = zif_cd_ops_trace_types=>gc_utc.
    IF it_files IS INITIAL.
      add_no_link( is_attempt = is_attempt iv_stage = zif_cd_ops_trace_types=>gc_stage-bank_ack
                   iv_after = zif_cd_ops_trace_types=>gc_stage-prism ).
      RETURN.
    ENDIF.
    DATA(lv_found) = abap_false.
    LOOP AT it_events ASSIGNING FIELD-SYMBOL(<ls_event>)
         WHERE stage = zif_cd_fmon_types=>gc_stage-ack OR stage = zif_cd_fmon_types=>gc_stage-nack.
      lv_found = abap_true.
      DATA(ls_file) = VALUE zif_cd_ops_trace_types=>ty_fmon_file( it_files[ file_id = <ls_event>-file_id ] OPTIONAL ).
      ls_base-status = COND #( WHEN <ls_event>-stage = zif_cd_fmon_types=>gc_stage-nack
                               THEN zif_cd_ops_trace_types=>gc_status-failed
                               WHEN lines( it_files ) > 1 THEN zif_cd_ops_trace_types=>gc_status-ambiguous
                               ELSE zif_cd_ops_trace_types=>gc_status-verified ).
      ls_base-reason = COND #( WHEN <ls_event>-stage = zif_cd_fmon_types=>gc_stage-nack THEN zif_cd_ops_trace_types=>gc_reason-nack
                               WHEN lines( it_files ) > 1 THEN zif_cd_ops_trace_types=>gc_reason-multiple
                               ELSE zif_cd_ops_trace_types=>gc_reason-ack_file_level ).
      CONVERT TIME STAMP <ls_event>-event_at TIME ZONE zif_cd_ops_trace_types=>gc_utc
        INTO DATE ls_base-evidence_date TIME ls_base-evidence_time.
      ls_base-record_key = key_text( iv_part1 = ls_file-file_ref iv_part2 = <ls_event>-stage iv_part3 = <ls_event>-src_id ).
      ls_base-detail     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-fmon_event
                                                  iv_v1    = ls_file-file_ref
                                                  iv_v2    = ls_file-iface_id
                                                  iv_v3    = <ls_event>-stage
                                                  iv_v4    = <ls_event>-event_at ).
      add_row( is_attempt = is_attempt is_row = ls_base ).
    ENDLOOP.
    IF lv_found = abap_false.
      ls_base-status     = zif_cd_ops_trace_types=>gc_status-missing.
      ls_base-reason     = zif_cd_ops_trace_types=>gc_reason-no_record.
      ls_base-record_key = it_files[ 1 ]-file_ref.
      ls_base-detail     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-stage_missing
                                                  iv_v1    = zif_cd_fmon_types=>gc_stage-ack
                                                  iv_v2    = it_files[ 1 ]-file_ref ).
      add_row( is_attempt = is_attempt is_row = ls_base ).
    ENDIF.
  ENDMETHOD.


  METHOD stage_settlement.
    DATA lt_ref TYPE zif_cd_ops_trace_types=>tt_ref.
    DATA(ls_base) = VALUE ty_row( stage = zif_cd_ops_trace_types=>gc_stage-settlement bukrs = is_attempt-bukrs ).
    DATA(lt_docno) = VALUE zif_cd_ops_trace_types=>tt_docno( ( is_attempt-ref ) ).

    " Returns lot (DFKKRP-SELW1 = clearing reference) and ACH retrieval log: positive evidence
    " that the money came back. Every item shows its return reason DFKKRP-RLGRD (code only);
    " items of one clearing reference with different reasons add one AMBIGUOUS row
    DATA lt_reasons TYPE SORTED TABLE OF zif_cd_ops_trace_types=>ty_return-rlgrd WITH UNIQUE KEY table_line.
    DATA(lt_returns) = mo_dao->get_returns( lt_docno ).
    LOOP AT lt_returns ASSIGNING FIELD-SYMBOL(<ls_return>).
      INSERT <ls_return>-rlgrd INTO TABLE lt_reasons.
      add_row( is_attempt = is_attempt
               is_row     = VALUE #( BASE ls_base status = zif_cd_ops_trace_types=>gc_status-failed
                                     reason       = zif_cd_ops_trace_types=>gc_reason-returned
                                     source_table = zif_cd_ops_trace_types=>gc_table-dfkkrp
                                     record_key   = key_text( iv_part1 = <ls_return>-selw1 iv_part2 = <ls_return>-opbel )
                                     detail       = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-returned
                                                                           iv_v1    = <ls_return>-opbel
                                                                           iv_v2    = <ls_return>-lot_stars
                                                                           iv_v3    = <ls_return>-rlgrd ) ) ).
    ENDLOOP.
    IF lines( lt_reasons ) > 1.
      DATA(lv_reasons) = REDUCE string( INIT lv_list = ``
                                        FOR lv_reason IN lt_reasons
                                        NEXT lv_list = condense( |{ lv_list } { lv_reason }| ) ).
      add_row( is_attempt = is_attempt
               is_row     = VALUE #( BASE ls_base status = zif_cd_ops_trace_types=>gc_status-ambiguous
                                     reason       = zif_cd_ops_trace_types=>gc_reason-return_reason_ambiguous
                                     source_table = zif_cd_ops_trace_types=>gc_table-dfkkrp
                                     record_key   = is_attempt-ref
                                     detail       = zcl_cd_ops_util=>text(
                                                      iv_msgno = zif_cd_ops_trace_types=>gc_msg-return_reasons
                                                      iv_v1    = is_attempt-ref
                                                      iv_v2    = lv_reasons ) ) ).
    ENDIF.
    TRY.
        LOOP AT mo_dao->get_retrievals( lt_docno ) INTO DATA(ls_rtrv).
          add_row( is_attempt = is_attempt
                   is_row     = VALUE #( BASE ls_base status = zif_cd_ops_trace_types=>gc_status-failed
                                         reason       = zif_cd_ops_trace_types=>gc_reason-retrieval
                                         source_table = zif_cd_ops_trace_types=>gc_table-rtrv
                                         record_key   = ls_rtrv-augbl
                                         detail       = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-retrieval
                                                                               iv_v1    = ls_rtrv-augbl
                                                                               iv_v2    = ls_rtrv-status ) ) ).
        ENDLOOP.
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        add_row( is_attempt = is_attempt
                 is_row     = VALUE #( BASE ls_base status = zif_cd_ops_trace_types=>gc_status-unavailable
                                       reason       = zif_cd_ops_trace_types=>gc_reason-not_readable
                                       source_table = zif_cd_ops_trace_types=>gc_table-rtrv
                                       detail       = lx_error->get_text( ) ) ).
    ENDTRY.

    IF iv_cheque = abap_true.
      " Cheque status (ZCD_CHECK_HIST): terminal 3 failed / 4 rejected / 9 returned
      LOOP AT it_checks ASSIGNING FIELD-SYMBOL(<ls_check>).
        INSERT <ls_check>-ztnum INTO TABLE lt_ref.
        DATA(ls_read) = read_source( is_source = ms_cfg-chq_hist is_key = VALUE #( key1 = <ls_check>-ztnum ) ).
        IF ls_read-status <> zif_cd_ops_trace_types=>gc_status-verified.
          add_row( is_attempt = is_attempt
                   is_row     = VALUE #( BASE ls_base status = ls_read-status
                                         reason       = ls_read-reason
                                         source_table = ms_cfg-chq_hist-table_name
                                         record_key   = <ls_check>-ztnum
                                         detail       = ls_read-text ) ).
        ENDIF.
        LOOP AT ls_read-rows ASSIGNING FIELD-SYMBOL(<ls_hist>)
             WHERE status IS NOT INITIAL.
          DATA(lv_terminal) = in_list( iv_value = <ls_hist>-status iv_list = ms_cfg-chq_failed ).
          add_row( is_attempt = is_attempt
                   is_row     = VALUE #( BASE ls_base
                                         status        = COND #( WHEN lv_terminal = abap_true
                                                                 THEN zif_cd_ops_trace_types=>gc_status-failed
                                                                 ELSE zif_cd_ops_trace_types=>gc_status-verified )
                                         reason        = COND #( WHEN lv_terminal = abap_true
                                                                 THEN zif_cd_ops_trace_types=>gc_reason-cheque_terminal
                                                                 ELSE zif_cd_ops_trace_types=>gc_reason-cheque_status )
                                         source_table  = ms_cfg-chq_hist-table_name
                                         record_key    = key_text( iv_part1 = <ls_hist>-key1 iv_part2 = <ls_hist>-ref )
                                         evidence_date = to_date( <ls_hist>-ev_date )
                                         evidence_time = to_time( <ls_hist>-ev_time )
                                         detail        = zcl_cd_ops_util=>text(
                                                           iv_msgno = zif_cd_ops_trace_types=>gc_msg-cheque_status
                                                           iv_v1    = <ls_hist>-key1
                                                           iv_v2    = <ls_hist>-status ) ) ).
        ENDLOOP.
      ENDLOOP.
    ELSE.
      " Methods E G H I J K L: FEBEP-CHECT = DFKKOP-AUGBL
      INSERT CONV zif_cd_ops_trace_types=>ty_ref( is_attempt-ref ) INTO TABLE lt_ref.
    ENDIF.

    ls_base-source_table = zif_cd_ops_trace_types=>gc_table-febep.
    IF lt_ref IS INITIAL.
      add_no_link( is_attempt = is_attempt iv_stage = zif_cd_ops_trace_types=>gc_stage-settlement
                   iv_after = zif_cd_ops_trace_types=>gc_stage-payment ).
      RETURN.
    ENDIF.
    " Bank lines from the clearing date minus the look-back; a historical attempt has no
    " known clearing date, so its lines are read by reference only
    DATA(lv_from) = is_attempt-augdt.
    IF lv_from IS NOT INITIAL.
      lv_from = lv_from - ms_cfg-lookback.
    ENDIF.
    DATA(lt_lines) = mo_dao->get_bank_lines( it_ref = lt_ref iv_from = lv_from iv_max_rows = ms_cfg-max_rows ).
    DATA(lv_read) = lines( lt_lines ).
    IF iv_cheque = abap_true.
      " Shared cheque link (as the morning report): FEBEP-CHECT = cheque number AND the line's statement
      " account (FEBKO) = the cheque's paying house bank account (company code of the attempt); a line of
      " another account is not this cheque's, a line fitting several cheques is attributed to none
      DATA(lt_owned) = it_checks.
      LOOP AT lt_owned ASSIGNING FIELD-SYMBOL(<ls_owned>) WHERE bukrs IS INITIAL.
        <ls_owned>-bukrs = is_attempt-bukrs.
      ENDLOOP.
      DATA(lt_read) = lt_lines.
      CLEAR lt_lines.
      LOOP AT zcl_cd_ops_cheque_link=>link( it_checks = lt_owned
                                            it_lines  = lt_read
                                            iv_length = 0 ) ASSIGNING FIELD-SYMBOL(<ls_link>).
        IF <ls_link>-candidates = 1.
          INSERT <ls_link>-line INTO TABLE lt_lines.
          CONTINUE.
        ENDIF.
        add_row( is_attempt = is_attempt
                 is_row     = VALUE #( BASE ls_base status = zif_cd_ops_trace_types=>gc_status-ambiguous
                                       reason        = zif_cd_ops_trace_types=>gc_reason-multiple
                                       record_key    = key_text( iv_part1 = <ls_link>-line-kukey
                                                                 iv_part2 = <ls_link>-line-esnum
                                                                 iv_part3 = <ls_link>-line-chect )
                                       evidence_date = <ls_link>-line-budat
                                       detail        = <ls_link>-detail ) ).
      ENDLOOP.
    ENDIF.
    " A capped read stays visible as AMBIGUOUS even when the link keeps fewer lines
    candidate_status( EXPORTING iv_count  = COND #( WHEN lv_read >= ms_cfg-max_rows THEN lv_read ELSE lines( lt_lines ) )
                      IMPORTING ev_status = ls_base-status
                                ev_reason = ls_base-reason ).
    IF lt_lines IS INITIAL.
      ls_base-record_key = lt_ref[ 1 ].
      ls_base-detail     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-stage_missing
                                                  iv_v1    = zif_cd_ops_trace_types=>gc_table-febep
                                                  iv_v2    = lt_ref[ 1 ] ).
      add_row( is_attempt = is_attempt is_row = ls_base ).
      RETURN.
    ENDIF.
    ls_base-reason = COND #( WHEN ls_base-reason IS NOT INITIAL THEN ls_base-reason
                             WHEN iv_cheque = abap_true THEN zif_cd_ops_trace_types=>gc_reason-encashed
                             ELSE zif_cd_ops_trace_types=>gc_reason-settled ).
    LOOP AT lt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      ls_base-record_key    = key_text( iv_part1 = <ls_line>-kukey iv_part2 = <ls_line>-esnum iv_part3 = <ls_line>-chect ).
      ls_base-evidence_date = <ls_line>-budat.
      ls_base-detail        = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-bank_line
                                                     iv_v1    = <ls_line>-kukey
                                                     iv_v2    = <ls_line>-esnum
                                                     iv_v3    = <ls_line>-chect
                                                     iv_v4    = <ls_line>-budat ).
      add_row( is_attempt = is_attempt is_row = ls_base ).
    ENDLOOP.
  ENDMETHOD.


  METHOD stage_clearing_and_gl.
    DATA lt_fikey TYPE zif_cd_ops_trace_types=>tt_fikey.
    DATA lt_keys TYPE zif_cd_ops_trace_types=>tt_gl_key.

    " Payment engine clearing: current = DFKKOP-AUGBL / AUGDT; historical = reset clearing
    DATA(ls_fica) = VALUE ty_row( stage = zif_cd_ops_trace_types=>gc_stage-fica bukrs = is_attempt-bukrs ).
    CASE is_attempt-kind.
      WHEN zif_cd_ops_trace_types=>gc_attempt-current.
        ls_fica-status        = zif_cd_ops_trace_types=>gc_status-verified.
        ls_fica-reason        = zif_cd_ops_trace_types=>gc_reason-cleared.
        ls_fica-source_table  = zif_cd_ops_trace_types=>gc_table-dfkkop.
        ls_fica-record_key    = key_text( iv_part1 = is_attempt-item_opbel iv_part2 = is_attempt-ref ).
        ls_fica-evidence_date = is_attempt-augdt.
        ls_fica-detail        = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-cleared
                                                       iv_v1    = is_attempt-item_opbel
                                                       iv_v2    = is_attempt-ref
                                                       iv_v3    = is_attempt-augdt ).
      WHEN zif_cd_ops_trace_types=>gc_attempt-historical.
        ls_fica-status        = zif_cd_ops_trace_types=>gc_status-verified.
        ls_fica-reason        = zif_cd_ops_trace_types=>gc_reason-clearing_reset.
        ls_fica-source_table  = is_attempt-hist_table.
        ls_fica-record_key    = key_text( iv_part1 = is_attempt-item_opbel iv_part2 = is_attempt-ref ).
        ls_fica-evidence_date = is_attempt-hist_date.
        ls_fica-evidence_time = is_attempt-hist_time.
        ls_fica-detail        = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-clearing_reset
                                                       iv_v1    = is_attempt-ref
                                                       iv_v2    = is_attempt-item_opbel
                                                       iv_v3    = is_attempt-hist_date ).
      WHEN OTHERS.
        ls_fica-status       = zif_cd_ops_trace_types=>gc_status-missing.
        ls_fica-reason       = zif_cd_ops_trace_types=>gc_reason-no_record.
        ls_fica-source_table = zif_cd_ops_trace_types=>gc_table-dfkkop.
        ls_fica-record_key   = is_attempt-item_opbel.
        ls_fica-detail       = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-stage_missing
                                                      iv_v1    = zif_cd_ops_trace_types=>gc_stage-fica
                                                      iv_v2    = is_attempt-item_opbel ).
    ENDCASE.
    add_row( is_attempt = is_attempt is_row = ls_fica ).
    IF is_attempt-ref IS INITIAL.
      RETURN.
    ENDIF.

    " G/L: DFKKKO-FIKEY of the payment document = DFKKSUMC-FIKEY = BKPF-AWKEY (AWTYP, BUKRS,
    " not reversed)
    DATA(ls_gl) = VALUE ty_row( stage = zif_cd_ops_trace_types=>gc_stage-gl bukrs = is_attempt-bukrs
                                source_table = zif_cd_ops_trace_types=>gc_table-dfkkko record_key = is_attempt-ref ).
    IF NOT line_exists( mt_headers[ KEY by_opbel opbel = is_attempt-ref ] ).
      INSERT LINES OF mo_dao->get_doc_headers( VALUE #( ( is_attempt-ref ) ) ) INTO TABLE mt_headers.
    ENDIF.
    DATA(lv_fikey) = VALUE zif_cd_ops_trace_types=>ty_doc_header-fikey( mt_headers[ KEY by_opbel opbel = is_attempt-ref ]-fikey OPTIONAL ).
    IF lv_fikey IS INITIAL.
      ls_gl-status = zif_cd_ops_trace_types=>gc_status-missing.
      ls_gl-reason = zif_cd_ops_trace_types=>gc_reason-no_fikey.
      ls_gl-detail = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-no_fikey iv_v1 = is_attempt-ref ).
      add_row( is_attempt = is_attempt is_row = ls_gl ).
      RETURN.
    ENDIF.
    INSERT VALUE #( fikey = lv_fikey bukrs = is_attempt-bukrs ) INTO TABLE lt_fikey.
    IF mo_dao->get_summary_keys( lt_fikey ) IS INITIAL.
      ls_gl-status       = zif_cd_ops_trace_types=>gc_status-missing.
      ls_gl-reason       = zif_cd_ops_trace_types=>gc_reason-not_summarised.
      ls_gl-source_table = zif_cd_ops_trace_types=>gc_table-sumc.
      ls_gl-record_key   = lv_fikey.
      ls_gl-detail       = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-not_summarised iv_v1 = lv_fikey ).
      add_row( is_attempt = is_attempt is_row = ls_gl ).
      RETURN.
    ENDIF.
    DATA(lt_docs) = mo_dao->get_gl_documents( it_fikey = lt_fikey iv_awtyp = ms_cfg-awtyp ).
    DELETE lt_docs WHERE stblg IS NOT INITIAL.
    ls_gl-source_table = zif_cd_ops_trace_types=>gc_table-bkpf.
    IF lt_docs IS INITIAL.
      ls_gl-status     = zif_cd_ops_trace_types=>gc_status-missing.
      ls_gl-reason     = zif_cd_ops_trace_types=>gc_reason-not_transferred.
      ls_gl-record_key = lv_fikey.
      ls_gl-detail     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-gl_missing
                                                iv_v1    = lv_fikey
                                                iv_v2    = ms_cfg-awtyp ).
      add_row( is_attempt = is_attempt is_row = ls_gl ).
      RETURN.
    ENDIF.
    LOOP AT lt_docs ASSIGNING FIELD-SYMBOL(<ls_doc>).
      INSERT VALUE #( bukrs = <ls_doc>-bukrs belnr = <ls_doc>-belnr gjahr = <ls_doc>-gjahr ) INTO TABLE lt_keys.
      ls_gl-status        = zif_cd_ops_trace_types=>gc_status-verified.
      ls_gl-reason        = zif_cd_ops_trace_types=>gc_reason-transferred.
      ls_gl-record_key    = key_text( iv_part1 = <ls_doc>-bukrs iv_part2 = <ls_doc>-belnr iv_part3 = <ls_doc>-gjahr ).
      ls_gl-evidence_date = <ls_doc>-cpudt.
      ls_gl-evidence_time = <ls_doc>-cputm.
      ls_gl-detail        = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-gl_doc
                                                   iv_v1    = <ls_doc>-bukrs
                                                   iv_v2    = <ls_doc>-belnr
                                                   iv_v3    = <ls_doc>-gjahr
                                                   iv_v4    = lv_fikey ).
      add_row( is_attempt = is_attempt is_row = ls_gl ).
    ENDLOOP.

    " Clearing-account line of the transferred documents: BSEG-XREF2 = DFKKOP-AUGBL
    " (methods E G H I J K L; read by document key, never by XREF2)
    IF iv_cheque = abap_true.
      RETURN.
    ENDIF.
    DATA(lt_lines) = mo_dao->get_gl_clearing_lines( it_keys = lt_keys iv_xref2 = is_attempt-ref ).
    ls_fica-source_table = zif_cd_ops_trace_types=>gc_table-bseg.
    ls_fica-reason       = zif_cd_ops_trace_types=>gc_reason-gl_line.
    CLEAR ls_fica-evidence_time.
    IF lt_lines IS INITIAL.
      ls_fica-status     = zif_cd_ops_trace_types=>gc_status-missing.
      ls_fica-record_key = is_attempt-ref.
      ls_fica-detail     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-stage_missing
                                                  iv_v1    = zif_cd_ops_trace_types=>gc_table-bseg
                                                  iv_v2    = is_attempt-ref ).
      add_row( is_attempt = is_attempt is_row = ls_fica ).
      RETURN.
    ENDIF.
    LOOP AT lt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      ls_fica-status        = zif_cd_ops_trace_types=>gc_status-verified.
      ls_fica-record_key    = key_text( iv_part1 = <ls_line>-belnr iv_part2 = <ls_line>-buzei iv_part3 = <ls_line>-augbl ).
      " Entry date of the G/L document that carries the line (BSEG has no own entry date)
      DATA(ls_line_doc) = VALUE zif_cd_ops_trace_types=>ty_gl_doc( lt_docs[ bukrs = <ls_line>-bukrs
                                                                             belnr = <ls_line>-belnr
                                                                             gjahr = <ls_line>-gjahr ] OPTIONAL ).
      ls_fica-evidence_date = ls_line_doc-cpudt.
      ls_fica-evidence_time = ls_line_doc-cputm.
      ls_fica-detail        = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-gl_line
                                                     iv_v1    = <ls_line>-belnr
                                                     iv_v2    = <ls_line>-buzei
                                                     iv_v3    = <ls_line>-hkont
                                                     iv_v4    = <ls_line>-xref2 ).
      add_row( is_attempt = is_attempt is_row = ls_fica ).
    ENDLOOP.
  ENDMETHOD.


  METHOD stage_noc.
    DATA lt_infof TYPE zif_cd_ops_trace_types=>tt_infof.
    DATA lt_forms TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
    DATA lt_refs TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    DATA lt_reasons TYPE SORTED TABLE OF zif_cd_ops_trace_types=>ty_noc-flgrd WITH UNIQUE KEY table_line.
    DATA lt_matched TYPE zif_cd_ops_trace_types=>tt_noc.
    DATA(ls_base) = VALUE ty_row( stage        = zif_cd_ops_trace_types=>gc_stage-noc
                                  bukrs        = is_attempt-bukrs
                                  source_table = zif_cd_ops_trace_types=>gc_table-dfkknrp ).

    " INFOF (CHAR 50) holds the payment document (AUGBL) or the payment reference (confirmed
    " 2026-11-06; exact content VERIFY-SE11): the clearing document of the attempt, the FIN
    " of its items and its cheque numbers - each as stored and without leading zeros
    INSERT CONV #( is_attempt-ref ) INTO TABLE lt_refs.
    LOOP AT mt_items ASSIGNING FIELD-SYMBOL(<ls_item>)
         WHERE fin IS NOT INITIAL AND ( opbel = is_attempt-item_opbel OR augbl = is_attempt-ref ).
      INSERT CONV #( <ls_item>-fin ) INTO TABLE lt_refs.
    ENDLOOP.
    LOOP AT it_checks ASSIGNING FIELD-SYMBOL(<ls_check>).
      INSERT CONV #( <ls_check>-ztnum ) INTO TABLE lt_refs.
    ENDLOOP.
    LOOP AT lt_refs ASSIGNING FIELD-SYMBOL(<lv_ref>).
      DATA(lv_canonical) = canonical( <lv_ref> ).
      IF lv_canonical IS INITIAL.
        CONTINUE.
      ENDIF.
      INSERT lv_canonical INTO TABLE lt_forms.
      INSERT CONV #( condense( <lv_ref> ) ) INTO TABLE lt_infof.
      INSERT CONV #( lv_canonical ) INTO TABLE lt_infof.
    ENDLOOP.

    DATA(lt_items) = mo_dao->get_noc_items( it_infof = lt_infof iv_max_rows = ms_cfg-max_rows ).
    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<ls_noc>).
      IF line_exists( lt_forms[ table_line = canonical( <ls_noc>-infof ) ] ).
        INSERT <ls_noc> INTO TABLE lt_matched.
        INSERT <ls_noc>-flgrd INTO TABLE lt_reasons.
      ENDIF.
    ENDLOOP.
    " No NOC item: the payment had no notification of change - not applicable, never missing
    IF lt_matched IS INITIAL.
      add_row( is_attempt = is_attempt
               is_row     = VALUE #( BASE ls_base status = zif_cd_ops_trace_types=>gc_status-not_applicable
                                     reason     = zif_cd_ops_trace_types=>gc_reason-no_noc
                                     record_key = is_attempt-ref
                                     detail     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-no_noc
                                                                         iv_v1    = is_attempt-ref
                                                                         iv_v2    = concat_lines_of( table = lt_forms
                                                                                                     sep   = ` ` ) ) ) ).
      RETURN.
    ENDIF.
    " Several items with different NOC reasons, or the row cap: AMBIGUOUS, every item listed
    IF lines( lt_reasons ) > 1 OR lines( lt_items ) > ms_cfg-max_rows.
      ls_base-status = zif_cd_ops_trace_types=>gc_status-ambiguous.
      ls_base-reason = COND #( WHEN lines( lt_items ) > ms_cfg-max_rows THEN zif_cd_ops_trace_types=>gc_reason-row_cap
                               ELSE zif_cd_ops_trace_types=>gc_reason-multiple ).
    ELSE.
      ls_base-status = zif_cd_ops_trace_types=>gc_status-verified.
      ls_base-reason = zif_cd_ops_trace_types=>gc_reason-noc_item.
    ENDIF.
    LOOP AT lt_matched ASSIGNING FIELD-SYMBOL(<ls_match>).
      ls_base-record_key = key_text( iv_part1 = <ls_match>-keyn1 iv_part2 = <ls_match>-posna ).
      ls_base-detail     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-noc_item
                                                  iv_v1    = <ls_match>-keyn1
                                                  iv_v2    = <ls_match>-posna
                                                  iv_v3    = <ls_match>-flgrd
                                                  iv_v4    = condense( <ls_match>-infof ) ).
      add_row( is_attempt = is_attempt is_row = ls_base ).
    ENDLOOP.
  ENDMETHOD.


  METHOD stage_outcome.
    DATA lt_docno TYPE zif_cd_ops_trace_types=>tt_docno.
    DATA lt_fin TYPE zif_cd_ops_payout_types=>tt_fin.
    DATA lt_sources TYPE zif_cd_ops_payout_types=>tt_fin_source.
    DATA lt_outcomes TYPE SORTED TABLE OF zif_cd_ops_payout_types=>ty_outcome WITH UNIQUE KEY table_line.
    DATA ls_evaluation TYPE zif_cd_ops_payout_types=>ty_evaluation.

    LOOP AT mt_attempts ASSIGNING FIELD-SYMBOL(<ls_attempt>)
         WHERE kind = zif_cd_ops_trace_types=>gc_attempt-current AND ref IS NOT INITIAL.
      INSERT <ls_attempt>-ref INTO TABLE lt_docno.
    ENDLOOP.
    IF lt_docno IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT mt_items ASSIGNING FIELD-SYMBOL(<ls_item>) WHERE fin IS NOT INITIAL.
      INSERT <ls_item>-fin INTO TABLE lt_fin.
    ENDLOOP.
    DATA(lo_outcome) = zcl_cd_ops_factory=>get_pay_outcome( ).
    DATA(lv_error) = ``.
    TRY.
        lo_outcome->load( iv_context  = zif_cd_ops_payout_types=>gc_context
                          iv_max_rows = zcl_cd_ops_pay_outcome=>evidence_cap( ) ).
        ls_evaluation = lo_outcome->evaluate_documents( lt_docno ).
        lt_sources = lo_outcome->sources_of( lt_fin ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        lv_error = lx_error->get_text( ).
    ENDTRY.

    LOOP AT mt_attempts ASSIGNING <ls_attempt>
         WHERE kind = zif_cd_ops_trace_types=>gc_attempt-current AND ref IS NOT INITIAL.
      DATA(ls_row) = VALUE ty_row( stage        = zif_cd_ops_trace_types=>gc_stage-outcome
                                   bukrs        = <ls_attempt>-bukrs
                                   source_table = zif_cd_ops_trace_types=>gc_table-outcome
                                   record_key   = <ls_attempt>-ref ).
      IF lv_error IS NOT INITIAL.
        ls_row-status = zif_cd_ops_trace_types=>gc_status-unavailable.
        ls_row-reason = zif_cd_ops_trace_types=>gc_reason-not_readable.
        ls_row-detail = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-trace_unavailable
                                               iv_v1    = <ls_attempt>-ref
                                               iv_tail  = lv_error ).
        add_row( is_attempt = <ls_attempt> is_row = ls_row ).
        CONTINUE.
      ENDIF.
      DATA(ls_verdict) = VALUE #( ls_evaluation-verdicts[ KEY by_doc doc1r = <ls_attempt>-ref ] OPTIONAL ).
      IF ls_verdict IS INITIAL.
        ls_row-status = zif_cd_ops_trace_types=>gc_status-not_applicable.
        ls_row-reason = zif_cd_ops_trace_types=>gc_reason-not_watched.
        ls_row-detail = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-trace_not_watched
                                               iv_v1    = <ls_attempt>-ref ).
        add_row( is_attempt = <ls_attempt> is_row = ls_row ).
        CONTINUE.
      ENDIF.
      " Source attribution of the attempt's FIN numbers: two or more sources = AMBIGUOUS, never one
      LOOP AT mt_items ASSIGNING <ls_item> WHERE augbl = <ls_attempt>-ref AND fin IS NOT INITIAL.
        LOOP AT lt_sources ASSIGNING FIELD-SYMBOL(<ls_source>) WHERE fin = <ls_item>-fin AND sources > 1.
          ls_verdict = lo_outcome->for_source( is_verdict = ls_verdict is_source = <ls_source> ).
          EXIT.
        ENDLOOP.
      ENDLOOP.
      ls_row-status        = outcome_status( ls_verdict-outcome ).
      ls_row-reason        = zif_cd_ops_trace_types=>gc_reason-outcome.
      ls_row-record_key    = key_text( iv_part1 = <ls_attempt>-ref iv_part2 = ls_verdict-laufd iv_part3 = ls_verdict-laufi ).
      ls_row-evidence_date = ls_verdict-laufd.
      ls_row-detail        = zcl_cd_ops_util=>text(
                               iv_msgno = zif_cd_ops_payout_types=>gc_msg-trace_outcome
                               iv_v1    = ls_verdict-outcome
                               iv_v2    = <ls_attempt>-ref
                               iv_v3    = |{ ls_verdict-laufd DATE = ISO }|
                               iv_v4    = ls_verdict-laufi
                               iv_tail  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-evidence_text
                                                                 iv_v1    = ls_verdict-evidence_kind
                                                                 iv_v2    = ls_verdict-finding
                                                                 iv_tail  = CONV string( ls_verdict-evidence_ref ) ) ).
      add_row( is_attempt = <ls_attempt> is_row = ls_row ).
      INSERT ls_verdict-outcome INTO TABLE lt_outcomes.
    ENDLOOP.
    " One outcome for the trace when every current attempt has the same; otherwise per row only
    IF lines( lt_outcomes ) = 1.
      cs_result-outcome = lt_outcomes[ 1 ].
    ENDIF.
  ENDMETHOD.


  METHOD stage_request_due.
    IF mt_req_keys IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_now) = CONV zif_cd_ops_payout_types=>ty_timestamp( trunc( zcl_cd_ops_factory=>get_clock( )->now( ) ) ).
    TRY.
        DATA(lt_requests) = zcl_cd_ops_factory=>get_pay_request( )->evaluate( it_keys = mt_req_keys iv_now = lv_now ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        add_row( is_row = VALUE #( stage        = zif_cd_ops_trace_types=>gc_stage-request_due
                                   status       = zif_cd_ops_trace_types=>gc_status-unavailable
                                   reason       = zif_cd_ops_trace_types=>gc_reason-not_readable
                                   source_table = ms_cfg-request-table_name
                                   detail       = lx_error->get_text( ) ) ).
        RETURN.
    ENDTRY.
    LOOP AT lt_requests ASSIGNING FIELD-SYMBOL(<ls_request>) WHERE stage IS NOT INITIAL.
      " Not paid by the end of the due date, or paid only after it: the request missed its date
      DATA(lv_missed) = xsdbool( <ls_request>-overdue = abap_true
                                 OR <ls_request>-stage = zif_cd_ops_payout_types=>gc_req_stage-paid_late ).
      add_row( is_row = VALUE #( stage         = zif_cd_ops_trace_types=>gc_stage-request_due
                                 status        = COND #( WHEN lv_missed = abap_true
                                                         THEN zif_cd_ops_trace_types=>gc_status-failed
                                                         ELSE zif_cd_ops_trace_types=>gc_status-verified )
                                 reason        = zif_cd_ops_trace_types=>gc_reason-request_due
                                 source_table  = ms_cfg-request-table_name
                                 record_key    = key_text( iv_part1 = <ls_request>-fin iv_part2 = <ls_request>-source )
                                 evidence_date = <ls_request>-due_date
                                 detail        = zcl_cd_ops_util=>text(
                                                   iv_msgno = zif_cd_ops_payout_types=>gc_msg-trace_request
                                                   iv_v1    = <ls_request>-fin
                                                   iv_v2    = <ls_request>-source
                                                   iv_v3    = <ls_request>-stage
                                                   iv_v4    = |{ <ls_request>-due_date DATE = ISO }|
                                                   iv_tail  = CONV string( <ls_request>-text ) ) ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD reference_documents.
    DATA lt_forms TYPE zif_cd_ops_trace_types=>tt_ref.
    DATA lv_doc TYPE n LENGTH 12.
    DATA lv_suffix TYPE n LENGTH 13.
    DATA(lv_ref) = condense( CONV string( iv_ref ) ).
    DATA(lv_key) = zcl_cd_ops_cheque_link=>ref_key( lv_ref ).
    DATA(lv_digits) = xsdbool( lv_ref CO gc_digits ).
    " The payment document itself (FEBEP-CHECT = AUGBL for methods E G H I J K L): as given and with the
    " leading zeros of the document number; get_items_by_clearing keeps only real clearing documents
    IF strlen( lv_ref ) <= zif_cd_ops_payout_types=>gc_docno_length.
      INSERT CONV #( lv_ref ) INTO TABLE rt_docno.
      IF lv_digits = abap_true.
        lv_doc = lv_ref.
        INSERT CONV #( lv_doc ) INTO TABLE rt_docno.
      ENDIF.
    ENDIF.
    " The cheque number (method C): full, without leading zeros, and the last 13 characters zero-padded
    INSERT CONV #( lv_ref ) INTO TABLE lt_forms.
    INSERT CONV #( lv_key ) INTO TABLE lt_forms.
    IF lv_digits = abap_true AND strlen( lv_ref ) <= zif_cd_hck_runtime_types=>gc_check_default-ztnum_suffix.
      lv_suffix = lv_ref.
      INSERT CONV #( lv_suffix ) INTO TABLE lt_forms.
    ENDIF.
    LOOP AT lt_forms ASSIGNING FIELD-SYMBOL(<lv_form>).
      LOOP AT mo_dao->get_checks_by_number( iv_ztnum = <lv_form> iv_max_rows = ms_cfg-max_rows )
           ASSIGNING FIELD-SYMBOL(<ls_check>) WHERE doc1r IS NOT INITIAL.
        " The register number is the reference, or ends with it (the statement shows the last 13)
        IF zcl_cd_ops_cheque_link=>ref_key( <ls_check>-ztnum ) = lv_key
           OR zcl_cd_ops_cheque_link=>ref_key( zcl_cd_ops_cheque_link=>suffix(
                iv_ztnum  = <ls_check>-ztnum
                iv_length = zif_cd_hck_runtime_types=>gc_check_default-ztnum_suffix ) ) = lv_key.
          INSERT <ls_check>-doc1r INTO TABLE rt_docno.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD outcome_status.
    rv_status = SWITCH #( iv_outcome
                          WHEN zif_cd_ops_payout_types=>gc_outcome-ambiguous    THEN zif_cd_ops_trace_types=>gc_status-ambiguous
                          WHEN zif_cd_ops_payout_types=>gc_outcome-inconsistent THEN zif_cd_ops_trace_types=>gc_status-failed
                          WHEN zif_cd_ops_payout_types=>gc_outcome-undetermined THEN zif_cd_ops_trace_types=>gc_status-unavailable
                          ELSE zif_cd_ops_trace_types=>gc_status-verified ).
  ENDMETHOD.


  METHOD canonical.
    rv_value = condense( CONV string( iv_value ) ).
    IF rv_value CO gc_digits.
      SHIFT rv_value LEFT DELETING LEADING '0'.
    ENDIF.
  ENDMETHOD.


  METHOD candidate_status.
    CLEAR ev_reason.
    IF iv_count >= ms_cfg-max_rows.
      ev_status = zif_cd_ops_trace_types=>gc_status-ambiguous.
      ev_reason = zif_cd_ops_trace_types=>gc_reason-row_cap.
    ELSEIF iv_count = 0.
      ev_status = zif_cd_ops_trace_types=>gc_status-missing.
      ev_reason = zif_cd_ops_trace_types=>gc_reason-no_record.
    ELSEIF iv_count = 1.
      ev_status = zif_cd_ops_trace_types=>gc_status-verified.
    ELSE.
      ev_status = zif_cd_ops_trace_types=>gc_status-ambiguous.
      ev_reason = zif_cd_ops_trace_types=>gc_reason-multiple.
    ENDIF.
  ENDMETHOD.


  METHOD add_row.
    DATA(ls_row) = is_row.
    ls_row-attempt      = is_attempt-no.
    ls_row-attempt_kind = is_attempt-kind.
    ls_row-clearing_ref = is_attempt-ref.
    ls_row-seq          = stage_seq( ls_row-stage ).
    ls_row-light        = light( ls_row-status ).
    " Nothing about a company the user may not see: no key, no time
    IF ls_row-reason = zif_cd_ops_trace_types=>gc_reason-not_authorised.
      CLEAR: ls_row-record_key, ls_row-evidence_date, ls_row-evidence_time, ls_row-clearing_ref.
    ENDIF.
    INSERT ls_row INTO TABLE mt_rows.
  ENDMETHOD.


  METHOD add_no_link.
    add_row( is_attempt = is_attempt
             is_row     = VALUE #( stage  = iv_stage
                                   status = zif_cd_ops_trace_types=>gc_status-unavailable
                                   reason = zif_cd_ops_trace_types=>gc_reason-no_link
                                   bukrs  = is_attempt-bukrs
                                   detail = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-no_link
                                                                   iv_v1    = iv_after ) ) ).
  ENDMETHOD.


  METHOD finish.
    DATA lv_current TYPE i.
    DATA lv_failed TYPE abap_bool.
    DATA lv_ambiguous TYPE abap_bool.
    DATA lv_gap TYPE abap_bool.

    SORT mt_rows STABLE BY attempt seq.
    " First missing or failed milestone of every attempt
    " NOC rows are informational (a notification of change is no failure of the payment)
    LOOP AT mt_rows ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE status <> zif_cd_ops_trace_types=>gc_status-verified
                                                      AND status <> zif_cd_ops_trace_types=>gc_status-not_applicable
                                                      AND stage <> zif_cd_ops_trace_types=>gc_stage-noc
                                                      AND stage <> zif_cd_ops_trace_types=>gc_stage-outcome
                                                      AND stage <> zif_cd_ops_trace_types=>gc_stage-request_due
                                                      AND stage <> zif_cd_ops_trace_types=>gc_stage-config.
      IF NOT line_exists( mt_rows[ attempt = <ls_row>-attempt first_gap = abap_true ] ).
        <ls_row>-first_gap = abap_true.
      ENDIF.
    ENDLOOP.

    " The verdict looks at the request and the current attempts; historical attempts were
    " reversed or reset and are shown for evidence only
    " The canonical outcome (OUTCOME rows) is shown and returned, but the verdict judges the evidence
    LOOP AT mt_rows INTO DATA(ls_row) WHERE attempt_kind <> zif_cd_ops_trace_types=>gc_attempt-historical
                                        AND stage <> zif_cd_ops_trace_types=>gc_stage-noc
                                        AND stage <> zif_cd_ops_trace_types=>gc_stage-outcome
                                        AND stage <> zif_cd_ops_trace_types=>gc_stage-request_due
                                        AND stage <> zif_cd_ops_trace_types=>gc_stage-config.
      CASE ls_row-status.
        WHEN zif_cd_ops_trace_types=>gc_status-failed.
          lv_failed = abap_true.
        WHEN zif_cd_ops_trace_types=>gc_status-ambiguous.
          lv_ambiguous = abap_true.
        WHEN zif_cd_ops_trace_types=>gc_status-missing OR zif_cd_ops_trace_types=>gc_status-unavailable.
          lv_gap = abap_true.
      ENDCASE.
      IF is_gap( ls_row-status ) = abap_true AND cs_result-first_gap_stage IS INITIAL.
        cs_result-first_gap_stage   = ls_row-stage.
        cs_result-first_gap_attempt = ls_row-attempt.
      ENDIF.
    ENDLOOP.
    LOOP AT mt_attempts TRANSPORTING NO FIELDS WHERE kind = zif_cd_ops_trace_types=>gc_attempt-current.
      lv_current += 1.
    ENDLOOP.

    cs_result-attempts = lines( mt_attempts ).
    cs_result-verdict = COND #( WHEN mv_found = abap_false THEN zif_cd_ops_trace_types=>gc_verdict-not_found
                                WHEN lv_failed = abap_true THEN zif_cd_ops_trace_types=>gc_verdict-failed
                                WHEN lv_ambiguous = abap_true THEN zif_cd_ops_trace_types=>gc_verdict-ambiguous
                                WHEN lv_gap = abap_true OR lv_current = 0
                                  THEN zif_cd_ops_trace_types=>gc_verdict-incomplete
                                ELSE zif_cd_ops_trace_types=>gc_verdict-complete ).
    cs_result-rows = mt_rows.
  ENDMETHOD.


  METHOD is_allowed.
    rv_allowed = zcl_cd_ops_factory=>get_auth( )->is_allowed( iv_activity = zif_cd_ops_auth=>gc_activity-display
                                                              iv_pe_area  = zif_cd_ops_types=>gc_pe_area-core
                                                              iv_bukrs    = iv_bukrs ).
  ENDMETHOD.


  METHOD stage_seq.
    rv_seq = SWITCH #( iv_stage
                       WHEN zif_cd_ops_trace_types=>gc_stage-config     THEN 0
                       WHEN zif_cd_ops_trace_types=>gc_stage-request    THEN 1
                       WHEN zif_cd_ops_trace_types=>gc_stage-request_due THEN 1
                       WHEN zif_cd_ops_trace_types=>gc_stage-sap_item   THEN 2
                       WHEN zif_cd_ops_trace_types=>gc_stage-history    THEN 3
                       WHEN zif_cd_ops_trace_types=>gc_stage-payment    THEN 4
                       WHEN zif_cd_ops_trace_types=>gc_stage-file       THEN 5
                       WHEN zif_cd_ops_trace_types=>gc_stage-prism      THEN 6
                       WHEN zif_cd_ops_trace_types=>gc_stage-bank_ack   THEN 7
                       WHEN zif_cd_ops_trace_types=>gc_stage-settlement THEN 8
                       WHEN zif_cd_ops_trace_types=>gc_stage-noc        THEN 9
                       WHEN zif_cd_ops_trace_types=>gc_stage-fica       THEN 10
                       WHEN zif_cd_ops_trace_types=>gc_stage-gl         THEN 11
                       WHEN zif_cd_ops_trace_types=>gc_stage-outcome    THEN 12 ).
  ENDMETHOD.


  METHOD light.
    rv_light = SWITCH #( iv_status
                         WHEN zif_cd_ops_trace_types=>gc_status-verified
                           OR zif_cd_ops_trace_types=>gc_status-not_applicable THEN zif_cd_ops_types=>gc_light-green
                         WHEN zif_cd_ops_trace_types=>gc_status-failed
                           OR zif_cd_ops_trace_types=>gc_status-missing THEN zif_cd_ops_types=>gc_light-red
                         ELSE zif_cd_ops_types=>gc_light-yellow ).
  ENDMETHOD.


  METHOD in_list.
    DATA(lv_value) = condense( CONV string( iv_value ) ).
    SPLIT iv_list AT zif_cd_ops_trace_types=>gc_list_sep INTO TABLE DATA(lt_values).
    LOOP AT lt_values ASSIGNING FIELD-SYMBOL(<lv_entry>).
      IF condense( <lv_entry> ) = lv_value.
        rv_in = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD to_date.
    " YYYYMMDD, or the date part of a time stamp YYYYMMDDhhmmss[.fffffff]
    DATA(lv_value) = condense( CONV string( iv_value ) ).
    IF strlen( lv_value ) >= gc_date_length.
      DATA(lv_date) = substring( val = lv_value len = gc_date_length ).
      IF lv_date CO gc_digits.
        rv_date = lv_date.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD to_time.
    " hhmmss, or the time part of a time stamp YYYYMMDDhhmmss[.fffffff]
    DATA(lv_value) = condense( CONV string( iv_value ) ).
    DATA(lv_time) = COND string( WHEN strlen( lv_value ) = gc_time_length THEN lv_value
                                 WHEN strlen( lv_value ) >= gc_date_length + gc_time_length
                                 THEN substring( val = lv_value off = gc_date_length len = gc_time_length ) ).
    IF lv_time IS NOT INITIAL AND lv_time CO gc_digits.
      rv_time = lv_time.
    ENDIF.
  ENDMETHOD.


  METHOD to_int.
    DATA(lv_value) = condense( iv_value ).
    rv_int = iv_default.
    IF lv_value IS NOT INITIAL AND lv_value CO gc_digits AND strlen( lv_value ) <= gc_date_length.
      rv_int = lv_value.
    ENDIF.
    IF rv_int <= 0.
      rv_int = iv_default.
    ENDIF.
  ENDMETHOD.


  METHOD is_gap.
    rv_gap = xsdbool( iv_status <> zif_cd_ops_trace_types=>gc_status-verified
                      AND iv_status <> zif_cd_ops_trace_types=>gc_status-not_applicable ).
  ENDMETHOD.


  METHOD key_text.
    rv_text = condense( CONV string( iv_part1 ) ).
    IF iv_part2 IS NOT INITIAL.
      rv_text = rv_text && zif_cd_ops_trace_types=>gc_key_sep && condense( CONV string( iv_part2 ) ).
    ENDIF.
    IF iv_part3 IS NOT INITIAL.
      rv_text = rv_text && zif_cd_ops_trace_types=>gc_key_sep && condense( CONV string( iv_part3 ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
