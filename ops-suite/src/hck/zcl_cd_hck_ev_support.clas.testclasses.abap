*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_support.clas.testclasses.abap
*& Purpose:
*& Unit tests of the evidence helpers: reference forms, comma lists,
*& earliest run, required parameter, evidence rows, one statement-line
*& read by reference mapped back to the payment document (both forms,
*& cap) and one G/L line read by XREF2 (company code, keys, accounts).
*& Payment trace repository and runtime DAO are doubles; does not prove
*& live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (clearing / return evidence as plug-ins, user rule 5).
*&---------------------------------------------------------------------*
CLASS ltd_trace_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_trace_dao PARTIALLY IMPLEMENTED.
    DATA mt_lines TYPE zif_cd_ops_trace_types=>tt_bank_line.
    DATA mt_asked TYPE zif_cd_ops_trace_types=>tt_ref.
    DATA mv_calls TYPE i.
ENDCLASS.

CLASS ltd_trace_dao IMPLEMENTATION.
  METHOD zif_cd_ops_trace_dao~get_bank_lines.
    mv_calls = mv_calls + 1.
    mt_asked = it_ref.
    LOOP AT mt_lines ASSIGNING FIELD-SYMBOL(<ls_line>) WHERE budat >= iv_from.
      IF line_exists( it_ref[ table_line = <ls_line>-chect ] ) AND lines( rt_lines ) < iv_max_rows.
        INSERT <ls_line> INTO TABLE rt_lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_runtime_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_runtime_dao PARTIALLY IMPLEMENTED.
    DATA mt_lines TYPE zif_cd_hck_runtime_types=>tt_gl_xref2_line.
    DATA mt_keys TYPE zif_cd_hck_runtime_types=>tt_xref2_key.
    DATA mt_hkont TYPE zif_cd_hck_runtime_types=>tt_hkont.
    DATA mv_from TYPE zif_cd_hck_runtime_types=>ty_year.
    DATA mv_to TYPE zif_cd_hck_runtime_types=>ty_year.
ENDCLASS.

CLASS ltd_runtime_dao IMPLEMENTATION.
  METHOD zif_cd_hck_runtime_dao~get_gl_lines_by_xref2.
    mt_keys  = it_keys.
    mt_hkont = it_hkont.
    mv_from  = iv_gjahr_from.
    mv_to    = iv_gjahr_to.
    rt_lines = mt_lines.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_ev_support DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_doc1 TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300001',
      gc_doc2 TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300002'.
    DATA mo_trace TYPE REF TO ltd_trace_dao.
    DATA mo_dao TYPE REF TO ltd_runtime_dao.

    METHODS setup.
    METHODS teardown.
    METHODS payments
      RETURNING
        VALUE(rt_payments) TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    METHODS ref_key_without_zeros      FOR TESTING.
    METHODS tokens_upper_case          FOR TESTING.
    METHODS earliest_run_date          FOR TESTING.
    METHODS blank_parameter_raises     FOR TESTING.
    METHODS hits_accumulate            FOR TESTING.
    METHODS lines_by_doc_one_read      FOR TESTING.
    METHODS lines_capped               FOR TESTING.
    METHODS gl_lines_keys_and_accounts FOR TESTING.
ENDCLASS.


