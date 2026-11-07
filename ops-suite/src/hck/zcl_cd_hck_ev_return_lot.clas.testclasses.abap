*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_return_lot.clas.testclasses.abap
*& Purpose:
*& Unit tests of the evidence "returns lot item" (DFKKRP-SELW1 = AUGBL):
*& found with lot / reason / amount in the detail, two items = two hits,
*& no item = no row, one read for all payments. Payment trace repository
*& is a double; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (user rule 4).
*&---------------------------------------------------------------------*
CLASS ltd_trace_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_trace_dao PARTIALLY IMPLEMENTED.
    DATA mt_returns TYPE zif_cd_ops_trace_types=>tt_return.
    DATA mv_calls TYPE i.
ENDCLASS.

CLASS ltd_trace_dao IMPLEMENTATION.
  METHOD zif_cd_ops_trace_dao~get_returns.
    mv_calls = mv_calls + 1.
    rt_returns = mt_returns.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_ev_return_lot DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_doc1 TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300001',
      gc_doc2 TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300002'.
    DATA mo_trace TYPE REF TO ltd_trace_dao.

    METHODS setup.
    METHODS teardown.
    METHODS lot_item_found        FOR TESTING.
    METHODS no_item_no_row        FOR TESTING.
ENDCLASS.


CLASS ltc_ev_return_lot IMPLEMENTATION.

  METHOD setup.
    DATA ls_return TYPE zif_cd_ops_trace_types=>ty_return.
    mo_trace = NEW #( ).
    zcl_cd_ops_injector=>inject_trace_dao( mo_trace ).
    ls_return-selw1  = gc_doc1.
    ls_return-opbel  = '000000700001'.
    ls_return-rlgrd  = 'R01'.
    ls_return-amount = '250.00'.
    INSERT ls_return INTO TABLE mo_trace->mt_returns.
    ls_return-opbel = '000000700002'.
    INSERT ls_return INTO TABLE mo_trace->mt_returns.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    CLEAR mo_trace.
  ENDMETHOD.


  " Rule: an item with SELW1 = AUGBL holds; two items = two hits; one read for all payments
  METHOD lot_item_found.
    DATA lt_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    TRY.
        INSERT VALUE #( doc1r = gc_doc1 ) INTO TABLE lt_payments.
        INSERT VALUE #( doc1r = gc_doc2 ) INTO TABLE lt_payments.
        DATA(ls_result) = NEW zcl_cd_hck_ev_return_lot( )->zif_cd_hck_evidence~collect( it_payments = lt_payments
                                                                                        is_rule     = VALUE #( )
                                                                                        iv_max_rows = 100 ).
        DATA(ls_evidence) = ls_result-evidence[ doc1r = gc_doc1 ].
        cl_abap_unit_assert=>assert_true( act = ls_evidence-found msg = 'Returns lot item' ).
        cl_abap_unit_assert=>assert_equals( act = ls_evidence-hits exp = 2 msg = 'Two items' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( find( val = ls_evidence-detail sub = `R01` ) >= 0 )
                                          msg = 'Reason shown' ).
        cl_abap_unit_assert=>assert_equals( act = mo_trace->mv_calls exp = 1 msg = 'One read' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( ls_result-evidence[ doc1r = gc_doc2 ] ) )
                                           msg = 'No item: no row' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: no payment = no read
  METHOD no_item_no_row.
    TRY.
        DATA(ls_result) = NEW zcl_cd_hck_ev_return_lot( )->zif_cd_hck_evidence~collect( it_payments = VALUE #( )
                                                                                        is_rule     = VALUE #( )
                                                                                        iv_max_rows = 100 ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-evidence msg = 'Nothing' ).
        cl_abap_unit_assert=>assert_equals( act = mo_trace->mv_calls exp = 0 msg = 'No read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
