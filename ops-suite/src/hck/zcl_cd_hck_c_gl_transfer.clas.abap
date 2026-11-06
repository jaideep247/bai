*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_gl_transfer.clas.abap
*& Purpose:
*& Financial integrity: every payment engine reconciliation key with totals records
*& must have reached the general ledger (DFKKSUMC/DFKKKO-FIKEY = AWKEY).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - payment engine to GL transfer completeness</p>
"! PARAM1 = lag in days (keys younger than this are still open, default 1),
"! PARAM2 = window in days (default 7), PARAM3 = max keys listed (default 500).
"! Metric GL_MISSING_KEYS (DIM1 '*'); one owned exception per missing key.
CLASS zcl_cd_hck_c_gl_transfer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS gc_metric TYPE zif_cd_hck_types=>ty_metric_name VALUE 'GL_MISSING_KEYS'.

ENDCLASS.



CLASS zcl_cd_hck_c_gl_transfer IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA(lv_lag)    = zcl_cd_hck_param=>int( iv_value = is_def-param1 iv_default = 1 ).
    DATA(lv_window) = nmax( val1 = 1
                            val2 = zcl_cd_hck_param=>int( iv_value = is_def-param2 iv_default = 7 ) ).
    DATA(lv_max)    = zcl_cd_hck_param=>int( iv_value = is_def-param3 iv_default = 500 ).
    DATA(lv_to)     = CONV d( is_context-report_date - lv_lag ).
    DATA(lv_from)   = CONV d( lv_to - lv_window + 1 ).

    DATA(lt_gaps) = zcl_cd_hck_factory=>get_dao( )->get_fikeys_without_gl( iv_from     = lv_from
                                                                           iv_to       = lv_to
                                                                           iv_max_rows = lv_max ).
    INSERT VALUE #( metric = gc_metric
                    dim1   = zif_cd_hck_types=>gc_default_key
                    value  = lines( lt_gaps ) ) INTO TABLE rs_result-metrics.
    LOOP AT lt_gaps INTO DATA(ls_gap).
      INSERT VALUE #( object_key = ls_gap-fikey
                      check_code = zif_cd_hck_types=>gc_code-gl_gap
                      severity   = zif_cd_ops_types=>gc_severity-error
                      action     = zif_cd_ops_types=>gc_action-exception
                      reference  = ls_gap-fikey
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-reconciliation_key_has_tota
                                                          iv_v1    = ls_gap-fikey
                                                          iv_v2    = |{ lv_from DATE = ISO }|
                                                          iv_v3    = |{ lv_to DATE = ISO }| ) ) INTO TABLE rs_result-findings.
    ENDLOOP.
    IF lines( lt_gaps ) >= lv_max.
      rs_result-summary = |At least { lv_max } reconciliation keys without GL document (list capped)|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
