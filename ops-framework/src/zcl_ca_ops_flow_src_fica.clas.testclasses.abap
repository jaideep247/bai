*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_flow_src_fica.clas.testclasses.abap
*& Purpose:
*& Tests of the open FI-CA items source: the open items per currency are
*& accounted for, signed as the subledger delivers them; the account's
*& range, currency and the key date reach the read; an account of every
*& currency gets a blank-currency row (nothing open in the others).
*& Data access double. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build G: account flow reconciliation).
*&---------------------------------------------------------------------*
CLASS ltd_flow_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_flow_dao PARTIALLY IMPLEMENTED.
    DATA mt_sums TYPE zif_ca_ops_flow_types=>tt_currency_sum.
    DATA mv_hkont_to TYPE saknr.
    DATA mv_currency TYPE zif_ca_ops_types=>ty_currency.
    DATA mv_key_date TYPE d.
ENDCLASS.

CLASS ltd_flow_dao IMPLEMENTATION.
  METHOD zif_ca_ops_flow_dao~fica_open_items.
    mv_hkont_to = iv_hkont_to.
    mv_currency = iv_currency.
    mv_key_date = iv_key_date.
    rt_sums = mt_sums.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_flow_src_fica DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_dao TYPE REF TO ltd_flow_dao.

    METHODS setup.
    METHODS teardown.

    METHODS open_items_per_currency FOR TESTING RAISING zcx_ca_ops_error.
    METHODS range_and_currency_read FOR TESTING RAISING zcx_ca_ops_error.
    METHODS nothing_open_is_zero    FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_flow_src_fica IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    zcl_ca_ops_injector=>inject_flow_dao( mo_dao ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  " Rule: the open items of the reconciliation account are what the subledger accounts for, signed (payable credit -)
  METHOD open_items_per_currency.
    mo_dao->mt_sums = VALUE #( ( currency = 'USD' amount = '-300.00' item_count = 1 ) ).
    DATA(lt_rows) = NEW zcl_ca_ops_flow_src_fica( )->zif_ca_ops_flow_source~accounted_for(
                      is_config   = VALUE #( )
                      is_account  = VALUE #( flow_acct = 'PAYABLE' bukrs = 'ZT01' hkont_from = '0000160000' )
                      iv_key_date = '20261115' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ currency = 'USD' ]-amount exp = '-300.00' msg = 'Signed' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ currency = 'USD' ]-status
                                        exp = zif_ca_ops_flow_types=>gc_item_status-evaluated msg = 'Evaluated' ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_rows[ currency = '' ] ) )
                                      msg = 'Other currencies: nothing open' ).
  ENDMETHOD.


  " Rule: the account's G/L range, its currency and the key date are the read's
  METHOD range_and_currency_read.
    NEW zcl_ca_ops_flow_src_fica( )->zif_ca_ops_flow_source~accounted_for(
      is_config   = VALUE #( )
      is_account  = VALUE #( bukrs = 'ZT01' hkont_from = '0000160000' hkont_to = '0000160009' currency = 'USD' )
      iv_key_date = '20261115' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_hkont_to exp = '0000160009' msg = 'Range end' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_currency exp = 'USD' msg = 'Currency' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_key_date exp = '20261115' msg = 'Key date' ).
  ENDMETHOD.


  " Rule: nothing open is an evaluated zero (the subledger was read), not "not evaluated"
  METHOD nothing_open_is_zero.
    DATA(lt_rows) = NEW zcl_ca_ops_flow_src_fica( )->zif_ca_ops_flow_source~accounted_for(
                      is_config   = VALUE #( )
                      is_account  = VALUE #( bukrs = 'ZT01' hkont_from = '0000160000' currency = 'USD' )
                      iv_key_date = '20261115' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One row' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-status
                                        exp = zif_ca_ops_flow_types=>gc_item_status-evaluated msg = 'Evaluated' ).
    cl_abap_unit_assert=>assert_initial( act = lt_rows[ 1 ]-amount msg = 'Zero' ).
  ENDMETHOD.

ENDCLASS.
