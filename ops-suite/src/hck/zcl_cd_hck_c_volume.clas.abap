*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_volume.clas.abap
*& Purpose:
*& Payment engine volume KPIs: counts per day and source/LOB from ZCD_HCK_AGG
*& definitions, stored as metrics to feed baselines and the dashboard.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - volume KPIs per day / source (LOB)</p>
"! Every ZCD_HCK_AGG row of the check is measured in DAY mode: DATE_FIELD =
"! report date - offset. PARAM1 = first offset in days (default 1 =
"! yesterday), PARAM2 = number of days (default 1; >1 backfills history).
"! DIM1 = GROUP_FIELD value (source / LOB, '*' when ungrouped), DIM2 = day.
"! A missing feed is visible as value 0 under '*' (lower-is-worse threshold).
CLASS zcl_cd_hck_c_volume DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

ENDCLASS.



CLASS zcl_cd_hck_c_volume IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA(lo_dao) = zcl_cd_hck_factory=>get_dao( ).
    DATA(lv_offset) = zcl_cd_hck_param=>int( iv_value = is_def-param1 iv_default = 1 ).
    DATA(lv_days) = nmax( val1 = 1
                          val2 = zcl_cd_hck_param=>int( iv_value = is_def-param2 iv_default = 1 ) ).
    DATA(lt_defs) = lo_dao->get_agg_defs( is_def-check_id ).
    IF lt_defs IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e310(zcd_ops) WITH is_def-check_id.
    ENDIF.

    LOOP AT lt_defs INTO DATA(ls_agg).
      ls_agg-date_mode = zif_cd_hck_types=>gc_date_mode-day.
      DO lv_days TIMES.
        ls_agg-age_days_min = lv_offset + sy-index - 1.
        TRY.
            INSERT LINES OF zcl_cd_hck_agg_query=>measure( is_def      = ls_agg
                                                           iv_ref_date = is_context-report_date
                                                           io_dao      = lo_dao ) INTO TABLE rs_result-metrics.
          CATCH zcx_cd_ops_error INTO DATA(lx_config).
            INSERT VALUE #( object_key = |{ is_def-check_id }/{ ls_agg-agg_id }|
                            check_code = zif_cd_hck_types=>gc_code-agg_invalid
                            severity   = zif_cd_ops_types=>gc_severity-error
                            action     = zif_cd_ops_types=>gc_action-notify
                            reference  = ls_agg-tabname
                            message    = lx_config->get_text( ) ) INTO TABLE rs_result-findings.
            EXIT.
        ENDTRY.
      ENDDO.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
