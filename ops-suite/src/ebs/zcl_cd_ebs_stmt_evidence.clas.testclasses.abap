*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_stmt_evidence.clas.testclasses.abap
*& Purpose:
*& Application tests of the statement evidence with LTD_* FEB and configuration
*& DAOs (ZCL_CD_EBS_INJECTOR) and the delivered parameter definitions: accounts
*& expected and imported per bank and date, a missing account, posted and
*& unposted entries, map disposition NOT_POSTED, blocked entries, another
*& bank's statement, the payment engine account scope and the posting-open
*& definition shared with the EBS engine. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (BAI processing deadline, statement evidence for FMON).
*&---------------------------------------------------------------------*
CLASS ltd_feb_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_feb_dao PARTIALLY IMPLEMENTED.
    DATA mt_headers TYPE zif_cd_ebs_feb_dao=>tt_header.
    DATA mt_items TYPE zif_cd_ebs_feb_dao=>tt_item.
    DATA mv_item_reads TYPE i.
ENDCLASS.


CLASS ltd_feb_dao IMPLEMENTATION.
  METHOD zif_cd_ebs_feb_dao~get_headers.
    rt_headers = VALUE #( FOR ls_header IN mt_headers
                          WHERE ( azdat BETWEEN is_selection-date_from AND is_selection-date_to )
                          ( ls_header ) ).
  ENDMETHOD.

  METHOD zif_cd_ebs_feb_dao~get_items.
    mv_item_reads += 1.
    LOOP AT mt_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      IF line_exists( it_kukey[ table_line = <ls_item>-kukey ] ).
        INSERT <ls_item> INTO TABLE rt_items.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_cfg_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_cfg_dao PARTIALLY IMPLEMENTED.
    DATA mt_accounts TYPE zif_cd_ebs_types=>tt_account_cfg.
    DATA mt_map TYPE zif_cd_ebs_types=>tt_btc_map.
ENDCLASS.


CLASS ltd_cfg_dao IMPLEMENTATION.
  METHOD zif_cd_ebs_cfg_dao~get_accounts.
    rt_accounts = mt_accounts.
  ENDMETHOD.

  METHOD zif_cd_ebs_cfg_dao~get_btc_map.
    rt_map = mt_map.
  ENDMETHOD.

  METHOD zif_cd_ebs_cfg_dao~get_flow_patterns.
    CLEAR rt_patterns.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_evidence DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        bank       TYPE zif_cd_ebs_types=>ty_bank_key VALUE 'JPMC',
        other_bank TYPE zif_cd_ebs_types=>ty_bank_key VALUE 'BOA',
        bukrs      TYPE c LENGTH 4 VALUE '1000',
        hbkid      TYPE c LENGTH 5 VALUE 'JPMC1',
        hktid_1    TYPE c LENGTH 5 VALUE 'ACC01',
        hktid_2    TYPE c LENGTH 5 VALUE 'ACC02',
        boa_hbkid  TYPE c LENGTH 5 VALUE 'BOA01',
        account_1  TYPE zif_cd_ebs_types=>ty_text35 VALUE '8XX1174412',
        account_2  TYPE zif_cd_ebs_types=>ty_text35 VALUE '8XX1174499',
        xblnr_1    TYPE c LENGTH 16 VALUE 'JPMC8XX117441201',
        xblnr_2    TYPE c LENGTH 16 VALUE 'JPMC8XX117449901',
        xblnr_out  TYPE c LENGTH 16 VALUE 'JPMC9ZZ000000001',
        stmt_date  TYPE d VALUE '20261106',
        code_post  TYPE c LENGTH 3 VALUE '165',
        code_info  TYPE c LENGTH 3 VALUE '475',
        category   TYPE zif_cd_ebs_types=>ty_category VALUE 'P01',
        max_rows   TYPE i VALUE 100,
      END OF gc_test.

    TYPES:
      BEGIN OF ty_flags,
        "! Statements imported for account 1 / account 2 (JPMC)
        stmt_1        TYPE abap_bool,
        stmt_2        TYPE abap_bool,
        "! Entry of statement 1 posted
        posted_1      TYPE abap_bool,
        "! Entry of statement 1 carries a code mapped NOT_POSTED / no map row (blocked)
        info_code_1   TYPE abap_bool,
        unmapped_1    TYPE abap_bool,
        "! Entry of statement 1 carries an account outside the payment engine scope
        out_of_scope  TYPE abap_bool,
        "! A BOA statement on the same date
        boa_stmt      TYPE abap_bool,
      END OF ty_flags.

    DATA mo_feb TYPE REF TO ltd_feb_dao.
    DATA mo_cfg TYPE REF TO ltd_cfg_dao.

    METHODS setup.
    METHODS teardown.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS add_account
      IMPORTING
        iv_hbkid   TYPE clike
        iv_hktid   TYPE clike
        iv_account TYPE clike
        iv_bank    TYPE zif_cd_ebs_types=>ty_bank_key.
    METHODS add_statement
      IMPORTING
        iv_kukey TYPE zif_cd_ebs_types=>ty_kukey
        iv_hbkid TYPE clike
        iv_hktid TYPE clike.
    METHODS add_item
      IMPORTING
        iv_kukey  TYPE zif_cd_ebs_types=>ty_kukey
        iv_xblnr  TYPE clike
        iv_code   TYPE clike
        iv_posted TYPE abap_bool.
    METHODS evidence
      RETURNING
        VALUE(rs_evidence) TYPE zif_cd_ebs_stmt_evidence=>ty_evidence
      RAISING
        zcx_ca_ops_error.
    METHODS expected
      IMPORTING
        iv_imported    TYPE i
        iv_statements  TYPE i
        iv_lines       TYPE i
        iv_open        TYPE i
        iv_out         TYPE i DEFAULT 0
      RETURNING
        VALUE(rs_exp)  TYPE zif_cd_ebs_stmt_evidence=>ty_evidence.

    METHODS all_posted_is_complete     FOR TESTING.
    METHODS missing_account_counted    FOR TESTING.
    METHODS nothing_imported_reported  FOR TESTING.
    METHODS unposted_entry_is_open     FOR TESTING.
    METHODS not_posted_code_not_open   FOR TESTING.
    METHODS blocked_entry_is_open      FOR TESTING.
    METHODS other_bank_not_counted     FOR TESTING.
    METHODS mixed_statement_out_scope  FOR TESTING.
    METHODS one_item_read_for_all      FOR TESTING.
    METHODS ebs_open_excludes_blocked  FOR TESTING.
