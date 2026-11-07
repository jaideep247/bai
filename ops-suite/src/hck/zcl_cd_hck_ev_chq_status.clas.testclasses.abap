*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_chq_status.clas.testclasses.abap
*& Purpose:
*& Unit tests of the evidence "cheque status" (DFKKCR-STATE): B holds for
*& PARAM1 B, V for PARAM1 V, blank (open) never holds, no cheque = no row,
*& one read for all payments, PARAM1 required. Payment trace repository
*& is a double; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (user rule 2: B cashed, V voided, blank open).
*&---------------------------------------------------------------------*
CLASS ltd_trace_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_trace_dao PARTIALLY IMPLEMENTED.
    DATA mt_checks TYPE zif_cd_ops_trace_types=>tt_check.
    DATA mv_calls TYPE i.
ENDCLASS.

CLASS ltd_trace_dao IMPLEMENTATION.
  METHOD zif_cd_ops_trace_dao~get_checks_by_doc.
    mv_calls = mv_calls + 1.
    rt_checks = mt_checks.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_ev_chq_status DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_cashed TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300001',
      gc_voided TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300002',
      gc_open   TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300003',
      gc_none   TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300004'.
    DATA mo_trace TYPE REF TO ltd_trace_dao.

    METHODS setup.
    METHODS teardown.
    METHODS collect
      IMPORTING
        iv_param1        TYPE clike
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_runtime_types=>ty_evidence_result
      RAISING
        zcx_cd_ops_error.
    METHODS cashed_holds_for_b     FOR TESTING.
    METHODS voided_holds_for_v     FOR TESTING.
    METHODS blank_never_holds      FOR TESTING.
    METHODS blank_param1_raises    FOR TESTING.
ENDCLASS.


CLASS ltc_ev_chq_status IMPLEMENTATION.

  METHOD setup.
    DATA ls_check TYPE zif_cd_ops_trace_types=>ty_check.
    mo_trace = NEW #( ).
    zcl_cd_ops_injector=>inject_trace_dao( mo_trace ).
    ls_check-doc1r = gc_cashed.
    ls_check-state = 'B'.
    INSERT ls_check INTO TABLE mo_trace->mt_checks.
    ls_check-doc1r = gc_voided.
    ls_check-state = 'V'.
    INSERT ls_check INTO TABLE mo_trace->mt_checks.
    ls_check-doc1r = gc_open.
    CLEAR ls_check-state.
    INSERT ls_check INTO TABLE mo_trace->mt_checks.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    CLEAR mo_trace.
  ENDMETHOD.


  METHOD collect.
    DATA lt_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    INSERT VALUE #( doc1r = gc_cashed ) INTO TABLE lt_payments.
    INSERT VALUE #( doc1r = gc_voided ) INTO TABLE lt_payments.
    INSERT VALUE #( doc1r = gc_open ) INTO TABLE lt_payments.
    INSERT VALUE #( doc1r = gc_none ) INTO TABLE lt_payments.
    rs_result = NEW zcl_cd_hck_ev_chq_status( )->zif_cd_hck_evidence~collect(
                  it_payments = lt_payments
                  is_rule     = VALUE #( evidence_class = 'ZCL_CD_HCK_EV_CHQ_STATUS' param1 = iv_param1 )
                  iv_max_rows = 100 ).
  ENDMETHOD.


  " Rule: state B (cashed) holds for PARAM1 B; one read for all payments
  METHOD cashed_holds_for_b.
    TRY.
        DATA(ls_result) = collect( 'B' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_cashed ]-found msg = 'B holds' ).
        cl_abap_unit_assert=>assert_false( act = ls_result-evidence[ doc1r = gc_voided ]-found msg = 'V does not' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( ls_result-evidence[ doc1r = gc_none ] ) )
                                           msg = 'No cheque: no row' ).
        cl_abap_unit_assert=>assert_equals( act = mo_trace->mv_calls exp = 1 msg = 'One read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: state V (voided) holds for PARAM1 V
  METHOD voided_holds_for_v.
    TRY.
        DATA(ls_result) = collect( 'v' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_voided ]-found msg = 'V holds' ).
        cl_abap_unit_assert=>assert_false( act = ls_result-evidence[ doc1r = gc_cashed ]-found msg = 'B does not' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: blank state (open) never holds, the row shows the status
  METHOD blank_never_holds.
    TRY.
        DATA(ls_result) = collect( 'B,V' ).
        cl_abap_unit_assert=>assert_false( act = ls_result-evidence[ doc1r = gc_open ]-found msg = 'Open does not hold' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: PARAM1 (status values) is required
  METHOD blank_param1_raises.
    TRY.
        collect( space ).
        cl_abap_unit_assert=>fail( msg = 'Blank PARAM1 must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Raised' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