CLASS ltc_ev_support IMPLEMENTATION.

  METHOD setup.
    mo_trace = NEW #( ).
    zcl_cd_ops_injector=>inject_trace_dao( mo_trace ).
    mo_dao = NEW #( ).
    zcl_cd_hck_injector=>inject_runtime_dao( mo_dao ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    zcl_cd_hck_injector=>reset( ).
    CLEAR: mo_trace, mo_dao.
  ENDMETHOD.


  METHOD payments.
    DATA ls_payment TYPE zif_cd_hck_runtime_types=>ty_issued_payment.
    ls_payment-doc1r = gc_doc1.
    ls_payment-bukrs = 'US01'.
    ls_payment-laufd = '20261106'.
    INSERT ls_payment INTO TABLE rt_payments.
    ls_payment-doc1r = gc_doc2.
    ls_payment-laufd = '20251230'.
    INSERT ls_payment INTO TABLE rt_payments.
  ENDMETHOD.


  " Rule: references compare without blanks and leading zeros
  METHOD ref_key_without_zeros.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_ev_support=>ref_key( ' 000300 001' ) exp = `300001`
                                        msg = 'Blanks and leading zeros removed' ).
  ENDMETHOD.


  " Rule: comma lists are trimmed and upper case
  METHOD tokens_upper_case.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_ev_support=>tokens( 'cleared, Sent' )
                                        exp = VALUE string_table( ( `CLEARED` ) ( `SENT` ) )
                                        msg = 'Tokens' ).
  ENDMETHOD.


  " Rule: statement lines are read from the earliest run date of the payments
  METHOD earliest_run_date.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_ev_support=>earliest_run( payments( ) ) exp = '20251230'
                                        msg = 'Earliest run' ).
  ENDMETHOD.


  " Rule: a required rule parameter that is blank raises (the kind is unusable, never guessed)
  METHOD blank_parameter_raises.
    TRY.
        zcl_cd_hck_ev_support=>required_param( iv_value = space
                                               iv_name  = zif_cd_hck_runtime_types=>gc_rule_param-param1
                                               is_rule  = VALUE #( evidence_class = 'ZCL_CD_HCK_EV_PAY_STATUS' ) ).
        cl_abap_unit_assert=>fail( msg = 'Blank parameter must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Raised' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: hits of one payment accumulate; a not-found detail keeps the row not found
  METHOD hits_accumulate.
    DATA lt_evidence TYPE zif_cd_hck_runtime_types=>tt_evidence.
    zcl_cd_hck_ev_support=>add_hit( EXPORTING iv_doc1r = gc_doc1 iv_detail = `a` iv_found = abap_false
                                    CHANGING  ct_evidence = lt_evidence ).
    cl_abap_unit_assert=>assert_false( act = lt_evidence[ doc1r = gc_doc1 ]-found msg = 'Detail only: not found' ).
    zcl_cd_hck_ev_support=>add_hit( EXPORTING iv_doc1r = gc_doc1 iv_detail = `b`
                                    CHANGING  ct_evidence = lt_evidence ).
    zcl_cd_hck_ev_support=>add_hit( EXPORTING iv_doc1r = gc_doc1 iv_detail = `c`
                                    CHANGING  ct_evidence = lt_evidence ).
    cl_abap_unit_assert=>assert_equals( act = lt_evidence[ doc1r = gc_doc1 ]-hits exp = 2 msg = 'Two hits' ).
    cl_abap_unit_assert=>assert_equals( act = lt_evidence[ doc1r = gc_doc1 ]-detail exp = `a; b; c` msg = 'Details joined' ).
  ENDMETHOD.


  " Rule: one statement-line read for all payments, both reference forms asked, mapped back
  METHOD lines_by_doc_one_read.
    DATA ls_line TYPE zif_cd_ops_trace_types=>ty_bank_line.
    TRY.
        ls_line-chect = '300001'.
        ls_line-budat = '20261107'.
        INSERT ls_line INTO TABLE mo_trace->mt_lines.
        ls_line-chect = gc_doc2.
        INSERT ls_line INTO TABLE mo_trace->mt_lines.
        DATA(ls_lines) = zcl_cd_hck_ev_support=>lines_by_doc( it_payments = payments( ) iv_max_rows = 100 ).
        cl_abap_unit_assert=>assert_equals( act = mo_trace->mv_calls exp = 1 msg = 'One read' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_trace->mt_asked ) exp = 4 msg = 'Both forms of both documents' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_lines-lines ) exp = 2 msg = 'Both lines mapped' ).
        cl_abap_unit_assert=>assert_false( act = ls_lines-capped msg = 'Not capped' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a read that reaches the cap is flagged
  METHOD lines_capped.
    DATA ls_line TYPE zif_cd_ops_trace_types=>ty_bank_line.
    TRY.
        ls_line-chect = '300001'.
        ls_line-budat = '20261107'.
        INSERT ls_line INTO TABLE mo_trace->mt_lines.
        DATA(ls_lines) = zcl_cd_hck_ev_support=>lines_by_doc( it_payments = payments( ) iv_max_rows = 1 ).
        cl_abap_unit_assert=>assert_true( act = ls_lines-capped msg = 'Capped' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: G/L lines by company code + XREF2 (both forms), accounts padded, fiscal years of the runs + 1
  METHOD gl_lines_keys_and_accounts.
    DATA ls_line TYPE zif_cd_hck_runtime_types=>ty_gl_xref2_line.
    TRY.
        ls_line-bukrs = 'US01'.
        ls_line-xref2 = '300001'.
        INSERT ls_line INTO TABLE mo_dao->mt_lines.
        DATA(ls_lines) = zcl_cd_hck_ev_support=>gl_lines_by_doc( it_payments = payments( )
                                                                iv_accounts = '1100100'
                                                                iv_max_rows = 100 ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_keys ) exp = 4 msg = 'Both forms per document' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_hkont[ 1 ] exp = '0001100100' msg = 'Account padded' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_from exp = '2025' msg = 'From the earliest run year' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_to exp = '2027' msg = 'To the year after the latest run' ).
        cl_abap_unit_assert=>assert_equals( act = ls_lines-lines[ 1 ]-doc1r exp = gc_doc1 msg = 'Mapped to the document' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
