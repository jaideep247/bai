*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_pe_scope.clas.testclasses.abap
*& Purpose:
*& Domain tests of the payment engine account scope: account derived from
*& FEBEP-XBLNR (bank text JPMC / BOA / PNC removed, lower case, no bank text,
*& shorter than 10 characters, blank) and the statement scope of a package
*& (all lines payment engine accounts -> kept; mixed, unparseable, inactive
*& account or no line -> removed and counted; bank file statements kept).
*& No doubles. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (payment engine account scope, user decision).
*&---------------------------------------------------------------------*
CLASS ltc_pe_account DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        account   TYPE zif_cd_ebs_types=>ty_pe_account VALUE '8XX1174412',
        jpmc      TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'JPMC8XX1174412334',
        boa       TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'BOA8XX117441201',
        pnc       TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'PNC8XX11744129',
        lower     TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'jpmc8xx1174412334',
        no_prefix TYPE zif_cd_ebs_types=>ty_xblnr VALUE '8XX1174412334',
        short     TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'PNC12345',
        short_acc TYPE zif_cd_ebs_types=>ty_pe_account VALUE '12345',
        blank_gap TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'BOA 8XX1174412',
        only_text TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'JPMC',
      END OF gc_test.

    METHODS jpmc_prefix_removed          FOR TESTING.
    METHODS boa_prefix_removed           FOR TESTING.
    METHODS pnc_prefix_removed           FOR TESTING.
    METHODS lower_case_upper_account     FOR TESTING.
    METHODS no_prefix_first_10           FOR TESTING.
    METHODS shorter_than_10_kept         FOR TESTING.
    METHODS blank_after_text_condensed   FOR TESTING.
    METHODS blank_xblnr_no_account       FOR TESTING.
    METHODS bank_text_only_no_account    FOR TESTING.
ENDCLASS.


CLASS ltc_pe_account IMPLEMENTATION.

  " The example of the user decision: JPMC + 8XX1174412 + counter 334
  METHOD jpmc_prefix_removed.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ebs_pe_scope=>pe_account_from_xblnr( gc_test-jpmc )
                                        exp = gc_test-account
                                        msg = 'JPMC text removed, first 10 characters are the account' ).
  ENDMETHOD.


  METHOD boa_prefix_removed.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ebs_pe_scope=>pe_account_from_xblnr( gc_test-boa )
                                        exp = gc_test-account
                                        msg = 'BOA text removed, counter after the account ignored' ).
  ENDMETHOD.


  METHOD pnc_prefix_removed.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ebs_pe_scope=>pe_account_from_xblnr( gc_test-pnc )
                                        exp = gc_test-account
                                        msg = 'PNC text removed, one-digit counter ignored' ).
  ENDMETHOD.


  " Letters of the bank text in any case; the account itself is compared in upper case
  METHOD lower_case_upper_account.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ebs_pe_scope=>pe_account_from_xblnr( gc_test-lower )
                                        exp = gc_test-account
                                        msg = 'Lower-case bank text removed, account in upper case' ).
  ENDMETHOD.


  METHOD no_prefix_first_10.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ebs_pe_scope=>pe_account_from_xblnr( gc_test-no_prefix )
                                        exp = gc_test-account
                                        msg = 'Without bank text the first 10 characters are the account' ).
  ENDMETHOD.


  " Fewer than 10 characters after the bank text: taken as they are (they match no configured
  " 10-character account)
  METHOD shorter_than_10_kept.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ebs_pe_scope=>pe_account_from_xblnr( gc_test-short )
                                        exp = gc_test-short_acc
                                        msg = 'A short rest is taken as it is' ).
  ENDMETHOD.


  METHOD blank_after_text_condensed.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ebs_pe_scope=>pe_account_from_xblnr( gc_test-blank_gap )
                                        exp = gc_test-account
                                        msg = 'A blank between bank text and account is removed (condense)' ).
  ENDMETHOD.


  METHOD blank_xblnr_no_account.
    cl_abap_unit_assert=>assert_initial( act = zcl_cd_ebs_pe_scope=>pe_account_from_xblnr( space )
                                         msg = 'A blank XBLNR carries no payment engine account' ).
  ENDMETHOD.


  METHOD bank_text_only_no_account.
    cl_abap_unit_assert=>assert_initial( act = zcl_cd_ebs_pe_scope=>pe_account_from_xblnr( gc_test-only_text )
                                         msg = 'Bank text without account gives no account' ).
  ENDMETHOD.

ENDCLASS.


