*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_ect_pending.clas.abap
*& Purpose:
*& Check C_ECT_PENDING (control ECT_PENDING, proposal P3, build R): COUNT and
*& AGE of the cheques whose latest valid status in the cheque history
*& (ZCD_CHECK_HIST, IRIS status via PRISM; rows with STATE = space only,
*& confirmed 2026-11-07) is one of the pending ZECT_STATUS values of PARAM2
*& and that are still open on the cheque register (DFKKCR: encashment date
*& BNKDT initial and STATE blank). History names from PARAM1 as a source
*& specification (TABLE / KEY = cheque number / KEY2 = STATE / STATUS /
*& DATE / TIME, read through the DDIC-validated, approved configured-source
*& reader); the latest row of a cheque = the last by DATE, TIME. Evidence
*& per cheque: cheque number, payment document, company code, amount,
*& currency, age in days, deadline (pending date + red days); one exposure
*& finding per currency. A pending value list still unset (blank or a
*& placeholder) raises: no verdict, never green.
*& Modification log:
*& 2026-11-16 | Initial version (build R: pilot acceptance items of the first customer's daily controls).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - ECT pending cheques (count and age)</p>
"! PARAM1 TABLE=ZCD_CHECK_HIST;KEY=..;KEY2=STATE;STATUS=..;DATE=..;TIME=..
"! PARAM2 PENDING=<ZECT_STATUS values>;DAYS=180;MAX=200;ROWS=50000
CLASS zcl_cd_hck_c_ect_pending DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_latest,
        key    TYPE zif_cd_hck_cheque_types=>ty_cheque_no,
        status TYPE string,
        since  TYPE d,
      END OF ty_latest.
    TYPES tt_latest TYPE HASHED TABLE OF ty_latest WITH UNIQUE KEY key.

    "! Red limit in days of the age metric (default threshold row), 0 = none
    CLASS-METHODS red_days
      IMPORTING
        it_thresholds  TYPE zif_cd_hck_types=>tt_threshold
      RETURNING
        VALUE(rv_days) TYPE i.

ENDCLASS.



CLASS zcl_cd_hck_c_ect_pending IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA lt_latest TYPE tt_latest.
    DATA lt_cheques TYPE zif_cd_hck_cheque_types=>tt_cheque_no.
    DATA lt_items TYPE zif_cd_hck_cheque_types=>tt_item.
    DATA lv_param TYPE zif_ca_ops_types=>ty_param_name.

    DATA(lt_opt) = zcl_cd_hck_value_query=>parse( is_def-param2 ).
    DATA(lv_pending) = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = zif_cd_hck_cheque_types=>gc_spec-pending ).
    lv_param = is_def-check_id.
    DATA(ls_source) = zcl_cd_ops_trace_engine=>parse_source( iv_param = lv_param iv_spec = is_def-param1 ).
    IF zcl_cd_hck_exposure=>is_unset( lv_pending ) = abap_true.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e904(zcd_ops) WITH is_def-check_id zif_cd_hck_cheque_types=>gc_spec-pending.
    ENDIF.
    IF zcl_cd_hck_exposure=>is_unset( ls_source-key_field ) = abap_true
       OR zcl_cd_hck_exposure=>is_unset( ls_source-status_field ) = abap_true
       OR zcl_cd_hck_exposure=>is_unset( ls_source-date_field ) = abap_true.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e904(zcd_ops) WITH is_def-check_id is_def-param1.
    ENDIF.
    DATA(lt_values) = zcl_ca_ops_util=>split_list( lv_pending ).
    DATA(lv_days) = zcl_cd_hck_param=>int(
                      iv_value   = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = zif_cd_hck_cheque_types=>gc_spec-days )
                      iv_default = zif_cd_hck_cheque_types=>gc_default-days ).
    DATA(lv_max) = zcl_cd_hck_param=>int(
                     iv_value   = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = zif_cd_hck_cheque_types=>gc_spec-max )
                     iv_default = zif_cd_hck_cheque_types=>gc_default-max ).
    DATA(lv_rows) = zcl_cd_hck_param=>int(
                      iv_value   = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = zif_cd_hck_cheque_types=>gc_spec-rows )
                      iv_default = zif_cd_hck_cheque_types=>gc_default-rows ).
    DATA(lv_control) = zcl_cd_hck_value_query=>value( it_spec    = zcl_cd_hck_value_query=>parse( is_def-param3 )
                                                      iv_name    = zif_cd_hck_cheque_types=>gc_spec-control
                                                      iv_default = zif_cd_hck_cheque_types=>gc_default-ect_ctl ).
    DATA(lv_from) = CONV d( is_context-report_date - lv_days ).

    " Rows ordered by DATE, TIME, KEY: the last valid row of a cheque is its latest status
    DATA(lt_rows) = zcl_cd_ops_factory=>get_trace_dao( )->read_configured_after(
                      is_source   = ls_source
                      is_after    = VALUE #( date = lv_from )
                      iv_date_to  = is_context-report_date
                      iv_max_rows = lv_rows ).
    IF lines( lt_rows ) >= lv_rows.
      rs_result-completion = zif_cd_hck_types=>gc_completion-partial.
      rs_result-evidence   = zif_cd_hck_types=>gc_evidence-partial.
      INSERT VALUE #( object_key = is_def-check_id
                      check_code = zif_cd_hck_cheque_types=>gc_code-read_capped
                      severity   = zif_ca_ops_types=>gc_severity-warning
                      action     = zif_ca_ops_types=>gc_action-notify
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_cheque_types=>gc_msg-read_capped
                                                          iv_v1    = is_def-check_id
                                                          iv_v2    = lv_rows
                                                          iv_v3    = lv_from
                                                          iv_v4    = is_context-report_date ) )
        INTO TABLE rs_result-findings.
    ENDIF.
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE key2 IS INITIAL.
      DATA(ls_new) = VALUE ty_latest( key    = condense( <ls_row>-key1 )
                                      status = condense( CONV string( <ls_row>-status ) )
                                      since  = zcl_cd_ops_trace_engine=>to_date( <ls_row>-ev_date ) ).
      MODIFY TABLE lt_latest FROM ls_new.
      IF sy-subrc <> 0.
        INSERT ls_new INTO TABLE lt_latest.
      ENDIF.
    ENDLOOP.
    DELETE lt_latest WHERE status IS INITIAL.
    LOOP AT lt_latest ASSIGNING FIELD-SYMBOL(<ls_latest>).
      IF NOT line_exists( lt_values[ table_line = <ls_latest>-status ] ).
        CONTINUE.
      ENDIF.
      INSERT <ls_latest>-key INTO TABLE lt_cheques.
    ENDLOOP.

    DATA(lt_register) = zcl_cd_hck_factory=>get_cheque_dao( )->get_register( it_cheques  = lt_cheques
                                                                          iv_max_rows = lv_rows ).
    DATA(lv_red) = red_days( it_thresholds ).
    LOOP AT lt_cheques ASSIGNING FIELD-SYMBOL(<lv_cheque>).
      DATA(ls_latest) = lt_latest[ key = <lv_cheque> ].
      " Latest register row of the cheque (sorted latest run first); cashed or voided = no longer pending
      DATA(ls_register) = VALUE #( lt_register[ ztnum = <lv_cheque> ] OPTIONAL ).
      IF ls_register IS NOT INITIAL
         AND ( ls_register-bnkdt IS NOT INITIAL OR ls_register-state <> zif_cd_hck_cheque_types=>gc_state_open ).
        CONTINUE.
      ENDIF.
      INSERT VALUE #( object_key = <lv_cheque>
                      reference  = ls_register-doc1r
                      bukrs      = ls_register-bukrs
                      amount     = ls_register-amount
                      currency   = ls_register-currency
                      age        = nmax( val1 = 0 val2 = is_context-report_date - ls_latest-since )
                      event_date = ls_latest-since
                      deadline   = COND #( WHEN lv_red > 0 THEN ls_latest-since + lv_red ) )
        INTO TABLE lt_items.
    ENDLOOP.
    SORT lt_items BY age DESCENDING object_key.

    DATA(lv_oldest) = REDUCE i( INIT n = 0 FOR ls_item IN lt_items NEXT n = nmax( val1 = n val2 = ls_item-age ) ).
    INSERT VALUE #( metric = zif_cd_hck_cheque_types=>gc_metric-ect_count dim1 = zif_cd_hck_types=>gc_default_key
                    value = lines( lt_items ) ) INTO TABLE rs_result-metrics.
    INSERT VALUE #( metric = zif_cd_hck_cheque_types=>gc_metric-ect_age dim1 = zif_cd_hck_types=>gc_default_key
                    value = lv_oldest kind = zif_cd_hck_types=>gc_metric_kind-level ) INTO TABLE rs_result-metrics.

    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<ls_item>) FROM 1 TO lv_max.
      DATA(lv_status) = lt_latest[ key = CONV zif_cd_hck_cheque_types=>ty_cheque_no( <ls_item>-object_key ) ]-status.
      INSERT VALUE #(
        object_key    = <ls_item>-object_key
        check_code    = COND #( WHEN <ls_item>-reference IS INITIAL
                                THEN zif_cd_hck_cheque_types=>gc_code-ect_no_register
                                ELSE zif_cd_hck_cheque_types=>gc_code-ect_pending )
        severity      = COND #( WHEN lv_red > 0 AND <ls_item>-age >= lv_red
                                THEN zif_ca_ops_types=>gc_severity-error
                                ELSE zif_ca_ops_types=>gc_severity-warning )
        action        = zif_ca_ops_types=>gc_action-exception
        reference     = <ls_item>-reference
        amount        = <ls_item>-amount
        currency      = <ls_item>-currency
        company_code  = <ls_item>-bukrs
        business_date = <ls_item>-event_date
        item_count    = 1
        message       = COND #( WHEN <ls_item>-reference IS INITIAL
                                THEN zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_cheque_types=>gc_msg-ect_no_register
                                                            iv_v1    = <ls_item>-object_key
                                                            iv_v2    = lv_status
                                                            iv_v3    = <ls_item>-age )
                                ELSE zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_cheque_types=>gc_msg-ect_pending
                                                            iv_v1    = <ls_item>-object_key
                                                            iv_v2    = lv_status
                                                            iv_v3    = <ls_item>-age
                                                            iv_v4    = <ls_item>-reference ) )
        context       = zcl_cd_hck_exposure=>context( is_item     = <ls_item>
                                                      iv_control  = lv_control
                                                      iv_evidence = |{ <ls_item>-object_key } { <ls_item>-reference }| ) )
        INTO TABLE rs_result-findings.
    ENDLOOP.
    INSERT LINES OF zcl_cd_hck_exposure=>total_findings( it_totals  = zcl_cd_hck_exposure=>totals( lt_items )
                                                         iv_control = lv_control ) INTO TABLE rs_result-findings.
  ENDMETHOD.


  METHOD red_days.
    LOOP AT it_thresholds ASSIGNING FIELD-SYMBOL(<ls_threshold>)
         WHERE metric = zif_cd_hck_cheque_types=>gc_metric-ect_age AND bukrs = zif_cd_hck_types=>gc_default_key.
      rv_days = CONV i( <ls_threshold>-red ).
      RETURN.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
