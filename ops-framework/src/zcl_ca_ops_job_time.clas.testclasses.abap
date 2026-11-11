*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_time.clas.testclasses.abap
*& Purpose:
*& Tests of the time points of the SAP job monitor: minutes moved across
*& midnight, minutes between, order, a job that ran at a point (ended, or
*& still active until now), the clock double. Does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~now.
    rv_timestamp = '20261111100000.0000000'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~today.
    rv_date = '20261111'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~time.
    rv_time = '100000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_time DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS teardown.
    METHODS minutes_across_midnight FOR TESTING.
    METHODS minutes_between_points  FOR TESTING.
    METHODS order_of_points         FOR TESTING.
    METHODS ran_at_point            FOR TESTING.
    METHODS now_from_the_clock      FOR TESTING.
ENDCLASS.


CLASS ltc_time IMPLEMENTATION.

  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  " Rule: moving a point by minutes crosses midnight both ways
  METHOD minutes_across_midnight.
    DATA(ls_point) = VALUE zif_ca_ops_job_types=>ty_point( date = '20261111' time = '000500' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ca_ops_job_time=>add_minutes( is_point = ls_point iv_minutes = -10 )
      exp = VALUE zif_ca_ops_job_types=>ty_point( date = '20261110' time = '235500' )
      msg = 'Ten minutes earlier is the day before' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ca_ops_job_time=>add_minutes( is_point = VALUE #( date = '20261110' time = '235500' ) iv_minutes = 10 )
      exp = ls_point
      msg = 'And back' ).
  ENDMETHOD.


  " Rule: whole minutes between two points, negative when the second is earlier
  METHOD minutes_between_points.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ca_ops_job_time=>minutes_between( is_from = VALUE #( date = '20261110' time = '230000' )
                                                  is_to   = VALUE #( date = '20261111' time = '010030' ) )
      exp = 120
      msg = 'Two hours across midnight' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ca_ops_job_time=>minutes_between( is_from = VALUE #( date = '20261111' time = '010000' )
                                                  is_to   = VALUE #( date = '20261111' time = '000000' ) )
      exp = -60
      msg = 'Negative backwards' ).
  ENDMETHOD.


  " Rule: order of points and the earlier of two
  METHOD order_of_points.
    DATA(ls_early) = VALUE zif_ca_ops_job_types=>ty_point( date = '20261110' time = '235959' ).
    DATA(ls_late) = VALUE zif_ca_ops_job_types=>ty_point( date = '20261111' time = '000000' ).
    cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_job_time=>not_after( is_first = ls_early is_second = ls_late )
                                      msg = 'Earlier day first' ).
    cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_job_time=>not_after( is_first = ls_late is_second = ls_early )
                                       msg = 'Not the other way' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_job_time=>earlier( is_first = ls_late is_second = ls_early )
                                        exp = ls_early msg = 'The earlier point' ).
  ENDMETHOD.


  " Rule: a job ran at a point between its start and its end; an active job runs until now
  METHOD ran_at_point.
    DATA(ls_job) = VALUE zif_ca_ops_job_types=>ty_job( status = zif_ca_ops_job_types=>gc_status-finished
                                                       strtdate = '20261111' strttime = '090000'
                                                       enddate = '20261111' endtime = '091000' ).
    DATA(ls_now) = VALUE zif_ca_ops_job_types=>ty_point( date = '20261111' time = '100000' ).
    cl_abap_unit_assert=>assert_true(
      act = zcl_ca_ops_job_time=>ran_at( is_job = ls_job is_point = VALUE #( date = '20261111' time = '090500' )
                                         is_now = ls_now )
      msg = 'Inside the run' ).
    cl_abap_unit_assert=>assert_false(
      act = zcl_ca_ops_job_time=>ran_at( is_job = ls_job is_point = VALUE #( date = '20261111' time = '092000' )
                                         is_now = ls_now )
      msg = 'After the end' ).
    ls_job-status = zif_ca_ops_job_types=>gc_status-running.
    CLEAR: ls_job-enddate, ls_job-endtime.
    cl_abap_unit_assert=>assert_true(
      act = zcl_ca_ops_job_time=>ran_at( is_job = ls_job is_point = VALUE #( date = '20261111' time = '092000' )
                                         is_now = ls_now )
      msg = 'An active job runs until now' ).
    cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_job_time=>is_active( ls_job ) msg = 'Running is active' ).
  ENDMETHOD.


  " Rule: now is the server date and time of the clock
  METHOD now_from_the_clock.
    zcl_ca_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_job_time=>now( )
                                        exp = VALUE zif_ca_ops_job_types=>ty_point( date = '20261111' time = '100000' )
                                        msg = 'Server date and time' ).
  ENDMETHOD.

ENDCLASS.
