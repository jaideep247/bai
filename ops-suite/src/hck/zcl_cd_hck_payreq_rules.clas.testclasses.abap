*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_payreq_rules.clas.testclasses.abap
*& Purpose:
*& Pure tests of the known-table rules (USAA payment engine reference):
*& failure without SPE row, a SUCCESS row overrides failed attempts, paid
*& request left CANCELLED, cheque status may never go back (ZECT_STATUS).
*& Static ABAP Unit only; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*&---------------------------------------------------------------------*
CLASS ltc_payreq_rules DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS terminal
      RETURNING
        VALUE(rt_list) TYPE string_table.
    METHODS allowed
      RETURNING
        VALUE(rt_list) TYPE string_table.
    METHODS regression
      IMPORTING
        iv_from          TYPE string
        iv_to            TYPE string
      RETURNING
        VALUE(rv_result) TYPE abap_bool.

    METHODS failure_without_spe_reported FOR TESTING.
    METHODS success_row_clears_failure   FOR TESTING.
    METHODS paid_and_cancelled_reported  FOR TESTING.
    METHODS higher_status_overwrites     FOR TESTING.
    METHODS lower_after_higher_regresses FOR TESTING.
    METHODS mailed_to_returned_allowed   FOR TESTING.
    METHODS change_after_terminal_fails  FOR TESTING.
    METHODS history_reports_each_check   FOR TESTING.
ENDCLASS.


CLASS ltc_payreq_rules IMPLEMENTATION.

  METHOD terminal.
    rt_list = VALUE #( ( `3` ) ( `4` ) ( `9` ) ).
  ENDMETHOD.


  METHOD allowed.
    rt_list = VALUE #( ( `10>9` ) ).
  ENDMETHOD.


  METHOD regression.
    rv_result = zcl_cd_hck_payreq_rules=>is_regression( iv_from     = iv_from
                                                        iv_to       = iv_to
                                                        it_terminal = terminal( )
                                                        it_allowed  = allowed( ) ).
  ENDMETHOD.


  " Rule: every failure needs an SPE row, otherwise the hourly job never reports it
  METHOD failure_without_spe_reported.
    TRY.
        DATA(lt_keys) = zcl_cd_hck_payreq_rules=>failed_without_spe(
                          it_failed  = VALUE #( ( `R1` ) ( `R2` ) )
                          it_success = VALUE #( )
                          it_spe     = VALUE #( ( `R2` ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lt_keys exp = VALUE zif_cd_hck_value_types=>tt_key( ( `R1` ) )
                                            msg = 'Only the failure without SPE row must be reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (ZCD_PAYM_REQ_LOG): a request with a SUCCESS row is not failed, even if a failed
  " attempt was written later
  METHOD success_row_clears_failure.
    TRY.
        DATA(lt_keys) = zcl_cd_hck_payreq_rules=>failed_without_spe(
                          it_failed  = VALUE #( ( `R1` ) )
                          it_success = VALUE #( ( `R1` ) )
                          it_spe     = VALUE #( ) ).
        cl_abap_unit_assert=>assert_initial( act = lt_keys msg = 'A request with a SUCCESS row is not failed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (PCLM): a paid payment request must never be left CANCELLED
  METHOD paid_and_cancelled_reported.
    TRY.
        DATA(lt_keys) = zcl_cd_hck_payreq_rules=>paid_but_cancelled(
                          it_cancelled = VALUE #( ( `FIN1` ) ( `FIN2` ) )
                          it_paid      = VALUE #( ( `FIN2` ) ( `FIN3` ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lt_keys exp = VALUE zif_cd_hck_value_types=>tt_key( ( `FIN2` ) )
                                            msg = 'Only the paid and cancelled request must be reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (ZECT_STATUS): a higher status may overwrite a lower one
  METHOD higher_status_overwrites.
    cl_abap_unit_assert=>assert_false( act = regression( iv_from = `2` iv_to = `10` ) msg = '2 -> 10 is progress' ).
  ENDMETHOD.


  " Rule (ZECT_STATUS): never lower after higher
  METHOD lower_after_higher_regresses.
    cl_abap_unit_assert=>assert_true( act = regression( iv_from = `10` iv_to = `2` ) msg = '10 -> 2 is a regression' ).
  ENDMETHOD.


  " Rule (ZECT_STATUS): mailed (10) may become returned (9)
  METHOD mailed_to_returned_allowed.
    cl_abap_unit_assert=>assert_false( act = regression( iv_from = `10` iv_to = `9` ) msg = '10 -> 9 is allowed' ).
  ENDMETHOD.


  " Rule (ZECT_STATUS): 3 failed, 4 rejected, 9 returned are terminal
  METHOD change_after_terminal_fails.
    cl_abap_unit_assert=>assert_true( act = regression( iv_from = `9` iv_to = `10` ) msg = 'Returned is terminal' ).
    cl_abap_unit_assert=>assert_false( act = regression( iv_from = `9` iv_to = `9` ) msg = 'The same status is no change' ).
  ENDMETHOD.


  " Rule: the history of each cheque is checked in order; each regression is reported once
  METHOD history_reports_each_check.
    TRY.
        DATA(lt_found) = zcl_cd_hck_payreq_rules=>cheque_regressions(
                           it_events   = VALUE #( ( key = `C1` seq = `001` status = `2` )
                                                  ( key = `C1` seq = `002` status = `10` )
                                                  ( key = `C1` seq = `003` status = `9` )
                                                  ( key = `C2` seq = `001` status = `10` )
                                                  ( key = `C2` seq = `002` status = `2` ) )
                           it_terminal = terminal( )
                           it_allowed  = allowed( ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_found ) exp = 1 msg = 'Only C2 went backwards' ).
        cl_abap_unit_assert=>assert_equals( act = lt_found[ 1 ]-key exp = `C2` msg = 'The regression is on C2' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
