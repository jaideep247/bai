*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_job_runtime.clas.testclasses.abap
*& Purpose:
*& Unit tests of the job duration check: duration in minutes per finished
*& job started on the day, other states and days ignored, missing job
*& patterns raise. The DAO is a test double; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    DATA mt_runs TYPE zif_cd_hck_types=>tt_job_run.
    DATA mv_from TYPE d.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~get_job_runs.
    mv_from = iv_from.
    rt_runs = mt_runs.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_job_runtime DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check     TYPE zif_cd_hck_types=>ty_check_id VALUE 'B_JOB_RUNTIME',
      gc_patterns  TYPE zif_cd_hck_types=>ty_param VALUE 'ZCD_*',
      gc_job       TYPE zif_cd_hck_types=>ty_jobname VALUE 'ZCD_FPY1_PAYRUN',
      gc_count_1   TYPE zif_cd_hck_types=>ty_jobcount VALUE '00000001',
      gc_count_2   TYPE zif_cd_hck_types=>ty_jobcount VALUE '00000002',
      gc_today     TYPE d VALUE '20261106',
      gc_yesterday TYPE d VALUE '20261105',
      gc_older     TYPE d VALUE '20261104',
      gc_start     TYPE t VALUE '020000',
      gc_end       TYPE t VALUE '024500',
      gc_minutes   TYPE i VALUE 45.

    TYPES:
      BEGIN OF ty_flags,
        no_patterns TYPE abap_bool,
        finished    TYPE abap_bool,
        running     TYPE abap_bool,
        older       TYPE abap_bool,
      END OF ty_flags.

    DATA mo_dao TYPE REF TO ltd_dao.
    DATA ms_def TYPE zif_cd_hck_types=>ty_check_def.

    METHODS setup.
    METHODS teardown.
    METHODS finished_job_duration FOR TESTING.
    METHODS other_states_ignored FOR TESTING.
    METHODS missing_patterns_raises FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.
ENDCLASS.


CLASS ltc_job_runtime IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    CLEAR ms_def.
    ms_def-check_id = gc_check.
    zcl_cd_hck_injector=>inject_dao( mo_dao ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    CLEAR mo_dao.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_run TYPE zif_cd_hck_types=>ty_job_run.
    IF is_flags-no_patterns = abap_false.
      ms_def-param1 = gc_patterns.
    ENDIF.
    ls_run-jobname  = gc_job.
    ls_run-jobcount = gc_count_1.
    ls_run-strtdate = gc_yesterday.
    ls_run-strttime = gc_start.
    ls_run-enddate  = gc_yesterday.
    ls_run-endtime  = gc_end.
    IF is_flags-finished = abap_true.
      ls_run-status = zif_cd_hck_types=>gc_job_status-finished.
      INSERT ls_run INTO TABLE mo_dao->mt_runs.
    ENDIF.
    IF is_flags-running = abap_true.
      ls_run-jobcount = gc_count_2.
      ls_run-status   = zif_cd_hck_types=>gc_job_status-running.
      INSERT ls_run INTO TABLE mo_dao->mt_runs.
    ENDIF.
    IF is_flags-older = abap_true.
      ls_run-jobcount = gc_count_2.
      ls_run-status   = zif_cd_hck_types=>gc_job_status-finished.
      ls_run-strtdate = gc_older.
      INSERT ls_run INTO TABLE mo_dao->mt_runs.
    ENDIF.
  ENDMETHOD.


  METHOD act.
    rs_result = NEW zcl_cd_hck_c_job_runtime( )->zif_cd_hck_check~execute(
      is_def        = ms_def
      it_thresholds = VALUE #( )
      is_context    = VALUE #( report_date = gc_today ) ).
  ENDMETHOD.


  " Rule: a job finished yesterday is measured in minutes per job name and count
  METHOD finished_job_duration.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_metric.
    TRY.
        configure_scenario( VALUE #( finished = abap_true ) ).
        INSERT VALUE #( metric = zcl_cd_hck_c_job_runtime=>gc_metric dim1 = gc_job dim2 = gc_count_1
                        value  = gc_minutes ) INTO TABLE lt_exp.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics exp = lt_exp
                                            msg = 'Duration in minutes per job run' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_from exp = gc_yesterday
                                            msg = 'Default day is yesterday' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: running jobs and jobs started on another day are not measured
  METHOD other_states_ignored.
    TRY.
        configure_scenario( VALUE #( running = abap_true older = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-metrics msg = 'Nothing measured' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without job name patterns (PARAM1) the check raises
  METHOD missing_patterns_raises.
    configure_scenario( VALUE #( no_patterns = abap_true ) ).
    TRY.
        act( ).
        cl_abap_unit_assert=>fail( msg = 'Missing PARAM1 must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Configuration error raised' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
