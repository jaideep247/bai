*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_xrun_src_jobsch.clas.testclasses.abap
*& Purpose:
*& The plan "expected by configuration": a scheduler row with run days
*& Monday to Friday gives one run per weekday at its planned start with
*& its late minutes, predecessor and SAP job names; a holiday of the row's
*& calendar is "not expected"; a calendar that cannot answer leaves the
*& day "unknown" (never a holiday); a row without run days is no plan; run
*& days that are not X / blank make the row invalid; the cap of runs makes
*& the plan partial; weekdays from the date. Doubles: job monitor data
*& access (scheduler rows), business calendar.
*& Modification log:
*& 2026-11-16 | Initial version (build P: expected runs from the scheduler).
*&---------------------------------------------------------------------*
CLASS ltd_jobsch_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_dao PARTIALLY IMPLEMENTED.
    DATA mt_sched TYPE zif_ca_ops_job_types=>tt_sched.
ENDCLASS.

CLASS ltd_jobsch_dao IMPLEMENTATION.
  METHOD zif_ca_ops_job_dao~scheduler_jobs.
    rt_sched = mt_sched.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_jobsch_calendar DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_xrun_calendar.
ENDCLASS.

CLASS ltd_jobsch_calendar IMPLEMENTATION.
  METHOD zif_ca_ops_xrun_calendar~is_business_day.
    " calendar ZT: Monday 16 November 2026 is a holiday; calendar XX cannot answer
    IF iv_calendar_id = 'XX'.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e610(zca_ops) WITH 'XX'.
    ENDIF.
    rv_business = xsdbool( iv_date <> '20261116' ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_xrun_src_jobsch DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_now TYPE timestampl VALUE '20261116090000.0000000'.

    DATA mo_dao TYPE REF TO ltd_jobsch_dao.
    DATA mo_cut TYPE REF TO zif_ca_ops_expected_run_src.

    METHODS setup.
    METHODS row
      IMPORTING
        iv_days       TYPE zif_ca_ops_xrun_types=>ty_plan_days DEFAULT 'XXXXX'
        iv_calendar   TYPE zif_ca_ops_exc_contract=>ty_calendar_id OPTIONAL
      RETURNING
        VALUE(rs_row) TYPE zif_ca_ops_job_types=>ty_sched.
    "! Plan of the week Saturday 14 to Tuesday 17 November 2026
    METHODS plan
      IMPORTING
        iv_max         TYPE i DEFAULT 100
      RETURNING
        VALUE(rs_plan) TYPE zif_ca_ops_xrun_types=>ty_plan
      RAISING
        zcx_ca_ops_error.

    METHODS weekdays_give_runs        FOR TESTING RAISING zcx_ca_ops_error.
    METHODS holiday_not_expected      FOR TESTING RAISING zcx_ca_ops_error.
    METHODS calendar_unknown_day      FOR TESTING RAISING zcx_ca_ops_error.
    METHODS row_without_days_no_plan  FOR TESTING RAISING zcx_ca_ops_error.
    METHODS invalid_days_reported     FOR TESTING RAISING zcx_ca_ops_error.
    METHODS cap_makes_partial         FOR TESTING RAISING zcx_ca_ops_error.
    METHODS weekday_of_date           FOR TESTING.
ENDCLASS.


CLASS ltc_xrun_src_jobsch IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    mo_cut = NEW zcl_ca_ops_xrun_src_jobsch( io_dao = mo_dao io_calendar = NEW ltd_jobsch_calendar( ) ).
  ENDMETHOD.


  METHOD row.
    rs_row = VALUE #( sched_folder = 'ZT_FOLDER'
                      sched_job    = 'ZT_PAY_RUN'
                      sap_pattern  = 'ZT_PAYRUN.*'
                      criticality  = 'H'
                      plan_days    = iv_days
                      plan_time    = '070000'
                      late_min     = 45
                      calendar_id  = iv_calendar
                      pred_folder  = 'ZT_FOLDER'
                      pred_job     = 'ZT_PAY_PREP' ).
  ENDMETHOD.


  METHOD plan.
    rs_plan = mo_cut->read( VALUE #( from_date = '20261114' to_date = '20261117' max = iv_max now = gc_now ) ).
  ENDMETHOD.


  " Rule: Monday to Friday - Saturday and Sunday give no run, Monday and Tuesday one each
  METHOD weekdays_give_runs.
    mo_dao->mt_sched = VALUE #( ( row( ) ) ).

    DATA(ls_plan) = plan( ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_plan-runs ) exp = 2 ).
    DATA(ls_run) = ls_plan-runs[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_run-plan_date exp = '20261116' ).
    cl_abap_unit_assert=>assert_equals( act = ls_run-plan_time exp = '070000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_run-late_min exp = 45 ).
    cl_abap_unit_assert=>assert_equals( act = ls_run-pred_job exp = 'ZT_PAY_PREP' ).
    cl_abap_unit_assert=>assert_equals( act = ls_run-source_id exp = zcl_ca_ops_xrun_src_jobsch=>gc_id ).
    cl_abap_unit_assert=>assert_initial( ls_run-sched_state ).
    cl_abap_unit_assert=>assert_equals( act = ls_plan-newest_at exp = gc_now ).
  ENDMETHOD.


  " Fixture XRUN-04: Monday 16th is a holiday of calendar ZT - not expected; Tuesday is
  METHOD holiday_not_expected.
    mo_dao->mt_sched = VALUE #( ( row( iv_calendar = 'ZT' ) ) ).

    DATA(ls_plan) = plan( ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_plan-runs ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_plan-runs[ 1 ]-plan_date exp = '20261117' ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_plan-not_expected ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_plan-not_expected[ 1 ]-plan_date exp = '20261116' ).
  ENDMETHOD.


  " Rule: a calendar that cannot answer leaves the days unknown - neither a run nor a holiday
  METHOD calendar_unknown_day.
    mo_dao->mt_sched = VALUE #( ( row( iv_calendar = 'XX' ) ) ).

    DATA(ls_plan) = plan( ).

    cl_abap_unit_assert=>assert_initial( ls_plan-runs ).
    cl_abap_unit_assert=>assert_initial( ls_plan-not_expected ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_plan-unknown ) exp = 2 ).
  ENDMETHOD.


  " Rule: a scheduler row without run days maps SAP job names only (the job monitor) - no expected run
  METHOD row_without_days_no_plan.
    mo_dao->mt_sched = VALUE #( ( row( iv_days = space ) ) ).

    DATA(ls_plan) = plan( ).

    cl_abap_unit_assert=>assert_initial( ls_plan-runs ).
    cl_abap_unit_assert=>assert_initial( ls_plan-invalid ).
  ENDMETHOD.


  " Rule: run days other than X / blank make the row invalid (reported, never guessed)
  METHOD invalid_days_reported.
    mo_dao->mt_sched = VALUE #( ( row( iv_days = 'MO-FR' ) ) ).

    DATA(ls_plan) = plan( ).

    cl_abap_unit_assert=>assert_initial( ls_plan-runs ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_plan-invalid ) exp = 1 ).
    cl_abap_unit_assert=>assert_true( zcl_ca_ops_xrun_src_jobsch=>days_valid( 'X X X  ' ) ).
    cl_abap_unit_assert=>assert_false( zcl_ca_ops_xrun_src_jobsch=>days_valid( 'XYXXX' ) ).
  ENDMETHOD.


  " Rule: the cap of runs stops the plan and says so
  METHOD cap_makes_partial.
    mo_dao->mt_sched = VALUE #( ( row( ) ) ).

    DATA(ls_plan) = plan( 1 ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_plan-runs ) exp = 1 ).
    cl_abap_unit_assert=>assert_true( ls_plan-partial ).
  ENDMETHOD.


  " Rule: 16 November 2026 is a Monday, 15 November a Sunday
  METHOD weekday_of_date.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_xrun_src_jobsch=>weekday( '20261116' ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_xrun_src_jobsch=>weekday( '20261115' ) exp = 7 ).
  ENDMETHOD.

ENDCLASS.
