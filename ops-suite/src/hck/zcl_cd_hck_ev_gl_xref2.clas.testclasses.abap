*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_gl_xref2.clas.testclasses.abap
*& Purpose:
*& Unit tests of the evidence "G/L line cleared" (BSEG XREF2 = AUGBL with
*& AUGBL filled): cleared line found, open line shown but not found, no
*& line, one read for all payments, cap flagged. Runtime DAO is a double;
*& does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (user rule 3).
*&---------------------------------------------------------------------*
CLASS ltd_runtime_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_runtime_dao PARTIALLY IMPLEMENTED.
    DATA mt_lines TYPE zif_cd_hck_runtime_types=>tt_gl_xref2_line.
    DATA mv_calls TYPE i.
ENDCLASS.

CLASS ltd_runtime_dao IMPLEMENTATION.
  METHOD zif_cd_hck_runtime_dao~get_gl_lines_by_xref2.
    mv_calls = mv_calls + 1.
    LOOP AT mt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      IF line_exists( it_keys[ bukrs = <ls_line>-bukrs xref2 = <ls_line>-xref2 ] ) AND lines( rt_lines ) < iv_max_rows.
        INSERT <ls_line> INTO TABLE rt_lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_ev_gl_xref2 DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_bukrs TYPE c LENGTH 4 VALUE 'US01',
      gc_doc1  TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300001',
      gc_doc2  TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300002',
      gc_doc3  TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300003'.
    DATA mo_dao TYPE REF TO ltd_runtime_dao.

    METHODS setup.
    METHODS teardown.
    METHODS collect
      IMPORTING
        iv_max_rows      TYPE i DEFAULT 100
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_runtime_types=>ty_evidence_result
      RAISING
        zcx_ca_ops_error.
    METHODS cleared_line_found     FOR TESTING.
    METHODS open_line_not_found    FOR TESTING.
    METHODS one_read_and_cap       FOR TESTING.
ENDCLASS.


CLASS ltc_ev_gl_xref2 IMPLEMENTATION.

  METHOD setup.
    DATA ls_line TYPE zif_cd_hck_runtime_types=>ty_gl_xref2_line.
    mo_dao = NEW #( ).
    zcl_cd_hck_injector=>inject_runtime_dao( mo_dao ).
    ls_line-bukrs = gc_bukrs.
    ls_line-xref2 = '300001'.
    ls_line-belnr = '0100000001'.
    ls_line-augbl = '0200000001'.
    INSERT ls_line INTO TABLE mo_dao->mt_lines.
    ls_line-xref2 = gc_doc2.
    ls_line-belnr = '0100000002'.
    CLEAR ls_line-augbl.
    INSERT ls_line INTO TABLE mo_dao->mt_lines.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    CLEAR mo_dao.
  ENDMETHOD.


  METHOD collect.
    DATA lt_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    INSERT VALUE #( doc1r = gc_doc1 bukrs = gc_bukrs laufd = '20261106' ) INTO TABLE lt_payments.
    INSERT VALUE #( doc1r = gc_doc2 bukrs = gc_bukrs laufd = '20261106' ) INTO TABLE lt_payments.
    INSERT VALUE #( doc1r = gc_doc3 bukrs = gc_bukrs laufd = '20261106' ) INTO TABLE lt_payments.
    rs_result = NEW zcl_cd_hck_ev_gl_xref2( )->zif_cd_hck_evidence~collect( it_payments = lt_payments
                                                                            is_rule     = VALUE #( )
                                                                            iv_max_rows = iv_max_rows ).
  ENDMETHOD.


  " Rule: a BSEG line with XREF2 = AUGBL whose AUGBL is filled holds (XREF2 without leading zeros too)
  METHOD cleared_line_found.
    TRY.
        DATA(ls_result) = collect( ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_doc1 ]-found msg = 'Cleared line' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( ls_result-evidence[ doc1r = gc_doc3 ] ) )
                                           msg = 'No line: no evidence' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a line not cleared yet (AUGBL initial) does not hold; the line is in the detail
  METHOD open_line_not_found.
    TRY.
        DATA(ls_result) = collect( ).
        DATA(ls_evidence) = ls_result-evidence[ doc1r = gc_doc2 ].
        cl_abap_unit_assert=>assert_false( act = ls_evidence-found msg = 'Open line does not hold' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( find( val = ls_evidence-detail sub = `0100000002` ) >= 0 )
                                          msg = 'Line shown' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: one read for all payments; reaching the cap is flagged
  METHOD one_read_and_cap.
    TRY.
        DATA(ls_result) = collect( iv_max_rows = 1 ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_calls exp = 1 msg = 'One read' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-capped msg = 'Capped' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-source exp = zif_cd_ops_trace_types=>gc_table-bseg msg = 'BSEG' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
