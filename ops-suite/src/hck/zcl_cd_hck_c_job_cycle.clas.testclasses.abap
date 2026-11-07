*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_job_cycle.clas.testclasses.abap
*& Purpose:
*& Unit tests of the job cycle check: completed and missed steps counted per
*& cycle, a non-working day skipped, no cycle configured, a capped job read
*& reported, a missed predecessor blocks its successor. The DAO is a test
*& double; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*& 2026-11-06 | Step job name that is not valid PCRE: PATTERN_INVALID finding, step not evaluated
*&              (bad_step_pattern_reported).
*& 2026-11-07 | Parameters from the shared fake ZCL_CD_OPS_PARAMS_MEM (row caps at their delivered defaults).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    DATA mt_steps TYPE zif_cd_hck_types=>tt_cycle_step.
    DATA mt_runs TYPE zif_cd_hck_types=>tt_job_run.
    DATA mv_working TYPE abap_bool VALUE abap_true.
    DATA mv_run_reads TYPE i.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~get_cycle_steps.
    rt_steps = mt_steps.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~get_job_runs.
    mv_run_reads = mv_run_reads + 1.
    rt_runs = mt_runs.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~is_working_day.
    rv_working = mv_working.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_job_cycle DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check   TYPE zif_cd_hck_types=>ty_check_id VALUE 'B_JOB_CYCLE',
      gc_cycle   TYPE zif_cd_hck_types=>ty_cycle_id VALUE 'PAYRUN',
      gc_step_1  TYPE zif_cd_hck_types=>ty_step_no VALUE '010',
      gc_step_2  TYPE zif_cd_hck_types=>ty_step_no VALUE '020',
      gc_job_1   TYPE zif_cd_hck_types=>ty_jobname VALUE 'ZCD_FPY1_PAYRUN',
      gc_job_2   TYPE zif_cd_hck_types=>ty_jobname VALUE 'ZCD_FPF3_MEDIUM',
      gc_count   TYPE zif_cd_hck_types=>ty_jobcount VALUE '00000001',
      gc_today   TYPE d VALUE '20261106',
      gc_from    TYPE t VALUE '010000',
      gc_to      TYPE t VALUE '030000',
      gc_started TYPE t VALUE '011500',
      gc_ended   TYPE t VALUE '013000',
      gc_now     TYPE t VALUE '070000'.

    TYPES:
      BEGIN OF ty_flags,
        no_steps    TYPE abap_bool,
        holiday     TYPE abap_bool,
        step1_done  TYPE abap_bool,
        capped_read TYPE abap_bool,
        bad_step2   TYPE abap_bool,
      END OF ty_flags.

    DATA mo_dao TYPE REF TO ltd_dao.

    METHODS setup.
    METHODS teardown.
    METHODS steps_counted_per_cycle FOR TESTING.
    METHODS missed_pred_blocks_next FOR TESTING.
    METHODS holiday_is_skipped FOR TESTING.
    METHODS no_cycle_gives_summary FOR TESTING.
    METHODS capped_read_is_reported FOR TESTING.
    METHODS bad_step_pattern_reported FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.
    METHODS metric_value
      IMPORTING
        is_result       TYPE zif_cd_hck_types=>ty_check_result
        iv_metric       TYPE zif_cd_hck_types=>ty_metric_name
      RETURNING
        VALUE(rv_value) TYPE zif_cd_hck_types=>ty_value.
ENDCLASS.


