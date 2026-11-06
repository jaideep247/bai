*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_cycle_eval.clas.testclasses.abap
*& Purpose:
*& Unit tests of job-cycle step state derivation (NOT_STARTED, RUNNING,
*& COMPLETED, FAILED, STUCK, MISSED) and its findings; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
CLASS ltc_cycle_eval DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_cycle      TYPE zif_cd_hck_types=>ty_cycle_id VALUE 'DISB_DAY',
      gc_step       TYPE zif_cd_hck_types=>ty_step_no VALUE '020',
      gc_pattern    TYPE zif_cd_hck_types=>ty_jobname VALUE 'ZCD_PAYM_WIRE*',
      gc_job        TYPE zif_cd_hck_types=>ty_jobname VALUE 'ZCD_PAYM_WIRE_CORP',
      gc_jobcount   TYPE zif_cd_hck_types=>ty_jobcount VALUE '13300001',
      gc_cycle_date TYPE d VALUE '20261105',
      gc_win_from   TYPE t VALUE '133000',
      gc_win_to     TYPE t VALUE '140000',
      gc_start_time TYPE t VALUE '133100'.

    TYPES:
      BEGIN OF ty_flags,
        with_run   TYPE abap_bool,
        job_status TYPE zif_cd_hck_types=>ty_job_status,
        end_time   TYPE t,
        now_time   TYPE t,
        pred_state TYPE zif_cd_hck_types=>ty_step_state,
        critical   TYPE abap_bool,
        skippable  TYPE abap_bool,
      END OF ty_flags.

    DATA ms_step TYPE zif_cd_hck_types=>ty_cycle_step.
    DATA mt_runs TYPE zif_cd_hck_types=>tt_job_run.
    DATA ms_flags TYPE ty_flags.

    METHODS setup.
    METHODS no_run_before_window_end FOR TESTING.
    METHODS no_run_after_window_missed FOR TESTING.
    METHODS active_job_is_running FOR TESTING.
    METHODS stuck_step_after_max_runtime FOR TESTING.
    METHODS finished_job_is_completed FOR TESTING.
    METHODS slow_finish_flags_overrun FOR TESTING.
    METHODS cancelled_job_is_failed FOR TESTING.
    METHODS failed_pred_blocks_step FOR TESTING.
    METHODS critical_missed_is_error FOR TESTING.
    METHODS skippable_missed_is_info FOR TESTING.
    METHODS completed_step_no_finding FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.

    METHODS act
      RETURNING
        VALUE(rs_status) TYPE zif_cd_hck_types=>ty_step_status.

    METHODS expected_status
      IMPORTING
        iv_state         TYPE zif_cd_hck_types=>ty_step_state
        iv_with_run      TYPE abap_bool DEFAULT abap_false
        iv_runtime       TYPE i DEFAULT 0
      RETURNING
        VALUE(rs_status) TYPE zif_cd_hck_types=>ty_step_status.

ENDCLASS.