ENDCLASS.


CLASS ltc_evidence IMPLEMENTATION.

  METHOD setup.
    mo_feb = NEW #( ).
    mo_cfg = NEW #( ).
    zcl_cd_ebs_injector=>inject_feb_dao( mo_feb ).
    zcl_cd_ebs_injector=>inject_cfg_dao( mo_cfg ).
    zcl_cd_ops_injector=>inject_params( NEW zcl_cd_ops_param_seed( )->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ebs_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    CLEAR: mo_feb, mo_cfg.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_map TYPE zif_cd_ebs_types=>ty_btc_map.
    add_account( iv_hbkid = gc_test-hbkid iv_hktid = gc_test-hktid_1 iv_account = gc_test-account_1
                 iv_bank = gc_test-bank ).
    add_account( iv_hbkid = gc_test-hbkid iv_hktid = gc_test-hktid_2 iv_account = gc_test-account_2
                 iv_bank = gc_test-bank ).
    add_account( iv_hbkid = gc_test-boa_hbkid iv_hktid = gc_test-hktid_1 iv_account = gc_test-account_1
                 iv_bank = gc_test-other_bank ).
    ls_map-scheme   = zif_cd_ebs_types=>gc_scheme-bai2.
    ls_map-btc_code = gc_test-code_post.
    ls_map-category = gc_test-category.
    ls_map-active   = abap_true.
    INSERT ls_map INTO TABLE mo_cfg->mt_map.
    ls_map-btc_code    = gc_test-code_info.
    ls_map-disposition = zif_cd_ebs_types=>gc_disposition-not_posted.
    INSERT ls_map INTO TABLE mo_cfg->mt_map.

    IF is_flags-stmt_1 = abap_true.
      add_statement( iv_kukey = '00000001' iv_hbkid = gc_test-hbkid iv_hktid = gc_test-hktid_1 ).
      add_item( iv_kukey  = '00000001'
                iv_xblnr  = COND #( WHEN is_flags-out_of_scope = abap_true THEN gc_test-xblnr_out
                                    ELSE gc_test-xblnr_1 )
                iv_code   = COND #( WHEN is_flags-info_code_1 = abap_true THEN gc_test-code_info
                                    WHEN is_flags-unmapped_1 = abap_true THEN '999'
                                    ELSE gc_test-code_post )
                iv_posted = is_flags-posted_1 ).
    ENDIF.
    IF is_flags-stmt_2 = abap_true.
      add_statement( iv_kukey = '00000002' iv_hbkid = gc_test-hbkid iv_hktid = gc_test-hktid_2 ).
      add_item( iv_kukey = '00000002' iv_xblnr = gc_test-xblnr_2 iv_code = gc_test-code_post
                iv_posted = abap_true ).
    ENDIF.
    IF is_flags-boa_stmt = abap_true.
      add_statement( iv_kukey = '00000003' iv_hbkid = gc_test-boa_hbkid iv_hktid = gc_test-hktid_1 ).
      add_item( iv_kukey = '00000003' iv_xblnr = gc_test-xblnr_1 iv_code = gc_test-code_post
                iv_posted = abap_false ).
    ENDIF.
  ENDMETHOD.


  METHOD add_account.
    DATA ls_account TYPE zif_cd_ebs_types=>ty_account_cfg.
    ls_account-bukrs      = gc_test-bukrs.
    ls_account-hbkid      = iv_hbkid.
    ls_account-hktid      = iv_hktid.
    ls_account-account_no = iv_account.
    ls_account-bank_key   = iv_bank.
    ls_account-flow_default = zif_cd_ebs_types=>gc_flow-collection.
    ls_account-active     = abap_true.
    INSERT ls_account INTO TABLE mo_cfg->mt_accounts.
  ENDMETHOD.


  METHOD add_statement.
    DATA ls_header TYPE zif_cd_ebs_feb_dao=>ty_header.
    ls_header-kukey = iv_kukey.
    ls_header-bukrs = gc_test-bukrs.
    ls_header-hbkid = iv_hbkid.
    ls_header-hktid = iv_hktid.
    ls_header-aznum = '00001'.
    ls_header-azdat = gc_test-stmt_date.
    INSERT ls_header INTO TABLE mo_feb->mt_headers.
  ENDMETHOD.


  METHOD add_item.
    DATA ls_item TYPE zif_cd_ebs_feb_dao=>ty_item.
    ls_item-kukey  = iv_kukey.
    ls_item-esnum  = 1.
    ls_item-vorgc  = iv_code.
    ls_item-kwbtr  = 100.
    ls_item-xblnr  = iv_xblnr.
    ls_item-budat  = gc_test-stmt_date.
    ls_item-posted = iv_posted.
    INSERT ls_item INTO TABLE mo_feb->mt_items.
  ENDMETHOD.


  METHOD evidence.
    DATA ls_request TYPE zif_cd_ebs_stmt_evidence=>ty_request.
    INSERT gc_test-bank INTO TABLE ls_request-bank_keys.
    INSERT gc_test-stmt_date INTO TABLE ls_request-stmt_dates.
    ls_request-max_rows = gc_test-max_rows.
    DATA(lt_evidence) = zcl_cd_ebs_factory=>get_stmt_evidence( )->read( ls_request ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_evidence ) exp = 1
                                        msg = 'One row per requested bank and statement date' ).
    rs_evidence = lt_evidence[ 1 ].
  ENDMETHOD.


  METHOD expected.
    rs_exp-bank_key          = gc_test-bank.
    rs_exp-stmt_date         = gc_test-stmt_date.
    rs_exp-accounts_expected = 2.
    rs_exp-accounts_imported = iv_imported.
    rs_exp-statements        = iv_statements.
    rs_exp-out_of_scope      = iv_out.
    rs_exp-lines_total       = iv_lines.
    rs_exp-lines_open        = iv_open.
    rs_exp-posting_known     = abap_true.
  ENDMETHOD.


  " Rule: both payment engine accounts imported, every entry posted - nothing open
  METHOD all_posted_is_complete.
    TRY.
        configure_scenario( VALUE #( stmt_1 = abap_true stmt_2 = abap_true posted_1 = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = evidence( )
                                            exp = expected( iv_imported = 2 iv_statements = 2 iv_lines = 2
                                                            iv_open = 0 )
                                            msg = 'Two of two accounts imported, two entries, none open' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an account without a statement of the date is counted as expected, not imported
  METHOD missing_account_counted.
    TRY.
        configure_scenario( VALUE #( stmt_1 = abap_true posted_1 = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = evidence( )
                                            exp = expected( iv_imported = 1 iv_statements = 1 iv_lines = 1
                                                            iv_open = 0 )
                                            msg = 'One of two accounts imported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a bank and date without any statement is still reported (accounts expected, none imported)
  METHOD nothing_imported_reported.
    TRY.
        configure_scenario( VALUE #( ) ).
        cl_abap_unit_assert=>assert_equals( act = evidence( )
                                            exp = expected( iv_imported = 0 iv_statements = 0 iv_lines = 0
                                                            iv_open = 0 )
                                            msg = 'Nothing imported: zero of two accounts' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an entry expected to post whose posting-area flags are not complete is open
  METHOD unposted_entry_is_open.
    TRY.
        configure_scenario( VALUE #( stmt_1 = abap_true stmt_2 = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = evidence( )
                                            exp = expected( iv_imported = 2 iv_statements = 2 iv_lines = 2
                                                            iv_open = 1 )
                                            msg = 'One of two entries not posted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an entry whose code is mapped NOT_POSTED is never expected to post - not open
  METHOD not_posted_code_not_open.
    TRY.
        configure_scenario( VALUE #( stmt_1 = abap_true stmt_2 = abap_true info_code_1 = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = evidence( )
                                            exp = expected( iv_imported = 2 iv_statements = 2 iv_lines = 2
                                                            iv_open = 0 )
                                            msg = 'Disposition NOT_POSTED: unposted entry is not open' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a blocked (unmapped) unposted entry keeps the statement unprocessed for file monitoring
  METHOD blocked_entry_is_open.
    TRY.
        configure_scenario( VALUE #( stmt_1 = abap_true stmt_2 = abap_true unmapped_1 = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = evidence( )
                                            exp = expected( iv_imported = 2 iv_statements = 2 iv_lines = 2
                                                            iv_open = 1 )
                                            msg = 'Blocked and unposted: counted as not posted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a statement of another bank's account does not count for the requested bank
  METHOD other_bank_not_counted.
    TRY.
        configure_scenario( VALUE #( stmt_1 = abap_true stmt_2 = abap_true posted_1 = abap_true
                                     boa_stmt = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = evidence( )
                                            exp = expected( iv_imported = 2 iv_statements = 2 iv_lines = 2
                                                            iv_open = 0 )
                                            msg = 'The BOA statement and its open entry are not JPMC evidence' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: same scope as EBS - a statement with an entry outside the payment engine accounts
  " is imported (the account counts) but its entries do not
  METHOD mixed_statement_out_scope.
    TRY.
        configure_scenario( VALUE #( stmt_1 = abap_true stmt_2 = abap_true out_of_scope = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = evidence( )
                                            exp = expected( iv_imported = 2 iv_statements = 2 iv_lines = 1
                                                            iv_open = 0 iv_out = 1 )
                                            msg = 'Out-of-scope statement imported, its entry not counted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: one FEBEP read for every statement of the request (no read per account)
  METHOD one_item_read_for_all.
    TRY.
        configure_scenario( VALUE #( stmt_1 = abap_true stmt_2 = abap_true posted_1 = abap_true ) ).
        evidence( ).
        cl_abap_unit_assert=>assert_equals( act = mo_feb->mv_item_reads exp = 1
                                            msg = 'Entries of all statements in one read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the EBS definition (POSTING_INCOMPLETE) leaves a blocked entry out
  METHOD ebs_open_excludes_blocked.
    DATA ls_line TYPE zif_cd_ebs_types=>ty_line.
    ls_line-posting_state = zif_cd_ebs_types=>gc_posting_state-open.
    ls_line-blocked       = abap_true.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ebs_stmt_evidence=>is_posting_open( ls_line )
                                        exp = abap_false
                                        msg = 'EBS: a blocked entry is reported as blocked, not as open' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ebs_stmt_evidence=>is_posting_open(
                                                is_line          = ls_line
                                                iv_count_blocked = abap_true )
                                        exp = abap_true
                                        msg = 'File monitoring: a blocked unposted entry is open' ).
  ENDMETHOD.

ENDCLASS.
