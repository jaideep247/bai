*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pf_dao.clas.testclasses.abap
*& Purpose:
*& Tests of the payment file data access on doubled tables (ABAP SQL test
*& environment): an evidence row inserted twice is stored once (idempotent
*& ingestion); totals per file and currency are aggregated in the
*& database - payments, gross, payments without a known amount and the
*& duplicate exposure of payments another file carries - and never summed
*& across currencies; payments of a file are replaced; the files of a
*& payment key in other files are found (reissue). Does not prove live
*& SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
CLASS ltc_pf_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_pf_dao.
    DATA mv_f1 TYPE zif_ca_ops_pf_types=>ty_file_id VALUE '00000000000000000000000000000001'.
    DATA mv_f2 TYPE zif_ca_ops_pf_types=>ty_file_id VALUE '00000000000000000000000000000002'.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS events_stored_once     FOR TESTING.
    METHODS totals_per_currency    FOR TESTING RAISING zcx_ca_ops_error.
    METHODS payments_elsewhere     FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_pf_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZCA_OPS_PFEVT' ) ( 'ZCA_OPS_PFPAY' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_ca_ops_pf_dao( ).
  ENDMETHOD.


  METHOD events_stored_once.
    DATA(lt_events) = VALUE zif_ca_ops_pf_types=>tt_event( ( area = 'ZT' event_key = 'K1' file_id = mv_f1 )
                                                           ( area = 'ZT' event_key = 'K2' file_id = mv_f1 ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->insert_events( lt_events ) exp = 2 msg = 'New' ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->insert_events( lt_events ) exp = 0 msg = 'Read again: stored once' ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->get_events( iv_area = 'ZT' it_file_ids = VALUE #( ( mv_f1 ) ) ) )
                                        exp = 2 msg = 'Two rows' ).
  ENDMETHOD.


  METHOD totals_per_currency.
    mo_cut->save_payments(
      iv_area     = 'ZT'
      it_file_ids = VALUE #( ( mv_f1 ) )
      it_payments = VALUE #( ( area = 'ZT' file_id = mv_f1 pay_key = 'P1' currency = 'USD' amount = '100.00' amount_known = abap_true )
                             ( area = 'ZT' file_id = mv_f1 pay_key = 'P2' currency = 'USD' amount = '50.00' amount_known = abap_true
                               other_file = mv_f2 )
                             ( area = 'ZT' file_id = mv_f1 pay_key = 'P3' currency = 'EUR' amount = '0' ) ) ).
    DATA(lt_totals) = mo_cut->get_totals( iv_area = 'ZT' it_file_ids = VALUE #( ( mv_f1 ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_totals ) exp = 2 msg = 'One row per currency' ).
    DATA(ls_usd) = lt_totals[ currency = 'USD' ].
    cl_abap_unit_assert=>assert_equals( act = ls_usd-pay_count exp = 2 msg = 'Payments' ).
    cl_abap_unit_assert=>assert_equals( act = ls_usd-amount exp = '150.00' msg = 'Gross' ).
    cl_abap_unit_assert=>assert_equals( act = ls_usd-dup_amount exp = '50.00' msg = 'Exposure' ).
    cl_abap_unit_assert=>assert_equals( act = lt_totals[ currency = 'EUR' ]-unknown_count exp = 1 msg = 'Unknown amount' ).
  ENDMETHOD.


  METHOD payments_elsewhere.
    mo_cut->save_payments( iv_area     = 'ZT'
                           it_file_ids = VALUE #( ( mv_f1 ) )
                           it_payments = VALUE #( ( area = 'ZT' file_id = mv_f1 pay_key = 'P1' currency = 'USD' ) ) ).
    DATA(lt_found) = mo_cut->payments_elsewhere( iv_area     = 'ZT'
                                                 it_payments = VALUE #( ( area = 'ZT' file_id = mv_f2 pay_key = 'P1' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_found ) exp = 1 msg = 'The earlier file carries it' ).
    cl_abap_unit_assert=>assert_equals( act = lt_found[ 1 ]-file_id exp = mv_f1 msg = 'File 1' ).
  ENDMETHOD.

ENDCLASS.
