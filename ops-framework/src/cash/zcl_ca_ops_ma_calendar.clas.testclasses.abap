*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_ma_calendar.clas.testclasses.abap
*& Purpose:
*& The business calendar of the expected runs answers through the cash
*& checks' factory calendar: a working day is a business day, a holiday is
*& not, and a calendar that cannot answer raises (the day stays unknown).
*& Doubles: cash data access.
*& Modification log:
*& 2026-11-16 | Initial version (build P: expected runs from the scheduler).
*&---------------------------------------------------------------------*
CLASS ltd_cal_cash_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_cash_dao PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_cal_cash_dao IMPLEMENTATION.
  METHOD zif_ca_ops_cash_dao~working_day.
    IF iv_calendar <> 'ZT'.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e522(zca_ops) WITH iv_calendar.
    ENDIF.
    rv_working = xsdbool( iv_date <> '20261116' ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_ma_calendar DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zif_ca_ops_xrun_calendar.

    METHODS setup.
    METHODS teardown.
    METHODS business_day_and_holiday FOR TESTING RAISING zcx_ca_ops_error.
    METHODS unknown_calendar_raises  FOR TESTING.
ENDCLASS.


CLASS ltc_ma_calendar IMPLEMENTATION.

  METHOD setup.
    zcl_ca_ops_cash_injector=>inject_dao( NEW ltd_cal_cash_dao( ) ).
    mo_cut = NEW zcl_ca_ops_ma_calendar( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_cash_injector=>reset( ).
  ENDMETHOD.


  " Fixture XRUN-04 on a system with the pack: Monday 16th a holiday of calendar ZT, Tuesday a business day
  METHOD business_day_and_holiday.
    cl_abap_unit_assert=>assert_false( mo_cut->is_business_day( iv_calendar_id = 'ZT' iv_date = '20261116' ) ).
    cl_abap_unit_assert=>assert_true( mo_cut->is_business_day( iv_calendar_id = 'ZT' iv_date = '20261117' ) ).
  ENDMETHOD.


  " Rule: a calendar that cannot answer raises - never a holiday
  METHOD unknown_calendar_raises.
    TRY.
        mo_cut->is_business_day( iv_calendar_id = 'XX' iv_date = '20261116' ).
        cl_abap_unit_assert=>fail( 'unknown calendar answered' ).
      CATCH zcx_ca_ops_error.
        RETURN.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
