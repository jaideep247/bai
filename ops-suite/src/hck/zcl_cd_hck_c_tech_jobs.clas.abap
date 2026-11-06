*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_tech_jobs.clas.abap
*& Purpose:
*& Technical health: background jobs of configured name patterns that were
*& cancelled, run too long or did not start on time (TBTCO).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - cancelled / long-running / late jobs</p>
"! PARAM1 = job name patterns, PARAM2 = long-running minutes (default 120),
"! PARAM3 = late-start grace minutes (default 30). Window: report date - 1
"! to report date. Metrics CANCELLED, LONG_RUNNING, LATE_START (DIM1 '*').
CLASS zcl_cd_hck_c_tech_jobs DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS:
      BEGIN OF gc_metric,
        cancelled    TYPE zif_cd_hck_types=>ty_metric_name VALUE 'CANCELLED',
        long_running TYPE zif_cd_hck_types=>ty_metric_name VALUE 'LONG_RUNNING',
        late_start   TYPE zif_cd_hck_types=>ty_metric_name VALUE 'LATE_START',
      END OF gc_metric.

ENDCLASS.



CLASS zcl_cd_hck_c_tech_jobs IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA lv_cancelled TYPE i.
    DATA lv_long TYPE i.
    DATA lv_late TYPE i.

    DATA(lt_patterns) = CORRESPONDING zif_cd_hck_types=>tt_jobname_range( zcl_cd_hck_param=>pattern_range( is_def-param1 ) ).
    IF lt_patterns IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e050(zcd_ops) WITH is_def-check_id 'PARAM1 (job name patterns)'.
    ENDIF.
    DATA(lv_long_min)  = zcl_cd_hck_param=>int( iv_value = is_def-param2 iv_default = 120 ).
    DATA(lv_grace_min) = zcl_cd_hck_param=>int( iv_value = is_def-param3 iv_default = 30 ).

    DATA(lt_runs) = zcl_cd_hck_factory=>get_dao( )->get_job_runs( it_jobnames = lt_patterns
                                                                   iv_from     = CONV d( is_context-report_date - 1 )
                                                                   iv_to       = is_context-report_date ).
    LOOP AT lt_runs INTO DATA(ls_run).
      DATA(ls_finding) = VALUE zif_cd_ops_types=>ty_finding( object_key = |{ ls_run-jobname }/{ ls_run-jobcount }|
                                                             reference  = ls_run-jobname
                                                             action     = zif_cd_ops_types=>gc_action-notify ).
      CASE ls_run-status.
        WHEN zif_cd_hck_types=>gc_job_status-aborted.
          lv_cancelled = lv_cancelled + 1.
          ls_finding-check_code = zif_cd_hck_types=>gc_code-job_cancelled.
          ls_finding-severity   = zif_cd_ops_types=>gc_severity-error.
          ls_finding-message    = |Job { ls_run-jobname } cancelled (started { ls_run-strtdate DATE = ISO } | &&
                                  |{ ls_run-strttime TIME = ISO })|.
        WHEN zif_cd_hck_types=>gc_job_status-running.
          DATA(lv_minutes) = zcl_cd_hck_cycle_eval=>minutes_between( iv_from_date = ls_run-strtdate
                                                                     iv_from_time = ls_run-strttime
                                                                     iv_to_date   = is_context-now_date
                                                                     iv_to_time   = is_context-now_time ).
          IF lv_minutes <= lv_long_min.
            CONTINUE.
          ENDIF.
          lv_long = lv_long + 1.
          ls_finding-check_code = zif_cd_hck_types=>gc_code-job_long_running.
          ls_finding-severity   = zif_cd_ops_types=>gc_severity-warning.
          ls_finding-message    = |Job { ls_run-jobname } active for { lv_minutes } min (limit { lv_long_min })|.
        WHEN zif_cd_hck_types=>gc_job_status-released OR zif_cd_hck_types=>gc_job_status-ready.
          DATA(lv_late_min) = zcl_cd_hck_cycle_eval=>minutes_between( iv_from_date = ls_run-sdlstrtdt
                                                                      iv_from_time = ls_run-sdlstrttm
                                                                      iv_to_date   = is_context-now_date
                                                                      iv_to_time   = is_context-now_time ).
          IF ls_run-sdlstrtdt IS INITIAL OR lv_late_min <= lv_grace_min.
            CONTINUE.
          ENDIF.
          lv_late = lv_late + 1.
          ls_finding-check_code = zif_cd_hck_types=>gc_code-job_late_start.
          ls_finding-severity   = zif_cd_ops_types=>gc_severity-warning.
          ls_finding-message    = |Job { ls_run-jobname } planned { ls_run-sdlstrtdt DATE = ISO } | &&
                                  |{ ls_run-sdlstrttm TIME = ISO } has not started|.
        WHEN OTHERS.
          CONTINUE.
      ENDCASE.
      INSERT ls_finding INTO TABLE rs_result-findings.
    ENDLOOP.

    INSERT VALUE #( metric = gc_metric-cancelled dim1 = zif_cd_hck_types=>gc_default_key value = lv_cancelled )
      INTO TABLE rs_result-metrics.
    INSERT VALUE #( metric = gc_metric-long_running dim1 = zif_cd_hck_types=>gc_default_key value = lv_long )
      INTO TABLE rs_result-metrics.
    INSERT VALUE #( metric = gc_metric-late_start dim1 = zif_cd_hck_types=>gc_default_key value = lv_late )
      INTO TABLE rs_result-metrics.
  ENDMETHOD.

ENDCLASS.
