*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_prq_spe.clas.abap
*& Purpose:
*& Check: PRISM payment request failed without an SPE row. Every failure
*& needs a ZCD_SPE_EXCP_LOG row or the hourly payment-status job never
*& reports it to the source; a request with a SUCCESS row is not failed
*& (ZCD_PAYM_REQ_LOG rule). Table / field names from PARAM1-3, validated
*& against the DDIC and the whitelist (VERIFY-SE11 in config/hck_seed.md).
*& Modification log:
*& 2026-11-06 | Initial version (USAA known tables, phase 3).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - payment request failed without SPE row</p>
"! PARAM1 TABLE=ZCD_PAYM_REQ_LOG;KEY=..;STATUS=ZZ_STATUS;DATE=..
"! PARAM2 FAIL=<statuses>;OK=SUCCESS;DAYS=3;MAX=200
"! PARAM3 TABLE=ZCD_SPE_EXCP_LOG;KEY=..;DATE=..
CLASS zcl_cd_hck_c_prq_spe DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS gc_metric TYPE zif_cd_hck_types=>ty_metric_name VALUE 'PRQ_FAILED_NO_SPE'.
    CONSTANTS gc_code TYPE zif_cd_ops_types=>ty_check_code VALUE 'PRQ_FAILED_NO_SPE'.
ENDCLASS.



CLASS zcl_cd_hck_c_prq_spe IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA(lo_dao) = zcl_cd_hck_factory=>get_dao( ).
    DATA(lt_log) = zcl_cd_hck_value_query=>parse( is_def-param1 ).
    DATA(lt_opt) = zcl_cd_hck_value_query=>parse( is_def-param2 ).
    DATA(lt_spe) = zcl_cd_hck_value_query=>parse( is_def-param3 ).
    DATA(lv_max) = zcl_cd_hck_param=>int( iv_value = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = 'MAX' )
                                          iv_default = 200 ).
    DATA(lv_from) = CONV d( is_context-report_date
                          - zcl_cd_hck_param=>int( iv_value   = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = 'DAYS' )
                                                   iv_default = 3 ) ).
    DATA(lv_rows) = zcl_cd_hck_param=>int( iv_value = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = 'ROWS' )
                                           iv_default = 50000 ).

    DATA(lv_table) = zcl_cd_hck_value_query=>value( it_spec = lt_log iv_name = 'TABLE' iv_default = `ZCD_PAYM_REQ_LOG` ).
    DATA(lv_key) = zcl_cd_hck_value_query=>value( it_spec = lt_log iv_name = 'KEY' ).
    DATA(lv_status) = zcl_cd_hck_value_query=>value( it_spec = lt_log iv_name = 'STATUS' iv_default = `ZZ_STATUS` ).
    DATA(lv_date) = zcl_cd_hck_value_query=>value( it_spec = lt_log iv_name = 'DATE' ).

    DATA(lt_failed) = zcl_cd_hck_value_query=>keys( zcl_cd_hck_value_query=>read(
      io_dao        = lo_dao
      iv_tabname    = lv_table
      it_return     = VALUE #( ( lv_key ) )
      it_conditions = VALUE #( ( field    = lv_status
                                 operator = zif_cd_hck_types=>gc_operator-in_set
                                 value    = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = 'FAIL' ) ) )
      iv_date_field = lv_date
      iv_date_from  = lv_from
      iv_max_rows   = lv_rows ) ).

    DATA(lt_success) = zcl_cd_hck_value_query=>keys( zcl_cd_hck_value_query=>read(
      io_dao        = lo_dao
      iv_tabname    = lv_table
      it_return     = VALUE #( ( lv_key ) )
      it_conditions = VALUE #( ( field    = lv_status
                                 operator = zif_cd_hck_types=>gc_operator-eq
                                 value    = zcl_cd_hck_value_query=>value( it_spec    = lt_opt
                                                                           iv_name    = 'OK'
                                                                           iv_default = `SUCCESS` ) ) )
      iv_date_field = lv_date
      iv_date_from  = lv_from
      iv_max_rows   = lv_rows ) ).

    DATA(lt_spe_keys) = zcl_cd_hck_value_query=>keys( zcl_cd_hck_value_query=>read(
      io_dao        = lo_dao
      iv_tabname    = zcl_cd_hck_value_query=>value( it_spec = lt_spe iv_name = 'TABLE' iv_default = `ZCD_SPE_EXCP_LOG` )
      it_return     = VALUE #( ( zcl_cd_hck_value_query=>value( it_spec = lt_spe iv_name = 'KEY' ) ) )
      iv_date_field = zcl_cd_hck_value_query=>value( it_spec = lt_spe iv_name = 'DATE' )
      iv_date_from  = lv_from
      iv_max_rows   = lv_rows ) ).

    DATA(lt_missing) = zcl_cd_hck_payreq_rules=>failed_without_spe( it_failed  = lt_failed
                                                                    it_success = lt_success
                                                                    it_spe     = lt_spe_keys ).
    INSERT VALUE #( metric = gc_metric dim1 = zif_cd_hck_types=>gc_default_key value = lines( lt_missing ) )
      INTO TABLE rs_result-metrics.
    LOOP AT lt_missing INTO DATA(lv_request) FROM 1 TO lv_max.
      INSERT VALUE #( object_key = lv_request
                      check_code = gc_code
                      severity   = zif_cd_ops_types=>gc_severity-error
                      action     = zif_cd_ops_types=>gc_action-exception
                      reference  = lv_request
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-payment_request_failed_with
                                                          iv_v1    = lv_request ) )
        INTO TABLE rs_result-findings.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