CLASS ltc_cycle_eval IMPLEMENTATION.

  METHOD setup.
    CLEAR: ms_step, mt_runs, ms_flags.
    ms_step-cycle_id        = gc_cycle.
    ms_step-step_no         = gc_step.
    ms_step-jobname         = gc_pattern.
    ms_step-window_from     = gc_win_from.
    ms_step-window_to       = gc_win_to.
    ms_step-max_runtime_min = 30.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_run TYPE zif_cd_hck_types=>ty_job_run.
    ms_flags = is_flags.
    ms_step-critical  = is_flags-critical.
    ms_step-skippable = is_flags-skippable.
    IF is_flags-with_run = abap_false.
      RETURN.
    ENDIF.
    ls_run-jobname   = gc_job.
    ls_run-jobcount  = gc_jobcount.
    ls_run-status    = is_flags-job_status.
    ls_run-sdlstrtdt = gc_cycle_date.
    ls_run-sdlstrttm = gc_win_from.
    ls_run-strtdate  = gc_cycle_date.
    ls_run-strttime  = gc_start_time.
    IF is_flags-end_time IS NOT INITIAL.
      ls_run-enddate = gc_cycle_date.
      ls_run-endtime = is_flags-end_time.
    ENDIF.
    INSERT ls_run INTO TABLE mt_runs.
  ENDMETHOD.


  METHOD act.
    rs_status = zcl_cd_hck_cycle_eval=>derive_state( is_step       = ms_step
                                                     it_runs       = mt_runs
                                                     iv_cycle_date = gc_cycle_date
                                                     iv_now_date   = gc_cycle_date
                                                     iv_now_time   = ms_flags-now_time
                                                     iv_pred_state = ms_flags-pred_state ).
  ENDMETHOD.


  METHOD expected_status.
    rs_status-cycle_id   = gc_cycle.
    rs_status-step_no    = gc_step.
    rs_status-jobname    = gc_pattern.
    rs_status-state      = iv_state.
    rs_status-cycle_date = gc_cycle_date.
    IF iv_with_run = abap_true.
      rs_status-jobname     = gc_job.
      rs_status-jobcount    = gc_jobcount.
      rs_status-started_on  = gc_cycle_date.
      rs_status-started_at  = gc_start_time.
      rs_status-runtime_min = iv_runtime.
    ENDIF.
  ENDMETHOD.


  " Rule: no job yet and the window is still open -> NOT_STARTED
  METHOD no_run_before_window_end.
    TRY.
        configure_scenario( VALUE #( now_time = '133500' ) ).
        cl_abap_unit_assert=>assert_equals( act = act( )
                                            exp = expected_status( zif_cd_hck_types=>gc_step_state-not_started )
                                            msg = 'Inside the window without a job the step is NOT_STARTED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: no job and the window has closed -> MISSED
  METHOD no_run_after_window_missed.
    TRY.
        configure_scenario( VALUE #( now_time = '140100' ) ).
        cl_abap_unit_assert=>assert_equals( act = act( )
                                            exp = expected_status( zif_cd_hck_types=>gc_step_state-missed )
                                            msg = 'After the window without a job the step is MISSED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: active job within max runtime -> RUNNING
  METHOD active_job_is_running.
    TRY.
        configure_scenario( VALUE #( with_run = abap_true job_status = 'R' now_time = '134100' ) ).
        cl_abap_unit_assert=>assert_equals( act = act( )
                                            exp = expected_status( iv_state    = zif_cd_hck_types=>gc_step_state-running
                                                                   iv_with_run = abap_true
                                                                   iv_runtime  = 10 )
                                            msg = 'Active job for 10 of 30 minutes is RUNNING' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: active job beyond max runtime -> STUCK
  METHOD stuck_step_after_max_runtime.
    TRY.
        configure_scenario( VALUE #( with_run = abap_true job_status = 'R' now_time = '141100' ) ).
        DATA(ls_exp) = expected_status( iv_state    = zif_cd_hck_types=>gc_step_state-stuck
                                        iv_with_run = abap_true
                                        iv_runtime  = 40 ).
        ls_exp-overrun = abap_true.
        cl_abap_unit_assert=>assert_equals( act = act( )
                                            exp = ls_exp
                                            msg = 'Active job for 40 of 30 minutes is STUCK' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: finished job -> COMPLETED with its runtime
  METHOD finished_job_is_completed.
    TRY.
        configure_scenario( VALUE #( with_run = abap_true job_status = 'F' end_time = '134600' now_time = '150000' ) ).
        cl_abap_unit_assert=>assert_equals( act = act( )
                                            exp = expected_status( iv_state    = zif_cd_hck_types=>gc_step_state-completed
                                                                   iv_with_run = abap_true
                                                                   iv_runtime  = 15 )
                                            msg = 'Finished job is COMPLETED with 15 minutes runtime' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: finished beyond max runtime -> COMPLETED with overrun flag
  METHOD slow_finish_flags_overrun.
    TRY.
        configure_scenario( VALUE #( with_run = abap_true job_status = 'F' end_time = '142100' now_time = '150000' ) ).
        DATA(ls_exp) = expected_status( iv_state    = zif_cd_hck_types=>gc_step_state-completed
                                        iv_with_run = abap_true
                                        iv_runtime  = 50 ).
        ls_exp-overrun = abap_true.
        cl_abap_unit_assert=>assert_equals( act = act( )
                                            exp = ls_exp
                                            msg = 'Finished after 50 of 30 minutes is an overrun' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: cancelled job -> FAILED
  METHOD cancelled_job_is_failed.
    TRY.
        configure_scenario( VALUE #( with_run = abap_true job_status = 'A' end_time = '133600' now_time = '150000' ) ).
        cl_abap_unit_assert=>assert_equals( act = act( )
                                            exp = expected_status( iv_state    = zif_cd_hck_types=>gc_step_state-failed
                                                                   iv_with_run = abap_true
                                                                   iv_runtime  = 5 )
                                            msg = 'Cancelled job is FAILED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: failed predecessor marks a not-started step as blocked
  METHOD failed_pred_blocks_step.
    TRY.
        configure_scenario( VALUE #( now_time = '133500' pred_state = zif_cd_hck_types=>gc_step_state-failed ) ).
        DATA(ls_exp) = expected_status( zif_cd_hck_types=>gc_step_state-not_started ).
        ls_exp-blocked = abap_true.
        cl_abap_unit_assert=>assert_equals( act = act( )
                                            exp = ls_exp
                                            msg = 'Step behind a FAILED predecessor is blocked' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a missed critical step is an error finding
  METHOD critical_missed_is_error.
    DATA lt_exp TYPE zif_cd_ops_types=>tt_finding.
    TRY.
        configure_scenario( VALUE #( now_time = '140100' critical = abap_true ) ).
        INSERT VALUE #( object_type = zif_cd_hck_types=>gc_object_type
                        object_key  = |{ gc_cycle }/{ gc_step }|
                        check_code  = zif_cd_hck_types=>gc_code-step_missed
                        severity    = zif_cd_ops_types=>gc_severity-error
                        action      = zif_cd_ops_types=>gc_action-notify
                        reference   = gc_pattern
                        message     = |Cycle { gc_cycle } step { gc_step } ({ gc_pattern }): MISSED| )
          INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_cycle_eval=>findings_for( is_step   = ms_step
                                                     is_status = act( ) )
          exp = lt_exp
          msg = 'Missed critical step must give one error finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a missed skippable step is information only
  METHOD skippable_missed_is_info.
    TRY.
        configure_scenario( VALUE #( now_time = '140100' skippable = abap_true ) ).
        DATA(lt_findings) = zcl_cd_hck_cycle_eval=>findings_for( is_step   = ms_step
                                                                 is_status = act( ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_findings ) exp = 1 msg = 'One finding expected' ).
        cl_abap_unit_assert=>assert_equals( act = lt_findings[ 1 ]-severity
                                            exp = zif_cd_ops_types=>gc_severity-info
                                            msg = 'Skippable missed step must be information' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a completed step without overrun raises nothing
  METHOD completed_step_no_finding.
    DATA lt_exp TYPE zif_cd_ops_types=>tt_finding.
    TRY.
        configure_scenario( VALUE #( with_run = abap_true job_status = 'F' end_time = '134600' now_time = '150000' ) ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_cycle_eval=>findings_for( is_step   = ms_step
                                                     is_status = act( ) )
          exp = lt_exp
          msg = 'Completed step in time must give no finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
