*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_docchg.clas.abap
*& Purpose:
*& Document-change risk check A_DOC_CHANGE (build C, severity E, through the
*& HCK check contract): payment documents reversed in the window (one
*& set-based read, ZIF_CD_HCK_DOCCHG_DAO) are judged with batch reads of the
*& existing repositories - bank lines by CHECT and cheques by payment document
*& (payment trace repository, as A_INFLIGHT), G/L transfer gaps of the
*& reconciliation keys (the A_GL_TRANSFER read, reused - no second gap rule):
*& REV_AFTER_LEFT_SAP - reversed after it left SAP (payment status in PARAM4,
*& a bank line, a cashed cheque): possible double payment or orphaned bank
*& item; REV_GL_NOT_REVERSED - the reversal's reconciliation key has no G/L
*& transfer after the lag; REV_BANK_LINE - a bank line references the
*& reversed payment document (bucket reset / reversal of the ledger
*& reconciliation). No SELECT per payment. Not built: clearing reset without
*& re-clearing after N days (needs the clearing-reset history, VERIFY).
*& Read-only: findings only, through the engine.
*& Modification log:
*& 2026-11-11 | Initial version (reversal and reset-clearing tracking, build C).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - reversals of payments that left SAP</p>
"! PARAM1 = window in days (default 7, reversal entry dates up to the day before the report date),
"! PARAM2 = G/L transfer lag in days (default 1), PARAM3 = row cap of every read (default 500),
"! PARAM4 = payment statuses that mean the payment left SAP (comma list, default ISSUED, CONFIRMED,
"! CLEARED, RETURNED, RETRIEVED). A capped read is REV_READ_CAPPED (W) and evidence PARTIAL.
CLASS zcl_cd_hck_c_docchg DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_ref_doc,
        ref TYPE zif_cd_ops_trace_types=>ty_ref,
        doc TYPE zif_cd_hck_docchg_types=>ty_docno,
      END OF ty_ref_doc.
    TYPES tt_ref_doc TYPE SORTED TABLE OF ty_ref_doc WITH NON-UNIQUE KEY ref.

    "! Leading zero of a document number (statement references are read with and without)
    CONSTANTS gc_leading_zero TYPE string VALUE `0`.

    DATA ms_result TYPE zif_cd_hck_types=>ty_check_result.

    "! The latest payment run of every reversed payment document (rows ordered by document, run
    "! date and run ID descending)
    METHODS latest_runs
      IMPORTING
        it_rows             TYPE zif_cd_hck_docchg_types=>tt_reversal
      RETURNING
        VALUE(rt_reversals) TYPE zif_cd_hck_docchg_types=>tt_reversal.

    "! Statement references of the documents: as stored and without leading zeros (both forms of
    "! FEBEP-CHECT are read, as the in-flight check)
    METHODS reference_forms
      IMPORTING
        it_reversals   TYPE zif_cd_hck_docchg_types=>tt_reversal
      RETURNING
        VALUE(rt_refs) TYPE tt_ref_doc.

    METHODS add_metric
      IMPORTING
        iv_metric TYPE zif_cd_hck_types=>ty_metric_name
        iv_value  TYPE i.

ENDCLASS.



