*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_feb_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the FEBKO repository: the prior statement is the latest one
*& before the given date (or same date, lower number); duplicate detection.
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Audit A14: recent items of an account (R22 history).
*& 2026-11-06 | Performance fix 2: recent items carry the statement date FEBKO-AZDAT.
*& 2026-11-06 | Performance fix 3: one item read with reason field and posting flags (tests moved from the SAP DAO).
*& 2026-11-06 | Return reason correction: FEBEP carries no return reason - reason-field tests removed.
*& 2026-11-07 | FEBEP-VB1OK / VB2OK confirmed as the posted flags (user, 2026-11-07).
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
    METHODS items_with_posting_flags     FOR TESTING.
    METHODS posting_unknown_field_raises FOR TESTING.
    METHODS posting_empty_keys_nothing   FOR TESTING.
    METHODS headers_in_date_range        FOR TESTING.
    METHODS headers_by_company_and_key   FOR TESTING.
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
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_items[ kukey = '00000002' ]-azdat OPTIONAL )
                                            exp = CONV d( '20261104' )
                                            msg = 'Each item must carry its statement date (R22 window in ABAP)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Fix 3: one FEBEP read returns the items with their posting state (posted only when every
  " flag is X). FEBEP-VB1OK / VB2OK confirmed 2026-11-07
  METHOD items_with_posting_flags.
    DATA lt_febep TYPE STANDARD TABLE OF febep WITH EMPTY KEY.
    DATA ls_febep TYPE febep.
    DATA ls_extras TYPE zif_cd_ebs_feb_dao=>ty_item_extras.
    TRY.
        ls_febep-kukey = '00000002'.
        ls_febep-esnum = 1.
        ls_febep-vgint = 'R01'.
        ls_febep-vb1ok = abap_true.
        ls_febep-vb2ok = abap_true.
        INSERT ls_febep INTO TABLE lt_febep.
        ls_febep-esnum = 2.
        ls_febep-vgint = 'R02'.
        ls_febep-vb2ok = abap_false.
        INSERT ls_febep INTO TABLE lt_febep.
        go_env->insert_test_data( lt_febep ).
        INSERT `VB1OK` INTO TABLE ls_extras-posted_fields.
        INSERT `VB2OK` INTO TABLE ls_extras-posted_fields.
        DATA(lt_items) = mo_cut->get_items( it_kukey  = VALUE #( ( '00000002' ) )
                                            is_extras = ls_extras ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 2 msg = 'Both items of the statement' ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-vgint exp = 'R01'
                                            msg = 'The item fields must be read' ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-posted exp = abap_true
                                            msg = 'Both posting areas complete: posted' ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 2 ]-posted exp = abap_false
                                            msg = 'One posting area open: not posted' ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 2 ]-chect exp = ls_febep-chect
                                            msg = 'The item fields are read in the same pass' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Operating model 2026-11-06: a posting-area flag name that is not a FEBEP field is a
  " configuration error (message 051) - never a silent 'every entry not posted'
  METHOD posting_unknown_field_raises.
    DATA ls_extras TYPE zif_cd_ebs_feb_dao=>ty_item_extras.
    INSERT `ZZ_NOT_A_FEBEP_FIELD` INTO TABLE ls_extras-posted_fields.
    TRY.
        mo_cut->get_items( it_kukey = VALUE #( ( '00001001' ) ) is_extras = ls_extras ).
        cl_abap_unit_assert=>fail( msg = 'An unknown FEBEP field must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '051'
                                            msg = 'Message 051 (invalid configuration value) expected' ).
    ENDTRY.
  ENDMETHOD.


  " FOR ALL ENTRIES guard: no statement key, no read
  METHOD posting_empty_keys_nothing.
    DATA ls_extras TYPE zif_cd_ebs_feb_dao=>ty_item_extras.
    INSERT `VB1OK` INTO TABLE ls_extras-posted_fields.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_items( it_kukey  = VALUE #( )
                                                                       is_extras = ls_extras )
                                             msg = 'Empty key list must return nothing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

  " Headers of the selected date range only, in statement order
  METHOD headers_in_date_range.
    TRY.
        DATA(lt_headers) = mo_cut->get_headers( VALUE #( date_from = '20261104' date_to = '20261105' ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_headers ) exp = 2
                                            msg = 'Statements of 4 and 5 Nov only' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_headers[ 1 ]-aznum OPTIONAL ) exp = '00041'
                                            msg = 'Ordered by statement date and number' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_headers[ 2 ]-aznum OPTIONAL ) exp = '00042'
                                            msg = 'The later statement comes second' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Company code and statement key ranges restrict the read; another company code is never read
  METHOD headers_by_company_and_key.
    DATA lt_febko TYPE STANDARD TABLE OF febko WITH EMPTY KEY.
    TRY.
        lt_febko = VALUE #( ( kukey = '00000009' bukrs = 'CA01' hbkid = 'JPMC1' hktid = 'DISB1'
                              aznum = '00001' azdat = '20261105' ) ).
        go_env->insert_test_data( lt_febko ).
        DATA(lt_headers) = mo_cut->get_headers( VALUE #( bukrs     = VALUE #( ( sign = 'I' option = 'EQ' low = 'US01' ) )
                                                         kukey     = VALUE #( ( sign = 'I' option = 'EQ' low = '00000003' ) )
                                                         date_from = '20261101'
                                                         date_to   = '20261130' ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_headers ) exp = 1 msg = 'Only the selected statement' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_headers[ 1 ]-kukey OPTIONAL ) exp = '00000003'
                                            msg = 'Statement key range applied' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
