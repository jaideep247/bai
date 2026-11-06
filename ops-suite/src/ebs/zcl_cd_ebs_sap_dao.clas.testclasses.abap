*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_sap_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the payment engine read repository: returns lot items are found
*& by SELW1 with the lot status of their OPBEL; payments by DOC1R; an empty key
*& list reads nothing. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Operating model: posting-area flag names are DDIC-validated (unknown name raises).
*& 2026-11-06 | Performance fix 3: posting-flag tests moved to ZCL_CD_EBS_FEB_DAO (read joined the item read).
*& 2026-11-06 | Performance fix 6: G/L balances of several statements in one aggregate (ACDOCA double).
*&---------------------------------------------------------------------*
CLASS ltc_sap_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        payment TYPE zif_cd_ebs_sap_dao=>ty_docno VALUE '000000012345',
        lot_doc TYPE zif_cd_ebs_sap_dao=>ty_docno VALUE '000000099999',
      END OF gc_test.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ebs_sap_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS return_item_found_by_selw1   FOR TESTING.
    METHODS empty_keys_read_nothing      FOR TESTING.
    METHODS payment_found_by_doc1r       FOR TESTING.
    METHODS gl_balances_per_request      FOR TESTING.
    METHODS gl_balances_empty_requests   FOR TESTING.
ENDCLASS.


CLASS ltc_sap_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'DFKKRP' ) ( 'DFKKRK' ) ( 'DPAYH' ) ( 'ACDOCA' ) ( 'ZCD_OPS_PARAM' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_rp TYPE STANDARD TABLE OF dfkkrp WITH EMPTY KEY.
    DATA ls_rp TYPE dfkkrp.
    DATA lt_rk TYPE STANDARD TABLE OF dfkkrk WITH EMPTY KEY.
    DATA ls_rk TYPE dfkkrk.
    DATA lt_payh TYPE STANDARD TABLE OF dpayh WITH EMPTY KEY.
    DATA ls_payh TYPE dpayh.

    go_env->clear_doubles( ).
    ls_rp-opbel = gc_test-lot_doc.
    ls_rp-selw1 = gc_test-payment.
    INSERT ls_rp INTO TABLE lt_rp.
    go_env->insert_test_data( lt_rp ).
    ls_rk-opbel = gc_test-lot_doc.
    ls_rk-stars = '5'.
    INSERT ls_rk INTO TABLE lt_rk.
    go_env->insert_test_data( lt_rk ).
    ls_payh-doc1r = gc_test-payment.
    ls_payh-laufd = '20261104'.
    ls_payh-laufi = 'PCLM01'.
    INSERT ls_payh INTO TABLE lt_payh.
    go_env->insert_test_data( lt_payh ).
    mo_cut = NEW zcl_cd_ebs_sap_dao( ).
  ENDMETHOD.


  " Confirmed path DFKKRP-SELW1 = payment document; lot status via DFKKRP-OPBEL
  METHOD return_item_found_by_selw1.
    TRY.
        DATA(lt_items) = mo_cut->get_return_items( VALUE #( ( gc_test-payment ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 1 msg = 'One returns item expected' ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-lot_stars exp = '5'
                                            msg = 'Lot status must come from DFKKRK of the item OPBEL' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " FOR ALL ENTRIES guard: an empty key list must not read the whole table
  METHOD empty_keys_read_nothing.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_return_items( VALUE #( ) )
                                             msg = 'Empty key list must return nothing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Fix 6: one aggregate returns the balance of every request - same SUM as the former
  " per-statement read (ledger 0L, company code, account, currency, posting date up to the
  " request's date); a request without postings returns no row.
  " VERIFY-ADT: internal table as JOIN source (@itab) inside cl_osql_test_environment
  METHOD gl_balances_per_request.
    DATA lt_acdoca TYPE STANDARD TABLE OF acdoca WITH EMPTY KEY.
    DATA ls_acdoca TYPE acdoca.
    DATA lt_requests TYPE zif_cd_ebs_sap_dao=>tt_gl_request.
    DATA ls_request TYPE zif_cd_ebs_sap_dao=>ty_gl_request.
    TRY.
        ls_acdoca-rldnr  = '0L'.
        ls_acdoca-rbukrs = 'US01'.
        ls_acdoca-gjahr  = '2026'.
        ls_acdoca-racct  = '0011001000'.
        ls_acdoca-rtcur  = 'USD'.
        ls_acdoca-belnr  = '0000000001'.
        ls_acdoca-budat  = '20261101'.
        ls_acdoca-tsl    = '100.00'.
        INSERT ls_acdoca INTO TABLE lt_acdoca.
        ls_acdoca-belnr  = '0000000002'.
        ls_acdoca-budat  = '20261104'.
        ls_acdoca-tsl    = '50.00'.
        INSERT ls_acdoca INTO TABLE lt_acdoca.
        " after the first request's date, before the second's
        ls_acdoca-belnr  = '0000000003'.
        ls_acdoca-budat  = '20261106'.
        ls_acdoca-tsl    = '25.00'.
        INSERT ls_acdoca INTO TABLE lt_acdoca.
        " other ledger and other currency never count
        ls_acdoca-belnr  = '0000000004'.
        ls_acdoca-rldnr  = '2L'.
        ls_acdoca-tsl    = '1000.00'.
        INSERT ls_acdoca INTO TABLE lt_acdoca.
        ls_acdoca-belnr  = '0000000005'.
        ls_acdoca-rldnr  = '0L'.
        ls_acdoca-rtcur  = 'EUR'.
        ls_acdoca-tsl    = '7.00'.
        INSERT ls_acdoca INTO TABLE lt_acdoca.
        go_env->insert_test_data( lt_acdoca ).
        ls_request-bukrs      = 'US01'.
        ls_request-gl_account = '0011001000'.
        ls_request-currency   = 'USD'.
        ls_request-request_no = 1.
        ls_request-stmt_date  = '20261105'.
        INSERT ls_request INTO TABLE lt_requests.
        ls_request-request_no = 2.
        ls_request-stmt_date  = '20261110'.
        INSERT ls_request INTO TABLE lt_requests.
        ls_request-request_no = 3.
        ls_request-gl_account = '0011009999'.
        INSERT ls_request INTO TABLE lt_requests.
        DATA(lt_balances) = mo_cut->get_gl_balances( lt_requests ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_balances[ request_no = 1 ]-balance OPTIONAL )
                                            exp = CONV zif_cd_ops_types=>ty_amount( '150.00' )
                                            msg = 'Postings up to 05 Nov: 100 + 50' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_balances[ request_no = 2 ]-balance OPTIONAL )
                                            exp = CONV zif_cd_ops_types=>ty_amount( '175.00' )
                                            msg = 'Postings up to 10 Nov: 100 + 50 + 25' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_balances[ request_no = 3 ] ) )
                                           msg = 'An account without postings has no row (balance 0)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Fix 6: no request, no read
  METHOD gl_balances_empty_requests.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_gl_balances( VALUE #( ) )
                                             msg = 'Empty request list must return nothing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Payment run entry is found by DOC1R
  METHOD payment_found_by_doc1r.
    TRY.
        DATA(lt_payments) = mo_cut->get_payments( VALUE #( ( gc_test-payment ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_payments ) exp = 1 msg = 'One payment expected' ).
        cl_abap_unit_assert=>assert_equals( act = lt_payments[ 1 ]-laufi exp = 'PCLM01'
                                            msg = 'Payment run id must be returned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
