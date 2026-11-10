*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_demo_dao.clas.testclasses.abap
*& Purpose:
*& Tests of the job counts on an OSQL test double of TBTCO (no real job is
*& read): status, end time and planned start inside / outside the window,
*& the day boundaries and jobs of another client.
*& Modification log:
*& 2026-11-10 | Initial version (demo consumer of the operations framework).
*&---------------------------------------------------------------------*
CLASS ltc_demo_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_demo_dao.
    DATA ms_from TYPE zif_ca_ops_demo_types=>ty_moment.
    DATA ms_to TYPE zif_ca_ops_demo_types=>ty_moment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS add_job
      IMPORTING
        iv_name   TYPE btcjob
        iv_status TYPE zif_ca_ops_demo_types=>ty_job_status
        iv_date   TYPE d
        iv_time   TYPE t
        iv_client TYPE mandt OPTIONAL.

    METHODS ended_in_window_counted   FOR TESTING.
    METHODS planned_in_window_counted FOR TESTING.
    METHODS other_client_not_counted  FOR TESTING.
ENDCLASS.


CLASS ltc_demo_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'TBTCO' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_ca_ops_demo_dao( ).
    ms_from-date = '20261109'.
    ms_from-time = '070000'.
    ms_to-date   = '20261110'.
    ms_to-time   = '070000'.
  ENDMETHOD.


  METHOD add_job.
    DATA lt_jobs TYPE STANDARD TABLE OF tbtco WITH EMPTY KEY.
    DATA ls_job TYPE tbtco.
    ls_job-jobname   = iv_name.
    ls_job-jobcount  = '00000001'.
    ls_job-status    = iv_status.
    ls_job-authckman = COND #( WHEN iv_client IS INITIAL THEN sy-mandt ELSE iv_client ).
    ls_job-enddate   = iv_date.
    ls_job-endtime   = iv_time.
    ls_job-sdlstrtdt = iv_date.
    ls_job-sdlstrttm = iv_time.
    INSERT ls_job INTO TABLE lt_jobs.
    go_env->insert_test_data( lt_jobs ).
  ENDMETHOD.


  METHOD ended_in_window_counted.
    TRY.
        add_job( iv_name = 'ZT_FIRST_EDGE' iv_status = zif_ca_ops_demo_types=>gc_job_status-aborted
                 iv_date = '20261109' iv_time = '070000' ).
        add_job( iv_name = 'ZT_INSIDE' iv_status = zif_ca_ops_demo_types=>gc_job_status-aborted
                 iv_date = '20261110' iv_time = '010000' ).
        add_job( iv_name = 'ZT_LAST_EDGE' iv_status = zif_ca_ops_demo_types=>gc_job_status-aborted
                 iv_date = '20261110' iv_time = '070000' ).
        add_job( iv_name = 'ZT_TOO_EARLY' iv_status = zif_ca_ops_demo_types=>gc_job_status-aborted
                 iv_date = '20261109' iv_time = '065959' ).
        add_job( iv_name = 'ZT_TOO_LATE' iv_status = zif_ca_ops_demo_types=>gc_job_status-aborted
                 iv_date = '20261110' iv_time = '070001' ).
        add_job( iv_name = 'ZT_FINISHED' iv_status = zif_ca_ops_demo_types=>gc_job_status-finished
                 iv_date = '20261110' iv_time = '010000' ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->count_ended( iv_status = zif_ca_ops_demo_types=>gc_job_status-aborted
                                     is_from   = ms_from
                                     is_to     = ms_to )
          exp = 3
          msg = 'Cancelled jobs from the first to the last second of the window' ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->count_ended( iv_status = zif_ca_ops_demo_types=>gc_job_status-finished
                                     is_from   = ms_from
                                     is_to     = ms_to )
          exp = 1
          msg = 'Status is part of the count' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD planned_in_window_counted.
    TRY.
        add_job( iv_name = 'ZT_LATE' iv_status = zif_ca_ops_demo_types=>gc_job_status-released
                 iv_date = '20261110' iv_time = '050000' ).
        add_job( iv_name = 'ZT_NOT_YET_LATE' iv_status = zif_ca_ops_demo_types=>gc_job_status-released
                 iv_date = '20261110' iv_time = '063000' ).
        ms_to-time = '060000'.
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->count_planned( iv_status = zif_ca_ops_demo_types=>gc_job_status-released
                                       is_from   = ms_from
                                       is_to     = ms_to )
          exp = 1
          msg = 'Only the job planned before the cut is late' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD other_client_not_counted.
    TRY.
        add_job( iv_name = 'ZT_OTHER' iv_status = zif_ca_ops_demo_types=>gc_job_status-aborted
                 iv_date = '20261110' iv_time = '010000' iv_client = 'ZZZ' ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->count_ended( iv_status = zif_ca_ops_demo_types=>gc_job_status-aborted
                                     is_from   = ms_from
                                     is_to     = ms_to )
          exp = 0
          msg = 'Jobs of another client are not counted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
