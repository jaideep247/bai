*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_prq_not_paid.clas.abap
*& Purpose:
*& Financial integrity: payment requests (ZCD_PAYM_REQ_LOG, a SUCCESS
*& attempt of FIN + source) not paid in a payment run by the end of their
*& due date (user decision 2026-11-08). Reads only the payment worklist
*& ZCD_PAY_OUTCOME: the current request rows due before today - REQ_NOT_PAID
*& (marked by the nightly re-evaluation) and REQ_OPEN rows the nightly has
*& not judged yet - with the stage they reached (no payment engine item,
*& payment block, item open and not in a payment run, cleared without
*& payment run). One finding per source + stage + due date (severity E: RED
*& from the morning after the due date) with the count, the amount per
*& currency (the items of the FIN; without item the request amount,
*& VERIFY-SE11, currency unknown) and the first PAYOUT_EXAMPLES requests.
*& A nightly re-evaluation not completed since the start of the day is said
*& (PAY_NIGHTLY_MISSING W, evidence PARTIAL). Failed requests stay with
*& C_PRQ_NO_SPE, paid-but-cancelled with C_PRQ_CANCEL. Read-only.
*& Modification log:
*& 2026-11-08 | Initial version (requests not paid on their requested payment date).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - payment requests not paid on the due date</p>
"! No PARAM1-4: row cap HCK_INFLIGHT_MAX_ROWS (as A_INFLIGHT), examples PAYOUT_EXAMPLES. Metric
"! PRQ_NOT_PAID: DIM1 * (all) and per source with DIM2 the stage; thresholds ZCD_HCK_THRESH.
CLASS zcl_cd_hck_c_prq_not_paid DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS gc_metric TYPE zif_cd_hck_types=>ty_metric_name VALUE 'PRQ_NOT_PAID'.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_amount,
        currency TYPE zif_ca_ops_types=>ty_currency,
        amount   TYPE zif_ca_ops_types=>ty_amount,
      END OF ty_amount.
    TYPES tt_amount TYPE SORTED TABLE OF ty_amount WITH UNIQUE KEY currency.

    "! One aggregated finding: source, stage, due date
    TYPES:
      BEGIN OF ty_cell,
        source   TYPE zif_cd_ops_trace_types=>ty_source,
        stage    TYPE zif_cd_ops_payout_types=>ty_req_stage,
        due_date TYPE d,
        requests TYPE i,
        amounts  TYPE tt_amount,
        examples TYPE string_table,
      END OF ty_cell.
    TYPES tt_cell TYPE SORTED TABLE OF ty_cell WITH UNIQUE KEY source stage due_date.

    DATA ms_def TYPE zif_cd_hck_types=>ty_check_def.
    DATA mv_examples TYPE i.

    "! The nightly re-evaluation of the request rows completed since the start of today
    METHODS nightly_done
      IMPORTING
        is_context     TYPE zif_cd_hck_types=>ty_context
      RETURNING
        VALUE(rv_done) TYPE abap_bool.

    "! The request amount (request log AMOUNT=, VERIFY-SE11) of rows without item
    METHODS request_amounts
      IMPORTING
        it_rows           TYPE zif_cd_ops_payout_types=>tt_due_request
        is_context        TYPE zif_cd_hck_types=>ty_context
      RETURNING
        VALUE(rt_amounts) TYPE zif_cd_ops_payout_types=>tt_request.

ENDCLASS.