CLASS zcl_cd_hck_c_docchg IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA lt_docnos TYPE zif_cd_ops_trace_types=>tt_docno.
    DATA lt_refs TYPE zif_cd_ops_trace_types=>tt_ref.
    DATA lt_left TYPE zif_cd_hck_docchg_types=>tt_pay_status.
    DATA lv_left_count TYPE i.
    DATA lv_gl_count TYPE i.
    DATA lv_line_count TYPE i.
    CLEAR ms_result.

    DATA(lv_window) = nmax( val1 = 1
                            val2 = zcl_cd_hck_param=>int( iv_value   = is_def-param1
                                                          iv_default = zif_cd_hck_docchg_types=>gc_default-window_days ) ).
    DATA(lv_lag) = zcl_cd_hck_param=>int( iv_value   = is_def-param2
                                          iv_default = zif_cd_hck_docchg_types=>gc_default-lag_days ).
    DATA(lv_max) = nmax( val1 = 1
                         val2 = zcl_cd_hck_param=>int( iv_value   = is_def-param3
                                                       iv_default = zif_cd_hck_docchg_types=>gc_default-max_rows ) ).
    DATA(lv_list) = COND string( WHEN is_def-param4 IS INITIAL THEN zif_cd_hck_docchg_types=>gc_default-left_statuses
                                 ELSE is_def-param4 ).
    LOOP AT zcl_ca_ops_util=>split_list( lv_list ) INTO DATA(lv_status).
      INSERT CONV zif_cd_hck_docchg_types=>ty_pay_status( to_upper( condense( lv_status ) ) ) INTO TABLE lt_left.
    ENDLOOP.
    DATA(lv_to)   = CONV d( is_context-report_date - 1 ).
    DATA(lv_from) = CONV d( lv_to - lv_window + 1 ).

    " 1. Reversed payments of the window (one read; the cap + 1 tells a capped read)
    DATA(lt_rows) = zcl_cd_hck_factory=>get_docchg_dao( )->get_reversed_payments( iv_from     = lv_from
                                                                                   iv_to       = lv_to
                                                                                   iv_max_rows = lv_max + 1 ).
    DATA(lv_capped) = xsdbool( lines( lt_rows ) > lv_max ).
    IF lv_capped = abap_true.
      DELETE lt_rows FROM lv_max + 1.
    ENDIF.
    DATA(lt_reversals) = latest_runs( lt_rows ).
    add_metric( iv_metric = zif_cd_hck_docchg_types=>gc_metric-reversals iv_value = lines( lt_reversals ) ).

    " 2. Evidence that the payments left SAP and their bank lines - batch reads of the trace repository
    DATA(lt_ref_doc) = reference_forms( lt_reversals ).
    DATA(lv_first_run) = lv_from.
    LOOP AT lt_reversals ASSIGNING FIELD-SYMBOL(<ls_reversal>).
      INSERT CONV #( <ls_reversal>-payment_doc ) INTO TABLE lt_docnos.
      IF <ls_reversal>-laufd IS NOT INITIAL AND <ls_reversal>-laufd < lv_first_run.
        lv_first_run = <ls_reversal>-laufd.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_ref_doc ASSIGNING FIELD-SYMBOL(<ls_ref>).
      INSERT <ls_ref>-ref INTO TABLE lt_refs.
    ENDLOOP.
    DATA(lo_trace) = zcl_cd_ops_factory=>get_trace_dao( ).
    DATA(lt_lines) = COND zif_cd_ops_trace_types=>tt_bank_line(
                       WHEN lt_refs IS NOT INITIAL
                       THEN lo_trace->get_bank_lines( it_ref      = lt_refs
                                                      iv_from     = lv_first_run
                                                      iv_max_rows = lv_max + 1 ) ).
    IF lines( lt_lines ) > lv_max.
      lv_capped = abap_true.
      DELETE lt_lines FROM lv_max + 1.
    ENDIF.
    DATA(lt_checks) = COND zif_cd_ops_trace_types=>tt_check(
                        WHEN lt_docnos IS NOT INITIAL THEN lo_trace->get_checks_by_doc( lt_docnos ) ).

    " 3. Reconciliation keys without G/L transfer after the lag: the A_GL_TRANSFER read, reused
    DATA(lv_gl_to) = CONV d( lv_to - lv_lag ).
    DATA(lt_gaps) = COND zif_cd_hck_types=>tt_fikey_gap(
                      WHEN lt_reversals IS NOT INITIAL AND lv_gl_to >= lv_from
                      THEN zcl_cd_hck_factory=>get_dao( )->get_fikeys_without_gl(
                             iv_from     = lv_from
                             iv_to       = lv_gl_to
                             iv_max_rows = lv_max + 1
                             iv_awtyp    = zcl_cd_hck_c_gl_transfer=>gc_default_awtyp ) ).
    IF lines( lt_gaps ) > lv_max.
      lv_capped = abap_true.
    ENDIF.

    LOOP AT lt_reversals ASSIGNING <ls_reversal>.
      DATA(lv_evidence) = COND zif_cd_hck_docchg_types=>ty_evidence(
        WHEN line_exists( lt_left[ table_line = <ls_reversal>-status ] ) THEN <ls_reversal>-status ).
      IF lv_evidence IS INITIAL.
        LOOP AT lt_ref_doc ASSIGNING <ls_ref> WHERE doc = <ls_reversal>-payment_doc.
          IF line_exists( lt_lines[ chect = <ls_ref>-ref ] ).
            lv_evidence = zif_cd_hck_docchg_types=>gc_evidence-bank_line.
          ENDIF.
        ENDLOOP.
      ENDIF.
      IF lv_evidence IS INITIAL
     AND line_exists( lt_checks[ doc1r = <ls_reversal>-payment_doc state = zif_cd_hck_docchg_types=>gc_cheque_cashed ] ).
        lv_evidence = zif_cd_hck_docchg_types=>gc_evidence-cheque_cashed.
      ENDIF.
      IF lv_evidence IS NOT INITIAL.
        lv_left_count = lv_left_count + 1.
        INSERT VALUE #( object_key    = |{ zif_cd_hck_docchg_types=>gc_key-left_sap }|
                                     && |{ zif_cd_hck_docchg_types=>gc_key-separator }{ <ls_reversal>-payment_doc }|
                        check_code    = zif_cd_hck_docchg_types=>gc_code-left_sap
                        severity      = zif_ca_ops_types=>gc_severity-error
                        action        = zif_ca_ops_types=>gc_action-exception
                        amount        = abs( <ls_reversal>-amount )
                        currency      = <ls_reversal>-currency
                        reference     = <ls_reversal>-payment_doc
                        business_date = <ls_reversal>-reversed_on
                        company_code  = <ls_reversal>-bukrs
                        item_count    = 1
                        message       = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_docchg_types=>gc_msg-left_sap
                                                               iv_v1    = <ls_reversal>-payment_doc
                                                               iv_v2    = <ls_reversal>-reversal_doc
                                                               iv_v3    = |{ <ls_reversal>-reversed_on DATE = ISO }|
                                                               iv_v4    = lv_evidence ) ) INTO TABLE ms_result-findings.
      ENDIF.
      IF line_exists( lt_gaps[ fikey = <ls_reversal>-fikey bukrs = <ls_reversal>-bukrs ] ).
        lv_gl_count = lv_gl_count + 1.
        INSERT VALUE #( object_key    = |{ zif_cd_hck_docchg_types=>gc_key-gl_not_rev }|
                                     && |{ zif_cd_hck_docchg_types=>gc_key-separator }{ <ls_reversal>-reversal_doc }|
                        check_code    = zif_cd_hck_docchg_types=>gc_code-gl_not_rev
                        severity      = zif_ca_ops_types=>gc_severity-error
                        action        = zif_ca_ops_types=>gc_action-exception
                        amount        = abs( <ls_reversal>-amount )
                        currency      = <ls_reversal>-currency
                        reference     = <ls_reversal>-payment_doc
                        business_date = <ls_reversal>-reversed_on
                        company_code  = <ls_reversal>-bukrs
                        item_count    = 1
                        message       = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_docchg_types=>gc_msg-gl_not_rev
                                                               iv_v1    = <ls_reversal>-reversal_doc
                                                               iv_v2    = <ls_reversal>-payment_doc
                                                               iv_v3    = <ls_reversal>-fikey ) ) INTO TABLE ms_result-findings.
      ENDIF.
    ENDLOOP.

    " 4. Bank lines that reference a reversed payment document (bucket reset / reversal)
    LOOP AT lt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      READ TABLE lt_ref_doc ASSIGNING <ls_ref> WITH TABLE KEY ref = <ls_line>-chect.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      READ TABLE lt_reversals ASSIGNING <ls_reversal> WITH KEY payment_doc = <ls_ref>-doc.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      lv_line_count = lv_line_count + 1.
      DATA(lv_line_key) = |{ <ls_line>-kukey }{ zif_cd_hck_docchg_types=>gc_key-separator }{ <ls_line>-esnum }|.
      INSERT VALUE #( object_key    = |{ zif_cd_hck_docchg_types=>gc_key-bank_line }|
                                   && |{ zif_cd_hck_docchg_types=>gc_key-separator }{ lv_line_key }|
                      check_code    = zif_cd_hck_docchg_types=>gc_code-bank_line
                      severity      = zif_ca_ops_types=>gc_severity-error
                      action        = zif_ca_ops_types=>gc_action-exception
                      reference     = <ls_reversal>-payment_doc
                      business_date = <ls_line>-budat
                      company_code  = <ls_line>-bukrs
                      account       = |{ <ls_line>-hbkid }{ zif_cd_hck_docchg_types=>gc_key-separator }{ <ls_line>-hktid }|
                      item_count    = 1
                      message       = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_docchg_types=>gc_msg-bank_line
                                                             iv_v1    = lv_line_key
                                                             iv_v2    = <ls_reversal>-payment_doc
                                                             iv_v3    = <ls_reversal>-reversal_doc ) ) INTO TABLE ms_result-findings.
    ENDLOOP.

    add_metric( iv_metric = zif_cd_hck_docchg_types=>gc_metric-left_sap iv_value = lv_left_count ).
    add_metric( iv_metric = zif_cd_hck_docchg_types=>gc_metric-gl_not_rev iv_value = lv_gl_count ).
    add_metric( iv_metric = zif_cd_hck_docchg_types=>gc_metric-bank_line iv_value = lv_line_count ).
    IF lv_capped = abap_true.
      ms_result-completion = zif_cd_hck_types=>gc_completion-partial.
      ms_result-evidence   = zif_cd_hck_types=>gc_completion-partial.
      INSERT VALUE #( object_key = CONV #( zif_cd_hck_docchg_types=>gc_code-capped )
                      check_code = zif_cd_hck_docchg_types=>gc_code-capped
                      severity   = zif_ca_ops_types=>gc_severity-warning
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_docchg_types=>gc_msg-capped
                                                          iv_v1    = lv_max
                                                          iv_v2    = |{ lv_from DATE = ISO }|
                                                          iv_v3    = |{ lv_to DATE = ISO }| ) ) INTO TABLE ms_result-findings.
    ENDIF.
    rs_result = ms_result.
  ENDMETHOD.


  METHOD latest_runs.
    " rows come ordered by document, run date and run ID descending: the first row of a document wins
    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF NOT line_exists( rt_reversals[ payment_doc = <ls_row>-payment_doc ] ).
        INSERT <ls_row> INTO TABLE rt_reversals.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD reference_forms.
    LOOP AT it_reversals ASSIGNING FIELD-SYMBOL(<ls_reversal>).
      INSERT VALUE #( ref = <ls_reversal>-payment_doc doc = <ls_reversal>-payment_doc ) INTO TABLE rt_refs.
      DATA(lv_short) = shift_left( val = CONV string( <ls_reversal>-payment_doc ) sub = gc_leading_zero ).
      IF lv_short <> CONV string( <ls_reversal>-payment_doc ) AND lv_short IS NOT INITIAL.
        INSERT VALUE #( ref = lv_short doc = <ls_reversal>-payment_doc ) INTO TABLE rt_refs.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD add_metric.
    INSERT VALUE #( metric = iv_metric
                    dim1   = zif_cd_hck_types=>gc_default_key
                    value  = iv_value ) INTO TABLE ms_result-metrics.
  ENDMETHOD.

ENDCLASS.
