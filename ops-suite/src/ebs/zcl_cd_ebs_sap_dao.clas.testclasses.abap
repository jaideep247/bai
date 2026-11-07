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
*& 2026-11-06 | Return / NOC reason correction: RLGRD with the returns lot item; NOC items by INFOF (DFKKNRP double).
*& 2026-11-06 | ltc_sap_dao_reads: cheques, FI lines, lookup rows, retrieval field check (coverage gap closure).
*& 2026-11-07 | Parameters from the shared fake ZCL_CD_OPS_PARAMS_MEM (ZCL_CD_OPS_INJECTOR=>INJECT_PARAMS)
*&            | instead of a hand-written store double: the semantics of ZCL_CD_OPS_STORE.
*&---------------------------------------------------------------------*
CLASS ltc_sap_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        payment TYPE zif_cd_ebs_sap_dao=>ty_docno VALUE '000000012345',
        lot_doc TYPE zif_cd_ebs_sap_dao=>ty_docno VALUE '000000099999',
        noc_lot TYPE c LENGTH 12 VALUE 'NOC000000001',
        rlgrd   TYPE zif_cd_ebs_sap_dao=>ty_lot_reason VALUE 'R01',
        flgrd   TYPE zif_cd_ebs_sap_dao=>ty_lot_reason VALUE 'C01',
        other_ref TYPE zif_cd_ebs_sap_dao=>ty_infof VALUE 'OTHER-REF',
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
    METHODS noc_item_found_by_infof      FOR TESTING.
    METHODS noc_empty_keys_read_nothing  FOR TESTING.
ENDCLASS.


