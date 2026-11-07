*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_stmt_cheque.clas.testclasses.abap
*& Purpose:
*& Unit tests of the evidence "statement line of the cheque": CHECT = the
*& last 13 characters of ZTNUM (default and PARAM1), shorter numbers in
*& full, no line = not found, one cheque and one line read, cap flagged.
*& Payment trace repository is a double; does not prove live SAP runtime
*& behavior.
*& Modification log:
*& 2026-11-07 | Initial version (user rule 2: ZTNUM suffix 13).
*&---------------------------------------------------------------------*
CLASS ltd_trace_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_trace_dao PARTIALLY IMPLEMENTED.
    DATA mt_checks TYPE zif_cd_ops_trace_types=>tt_check.
    DATA mt_lines TYPE zif_cd_ops_trace_types=>tt_bank_line.
    DATA mv_calls TYPE i.
ENDCLASS.

CLASS ltd_trace_dao IMPLEMENTATION.
  METHOD zif_cd_ops_trace_dao~get_checks_by_doc.
    rt_checks = mt_checks.
  ENDMETHOD.

  METHOD zif_cd_ops_trace_dao~get_bank_lines.
    mv_calls = mv_calls + 1.
    LOOP AT mt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      IF line_exists( it_ref[ table_line = <ls_line>-chect ] ) AND lines( rt_lines ) < iv_max_rows.
        INSERT <ls_line> INTO TABLE rt_lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_ev_stmt_cheque DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_doc1 TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300001',
      gc_doc2 TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300002',
      "! 20 characters: bank prefix + 13-character cheque reference
      gc_ztnum TYPE zif_cd_ops_trace_types=>ty_ref VALUE 'JPMC0011234567890123'.
    DATA mo_trace TYPE REF TO ltd_trace_dao.

    METHODS setup.
    METHODS teardown.
    METHODS collect
      IMPORTING
        iv_param1        TYPE clike OPTIONAL
        iv_max_rows      TYPE i DEFAULT 100
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_runtime_types=>ty_evidence_result
      RAISING
        zcx_cd_ops_error.
    METHODS suffix_13_matches       FOR TESTING.
    METHODS other_length_by_param1  FOR TESTING.
    METHODS short_number_in_full    FOR TESTING.
    METHODS one_read_and_cap        FOR TESTING.
ENDCLASS.


CLASS ltc_ev_stmt_cheque IMPLEMENTATION.

  METHOD setup.
    DATA ls_check TYPE zif_cd_ops_trace_types=>ty_check.
    DATA ls_line TYPE zif_cd_ops_trace_types=>ty_bank_line.
    mo_trace = NEW #( ).
    zcl_cd_ops_injector=>inject_trace_dao( mo_trace ).
    ls_check-doc1r = gc_doc1.
    ls_check-ztnum = gc_ztnum.
    INSERT ls_check INTO TABLE mo_trace->mt_checks.
    ls_check-doc1r = gc_doc2.
    ls_check-ztnum = 'JPMC0019999999999999'.
    INSERT ls_check INTO TABLE mo_trace->mt_checks.
    ls_line-chect = '1234567890123'.
    ls_line-budat = '20261010'.
    INSERT ls_line INTO TABLE mo_trace->mt_lines.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    CLEAR mo_trace.
  ENDMETHOD.


  METHOD collect.
    DATA lt_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    INSERT VALUE #( doc1r = gc_doc1 laufd = '20261001' ) INTO TABLE lt_payments.
    INSERT VALUE #( doc1r = gc_doc2 laufd = '20261001' ) INTO TABLE lt_payments.
    rs_result = NEW zcl_cd_hck_ev_stmt_cheque( )->zif_cd_hck_evidence~collect(
                  it_payments = lt_payments
                  is_rule     = VALUE #( param1 = iv_param1 )
                  iv_max_rows = iv_max_rows ).
  ENDMETHOD.


  " Rule: FEBEP-CHECT = the last 13 characters of DFKKCR-ZTNUM (default when PARAM1 is blank)
  METHOD suffix_13_matches.
    TRY.
        DATA(ls_result) = collect( ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_doc1 ]-found msg = 'Suffix 13 matched' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( ls_result-evidence[ doc1r = gc_doc2 ] ) )
                                           msg = 'No line: not found' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the suffix length is configuration (PARAM1)
  METHOD other_length_by_param1.
    TRY.
        DATA(ls_result) = collect( iv_param1 = '10' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( ls_result-evidence[ doc1r = gc_doc1 ] ) )
                                           msg = 'Suffix 10 does not match a 13-character CHECT' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_ev_stmt_cheque=>suffix( iv_ztnum = gc_ztnum iv_length = 13 )
                                            exp = `1234567890123` msg = 'Last 13' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a cheque number shorter than the suffix is used in full
  METHOD short_number_in_full.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_ev_stmt_cheque=>suffix( iv_ztnum = ' 770001' iv_length = 13 )
                                            exp = `770001` msg = 'Short number kept' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: one statement-line read for all cheques; reaching the cap is flagged
  METHOD one_read_and_cap.
    TRY.
        DATA(ls_result) = collect( iv_max_rows = 1 ).
        cl_abap_unit_assert=>assert_equals( act = mo_trace->mv_calls exp = 1 msg = 'One read' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-capped msg = 'Capped' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
