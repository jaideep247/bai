*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_job_runtime.clas.abap
*& Purpose:
*& Mass-run health: duration of finished background jobs (Control-M jobs
*& ZCD_<function>_<ENTITY>, mostly RFKK_MA_SCHEDULER) vs rolling baseline.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | PARAM1 job names are PCRE (complete name, case ignored); an invalid pattern raises E373.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - job duration vs rolling baseline</p>
"! PARAM1 = job name patterns (e.g. ZCD_*), PARAM2 = day offset (default 1 =
"! jobs started yesterday). Metric DURATION_MIN, DIM1 = job name,
"! DIM2 = job count. Baseline (ZSCORE/IQR) per job name via ZCD_HCK_THRESH.
"! Throughput (items/hour) needs mass-activity statistics - next phase.
CLASS zcl_cd_hck_c_job_runtime DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS gc_metric TYPE zif_cd_hck_types=>ty_metric_name VALUE 'DURATION_MIN'.

ENDCLASS.



CLASS zcl_cd_hck_c_job_runtime IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA(lt_patterns) = zcl_cd_hck_param=>patterns( is_def-param1 ).
    IF lt_patterns IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e345(zcd_ops) WITH is_def-check_id.
    ENDIF.
    zcl_cd_hck_param=>check_patterns( it_patterns = lt_patterns iv_check_id = is_def-check_id ).
    DATA(lv_day) = CONV d( is_context-report_date - zcl_cd_hck_param=>int( iv_value = is_def-param2 iv_default = 1 ) ).

    DATA(lt_runs) = zcl_cd_hck_factory=>get_dao( )->get_job_runs( it_jobnames = lt_patterns
                                                                   iv_from     = lv_day
                                                                   iv_to       = lv_day ).
    LOOP AT lt_runs ASSIGNING FIELD-SYMBOL(<ls_run>)
         WHERE status = zif_cd_hck_types=>gc_job_status-finished AND strtdate = lv_day.
      INSERT VALUE #( metric = gc_metric
                      dim1   = <ls_run>-jobname
                      dim2   = <ls_run>-jobcount
                      value  = zcl_cd_hck_cycle_eval=>minutes_between( iv_from_date = <ls_run>-strtdate
                                                                       iv_from_time = <ls_run>-strttime
                                                                       iv_to_date   = <ls_run>-enddate
                                                                       iv_to_time   = <ls_run>-endtime ) )
        INTO TABLE rs_result-metrics.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