CLASS ltc_sap_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'DFKKRP' ) ( 'DFKKRK' ) ( 'DFKKNRP' ) ( 'DPAYH' ) ( 'ACDOCA' )
                                  ( 'ZCD_OPS_PARAM' ) ) ).
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
    DATA lt_nrp TYPE STANDARD TABLE OF dfkknrp WITH EMPTY KEY.
    DATA ls_nrp TYPE dfkknrp.

    go_env->clear_doubles( ).
    ls_rp-opbel = gc_test-lot_doc.
    ls_rp-selw1 = gc_test-payment.
    ls_rp-rlgrd = gc_test-rlgrd.
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
    " NOC lot: one item carries the payment document, one an unrelated reference
    ls_nrp-keyn1 = gc_test-noc_lot.
    ls_nrp-posna = 1.
    ls_nrp-infof = gc_test-payment.
    ls_nrp-flgrd = gc_test-flgrd.
    INSERT ls_nrp INTO TABLE lt_nrp.
    ls_nrp-posna = 2.
    ls_nrp-infof = gc_test-other_ref.
    INSERT ls_nrp INTO TABLE lt_nrp.
    go_env->insert_test_data( lt_nrp ).
    mo_cut = NEW zcl_cd_ebs_sap_dao( ).
  ENDMETHOD.


  " Confirmed path DFKKRP-SELW1 = payment document; lot status via DFKKRP-OPBEL
  METHOD return_item_found_by_selw1.
    TRY.
        DATA(lt_items) = mo_cut->get_return_items( VALUE #( ( gc_test-payment ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 1 msg = 'One returns item expected' ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-lot_stars exp = '5'
                                            msg = 'Lot status must come from DFKKRK of the item OPBEL' ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-rlgrd exp = gc_test-rlgrd
                                            msg = 'The return reason must come from DFKKRP-RLGRD' ).
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

  " Return / NOC reason correction 2026-11-06: NOC lot items are found by INFOF (payment
  " document or payment reference) with their NOC reason FLGRD; other items are not returned
  METHOD noc_item_found_by_infof.
    TRY.
        DATA(lt_items) = mo_cut->get_noc_items( VALUE #( ( CONV #( gc_test-payment ) ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 1 msg = 'One NOC item expected' ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-flgrd exp = gc_test-flgrd
                                            msg = 'The NOC reason must come from DFKKNRP-FLGRD' ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-keyn1 exp = gc_test-noc_lot
                                            msg = 'The NOC lot key must be returned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " FOR ALL ENTRIES guard: an empty INFOF list must not read the whole NOC item table
  METHOD noc_empty_keys_read_nothing.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_noc_items( VALUE #( ) )
                                             msg = 'Empty INFOF list must return nothing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! OSQL tests of the cheque, FI line and lookup reads (DFKKCR, BSEG and ZCD_OPS_PARAM doubled;
"! ZCD_OPS_PARAM also serves as the configured lookup table). get_retrievals is tested up to
"! its DDIC field check, which raises before the SELECT on ZCD_ACH_RTRV_LOG
"! (osql-not-reached: ZCD_ACH_RTRV_LOG).
CLASS ltc_sap_dao_reads DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        cheque      TYPE zif_cd_ebs_sap_dao=>ty_ztnum VALUE '0000100001',
        other_chq   TYPE zif_cd_ebs_sap_dao=>ty_ztnum VALUE '0000100002',
        doc1r       TYPE zif_cd_ebs_sap_dao=>ty_docno VALUE '000000012345',
        hbkid       TYPE c LENGTH 5 VALUE 'BOA01',
        bukrs       TYPE c LENGTH 4 VALUE 'US01',
        belnr       TYPE c LENGTH 10 VALUE '0100000001',
        gjahr       TYPE n LENGTH 4 VALUE '2026',
        hkont       TYPE c LENGTH 10 VALUE '0011000100',
        param       TYPE c LENGTH 30 VALUE 'EBS_LOOKUP_UNIT_TEST',
        param_text  TYPE c LENGTH 60 VALUE 'OPEN',
        lookup_tab  TYPE c LENGTH 30 VALUE 'ZCD_OPS_PARAM',
        lookup_key  TYPE c LENGTH 30 VALUE 'PARAM_NAME',
        lookup_stat TYPE c LENGTH 30 VALUE 'DESCRIPTION',
        bad_field   TYPE c LENGTH 30 VALUE 'NO_SUCH_FIELD',
        msgno_field TYPE symsgno VALUE '051',
      END OF gc_test.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ebs_sap_dao.
    DATA mo_params TYPE REF TO zcl_cd_ops_params_mem.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.

    METHODS cheque_found_by_number FOR TESTING.
    METHODS unknown_bukrs_field_ignored FOR TESTING.
    METHODS retrieval_bad_field_raises FOR TESTING.
    METHODS cheques_empty_keys_nothing FOR TESTING.
    METHODS fi_lines_by_document_key FOR TESTING.
    METHODS lookup_rows_key_and_status FOR TESTING.
    METHODS lookup_unknown_field_raises FOR TESTING.
    METHODS lookup_empty_keys_nothing FOR TESTING.
ENDCLASS.


CLASS ltc_sap_dao_reads IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'DFKKCR' ) ( 'BSEG' ) ( 'ZCD_OPS_PARAM' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_params = NEW #( ).
    zcl_cd_ops_injector=>inject_params( mo_params ).
    mo_cut = NEW zcl_cd_ebs_sap_dao( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  " Rule (A07): a configured company-code field that DFKKCR does not have is ignored, not selected
  METHOD unknown_bukrs_field_ignored.
    DATA lt_cr TYPE STANDARD TABLE OF dfkkcr WITH EMPTY KEY.
    DATA ls_cr TYPE dfkkcr.
    DATA lt_keys TYPE zif_cd_ebs_sap_dao=>tt_ztnum.
    TRY.
        mo_params->set( iv_name = zif_cd_ebs_types=>gc_param-dfkkcr_bukrs_field iv_value = gc_test-bad_field ).
        ls_cr-ztnum = gc_test-cheque.
        INSERT ls_cr INTO TABLE lt_cr.
        go_env->insert_test_data( lt_cr ).
        INSERT gc_test-cheque INTO TABLE lt_keys.
        DATA(lt_checks) = mo_cut->get_checks( lt_keys ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_checks ) exp = 1 msg = 'Cheque still read' ).
        cl_abap_unit_assert=>assert_initial( act = lt_checks[ 1 ]-bukrs msg = 'Unknown field not selected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a retrieval status field the table does not have fails closed (051) before any SQL
  METHOD retrieval_bad_field_raises.
    DATA lt_docno TYPE zif_cd_ebs_sap_dao=>tt_docno.
    mo_params->set( iv_name = zif_cd_ebs_types=>gc_param-rtrv_status_field iv_value = gc_test-bad_field ).
    INSERT gc_test-doc1r INTO TABLE lt_docno.
    TRY.
        mo_cut->get_retrievals( lt_docno ).
        cl_abap_unit_assert=>fail( msg = 'Unknown status field must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno
                                            exp = gc_test-msgno_field
                                            msg = 'Unknown field is message 051' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: cheques are read by ZTNUM (= FEBEP-CHECT) with house bank and DOC1R
  METHOD cheque_found_by_number.
    DATA lt_cr TYPE STANDARD TABLE OF dfkkcr WITH EMPTY KEY.
    DATA ls_cr TYPE dfkkcr.
    DATA lt_keys TYPE zif_cd_ebs_sap_dao=>tt_ztnum.
    TRY.
        ls_cr-ztnum = gc_test-cheque.
        ls_cr-hbkid = gc_test-hbkid.
        ls_cr-doc1r = gc_test-doc1r.
        INSERT ls_cr INTO TABLE lt_cr.
        ls_cr-ztnum = gc_test-other_chq.
        INSERT ls_cr INTO TABLE lt_cr.
        go_env->insert_test_data( lt_cr ).
        INSERT gc_test-cheque INTO TABLE lt_keys.
        DATA(lt_checks) = mo_cut->get_checks( lt_keys ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_checks ) exp = 1 msg = 'Only the asked cheque' ).
        cl_abap_unit_assert=>assert_equals( act = lt_checks[ 1 ]-doc1r exp = gc_test-doc1r
                                            msg = 'Payment document DOC1R returned' ).
        cl_abap_unit_assert=>assert_equals( act = lt_checks[ 1 ]-hbkid exp = gc_test-hbkid
                                            msg = 'House bank returned' ).
        cl_abap_unit_assert=>assert_initial( act = lt_checks[ 1 ]-bukrs
                                             msg = 'No company-code field configured: blank' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Boundary: no cheque number - nothing read (FOR ALL ENTRIES guard)
  METHOD cheques_empty_keys_nothing.
    DATA lt_cr TYPE STANDARD TABLE OF dfkkcr WITH EMPTY KEY.
    DATA ls_cr TYPE dfkkcr.
    TRY.
        ls_cr-ztnum = gc_test-cheque.
        INSERT ls_cr INTO TABLE lt_cr.
        go_env->insert_test_data( lt_cr ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_checks( VALUE #( ) )
                                             msg = 'Empty key list reads nothing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: FI lines by document key only (BUKRS / BELNR / GJAHR), with G/L account and clearing
  METHOD fi_lines_by_document_key.
    DATA lt_bseg TYPE STANDARD TABLE OF bseg WITH EMPTY KEY.
    DATA ls_bseg TYPE bseg.
    DATA lt_keys TYPE zif_cd_ebs_sap_dao=>tt_fi_key.
    DATA ls_key TYPE zif_cd_ebs_sap_dao=>ty_fi_key.
    TRY.
        ls_bseg-bukrs = gc_test-bukrs.
        ls_bseg-belnr = gc_test-belnr.
        ls_bseg-gjahr = gc_test-gjahr.
        ls_bseg-buzei = 1.
        ls_bseg-hkont = gc_test-hkont.
        ls_bseg-augbl = gc_test-doc1r.
        INSERT ls_bseg INTO TABLE lt_bseg.
        ls_bseg-buzei = 2.
        INSERT ls_bseg INTO TABLE lt_bseg.
        ls_bseg-gjahr = gc_test-gjahr - 1.
        INSERT ls_bseg INTO TABLE lt_bseg.
        go_env->insert_test_data( lt_bseg ).
        ls_key-bukrs = gc_test-bukrs.
        ls_key-belnr = gc_test-belnr.
        ls_key-gjahr = gc_test-gjahr.
        INSERT ls_key INTO TABLE lt_keys.
        DATA(lt_lines) = mo_cut->get_fi_lines( lt_keys ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 2
                                            msg = 'Both lines of the document, not the other year' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-hkont exp = gc_test-hkont msg = 'G/L account' ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_fi_lines( VALUE #( ) )
                                             msg = 'Empty key list reads nothing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (R21): configured table, key and status field are DDIC-checked, rows read by key
  METHOD lookup_rows_key_and_status.
    DATA lt_param TYPE STANDARD TABLE OF zcd_ops_param WITH EMPTY KEY.
    DATA ls_param TYPE zcd_ops_param.
    DATA ls_lookup TYPE zif_cd_ebs_types=>ty_lookup_cfg.
    DATA lt_keys TYPE zif_cd_ebs_sap_dao=>tt_lookup_key.
    TRY.
        ls_param-param_name = gc_test-param.
        ls_param-description = gc_test-param_text.
        INSERT ls_param INTO TABLE lt_param.
        go_env->insert_test_data( lt_param ).
        ls_lookup-table_name   = gc_test-lookup_tab.
        ls_lookup-key_field    = gc_test-lookup_key.
        ls_lookup-status_field = gc_test-lookup_stat.
        INSERT CONV #( gc_test-param ) INTO TABLE lt_keys.
        DATA(lt_rows) = mo_cut->get_lookup_rows( is_lookup = ls_lookup it_keys = lt_keys ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One row for the key' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-status exp = gc_test-param_text
                                            msg = 'Status field returned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an unknown key field fails closed (051) before any SQL
  METHOD lookup_unknown_field_raises.
    DATA ls_lookup TYPE zif_cd_ebs_types=>ty_lookup_cfg.
    DATA lt_keys TYPE zif_cd_ebs_sap_dao=>tt_lookup_key.
    ls_lookup-table_name = gc_test-lookup_tab.
    ls_lookup-key_field  = gc_test-bad_field.
    INSERT CONV #( gc_test-param ) INTO TABLE lt_keys.
    TRY.
        mo_cut->get_lookup_rows( is_lookup = ls_lookup it_keys = lt_keys ).
        cl_abap_unit_assert=>fail( msg = 'Unknown key field must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno
                                            exp = gc_test-msgno_field
                                            msg = 'Unknown field is message 051' ).
    ENDTRY.
  ENDMETHOD.


  " Boundary: no key - nothing read, no exception even for a broken configuration
  METHOD lookup_empty_keys_nothing.
    DATA ls_lookup TYPE zif_cd_ebs_types=>ty_lookup_cfg.
    TRY.
        ls_lookup-table_name = gc_test-lookup_tab.
        ls_lookup-key_field  = gc_test-bad_field.
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_lookup_rows( is_lookup = ls_lookup
                                                                            it_keys   = VALUE #( ) )
                                             msg = 'Empty key list reads nothing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