CLASS zcl_cd_hck_c_prq_not_paid IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA lt_cells TYPE tt_cell.
    DATA lt_counted TYPE zif_cd_ops_payout_types=>tt_req_key.
    DATA lt_details TYPE string_table.
    DATA lt_amounts TYPE string_table.
    ms_def = is_def.
    DATA(lv_cap) = zcl_cd_hck_param=>row_cap( iv_name    = zif_cd_hck_runtime_types=>gc_param-inflight_max_rows
                                              iv_default = zif_cd_hck_runtime_types=>gc_param_default-inflight_max_rows
                                              iv_ceiling = zif_cd_hck_runtime_types=>gc_max_inflight_rows ).
    mv_examples = nmax( val1 = 1
                        val2 = zcl_ca_ops_util=>param_int( io_params  = zcl_cd_ops_factory=>get_params( )
                                                           iv_name    = zif_cd_ops_payout_types=>gc_param-examples
                                                           iv_default = zif_cd_ops_payout_types=>gc_param_default-examples ) ).

    " Without the nightly re-evaluation a request due yesterday may still be an open row (counted, but
    " its stage is the one of its last evaluation): said, never green on it
    IF nightly_done( is_context ) = abap_false.
      rs_result-evidence = zif_cd_hck_types=>gc_evidence-partial.
      INSERT VALUE #( object_key = |{ ms_def-check_id }/{ zif_cd_ops_payout_types=>gc_code-nightly_missing }|
                      check_code = zif_cd_ops_payout_types=>gc_code-nightly_missing
                      severity   = zif_ca_ops_types=>gc_severity-warning
                      action     = zif_ca_ops_types=>gc_action-notify
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-nightly_missing
                                                          iv_v1    = zif_cd_ops_payout_types=>gc_mode-nightly
                                                          iv_v2    = |{ is_context-now_date DATE = ISO }| ) )
             INTO TABLE rs_result-findings.
    ENDIF.

    " The request rows due before today (exceptions only, bounded); a capped read is said
    DATA(lt_rows) = zcl_cd_ops_factory=>get_pay_outcome_dao( )->get_due_requests( iv_before = is_context-now_date
                                                                                 iv_max    = lv_cap ).
    IF lines( lt_rows ) >= lv_cap.
      rs_result-completion = zif_cd_hck_types=>gc_completion-partial.
      INSERT VALUE #( object_key = |{ ms_def-check_id }/{ zif_cd_ops_payout_types=>gc_table-outcome }|
                      check_code = zif_cd_hck_runtime_types=>gc_code-read_capped
                      severity   = zif_ca_ops_types=>gc_severity-warning
                      action     = zif_ca_ops_types=>gc_action-notify
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-read_capped
                                                          iv_v1    = zif_cd_ops_payout_types=>gc_table-outcome
                                                          iv_v2    = lv_cap
                                                          iv_v3    = ms_def-check_id ) ) INTO TABLE rs_result-findings.
    ENDIF.
    DATA(lt_requested) = request_amounts( it_rows = lt_rows is_context = is_context ).

    " One cell per source + stage + due date; a request counts once (its items may be in two currencies)
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      READ TABLE lt_cells ASSIGNING FIELD-SYMBOL(<ls_cell>)
           WITH TABLE KEY source = <ls_row>-source stage = <ls_row>-stage due_date = <ls_row>-due_date.
      IF sy-subrc <> 0.
        INSERT VALUE #( source = <ls_row>-source stage = <ls_row>-stage due_date = <ls_row>-due_date )
          INTO TABLE lt_cells ASSIGNING <ls_cell>.
      ENDIF.
      DATA(ls_amount) = VALUE ty_amount( currency = <ls_row>-currency amount = abs( <ls_row>-amount ) ).
      IF <ls_row>-currency IS INITIAL.
        " No item: the request amount (currency not known - VERIFY-SE11)
        ls_amount-amount = abs( VALUE #( lt_requested[ KEY by_key fin = <ls_row>-fin_id source = <ls_row>-source ]-amount
                                         OPTIONAL ) ).
      ENDIF.
      READ TABLE <ls_cell>-amounts ASSIGNING FIELD-SYMBOL(<ls_sum>) WITH TABLE KEY currency = ls_amount-currency.
      IF sy-subrc <> 0.
        INSERT VALUE #( currency = ls_amount-currency ) INTO TABLE <ls_cell>-amounts ASSIGNING <ls_sum>.
      ENDIF.
      <ls_sum>-amount = <ls_sum>-amount + ls_amount-amount.
      IF line_exists( lt_counted[ fin = <ls_row>-fin_id source = <ls_row>-source ] ).
        CONTINUE.
      ENDIF.
      INSERT VALUE #( fin = <ls_row>-fin_id source = <ls_row>-source ) INTO TABLE lt_counted.
      <ls_cell>-requests = <ls_cell>-requests + 1.
      " The rows come oldest due date first, then FIN: the first N are the examples
      IF lines( <ls_cell>-examples ) < mv_examples.
        INSERT |{ zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-req_example
                                         iv_v1    = <ls_row>-fin_id
                                         iv_v2    = <ls_row>-source
                                         iv_v3    = |{ <ls_row>-due_date DATE = ISO }| ) } { <ls_row>-evidence_ref }|
          INTO TABLE <ls_cell>-examples.
      ENDIF.
    ENDLOOP.

    " Zero is evidence: the total is measured every run
    INSERT VALUE #( metric = gc_metric dim1 = zif_cd_hck_types=>gc_default_key value = lines( lt_counted ) )
      INTO TABLE rs_result-metrics.
    LOOP AT lt_cells ASSIGNING <ls_cell>.
      CLEAR: lt_details, lt_amounts.
      READ TABLE rs_result-metrics ASSIGNING FIELD-SYMBOL(<ls_metric>)
           WITH KEY metric = gc_metric dim1 = <ls_cell>-source dim2 = <ls_cell>-stage.
      IF sy-subrc <> 0.
        INSERT VALUE #( metric = gc_metric dim1 = <ls_cell>-source dim2 = <ls_cell>-stage )
          INTO TABLE rs_result-metrics ASSIGNING <ls_metric>.
      ENDIF.
      <ls_metric>-value = <ls_metric>-value + <ls_cell>-requests.
      LOOP AT <ls_cell>-amounts ASSIGNING <ls_sum>.
        INSERT zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-amount_currency
                                      iv_v1    = |{ <ls_sum>-amount STYLE = SIMPLE }|
                                      iv_v2    = <ls_sum>-currency ) INTO TABLE lt_amounts.
      ENDLOOP.
      INSERT concat_lines_of( table = lt_amounts sep = ` | ` ) INTO TABLE lt_details.
      INSERT zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-examples_head
                                    iv_v1    = lines( <ls_cell>-examples )
                                    iv_v2    = <ls_cell>-requests ) INTO TABLE lt_details.
      INSERT LINES OF <ls_cell>-examples INTO TABLE lt_details.
      INSERT zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-req_drill_down
                                    iv_v1    = <ls_cell>-source
                                    iv_v2    = <ls_cell>-stage
                                    iv_v3    = |{ <ls_cell>-due_date DATE = ISO }| ) INTO TABLE lt_details.
      " One finding per source + stage + due date; the key is stable across runs (auto-resolve when paid)
      INSERT VALUE #( object_key = |{ ms_def-check_id }/{ <ls_cell>-source }/{ <ls_cell>-stage }/{ <ls_cell>-due_date }|
                      group1     = <ls_cell>-source
                      group2     = <ls_cell>-stage
                      check_code = zif_cd_ops_payout_types=>gc_code-request_not_paid
                      severity   = zif_ca_ops_types=>gc_severity-error
                      action     = zif_ca_ops_types=>gc_action-notify
                      amount     = COND #( WHEN lines( <ls_cell>-amounts ) = 1 THEN <ls_cell>-amounts[ 1 ]-amount )
                      currency   = COND #( WHEN lines( <ls_cell>-amounts ) = 1 THEN <ls_cell>-amounts[ 1 ]-currency )
                      reference  = <ls_cell>-source
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-req_not_paid
                                                          iv_v1    = <ls_cell>-source
                                                          iv_v2    = <ls_cell>-stage
                                                          iv_v3    = |{ <ls_cell>-due_date DATE = ISO }|
                                                          iv_v4    = <ls_cell>-requests )
                      details    = concat_lines_of( table = lt_details sep = cl_abap_char_utilities=>newline ) )
             INTO TABLE rs_result-findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD nightly_done.
    DATA lv_day_start TYPE timestampl.
    DATA(lt_watermarks) = zcl_cd_ops_factory=>get_pay_outcome_dao( )->get_watermarks( ).
    DATA(ls_watermark) = VALUE #( lt_watermarks[ source = zif_cd_ops_payout_types=>gc_source-nightly_req ] OPTIONAL ).
    CONVERT DATE is_context-now_date TIME zif_ca_ops_types=>gc_time-day_start
      INTO TIME STAMP lv_day_start TIME ZONE sy-zonlo.
    " CURRENT_TO of a cursor = the run that reached the end of the request rows
    rv_done = xsdbool( ls_watermark-current_to IS NOT INITIAL AND ls_watermark-current_to >= lv_day_start ).
  ENDMETHOD.


  METHOD request_amounts.
    DATA lt_keys TYPE zif_cd_ops_payout_types=>tt_req_key.
    DATA lv_now TYPE timestamp.
    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE currency IS INITIAL.
      INSERT VALUE #( fin = <ls_row>-fin_id source = <ls_row>-source ) INTO TABLE lt_keys.
    ENDLOOP.
    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.
    CONVERT DATE is_context-now_date TIME is_context-now_time INTO TIME STAMP lv_now TIME ZONE sy-zonlo.
    TRY.
        " The request rule's own read of the request log (the amount of the SUCCESS attempt)
        rt_amounts = zcl_cd_ops_factory=>get_pay_request( )->evaluate( it_keys = lt_keys iv_now = lv_now ).
      CATCH zcx_ca_ops_error.
        " The request log cannot be read: the findings show the item amounts only
        CLEAR rt_amounts.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
