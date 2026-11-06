*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_gl_transfer.clas.abap
*& Purpose:
*& Financial integrity: every payment engine reconciliation key with totals records
*& must have reached the general ledger (DFKKSUMC/DFKKKO-FIKEY = AWKEY).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Gaps per company code and AWTYP (PARAM4), unreversed GL document; metric = total gaps (audit A43).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - payment engine to GL transfer completeness</p>
"! PARAM1 = lag in days (keys younger than this are still open, default 1),
"! PARAM2 = window in days (default 7), PARAM3 = max keys listed (default 500),
"! PARAM4 = AWTYP of the GL transfer document (default FKKSU, VERIFY-DDIC).
"! A gap is a key and company code without an unreversed GL document of that type
"! (A43). Metric GL_MISSING_KEYS = total gaps (not the listed ones); one owned
"! exception per listed gap.
CLASS zcl_cd_hck_c_gl_transfer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS gc_metric TYPE zif_cd_hck_types=>ty_metric_name VALUE 'GL_MISSING_KEYS'.
    "! Reference type of the payment engine GL transfer documents (VERIFY-DDIC)
    CONSTANTS gc_default_awtyp TYPE awtyp VALUE 'FKKSU'.

ENDCLASS.



CLASS zcl_cd_hck_c_gl_transfer IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA(lv_lag)    = zcl_cd_hck_param=>int( iv_value = is_def-param1 iv_default = 1 ).
    DATA(lv_window) = nmax( val1 = 1
                            val2 = zcl_cd_hck_param=>int( iv_value = is_def-param2 iv_default = 7 ) ).
    DATA(lv_max)    = zcl_cd_hck_param=>int( iv_value = is_def-param3 iv_default = 500 ).
    DATA(lv_to)     = CONV d( is_context-report_date - lv_lag ).
    DATA(lv_from)   = CONV d( lv_to - lv_window + 1 ).

    DATA(lv_awtyp) = CONV awtyp( COND #( WHEN is_def-param4 IS INITIAL THEN gc_default_awtyp
                                         ELSE to_upper( condense( is_def-param4 ) ) ) ).
    DATA(lo_dao) = zcl_cd_hck_factory=>get_dao( ).
    DATA(lt_gaps) = lo_dao->get_fikeys_without_gl( iv_from     = lv_from
                                                   iv_to       = lv_to
                                                   iv_max_rows = lv_max
                                                   iv_awtyp    = lv_awtyp ).
    " A43: the metric is the total, independent of how many gaps are listed
    DATA(lv_total) = COND i( WHEN lines( lt_gaps ) < lv_max THEN lines( lt_gaps )
                             ELSE lo_dao->count_fikeys_without_gl( iv_from  = lv_from
                                                                   iv_to    = lv_to
                                                                   iv_awtyp = lv_awtyp ) ).
    INSERT VALUE #( metric = gc_metric
                    dim1   = zif_cd_hck_types=>gc_default_key
                    value  = lv_total ) INTO TABLE rs_result-metrics.
    LOOP AT lt_gaps ASSIGNING FIELD-SYMBOL(<ls_gap>).
      INSERT VALUE #( object_key = |{ <ls_gap>-fikey }/{ <ls_gap>-bukrs }|
                      check_code = zif_cd_hck_types=>gc_code-gl_gap
                      severity   = zif_cd_ops_types=>gc_severity-error
                      action     = zif_cd_ops_types=>gc_action-exception
                      reference  = <ls_gap>-fikey
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-reconciliation_key_has_tota
                                                          iv_v1    = <ls_gap>-fikey
                                                          iv_v2    = |{ lv_from DATE = ISO }|
                                                          iv_v3    = |{ lv_to DATE = ISO }| ) ) INTO TABLE rs_result-findings.
    ENDLOOP.
    IF lines( lt_gaps ) >= lv_max.
      rs_result-summary = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-gl_gaps_total
                                                 iv_v1    = lv_total
                                                 iv_v2    = lines( lt_gaps ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