"! Statement scope of a package: only statements whose every line is a payment engine account
CLASS ltc_scope DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        xblnr_pe       TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'JPMC8XX1174412334',
        xblnr_pe_2     TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'JPMC8XX1174412335',
        xblnr_other    TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'JPMC9999999999001',
        xblnr_inactive TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'PNC7000000001001',
        account        TYPE zif_cd_ebs_types=>ty_text35 VALUE '8XX1174412',
        account_lower  TYPE zif_cd_ebs_types=>ty_text35 VALUE ' 8xx1174412',
        inactive       TYPE zif_cd_ebs_types=>ty_text35 VALUE '7000000001',
        stmt_in        TYPE zif_cd_ebs_types=>ty_stmt_key VALUE 'FEB00000001',
        stmt_mixed     TYPE zif_cd_ebs_types=>ty_stmt_key VALUE 'FEB00000002',
        stmt_empty     TYPE zif_cd_ebs_types=>ty_stmt_key VALUE 'FEB00000003',
        stmt_blank     TYPE zif_cd_ebs_types=>ty_stmt_key VALUE 'FEB00000004',
        stmt_inactive  TYPE zif_cd_ebs_types=>ty_stmt_key VALUE 'FEB00000005',
        stmt_file      TYPE zif_cd_ebs_types=>ty_stmt_key VALUE 'S0001',
      END OF gc_test.

    DATA ms_package TYPE zif_cd_ebs_types=>ty_package.

    METHODS setup.
    METHODS scope
      IMPORTING
        iv_account      TYPE zif_cd_ebs_types=>ty_text35 DEFAULT gc_test-account
      RETURNING
        VALUE(ro_scope) TYPE REF TO zcl_cd_ebs_pe_scope.
    METHODS add_statement
      IMPORTING
        iv_stmt_key TYPE zif_cd_ebs_types=>ty_stmt_key
        iv_source   TYPE zif_cd_ebs_types=>ty_source DEFAULT zif_cd_ebs_types=>gc_source-feb.
    METHODS add_line
      IMPORTING
        iv_stmt_key TYPE zif_cd_ebs_types=>ty_stmt_key
        iv_xblnr    TYPE zif_cd_ebs_types=>ty_xblnr.
    METHODS has_statement
      IMPORTING
        iv_stmt_key   TYPE zif_cd_ebs_types=>ty_stmt_key
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

    METHODS all_pe_lines_kept            FOR TESTING.
    METHODS mixed_statement_removed      FOR TESTING.
    METHODS blank_xblnr_removed          FOR TESTING.
    METHODS inactive_account_removed     FOR TESTING.
    METHODS statement_without_lines_out  FOR TESTING.
    METHODS file_statement_kept          FOR TESTING.
    METHODS config_condensed_upper       FOR TESTING.
    METHODS lines_of_removed_stmt_gone   FOR TESTING.
ENDCLASS.