CLASS ltc_job_cycle IMPLEMENTATION.

  METHOD setup.
    zcl_cd_ops_injector=>inject_params( NEW zcl_cd_ops_params_mem( ) ).
    mo_dao = NEW #( ).
    zcl_cd_hck_injector=>inject_dao( mo_dao ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    CLEAR mo_dao.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_step TYPE zif_cd_hck_types=>ty_cycle_step.
    DATA ls_run TYPE zif_cd_hck_types=>ty_job_run.
    IF is_flags-no_steps = abap_true.
      RETURN.
    ENDIF.
    ls_step-cycle_id    = gc_cycle.
    ls_step-step_no     = gc_step_1.
    ls_step-jobname     = gc_job_1.
    ls_step-window_from = gc_from.
    ls_step-window_to   = gc_to.
    ls_step-critical    = abap_true.
    INSERT ls_step INTO TABLE mo_dao->mt_steps.
    ls_step-step_no   = gc_step_2.
    ls_step-jobname   = COND #( WHEN is_flags-bad_step2 = abap_true THEN |{ gc_job_2 }(| ELSE gc_job_2 ).
    ls_step-pred_step = gc_step_1.
    INSERT ls_step INTO TABLE mo_dao->mt_steps.
    mo_dao->mv_working = xsdbool( is_flags-holiday = abap_false ).
    IF is_flags-step1_done = abap_true.
      ls_run-jobname  = gc_job_1.
      ls_run-jobcount = gc_count.
      ls_run-status   = zif_cd_hck_types=>gc_job_status-finished.
      ls_run-strtdate = gc_today.
      ls_run-strttime = gc_started.
      ls_run-enddate  = gc_today.
      ls_run-endtime  = gc_ended.
      INSERT ls_run INTO TABLE mo_dao->mt_runs.
    ENDIF.
    IF is_flags-capped_read = abap_true.
      " the cap reached by planned (not started) instances of another job
      ls_run-jobname = gc_job_2.
      ls_run-status  = zif_cd_hck_types=>gc_job_status-scheduled.
      DO zif_cd_hck_types=>gc_param_default-max_job_rows TIMES.
        ls_run-jobcount = sy-index.
        INSERT ls_run INTO TABLE mo_dao->mt_runs.
      ENDDO.
    ENDIF.
  ENDMETHOD.


  METHOD act.
    rs_result = NEW zcl_cd_hck_c_job_cycle( )->zif_cd_hck_check~execute(
      is_def        = VALUE #( check_id = gc_check )
      it_thresholds = VALUE #( )
      is_context    = VALUE #( report_date = gc_today now_date = gc_today now_time = gc_now ) ).
  ENDMETHOD.


  METHOD metric_value.
    rv_value = VALUE #( is_result-metrics[ metric = iv_metric ]-value OPTIONAL ).
  ENDMETHOD.


  " A step job name that is not valid PCRE is a configuration finding of the step (not MISSED):
  " the step is not evaluated and counts as not OK
  METHOD bad_step_pattern_reported.
    TRY.
        configure_scenario( VALUE #( step1_done = abap_true bad_step2 = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-step_status ) exp = 1
                                            msg = 'Only the valid step is evaluated' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1
                                            msg = 'One finding for the invalid step' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                            exp = zif_cd_hck_types=>gc_code-pattern_invalid
                                            msg = 'The finding names the invalid pattern, not a missed step' ).
        cl_abap_unit_assert=>assert_equals( act = metric_value( is_result = ls_result
                                                                iv_metric = zcl_cd_hck_c_job_cycle=>gc_metric-not_ok )
                                            exp = 1
                                            msg = 'The invalid step counts as not OK' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a finished step is completed, a step whose window closed without a run is missed
  METHOD steps_counted_per_cycle.
    TRY.
        configure_scenario( VALUE #( step1_done = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-step_status ) exp = 2
                                            msg = 'Both steps evaluated' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-step_status[ 1 ]-state
                                            exp = zif_cd_hck_types=>gc_step_state-completed
                                            msg = 'Step 1 completed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-step_status[ 2 ]-state
                                            exp = zif_cd_hck_types=>gc_step_state-missed
                                            msg = 'Step 2 missed' ).
        cl_abap_unit_assert=>assert_equals( act = metric_value( is_result = ls_result
                                                                iv_metric = zcl_cd_hck_c_job_cycle=>gc_metric-completed )
                                            exp = 1
                                            msg = 'One step completed' ).
        cl_abap_unit_assert=>assert_equals( act = metric_value( is_result = ls_result
                                                                iv_metric = zcl_cd_hck_c_job_cycle=>gc_metric-not_ok )
                                            exp = 1
                                            msg = 'One step not OK' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a missed predecessor marks the next step blocked
  METHOD missed_pred_blocks_next.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-step_status[ 1 ]-state
                                            exp = zif_cd_hck_types=>gc_step_state-missed
                                            msg = 'Step 1 missed' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-step_status[ 2 ]-blocked
                                          msg = 'Step 2 blocked by its predecessor' ).
        cl_abap_unit_assert=>assert_equals( act = metric_value( is_result = ls_result
                                                                iv_metric = zcl_cd_hck_c_job_cycle=>gc_metric-not_ok )
                                            exp = 2
                                            msg = 'Both steps not OK' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a non-working day of the cycle calendar is not evaluated
  METHOD holiday_is_skipped.
    TRY.
        configure_scenario( VALUE #( holiday = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-step_status msg = 'No step evaluated' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-metrics msg = 'No metric' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without an active cycle the check says so and reads no jobs
  METHOD no_cycle_gives_summary.
    TRY.
        configure_scenario( VALUE #( no_steps = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_not_initial( act = ls_result-summary msg = 'Summary explains the empty check' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_run_reads exp = 0 msg = 'No job read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (A44): a job read at its cap is reported as JOB_READ_CAPPED, never silently
  METHOD capped_read_is_reported.
    TRY.
        configure_scenario( VALUE #( step1_done = abap_true capped_read = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_hck_types=>gc_code-job_read_capped ] ) )
          msg = 'Capped read is reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
