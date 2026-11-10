*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_stmt_doc.clas.testclasses.abap
*& Purpose:
*& Unit tests of the evidence "statement line by payment document":
*& found (CHECT with or without leading zeros), not found, one read for
*& all payments, cap flagged. Payment trace repository is a double; does
*& not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (user rule 1).
*&---------------------------------------------------------------------*
CLASS ltd_trace_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_trace_dao PARTIALLY IMPLEMENTED.
    DATA mt_lines TYPE zif_cd_ops_trace_types=>tt_bank_line.
    DATA mv_calls TYPE i.
ENDCLASS.

CLASS ltd_trace_dao IMPLEMENTATION.
  METHOD zif_cd_ops_trace_dao~get_bank_lines.
    mv_calls = mv_calls + 1.
    LOOP AT mt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      IF line_exists( it_ref[ table_line = <ls_line>-chect ] ) AND lines( rt_lines ) < iv_max_rows.
        INSERT <ls_line> INTO TABLE rt_lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_ev_stmt_doc DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_doc1 TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300001',
      gc_doc2 TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300002',
      gc_doc3 TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300003'.
    DATA mo_trace TYPE REF TO ltd_trace_dao.

    METHODS setup.
    METHODS teardown.
    METHODS collect
      IMPORTING
        iv_max_rows      TYPE i DEFAULT 100
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_runtime_types=>ty_evidence_result
      RAISING
        zcx_ca_ops_error.
    METHODS found_both_forms     FOR TESTING.
    METHODS no_line_not_found    FOR TESTING.
    METHODS one_read_for_all     FOR TESTING.
    METHODS cap_flagged          FOR TESTING.
ENDCLASS.


CLASS ltc_ev_stmt_doc IMPLEMENTATION.

  METHOD setup.
    DATA ls_line TYPE zif_cd_ops_trace_types=>ty_bank_line.
    mo_trace = NEW #( ).
    zcl_cd_ops_injector=>inject_trace_dao( mo_trace ).
    ls_line-chect = '300001'.
    ls_line-vorgc = '495'.
    INSERT ls_line INTO TABLE mo_trace->mt_lines.
    ls_line-chect = gc_doc2.
    INSERT ls_line INTO TABLE mo_trace->mt_lines.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    CLEAR mo_trace.
  ENDMETHOD.


  METHOD collect.
    DATA lt_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    INSERT VALUE #( doc1r = gc_doc1 laufd = '20261106' ) INTO TABLE lt_payments.
    INSERT VALUE #( doc1r = gc_doc2 laufd = '20261106' ) INTO TABLE lt_payments.
    INSERT VALUE #( doc1r = gc_doc3 laufd = '20261106' ) INTO TABLE lt_payments.
    rs_result = NEW zcl_cd_hck_ev_stmt_doc( )->zif_cd_hck_evidence~collect( it_payments = lt_payments
                                                                            is_rule     = VALUE #( )
                                                                            iv_max_rows = iv_max_rows ).
  ENDMETHOD.


  " Rule: a line with CHECT = AUGBL counts, stored with or without leading zeros
  METHOD found_both_forms.
    TRY.
        DATA(ls_result) = collect( ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_doc1 ]-found msg = 'Without zeros' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_doc2 ]-found msg = 'As stored' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: no line = no evidence row
  METHOD no_line_not_found.
    TRY.
        DATA(ls_result) = collect( ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( ls_result-evidence[ doc1r = gc_doc3 ] ) )
                                           msg = 'Not found' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: one read for all payments (batch)
  METHOD one_read_for_all.
    TRY.
        collect( ).
        cl_abap_unit_assert=>assert_equals( act = mo_trace->mv_calls exp = 1 msg = 'One read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: reaching the row cap is flagged with the table
  METHOD cap_flagged.
    TRY.
        DATA(ls_result) = collect( iv_max_rows = 1 ).
        cl_abap_unit_assert=>assert_true( act = ls_result-capped msg = 'Capped' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-source exp = zif_cd_ops_trace_types=>gc_table-febep msg = 'FEBEP' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
