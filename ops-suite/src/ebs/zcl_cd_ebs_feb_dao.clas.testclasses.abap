*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_feb_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the FEBKO repository: the prior statement is the latest one
*& before the given date (or same date, lower number); duplicate detection.
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Audit A14: recent items of an account (R22 history).
*&---------------------------------------------------------------------*
CLASS ltc_feb_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ebs_feb_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS add_statement
      IMPORTING
        iv_kukey TYPE zif_cd_ebs_types=>ty_kukey
        iv_aznum TYPE zif_cd_ebs_feb_dao=>ty_header-aznum
        iv_azdat TYPE d.

    METHODS prior_is_latest_before_date  FOR TESTING.
    METHODS same_day_lower_number_prior  FOR TESTING.
    METHODS imported_statement_exists    FOR TESTING.
    METHODS recent_items_of_account      FOR TESTING.
ENDCLASS.


CLASS ltc_feb_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'FEBKO' ) ( 'FEBEP' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    add_statement( iv_kukey = '00000001' iv_aznum = '00040' iv_azdat = '20261103' ).
    add_statement( iv_kukey = '00000002' iv_aznum = '00041' iv_azdat = '20261104' ).
    add_statement( iv_kukey = '00000003' iv_aznum = '00042' iv_azdat = '20261105' ).
    mo_cut = NEW zcl_cd_ebs_feb_dao( ).
  ENDMETHOD.


  METHOD add_statement.
    DATA lt_febko TYPE STANDARD TABLE OF febko WITH EMPTY KEY.
    DATA ls_febko TYPE febko.
    ls_febko-kukey = iv_kukey.
    ls_febko-bukrs = 'US01'.
    ls_febko-hbkid = 'JPMC1'.
    ls_febko-hktid = 'DISB1'.
    ls_febko-aznum = iv_aznum.
    ls_febko-azdat = iv_azdat.
    INSERT ls_febko INTO TABLE lt_febko.
    go_env->insert_test_data( lt_febko ).
  ENDMETHOD.


  " The prior statement is the latest one dated before the statement date
  METHOD prior_is_latest_before_date.
    TRY.
        DATA(ls_prior) = mo_cut->get_prior_header( iv_bukrs = 'US01' iv_hbkid = 'JPMC1' iv_hktid = 'DISB1'
                                                   iv_before = '20261105' iv_aznum = '00042' ).
        cl_abap_unit_assert=>assert_equals( act = ls_prior-aznum exp = '00041'
                                            msg = 'Prior must be statement 41 of 4 Nov' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Two statements on one day: the lower number is the prior one
  METHOD same_day_lower_number_prior.
    TRY.
        add_statement( iv_kukey = '00000004' iv_aznum = '00043' iv_azdat = '20261105' ).
        DATA(ls_prior) = mo_cut->get_prior_header( iv_bukrs = 'US01' iv_hbkid = 'JPMC1' iv_hktid = 'DISB1'
                                                   iv_before = '20261105' iv_aznum = '00043' ).
        cl_abap_unit_assert=>assert_equals( act = ls_prior-aznum exp = '00042'
                                            msg = 'Same-day prior must be statement 42' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " An imported statement (account, number, date) is reported as existing
  METHOD imported_statement_exists.
    TRY.
        cl_abap_unit_assert=>assert_true(
          act = mo_cut->statement_exists( iv_bukrs = 'US01' iv_hbkid = 'JPMC1' iv_hktid = 'DISB1'
                                          iv_aznum = '00042' iv_azdat = '20261105' )
          msg = 'Statement 42 of 5 Nov must exist' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A14: items of the account's statements within the window - older statements excluded
  METHOD recent_items_of_account.
    DATA lt_febep TYPE STANDARD TABLE OF febep WITH EMPTY KEY.
    DATA ls_febep TYPE febep.
    TRY.
        ls_febep-kukey = '00000001'.
        ls_febep-esnum = 1.
        ls_febep-chect = '12345'.
        INSERT ls_febep INTO TABLE lt_febep.
        ls_febep-kukey = '00000002'.
        INSERT ls_febep INTO TABLE lt_febep.
        ls_febep-kukey = '00000003'.
        INSERT ls_febep INTO TABLE lt_febep.
        go_env->insert_test_data( lt_febep ).
        DATA(lt_items) = mo_cut->get_recent_items( iv_bukrs = 'US01' iv_hbkid = 'JPMC1' iv_hktid = 'DISB1'
                                                   iv_from  = '20261104' iv_to = '20261105' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 2
                                            msg = 'Only the statements of 04 and 05 Nov are in the window' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_items[ kukey = '00000001' ] ) )
                                           msg = 'The 03 Nov statement is outside the window' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