CLASS ltc_scope IMPLEMENTATION.

  METHOD setup.
    CLEAR ms_package.
  ENDMETHOD.


  " One active payment engine account and one inactive one (ZCD_EBS_ACCT)
  METHOD scope.
    DATA lt_accounts TYPE zif_cd_ebs_types=>tt_account_cfg.
    DATA ls_account TYPE zif_cd_ebs_types=>ty_account_cfg.
    ls_account-bukrs      = 'US01'.
    ls_account-hbkid      = 'JPMC1'.
    ls_account-hktid      = 'DISB1'.
    ls_account-account_no = iv_account.
    ls_account-active     = abap_true.
    INSERT ls_account INTO TABLE lt_accounts.
    CLEAR ls_account.
    ls_account-bukrs      = 'US01'.
    ls_account-hbkid      = 'PNC01'.
    ls_account-hktid      = 'COLL1'.
    ls_account-account_no = gc_test-inactive.
    ls_account-active     = abap_false.
    INSERT ls_account INTO TABLE lt_accounts.
    ro_scope = NEW #( lt_accounts ).
  ENDMETHOD.


  METHOD add_statement.
    DATA ls_stmt TYPE zif_cd_ebs_types=>ty_statement.
    ls_stmt-stmt_key = iv_stmt_key.
    ls_stmt-source   = iv_source.
    INSERT ls_stmt INTO TABLE ms_package-statements.
  ENDMETHOD.


  METHOD add_line.
    DATA ls_line TYPE zif_cd_ebs_types=>ty_line.
    ls_line-stmt_key = iv_stmt_key.
    ls_line-line_no  = lines( ms_package-lines ) + 1.
    ls_line-xblnr    = iv_xblnr.
    INSERT ls_line INTO TABLE ms_package-lines.
  ENDMETHOD.


  METHOD has_statement.
    rv_yes = xsdbool( line_exists( ms_package-statements[ stmt_key = iv_stmt_key ] ) ).
  ENDMETHOD.


  " Every line carries an active payment engine account (counters may differ): validated
  METHOD all_pe_lines_kept.
    TRY.
        add_statement( gc_test-stmt_in ).
        add_line( iv_stmt_key = gc_test-stmt_in iv_xblnr = gc_test-xblnr_pe ).
        add_line( iv_stmt_key = gc_test-stmt_in iv_xblnr = gc_test-xblnr_pe_2 ).

        DATA(lv_out) = scope( )->remove_out_of_scope( CHANGING cs_package = ms_package ).

        cl_abap_unit_assert=>assert_equals( act = lv_out exp = 0 msg = 'Nothing is out of scope' ).
        cl_abap_unit_assert=>assert_true( act = has_statement( gc_test-stmt_in ) msg = 'The statement stays' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ms_package-lines ) exp = 2 msg = 'Both lines stay' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " One line of another account: the whole statement is skipped and counted
  METHOD mixed_statement_removed.
    TRY.
        add_statement( gc_test-stmt_in ).
        add_line( iv_stmt_key = gc_test-stmt_in iv_xblnr = gc_test-xblnr_pe ).
        add_statement( gc_test-stmt_mixed ).
        add_line( iv_stmt_key = gc_test-stmt_mixed iv_xblnr = gc_test-xblnr_pe ).
        add_line( iv_stmt_key = gc_test-stmt_mixed iv_xblnr = gc_test-xblnr_other ).

        DATA(lv_out) = scope( )->remove_out_of_scope( CHANGING cs_package = ms_package ).

        cl_abap_unit_assert=>assert_equals( act = lv_out exp = 1 msg = 'The mixed statement is out of scope' ).
        cl_abap_unit_assert=>assert_false( act = has_statement( gc_test-stmt_mixed ) msg = 'Mixed statement removed' ).
        cl_abap_unit_assert=>assert_true( act = has_statement( gc_test-stmt_in ) msg = 'In-scope statement kept' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD blank_xblnr_removed.
    TRY.
        add_statement( gc_test-stmt_blank ).
        add_line( iv_stmt_key = gc_test-stmt_blank iv_xblnr = gc_test-xblnr_pe ).
        add_line( iv_stmt_key = gc_test-stmt_blank iv_xblnr = space ).

        DATA(lv_out) = scope( )->remove_out_of_scope( CHANGING cs_package = ms_package ).

        cl_abap_unit_assert=>assert_equals( act = lv_out exp = 1
                                            msg = 'A line without XBLNR takes its statement out of scope' ).
        cl_abap_unit_assert=>assert_initial( act = ms_package-statements msg = 'No statement left' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD inactive_account_removed.
    TRY.
        add_statement( gc_test-stmt_inactive ).
        add_line( iv_stmt_key = gc_test-stmt_inactive iv_xblnr = gc_test-xblnr_inactive ).

        DATA(lv_out) = scope( )->remove_out_of_scope( CHANGING cs_package = ms_package ).

        cl_abap_unit_assert=>assert_equals( act = lv_out exp = 1
                                            msg = 'An inactive configured account is not a payment engine account' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Documented decision: a statement without lines has no payment engine account - out of scope
  METHOD statement_without_lines_out.
    TRY.
        add_statement( gc_test-stmt_empty ).

        DATA(lv_out) = scope( )->remove_out_of_scope( CHANGING cs_package = ms_package ).

        cl_abap_unit_assert=>assert_equals( act = lv_out exp = 1 msg = 'A statement without lines is out of scope' ).
        cl_abap_unit_assert=>assert_initial( act = ms_package-statements msg = 'It is not validated' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Bank file before import: no XBLNR (set during import) - scoped by the account configuration
  METHOD file_statement_kept.
    TRY.
        add_statement( iv_stmt_key = gc_test-stmt_file iv_source = zif_cd_ebs_types=>gc_source-file ).
        add_line( iv_stmt_key = gc_test-stmt_file iv_xblnr = space ).

        DATA(lv_out) = scope( )->remove_out_of_scope( CHANGING cs_package = ms_package ).

        cl_abap_unit_assert=>assert_equals( act = lv_out exp = 0 msg = 'File statements are not scoped by XBLNR' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ms_package-lines ) exp = 1 msg = 'File line kept' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " ACCOUNT_NO is compared condensed and in upper case
  METHOD config_condensed_upper.
    TRY.
        add_statement( gc_test-stmt_in ).
        add_line( iv_stmt_key = gc_test-stmt_in iv_xblnr = gc_test-xblnr_pe ).

        DATA(lv_out) = scope( gc_test-account_lower )->remove_out_of_scope( CHANGING cs_package = ms_package ).

        cl_abap_unit_assert=>assert_equals( act = lv_out exp = 0
                                            msg = 'A configured account with blank / lower case still matches' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD lines_of_removed_stmt_gone.
    TRY.
        add_statement( gc_test-stmt_in ).
        add_line( iv_stmt_key = gc_test-stmt_in iv_xblnr = gc_test-xblnr_pe ).
        add_statement( gc_test-stmt_mixed ).
        add_line( iv_stmt_key = gc_test-stmt_mixed iv_xblnr = gc_test-xblnr_pe ).
        add_line( iv_stmt_key = gc_test-stmt_mixed iv_xblnr = gc_test-xblnr_other ).

        scope( )->remove_out_of_scope( CHANGING cs_package = ms_package ).

        cl_abap_unit_assert=>assert_equals( act = lines( ms_package-lines ) exp = 1
                                            msg = 'Only the line of the in-scope statement is validated' ).
        cl_abap_unit_assert=>assert_equals( act = ms_package-lines[ 1 ]-stmt_key exp = gc_test-stmt_in
                                            msg = 'The remaining line belongs to the in-scope statement' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
