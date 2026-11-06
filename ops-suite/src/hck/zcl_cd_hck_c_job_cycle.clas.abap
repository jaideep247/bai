*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_job_cycle.clas.abap
*& Purpose:
*& Job cycle monitor (Control-M fallback, monitoring only): state of each
*& configured cycle step from TBTCO; findings for missed/failed/stuck/overrun.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - job cycle monitor (ZCD_JOB_CYCLE/STEP)</p>
"! PARAM1 = cycle date offset in days (default 0 = report date),
"! PARAM2 = cycle ids (blank = all active cycles). Non-working days of the
"! cycle's factory calendar are skipped. Step rules: ZCL_CD_HCK_CYCLE_EVAL.
"! Metrics per cycle (DIM1): STEPS_NOT_OK (failed, missed, stuck),
"! STEPS_COMPLETED. Restart / retrigger is a later phase.
CLASS zcl_cd_hck_c_job_cycle DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS:
      BEGIN OF gc_metric,
        not_ok    TYPE zif_cd_hck_types=>ty_metric_name VALUE 'STEPS_NOT_OK',
        completed TYPE zif_cd_hck_types=>ty_metric_name VALUE 'STEPS_COMPLETED',
      END OF gc_metric.

ENDCLASS.



CLASS zcl_cd_hck_c_job_cycle IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA lt_patterns TYPE zif_cd_hck_types=>tt_jobname_range.
    DATA lv_max_offset TYPE i.
    DATA lv_not_ok TYPE i.
    DATA lv_completed TYPE i.
    DATA lv_pred_state TYPE zif_cd_hck_types=>ty_step_state.

    DATA(lo_dao) = zcl_cd_hck_factory=>get_dao( ).
    DATA(lv_cycle_date) = CONV d( is_context-report_date - zcl_cd_hck_param=>int( iv_value = is_def-param1 iv_default = 0 ) ).
    DATA(lt_steps) = lo_dao->get_cycle_steps(
      CORRESPONDING zif_cd_hck_types=>tt_cycle_range( zcl_cd_hck_param=>pattern_range( is_def-param2 ) ) ).
    IF lt_steps IS INITIAL.
      rs_result-summary = 'No active job cycle configured'.
      RETURN.
    ENDIF.

    LOOP AT lt_steps INTO DATA(ls_step).
      INSERT VALUE #( sign = 'I' option = 'CP' low = ls_step-jobname ) INTO TABLE lt_patterns.
      lv_max_offset = nmax( val1 = lv_max_offset val2 = ls_step-day_offset ).
    ENDLOOP.
    SORT lt_patterns BY low.
    DELETE ADJACENT DUPLICATES FROM lt_patterns COMPARING low.
    DATA(lt_runs) = lo_dao->get_job_runs( it_jobnames = lt_patterns
                                          iv_from     = lv_cycle_date
                                          iv_to       = CONV d( lv_cycle_date + lv_max_offset ) ).

    LOOP AT lt_steps INTO ls_step GROUP BY ls_step-cycle_id INTO DATA(lt_cycle_group).
      " ls_step is the first step of the cycle: calendar is a cycle attribute
      IF lo_dao->is_working_day( iv_calendar = ls_step-calendar
                                 iv_date     = lv_cycle_date ) = abap_false.
        CONTINUE.
      ENDIF.
      CLEAR: lv_not_ok, lv_completed.
      LOOP AT GROUP lt_cycle_group INTO DATA(ls_cycle_step).
        CLEAR lv_pred_state.
        IF ls_cycle_step-pred_step IS NOT INITIAL.
          READ TABLE rs_result-step_status INTO DATA(ls_pred)
            WITH KEY cycle_id = ls_cycle_step-cycle_id step_no = ls_cycle_step-pred_step.
          IF sy-subrc = 0.
            lv_pred_state = ls_pred-state.
          ENDIF.
        ENDIF.
        DATA(ls_status) = zcl_cd_hck_cycle_eval=>derive_state( is_step       = ls_cycle_step
                                                               it_runs       = lt_runs
                                                               iv_cycle_date = lv_cycle_date
                                                               iv_now_date   = is_context-now_date
                                                               iv_now_time   = is_context-now_time
                                                               iv_pred_state = lv_pred_state ).
        INSERT ls_status INTO TABLE rs_result-step_status.
        INSERT LINES OF zcl_cd_hck_cycle_eval=>findings_for( is_step   = ls_cycle_step
                                                             is_status = ls_status ) INTO TABLE rs_result-findings.
        CASE ls_status-state.
          WHEN zif_cd_hck_types=>gc_step_state-completed.
            lv_completed = lv_completed + 1.
          WHEN zif_cd_hck_types=>gc_step_state-failed
            OR zif_cd_hck_types=>gc_step_state-missed
            OR zif_cd_hck_types=>gc_step_state-stuck.
            lv_not_ok = lv_not_ok + 1.
        ENDCASE.
      ENDLOOP.
      INSERT VALUE #( metric = gc_metric-not_ok dim1 = ls_step-cycle_id dim2 = lv_cycle_date value = lv_not_ok )
        INTO TABLE rs_result-metrics.
      INSERT VALUE #( metric = gc_metric-completed dim1 = ls_step-cycle_id dim2 = lv_cycle_date value = lv_completed )
        INTO TABLE rs_result-metrics.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
