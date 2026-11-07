*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_tech_jobs.clas.abap
*& Purpose:
*& Technical health: background jobs of configured name patterns that were
*& cancelled, run too long or did not start on time (TBTCO).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Unresolved jobs read regardless of the window; capped read reported (audit A44).
*& 2026-11-06 | Sorted/hashed sweep: keyed lookups by sorted secondary keys / hashed tables (Performance_Review.md).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | PARAM1 job names are PCRE (complete name, case ignored); an invalid pattern raises E373.
*& 2026-11-07 | Cap reached against the effective cap ZCL_CD_HCK_PARAM=>JOB_ROWS_CAP (parameter HCK_MAX_JOB_ROWS).
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

    DATA(lt_patterns) = zcl_cd_hck_param=>patterns( is_def-param1 ).
    IF lt_patterns IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e345(zcd_ops) WITH is_def-check_id.
    ENDIF.
    zcl_cd_hck_param=>check_patterns( it_patterns = lt_patterns iv_check_id = is_def-check_id ).
    DATA(lv_long_min)  = zcl_cd_hck_param=>int( iv_value = is_def-param2 iv_default = 120 ).
    DATA(lv_grace_min) = zcl_cd_hck_param=>int( iv_value = is_def-param3 iv_default = 30 ).

    DATA(lo_dao) = zcl_cd_hck_factory=>get_dao( ).
    DATA(lt_runs) = lo_dao->get_job_runs( it_jobnames = lt_patterns
                                          iv_from     = CONV d( is_context-report_date - 1 )
                                          iv_to       = is_context-report_date ).
    " A44: unfinished jobs are read independently of the window (an old stuck job stays visible)
    DATA(lt_unresolved) = lo_dao->get_unresolved_jobs( lt_patterns ).
    " Sweep: job identities of the window by hash (was a scan of the runs per unresolved job)
    TYPES:
      BEGIN OF ty_job_key,
        jobname  TYPE zif_cd_hck_types=>ty_job_run-jobname,
        jobcount TYPE zif_cd_hck_types=>ty_job_run-jobcount,
      END OF ty_job_key.
    DATA lt_known TYPE HASHED TABLE OF ty_job_key WITH UNIQUE KEY jobname jobcount.
    lt_known = CORRESPONDING #( lt_runs DISCARDING DUPLICATES ).
    LOOP AT lt_unresolved ASSIGNING FIELD-SYMBOL(<ls_unresolved>).
      INSERT CORRESPONDING ty_job_key( <ls_unresolved> ) INTO TABLE lt_known.
      IF sy-subrc = 0.
        INSERT <ls_unresolved> INTO TABLE lt_runs.
      ENDIF.
    ENDLOOP.
    " A44: a read that reached its cap is reported - the counts below may be incomplete
    IF lines( lt_runs ) >= zcl_cd_hck_param=>job_rows_cap( )
       OR lines( lt_unresolved ) >= zcl_cd_hck_param=>job_rows_cap( ).
      INSERT VALUE #( object_key = is_def-check_id
                      check_code = zif_cd_hck_types=>gc_code-job_read_capped
                      severity   = zif_cd_ops_types=>gc_severity-warning
                      action     = zif_cd_ops_types=>gc_action-notify
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-job_read_capped
                                                          iv_v1    = zcl_cd_hck_param=>job_rows_cap( )
                                                          iv_v2    = is_def-check_id ) )
        INTO TABLE rs_result-findings.
    ENDIF.
    LOOP AT lt_runs ASSIGNING FIELD-SYMBOL(<ls_run>).
      DATA(ls_finding) = VALUE zif_cd_ops_types=>ty_finding( object_key = |{ <ls_run>-jobname }/{ <ls_run>-jobcount }|
                                                             reference  = <ls_run>-jobname
                                                             action     = zif_cd_ops_types=>gc_action-notify ).
      CASE <ls_run>-status.
        WHEN zif_cd_hck_types=>gc_job_status-aborted.
          lv_cancelled = lv_cancelled + 1.
          ls_finding-check_code = zif_cd_hck_types=>gc_code-job_cancelled.
          ls_finding-severity   = zif_cd_ops_types=>gc_severity-error.
          ls_finding-message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-job_cancelled_started
                                                         iv_v1    = <ls_run>-jobname
                                                         iv_v2    = |{ <ls_run>-strtdate DATE = ISO }|
                                                         iv_v3    = |{ <ls_run>-strttime TIME = ISO }| ).
        WHEN zif_cd_hck_types=>gc_job_status-running.
          DATA(lv_minutes) = zcl_cd_hck_cycle_eval=>minutes_between( iv_from_date = <ls_run>-strtdate
                                                                     iv_from_time = <ls_run>-strttime
                                                                     iv_to_date   = is_context-now_date
                                                                     iv_to_time   = is_context-now_time ).
          IF lv_minutes <= lv_long_min.
            CONTINUE.
          ENDIF.
          lv_long = lv_long + 1.
          ls_finding-check_code = zif_cd_hck_types=>gc_code-job_long_running.
          ls_finding-severity   = zif_cd_ops_types=>gc_severity-warning.
          ls_finding-message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-job_active_for_min_limit
                                                         iv_v1    = <ls_run>-jobname
                                                         iv_v2    = lv_minutes
                                                         iv_v3    = lv_long_min ).
        WHEN zif_cd_hck_types=>gc_job_status-released OR zif_cd_hck_types=>gc_job_status-ready.
          DATA(lv_late_min) = zcl_cd_hck_cycle_eval=>minutes_between( iv_from_date = <ls_run>-sdlstrtdt
                                                                      iv_from_time = <ls_run>-sdlstrttm
                                                                      iv_to_date   = is_context-now_date
                                                                      iv_to_time   = is_context-now_time ).
          IF <ls_run>-sdlstrtdt IS INITIAL OR lv_late_min <= lv_grace_min.
            CONTINUE.
          ENDIF.
          lv_late = lv_late + 1.
          ls_finding-check_code = zif_cd_hck_types=>gc_code-job_late_start.
          ls_finding-severity   = zif_cd_ops_types=>gc_severity-warning.
          ls_finding-message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-job_planned_has_not_started
                                                         iv_v1    = <ls_run>-jobname
                                                         iv_v2    = |{ <ls_run>-sdlstrtdt DATE = ISO }|
                                                         iv_v3    = |{ <ls_run>-sdlstrttm TIME = ISO }| ).
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
