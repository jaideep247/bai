*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_cheque_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the cheque pilot reads: register rows by cheque number
*& (latest run first, cap), and the anti-join of cheque payments without a
*& cheque register row - a payment with a register row, a proposal run, a
*& run outside the window and another payment method are not returned.
*& Tables DPAYH and DFKKCR are doubled; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-16 | Initial version (build R: pilot acceptance items of the first customer's daily controls).
*&---------------------------------------------------------------------*
CLASS ltc_cheque_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        run_day   TYPE d VALUE '20261113',
        run_old   TYPE d VALUE '20261101',
        no_cheque TYPE c LENGTH 24 VALUE '000000900001',
        with_chq  TYPE c LENGTH 24 VALUE '000000900002',
        proposal  TYPE c LENGTH 24 VALUE '000000900003',
        old_run   TYPE c LENGTH 24 VALUE '000000900004',
        ach       TYPE c LENGTH 24 VALUE '000000900005',
        cheque_no TYPE c LENGTH 13 VALUE '0000000700001',
        method    TYPE c LENGTH 1 VALUE 'C',
        method_ach TYPE c LENGTH 1 VALUE 'A',
        bukrs     TYPE c LENGTH 4 VALUE 'ZT01',
        currency  TYPE c LENGTH 5 VALUE 'USD',
        amount    TYPE p LENGTH 12 DECIMALS 2 VALUE '125.50',
        yes       TYPE c LENGTH 1 VALUE 'X',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS payment_without_register FOR TESTING.
    METHODS register_by_cheque FOR TESTING.

    METHODS payment
      IMPORTING
        iv_doc   TYPE clike
        iv_laufd TYPE d
        iv_rzawe TYPE clike
        iv_xvorl TYPE abap_bool DEFAULT abap_false.
    METHODS register
      IMPORTING
        iv_doc   TYPE clike
        iv_ztnum TYPE clike
        iv_laufd TYPE d.
ENDCLASS.


CLASS ltc_cheque_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'DPAYH' ) ( 'DFKKCR' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD payment.
    DATA lt_rows TYPE STANDARD TABLE OF dpayh WITH EMPTY KEY.
    DATA ls_row TYPE dpayh.
    ls_row-laufd = iv_laufd.
    ls_row-laufi = iv_doc+7(5).
    ls_row-doc1r = iv_doc.
    ls_row-xvorl = iv_xvorl.
    ls_row-rzawe = iv_rzawe.
    ls_row-bbukr = gc-bukrs.
    ls_row-rbetr = gc-amount.
    ls_row-waers = gc-currency.
    INSERT ls_row INTO TABLE lt_rows.
    go_env->insert_test_data( lt_rows ).
  ENDMETHOD.


  METHOD register.
    DATA lt_rows TYPE STANDARD TABLE OF dfkkcr WITH EMPTY KEY.
    DATA ls_row TYPE dfkkcr.
    ls_row-ztnum = iv_ztnum.
    ls_row-doc1r = iv_doc.
    ls_row-laufd = iv_laufd.
    ls_row-bbukr = gc-bukrs.
    ls_row-rbetr = gc-amount.
    ls_row-waers = gc-currency.
    INSERT ls_row INTO TABLE lt_rows.
    go_env->insert_test_data( lt_rows ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    payment( iv_doc = gc-no_cheque iv_laufd = gc-run_day iv_rzawe = gc-method ).
    payment( iv_doc = gc-with_chq iv_laufd = gc-run_day iv_rzawe = gc-method ).
    register( iv_doc = gc-with_chq iv_ztnum = gc-cheque_no iv_laufd = gc-run_day ).
    payment( iv_doc = gc-proposal iv_laufd = gc-run_day iv_rzawe = gc-method iv_xvorl = gc-yes ).
    payment( iv_doc = gc-old_run iv_laufd = gc-run_old iv_rzawe = gc-method ).
    payment( iv_doc = gc-ach iv_laufd = gc-run_day iv_rzawe = gc-method_ach ).
  ENDMETHOD.


  " Rule: a cheque payment of the window without a cheque register row is returned, nothing else
  METHOD payment_without_register.
    DATA lt_methods TYPE zif_cd_hck_cheque_types=>tt_pymet.
    INSERT CONV #( gc-method ) INTO TABLE lt_methods.
    TRY.
        DATA(lt_rows) = NEW zcl_cd_hck_cheque_dao( )->zif_cd_hck_cheque_dao~get_payments_without_cheque(
                          iv_from = gc-run_day iv_to = gc-run_day it_methods = lt_methods iv_max_rows = 100 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One payment without cheque number' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-doc1r exp = gc-no_cheque msg = 'The payment document' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-amount exp = gc-amount msg = 'Amount of the payment' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-currency exp = gc-currency msg = 'Currency' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: register rows are read by cheque number; an empty list reads nothing
  METHOD register_by_cheque.
    DATA lt_cheques TYPE zif_cd_hck_cheque_types=>tt_cheque_no.
    TRY.
        DATA(lo_dao) = NEW zcl_cd_hck_cheque_dao( ).
        cl_abap_unit_assert=>assert_initial( act = lo_dao->zif_cd_hck_cheque_dao~get_register( it_cheques  = lt_cheques
                                                                                               iv_max_rows = 10 )
                                             msg = 'Empty list reads nothing' ).
        INSERT CONV #( gc-cheque_no ) INTO TABLE lt_cheques.
        DATA(lt_rows) = lo_dao->zif_cd_hck_cheque_dao~get_register( it_cheques = lt_cheques iv_max_rows = 10 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One register row' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-doc1r exp = gc-with_chq msg = 'Payment document' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
