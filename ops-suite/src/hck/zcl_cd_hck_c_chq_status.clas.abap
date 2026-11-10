*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_chq_status.clas.abap
*& Purpose:
*& Check: cheque status went backwards in ZCD_CHECK_HIST (IRIS status via
*& PRISM). Domain ZECT_STATUS: 3 failed, 4 rejected, 9 returned are terminal;
*& mailed 10 may become returned 9; otherwise a higher status may overwrite
*& a lower one, never the reverse. Names from PARAM1, rules from PARAM2
*& (VERIFY-SE11 for key / sequence / status / date fields).
*& Modification log:
*& 2026-11-06 | Initial version (USAA known tables, phase 3).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - cheque status regression (ZECT_STATUS)</p>
"! PARAM1 TABLE=ZCD_CHECK_HIST;KEY=..;SEQ=..;STATUS=..;DATE=..
"! PARAM2 TERMINAL=3,4,9;ALLOWED=10>9;DAYS=7;MAX=200
CLASS zcl_cd_hck_c_chq_status DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS gc_metric TYPE zif_cd_hck_types=>ty_metric_name VALUE 'CHEQUE_REGRESSION'.
    CONSTANTS gc_code TYPE zif_ca_ops_types=>ty_check_code VALUE 'CHEQUE_STATUS_REGRESSION'.
ENDCLASS.



CLASS zcl_cd_hck_c_chq_status IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA lt_events TYPE zif_cd_hck_value_types=>tt_status_event.
    DATA(lt_names) = zcl_cd_hck_value_query=>parse( is_def-param1 ).
    DATA(lt_opt) = zcl_cd_hck_value_query=>parse( is_def-param2 ).
    DATA(lv_max) = zcl_cd_hck_param=>int( iv_value = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = 'MAX' )
                                          iv_default = 200 ).
    DATA(lv_from) = CONV d( is_context-report_date
                          - zcl_cd_hck_param=>int( iv_value   = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = 'DAYS' )
                                                   iv_default = 7 ) ).
    DATA(lv_rows) = zcl_cd_hck_param=>int( iv_value = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = 'ROWS' )
                                           iv_default = 50000 ).

    DATA(lt_rows) = zcl_cd_hck_value_query=>read(
      io_dao        = zcl_cd_hck_factory=>get_dao( )
      iv_tabname    = zcl_cd_hck_value_query=>value( it_spec = lt_names iv_name = 'TABLE' iv_default = `ZCD_CHECK_HIST` )
      it_return     = VALUE #( ( zcl_cd_hck_value_query=>value( it_spec = lt_names iv_name = 'KEY' ) )
                               ( zcl_cd_hck_value_query=>value( it_spec = lt_names iv_name = 'SEQ' ) )
                               ( zcl_cd_hck_value_query=>value( it_spec = lt_names iv_name = 'STATUS' ) ) )
      iv_date_field = zcl_cd_hck_value_query=>value( it_spec = lt_names iv_name = 'DATE' )
      iv_date_from  = lv_from
      iv_max_rows   = lv_rows ).
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      INSERT VALUE #( key = <ls_row>-v1 seq = <ls_row>-v2 status = <ls_row>-v3 ) INTO TABLE lt_events.
    ENDLOOP.

    DATA(lt_found) = zcl_cd_hck_payreq_rules=>cheque_regressions(
                       it_events   = lt_events
                       it_terminal = zcl_ca_ops_util=>split_list(
                                       zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = 'TERMINAL' iv_default = `3,4,9` ) )
                       it_allowed  = zcl_ca_ops_util=>split_list(
                                       zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = 'ALLOWED' iv_default = `10>9` ) ) ).
    INSERT VALUE #( metric = gc_metric dim1 = zif_cd_hck_types=>gc_default_key value = lines( lt_found ) )
      INTO TABLE rs_result-metrics.
    LOOP AT lt_found ASSIGNING FIELD-SYMBOL(<ls_found>) FROM 1 TO lv_max.
      INSERT VALUE #( object_key = <ls_found>-key
                      check_code = gc_code
                      severity   = zif_ca_ops_types=>gc_severity-error
                      action     = zif_ca_ops_types=>gc_action-exception
                      reference  = <ls_found>-key
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-cheque_status_is_not_allowe
                                                          iv_v1    = <ls_found>-key
                                                          iv_v2    = <ls_found>-from_status
                                                          iv_v3    = <ls_found>-to_status ) )
        INTO TABLE rs_result-findings.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
