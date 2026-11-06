*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_prq_cancel.clas.abap
*& Purpose:
*& Check: paid payment request left CANCELLED (PCLM). CANCELLED means money
*& will not leave; a request whose FIN number has a cleared open item
*& (DFKKOP-ZZ_FIN_TRANS_NUM, AUGBL filled) must never be CANCELLED. Names
*& from PARAM1 / PARAM3, values from PARAM2 (VERIFY-SE11 for the FIN number
*& and date fields of ZCD_PAYM_REQ_LOG).
*& Modification log:
*& 2026-11-06 | Initial version (USAA known tables, phase 3).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - paid payment request left CANCELLED</p>
"! PARAM1 TABLE=ZCD_PAYM_REQ_LOG;KEY=<FIN number>;STATUS=ZZ_STATUS;SOURCE=SOURCE;DATE=..
"! PARAM2 CANCELLED=CANCELLED;SRC=PCLM;DAYS=7;MAX=200
"! PARAM3 TABLE=DFKKOP;KEY=ZZ_FIN_TRANS_NUM;PAID=AUGBL;DATE=AUGDT
CLASS zcl_cd_hck_c_prq_cancel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS gc_metric TYPE zif_cd_hck_types=>ty_metric_name VALUE 'PRQ_PAID_CANCELLED'.
    CONSTANTS gc_code TYPE zif_cd_ops_types=>ty_check_code VALUE 'PRQ_PAID_CANCELLED'.
ENDCLASS.



CLASS zcl_cd_hck_c_prq_cancel IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA lt_conditions TYPE zif_cd_hck_value_types=>tt_condition.
    DATA(lo_dao) = zcl_cd_hck_factory=>get_dao( ).
    DATA(lt_log) = zcl_cd_hck_value_query=>parse( is_def-param1 ).
    DATA(lt_opt) = zcl_cd_hck_value_query=>parse( is_def-param2 ).
    DATA(lt_paid) = zcl_cd_hck_value_query=>parse( is_def-param3 ).
    DATA(lv_max) = zcl_cd_hck_param=>int( iv_value = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = 'MAX' )
                                          iv_default = 200 ).
    DATA(lv_from) = CONV d( is_context-report_date
                          - zcl_cd_hck_param=>int( iv_value   = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = 'DAYS' )
                                                   iv_default = 7 ) ).
    DATA(lv_rows) = zcl_cd_hck_param=>int( iv_value = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = 'ROWS' )
                                           iv_default = 50000 ).

    INSERT VALUE #( field    = zcl_cd_hck_value_query=>value( it_spec = lt_log iv_name = 'STATUS' iv_default = `ZZ_STATUS` )
                    operator = zif_cd_hck_types=>gc_operator-eq
                    value    = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = 'CANCELLED' iv_default = `CANCELLED` ) )
      INTO TABLE lt_conditions.
    DATA(lv_source_field) = zcl_cd_hck_value_query=>value( it_spec = lt_log iv_name = 'SOURCE' ).
    IF lv_source_field IS NOT INITIAL.
      INSERT VALUE #( field    = lv_source_field
                      operator = zif_cd_hck_types=>gc_operator-in_set
                      value    = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = 'SRC' iv_default = `PCLM` ) )
        INTO TABLE lt_conditions.
    ENDIF.
    DATA(lt_cancelled) = zcl_cd_hck_value_query=>keys( zcl_cd_hck_value_query=>read(
      io_dao        = lo_dao
      iv_tabname    = zcl_cd_hck_value_query=>value( it_spec = lt_log iv_name = 'TABLE' iv_default = `ZCD_PAYM_REQ_LOG` )
      it_return     = VALUE #( ( zcl_cd_hck_value_query=>value( it_spec = lt_log iv_name = 'KEY' ) ) )
      it_conditions = lt_conditions
      iv_date_field = zcl_cd_hck_value_query=>value( it_spec = lt_log iv_name = 'DATE' )
      iv_date_from  = lv_from
      iv_max_rows   = lv_rows ) ).

    DATA(lt_paid_keys) = zcl_cd_hck_value_query=>keys( zcl_cd_hck_value_query=>read(
      io_dao        = lo_dao
      iv_tabname    = zcl_cd_hck_value_query=>value( it_spec = lt_paid iv_name = 'TABLE' iv_default = `DFKKOP` )
      it_return     = VALUE #( ( zcl_cd_hck_value_query=>value( it_spec    = lt_paid
                                                                iv_name    = 'KEY'
                                                                iv_default = `ZZ_FIN_TRANS_NUM` ) ) )
      it_conditions = VALUE #( ( field    = zcl_cd_hck_value_query=>value( it_spec    = lt_paid
                                                                           iv_name    = 'PAID'
                                                                           iv_default = `AUGBL` )
                                 operator = zif_cd_hck_types=>gc_operator-ne
                                 value    = space ) )
      iv_date_field = zcl_cd_hck_value_query=>value( it_spec = lt_paid iv_name = 'DATE' iv_default = `AUGDT` )
      iv_date_from  = lv_from
      iv_max_rows   = lv_rows ) ).

    DATA(lt_found) = zcl_cd_hck_payreq_rules=>paid_but_cancelled( it_cancelled = lt_cancelled
                                                                  it_paid      = lt_paid_keys ).
    INSERT VALUE #( metric = gc_metric dim1 = zif_cd_hck_types=>gc_default_key value = lines( lt_found ) )
      INTO TABLE rs_result-metrics.
    LOOP AT lt_found INTO DATA(lv_fin) FROM 1 TO lv_max.
      INSERT VALUE #( object_key = lv_fin
                      check_code = gc_code
                      severity   = zif_cd_ops_types=>gc_severity-error
                      action     = zif_cd_ops_types=>gc_action-exception
                      reference  = lv_fin
                      message    = |Payment request { lv_fin } is CANCELLED but its open item is cleared (paid)| )
        INTO TABLE rs_result-findings.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
