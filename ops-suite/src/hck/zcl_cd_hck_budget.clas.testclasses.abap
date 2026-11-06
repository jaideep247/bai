*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_budget.clas.testclasses.abap
*& Purpose:
*& Unit tests of the check time budget with an LTD clock;
*& does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (audit A18: time budget per check).
*&---------------------------------------------------------------------*
CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock.
    DATA mv_now TYPE timestampl.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~now.
    rv_timestamp = mv_now.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~today.
    CLEAR rv_date.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~time.
    CLEAR rv_time.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_budget DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_deadline TYPE timestampl VALUE '20261105070500.0000000'.
    DATA mo_clock TYPE REF TO ltd_clock.

    METHODS setup.
    METHODS teardown.
    METHODS within_budget_continues FOR TESTING.
    METHODS past_deadline_stops FOR TESTING.
    METHODS no_deadline_never_stops FOR TESTING.

ENDCLASS.



CLASS ltc_budget IMPLEMENTATION.

  METHOD setup.
    mo_clock = NEW #( ).
    zcl_cd_ops_injector=>inject_clock( mo_clock ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  " Rule: before the deadline the check continues
  METHOD within_budget_continues.
    TRY.
        mo_clock->mv_now = '20261105070400.0000000'.
        cl_abap_unit_assert=>assert_false( act = zcl_cd_hck_budget=>exhausted( VALUE #( deadline = gc_deadline ) )
                                           msg = 'Before the deadline the budget is not exhausted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A18: after the deadline the check stops between items
  METHOD past_deadline_stops.
    TRY.
        mo_clock->mv_now = '20261105070600.0000000'.
        cl_abap_unit_assert=>assert_true( act = zcl_cd_hck_budget=>exhausted( VALUE #( deadline = gc_deadline ) )
                                          msg = 'After the deadline the budget is exhausted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a check called without a deadline (e.g. directly) is never stopped
  METHOD no_deadline_never_stops.
    TRY.
        mo_clock->mv_now = '20261105070600.0000000'.
        cl_abap_unit_assert=>assert_false( act = zcl_cd_hck_budget=>exhausted( VALUE #( ) )
                                           msg = 'Without a deadline there is no budget to exhaust' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
