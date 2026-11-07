*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_cheque_link.clas.testclasses.abap
*& Purpose:
*& Unit tests of the statement line to cheque link: the same cheque number
*& suffix on two house bank accounts (each line fits only the cheque of
*& its own account - neither inherits the other's cashing), two cheques of
*& one account with the same suffix (ambiguous, attributed to none, both
*& named), suffix and leading zeros, a side without the full account
*& identity fits nothing, query forms of the numbers. Pure logic, no
*& doubles needed; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (design review: cheque suffix collisions).
*&---------------------------------------------------------------------*
CLASS ltc_cheque_link DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        bukrs   TYPE zif_cd_ops_trace_types=>ty_bukrs VALUE 'US01',
        jpmc    TYPE c LENGTH 5 VALUE 'JPMC1',
        boa     TYPE c LENGTH 5 VALUE 'BOA01',
        account TYPE c LENGTH 5 VALUE 'CHK01',
        "! Two 20-character cheque numbers whose last 13 characters are equal
        ztnum_1 TYPE zif_cd_ops_trace_types=>ty_ref VALUE 'JPMC0011234567890123',
        ztnum_2 TYPE zif_cd_ops_trace_types=>ty_ref VALUE 'BOAX0021234567890123',
        chect   TYPE zif_cd_ops_trace_types=>ty_ref VALUE '1234567890123',
        doc_1   TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000300001',
        doc_2   TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000300002',
        length  TYPE i VALUE 13,
      END OF gc_test.

    DATA mt_checks TYPE zif_cd_ops_trace_types=>tt_check.
    DATA mt_lines TYPE zif_cd_ops_trace_types=>tt_bank_line.

    METHODS setup.
    METHODS add_check
      IMPORTING
        iv_ztnum TYPE zif_cd_ops_trace_types=>ty_ref
        iv_doc   TYPE zif_cd_ops_trace_types=>ty_docno
        iv_hbkid TYPE clike
        iv_bukrs TYPE clike DEFAULT gc_test-bukrs.
    METHODS add_line
      IMPORTING
        iv_chect TYPE clike DEFAULT gc_test-chect
        iv_hbkid TYPE clike
        iv_esnum TYPE i DEFAULT 1.

    METHODS other_account_never_fits    FOR TESTING.
    METHODS same_account_two_ambiguous  FOR TESTING.
    METHODS leading_zeros_ignored       FOR TESTING.
    METHODS missing_identity_no_fit     FOR TESTING.
    METHODS query_refs_both_forms       FOR TESTING.
ENDCLASS.


CLASS ltc_cheque_link IMPLEMENTATION.

  METHOD setup.
    CLEAR: mt_checks, mt_lines.
  ENDMETHOD.


  METHOD add_check.
    DATA ls_check TYPE zif_cd_ops_trace_types=>ty_check.
    ls_check-ztnum = iv_ztnum.
    ls_check-doc1r = iv_doc.
    ls_check-bukrs = iv_bukrs.
    ls_check-hbkid = iv_hbkid.
    ls_check-hktid = gc_test-account.
    INSERT ls_check INTO TABLE mt_checks.
  ENDMETHOD.


  METHOD add_line.
    DATA ls_line TYPE zif_cd_ops_trace_types=>ty_bank_line.
    ls_line-kukey = '00000101'.
    ls_line-esnum = iv_esnum.
    ls_line-chect = iv_chect.
    ls_line-budat = '20261105'.
    ls_line-bukrs = gc_test-bukrs.
    ls_line-hbkid = iv_hbkid.
    ls_line-hktid = gc_test-account.
    INSERT ls_line INTO TABLE mt_lines.
  ENDMETHOD.


  " Acceptance (design review 3): the same suffix on two house bank accounts - each line fits only
  " the cheque of its own statement account; neither inherits the other's cashing evidence
  METHOD other_account_never_fits.
    TRY.
        add_check( iv_ztnum = gc_test-ztnum_1 iv_doc = gc_test-doc_1 iv_hbkid = gc_test-jpmc ).
        add_check( iv_ztnum = gc_test-ztnum_2 iv_doc = gc_test-doc_2 iv_hbkid = gc_test-boa ).
        add_line( iv_hbkid = gc_test-jpmc ).
        DATA(lt_links) = zcl_cd_ops_cheque_link=>link( it_checks = mt_checks
                                                       it_lines  = mt_lines
                                                       iv_length = gc_test-length ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_links ) exp = 1 msg = 'One link' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-doc1r exp = gc_test-doc_1
                                            msg = 'Line of the JPMC account: the JPMC cheque only' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-candidates exp = 1 msg = 'One eligible cheque' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_links[ 1 ]-docs[ table_line = gc_test-doc_2 ] ) )
                                           msg = 'The BOA cheque never fits' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Acceptance (design review 3): two cheques of the same account with the same suffix - the line
  " is ambiguous, attributed to none, both cheques named
  METHOD same_account_two_ambiguous.
    TRY.
        add_check( iv_ztnum = gc_test-ztnum_1 iv_doc = gc_test-doc_1 iv_hbkid = gc_test-jpmc ).
        add_check( iv_ztnum = gc_test-ztnum_2 iv_doc = gc_test-doc_2 iv_hbkid = gc_test-jpmc ).
        add_line( iv_hbkid = gc_test-jpmc ).
        DATA(lt_links) = zcl_cd_ops_cheque_link=>link( it_checks = mt_checks
                                                       it_lines  = mt_lines
                                                       iv_length = gc_test-length ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-candidates exp = 2 msg = 'Two eligible cheques' ).
        cl_abap_unit_assert=>assert_initial( act = lt_links[ 1 ]-doc1r msg = 'Attributed to none' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_links[ 1 ]-docs ) exp = 2 msg = 'Both named' ).
        cl_abap_unit_assert=>assert_not_initial( act = lt_links[ 1 ]-detail msg = 'Ambiguity text' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: suffix of N characters, compared with and without leading zeros
  METHOD leading_zeros_ignored.
    TRY.
        add_check( iv_ztnum = '0000000000000000450' iv_doc = gc_test-doc_1 iv_hbkid = gc_test-jpmc ).
        add_line( iv_chect = '450' iv_hbkid = gc_test-jpmc ).
        cl_abap_unit_assert=>assert_equals(
          act = lines( zcl_cd_ops_cheque_link=>link( it_checks = mt_checks it_lines = mt_lines iv_length = gc_test-length ) )
          exp = 1 msg = 'Fits without leading zeros' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_cheque_link=>suffix( iv_ztnum = gc_test-ztnum_1 iv_length = 0 )
                                            exp = CONV string( gc_test-ztnum_1 )
                                            msg = 'Length 0: the whole number' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a line or a cheque without the full account identity fits nothing (fail closed)
  METHOD missing_identity_no_fit.
    TRY.
        add_check( iv_ztnum = gc_test-ztnum_1 iv_doc = gc_test-doc_1 iv_hbkid = gc_test-jpmc iv_bukrs = space ).
        add_check( iv_ztnum = gc_test-ztnum_2 iv_doc = gc_test-doc_2 iv_hbkid = gc_test-boa ).
        add_line( iv_hbkid = gc_test-jpmc ).
        add_line( iv_hbkid = space iv_esnum = 2 ).
        cl_abap_unit_assert=>assert_initial(
          act = zcl_cd_ops_cheque_link=>link( it_checks = mt_checks it_lines = mt_lines iv_length = gc_test-length )
          msg = 'No identity, no link' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the statement is read with the suffix as given and without leading zeros
  METHOD query_refs_both_forms.
    TRY.
        add_check( iv_ztnum = '0000000000000000450' iv_doc = gc_test-doc_1 iv_hbkid = gc_test-jpmc ).
        DATA(lt_refs) = zcl_cd_ops_cheque_link=>query_refs( it_checks = mt_checks iv_length = gc_test-length ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_refs ) exp = 2 msg = 'Two forms' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_refs[ table_line = '450' ] ) )
                                          msg = 'Without leading zeros' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_refs[ table_line = '0000000000450' ] ) )
                                          msg = 'Last 13 characters as stored' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
