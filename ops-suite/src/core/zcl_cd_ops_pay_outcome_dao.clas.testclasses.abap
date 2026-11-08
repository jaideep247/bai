*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pay_outcome_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the snapshot SQL on cl_osql_test_environment doubles: the
*& change read of each evidence source after its watermark (payment /
*& clearing documents with a FIN item, reversals, statement lines, returns
*& lots, G/L clearing of XREF2, recheck of outcomes not final), package size
*& and the watermark returned, cheques of statement references, FIN items
*& of payment documents, current versions by FIN, versions closed and
*& inserted set-based, watermark round trip. Does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (incremental 5-minute payment outcome snapshot).
*& 2026-11-08 | Scale: payment document without FIN picked up (DPAYH), pending marker rechecked first,
*&            | current versions by payment document, CURRENT_TO round trip, package rows (plan, claim,
*&            | finish, abandon, delete), versions of a run with their method, A_INFLIGHT reads: groups
*&            | count a payment once and keep every payment not final however old, examples per
*&            | partition oldest first, candidate rows by status, AMBIGUOUS-only payments, payment runs
*&            | not yet snapshotted.
*&---------------------------------------------------------------------*
CLASS ltc_pay_outcome_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        day      TYPE d VALUE '20261111',
        early    TYPE t VALUE '090000',
        wm_time  TYPE t VALUE '100000',
        late     TYPE t VALUE '110000',
        doc_old  TYPE c LENGTH 12 VALUE '000000900001',
        doc_new  TYPE c LENGTH 12 VALUE '000000900002',
        doc_nofin TYPE c LENGTH 12 VALUE '000000900003',
        reversal TYPE c LENGTH 12 VALUE '000000990001',
        ret_doc  TYPE c LENGTH 12 VALUE '600000009001',
        fin      TYPE c LENGTH 35 VALUE 'FIN0000009001',
        source   TYPE c LENGTH 10 VALUE 'PCLM',
        bukrs    TYPE c LENGTH 4 VALUE 'US01',
        run      TYPE c LENGTH 6 VALUE 'WIR001',
        kukey    TYPE n LENGTH 8 VALUE '00009001',
        cheque   TYPE c LENGTH 13 VALUE 'CHK0000000005',
        gl_doc   TYPE c LENGTH 10 VALUE '1400000001',
        gjahr    TYPE n LENGTH 4 VALUE '2026',
        from     TYPE p LENGTH 8 DECIMALS 0 VALUE '20261110080000',
        now      TYPE p LENGTH 8 DECIMALS 0 VALUE '20261111120000',
      END OF gc.
    "! A_INFLIGHT aggregate reads: a wire disbursement (method W) in the US, statuses as confirmed
    CONSTANTS:
      BEGIN OF gc_agg,
        old_day    TYPE d VALUE '20260901',
        wire       TYPE c LENGTH 1 VALUE 'W',
        country    TYPE c LENGTH 3 VALUE 'US',
        bank       TYPE c LENGTH 5 VALUE 'JPMC1',
        usd        TYPE c LENGTH 5 VALUE 'USD',
        eur        TYPE c LENGTH 5 VALUE 'EUR',
        issued     TYPE c LENGTH 20 VALUE 'ISSUED',
        confirmed  TYPE c LENGTH 20 VALUE 'CONFIRMED',
        fin2       TYPE c LENGTH 35 VALUE 'FIN0000009002',
        fin3       TYPE c LENGTH 35 VALUE 'FIN0000009003',
        amount     TYPE p LENGTH 12 DECIMALS 2 VALUE '-100.00',
        doc_eur    TYPE c LENGTH 12 VALUE '000000900004',
        doc_final  TYPE c LENGTH 12 VALUE '000000900005',
        lag_limit  TYPE p LENGTH 8 DECIMALS 0 VALUE '20261111090000',
      END OF gc_agg.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ops_pay_outcome_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS documents_after_watermark   FOR TESTING.
    METHODS package_size_sets_more      FOR TESTING.
    METHODS reversal_of_payment_doc     FOR TESTING.
    METHODS statement_lines_after_key   FOR TESTING.
    METHODS returns_by_return_document  FOR TESTING.
    METHODS gl_clearing_of_xref2        FOR TESTING.
    METHODS recheck_only_open_not_final FOR TESTING.
    METHODS cheque_of_statement_ref     FOR TESTING.
    METHODS versions_closed_inserted    FOR TESTING.
    METHODS watermark_round_trip        FOR TESTING.
    METHODS payment_doc_without_fin     FOR TESTING.
    METHODS recheck_pending_first       FOR TESTING.
    METHODS package_rows_life_cycle     FOR TESTING.
    METHODS new_versions_with_method    FOR TESTING.
    METHODS groups_count_payment_once   FOR TESTING.
    METHODS groups_keep_old_in_flight   FOR TESTING.
    METHODS examples_first_n_oldest     FOR TESTING.
    METHODS rows_by_payment_status      FOR TESTING.
    METHODS ambiguous_only_payments     FOR TESTING.
    METHODS unsnapshotted_runs          FOR TESTING.

    "! A DPAYH payment of method W (company code US01 in the US: disbursement) with its country rows
    METHODS given_payment
      IMPORTING
        iv_doc      TYPE clike
        iv_laufd    TYPE d DEFAULT gc-day
        iv_valut    TYPE d DEFAULT gc-day
        iv_currency TYPE clike DEFAULT gc_agg-usd
        iv_status   TYPE clike DEFAULT gc_agg-confirmed.
    METHODS given_country.
    "! The A_INFLIGHT query of the tests: method W, in flight / undetermined / inconsistent however old,
    "! CLEARED from the test day
    METHODS query
      RETURNING
        VALUE(rs_query) TYPE zif_cd_ops_payout_types=>ty_group_query.

    METHODS given_header
      IMPORTING
        iv_opbel TYPE clike
        iv_time  TYPE t
        iv_stbel TYPE clike OPTIONAL.
    METHODS given_item
      IMPORTING
        iv_augbl TYPE clike
        iv_fin   TYPE clike.
    METHODS watermark
      IMPORTING
        iv_source           TYPE zif_cd_ops_payout_types=>ty_source_id
      RETURNING
        VALUE(rs_watermark) TYPE zif_cd_ops_payout_types=>ty_watermark.
    METHODS version
      IMPORTING
        iv_augbl          TYPE clike
        iv_outcome        TYPE zif_cd_ops_payout_types=>ty_outcome
        iv_valid_to       TYPE zif_cd_ops_payout_types=>ty_timestamp DEFAULT zif_cd_ops_payout_types=>gc_valid_to_open
      RETURNING
        VALUE(rs_version) TYPE zif_cd_ops_payout_types=>ty_version.
ENDCLASS.


CLASS ltc_pay_outcome_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'DFKKKO' ) ( 'DFKKOP' ) ( 'FEBEP' ) ( 'DFKKRP' ) ( 'BKPF' ) ( 'BSEG' )
                                   ( 'DFKKCR' ) ( 'ZCD_PAY_OUTCOME' ) ( 'ZCD_PAY_OUTWM' ) ( 'ZCD_PAY_OUTPKG' )
                                   ( 'DPAYH' ) ( 'T001' ) ( 'TFK042Z' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_cd_ops_pay_outcome_dao( ).
  ENDMETHOD.


  METHOD given_header.
    DATA lt_headers TYPE STANDARD TABLE OF dfkkko WITH EMPTY KEY.
    DATA ls_header TYPE dfkkko.
    ls_header-opbel = iv_opbel.
    ls_header-cpudt = gc-day.
    ls_header-cputm = iv_time.
    ls_header-stbel = iv_stbel.
    INSERT ls_header INTO TABLE lt_headers.
    go_env->insert_test_data( lt_headers ).
  ENDMETHOD.


  METHOD given_item.
    DATA lt_items TYPE STANDARD TABLE OF dfkkop WITH EMPTY KEY.
    DATA ls_item TYPE dfkkop.
    ls_item-opbel            = iv_augbl.
    ls_item-bukrs            = gc-bukrs.
    ls_item-augbl            = iv_augbl.
    ls_item-zz_fin_trans_num = iv_fin.
    INSERT ls_item INTO TABLE lt_items.
    go_env->insert_test_data( lt_items ).
  ENDMETHOD.


  METHOD watermark.
    rs_watermark-source  = iv_source.
    rs_watermark-wm_date = gc-day.
    rs_watermark-wm_time = gc-wm_time.
  ENDMETHOD.


  METHOD version.
    rs_version-fin_id     = gc-fin.
    rs_version-source     = gc-source.
    rs_version-bukrs      = gc-bukrs.
    rs_version-augbl      = iv_augbl.
    rs_version-laufd      = gc-day.
    rs_version-laufi      = gc-run.
    rs_version-valid_from = gc-from.
    rs_version-valid_to   = iv_valid_to.
    rs_version-outcome    = iv_outcome.
  ENDMETHOD.


  " Rule: only payment / clearing documents entered after the watermark that clear an item with a
  " FIN are picked up; the watermark moves to the last document read
  METHOD documents_after_watermark.
    TRY.
        given_header( iv_opbel = gc-doc_old iv_time = gc-early ).
        given_header( iv_opbel = gc-doc_new iv_time = gc-late ).
        given_header( iv_opbel = gc-doc_nofin iv_time = gc-late ).
        given_item( iv_augbl = gc-doc_old iv_fin = gc-fin ).
        given_item( iv_augbl = gc-doc_new iv_fin = gc-fin ).
        DATA(ls_changes) = mo_cut->get_changes( iv_source    = zif_cd_ops_payout_types=>gc_source-documents
                                                is_watermark = watermark( zif_cd_ops_payout_types=>gc_source-documents )
                                                iv_max       = 100 ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_changes-docno ) exp = 1 msg = 'Only the new document' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( ls_changes-docno[ table_line = gc-doc_new ] ) )
                                          msg = 'The document entered after the watermark' ).
        cl_abap_unit_assert=>assert_equals( act = ls_changes-watermark-wm_time exp = gc-late msg = 'Watermark advanced' ).
        cl_abap_unit_assert=>assert_equals( act = ls_changes-watermark-wm_key exp = CONV zif_cd_ops_payout_types=>ty_wm_key( gc-doc_new )
                                            msg = 'Watermark key = last document' ).
        cl_abap_unit_assert=>assert_false( act = ls_changes-more msg = 'Nothing more waits' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a full package says more keys wait; the next read starts after the last key
  METHOD package_size_sets_more.
    TRY.
        given_header( iv_opbel = gc-doc_old iv_time = gc-late ).
        given_header( iv_opbel = gc-doc_new iv_time = gc-late ).
        given_item( iv_augbl = gc-doc_old iv_fin = gc-fin ).
        given_item( iv_augbl = gc-doc_new iv_fin = gc-fin ).
        DATA(ls_first) = mo_cut->get_changes( iv_source    = zif_cd_ops_payout_types=>gc_source-documents
                                              is_watermark = watermark( zif_cd_ops_payout_types=>gc_source-documents )
                                              iv_max       = 1 ).
        cl_abap_unit_assert=>assert_true( act = ls_first-more msg = 'Package full: more waits' ).
        DATA(ls_second) = mo_cut->get_changes( iv_source    = zif_cd_ops_payout_types=>gc_source-documents
                                               is_watermark = ls_first-watermark
                                               iv_max       = 1 ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( ls_second-docno[ table_line = gc-doc_new ] ) )
                                          msg = 'Same second: the next document by key' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a payment document reversed after the watermark is picked up (changed clearing)
  METHOD reversal_of_payment_doc.
    TRY.
        given_header( iv_opbel = gc-doc_old iv_time = gc-early iv_stbel = gc-reversal ).
        given_header( iv_opbel = gc-reversal iv_time = gc-late ).
        given_item( iv_augbl = gc-doc_old iv_fin = gc-fin ).
        DATA(ls_changes) = mo_cut->get_changes( iv_source    = zif_cd_ops_payout_types=>gc_source-reversals
                                                is_watermark = watermark( zif_cd_ops_payout_types=>gc_source-reversals )
                                                iv_max       = 100 ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( ls_changes-docno[ table_line = gc-doc_old ] ) )
                                          msg = 'The reversed payment document' ).
        cl_abap_unit_assert=>assert_equals( act = ls_changes-watermark-wm_key
                                            exp = CONV zif_cd_ops_payout_types=>ty_wm_key( gc-reversal )
                                            msg = 'Watermark at the reversal document' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: statement lines after the watermark key (KUKEY / ESNUM) give their references
  METHOD statement_lines_after_key.
    DATA lt_lines TYPE STANDARD TABLE OF febep WITH EMPTY KEY.
    DATA ls_line TYPE febep.
    TRY.
        ls_line-kukey = gc-kukey.
        ls_line-esnum = 1.
        ls_line-budat = gc-day.
        ls_line-chect = gc-doc_old.
        INSERT ls_line INTO TABLE lt_lines.
        ls_line-esnum = 2.
        ls_line-chect = gc-doc_new.
        INSERT ls_line INTO TABLE lt_lines.
        go_env->insert_test_data( lt_lines ).
        DATA(ls_watermark) = watermark( zif_cd_ops_payout_types=>gc_source-statement ).
        ls_watermark-wm_key = gc-kukey.
        ls_watermark-wm_seq = 1.
        DATA(ls_changes) = mo_cut->get_changes( iv_source    = zif_cd_ops_payout_types=>gc_source-statement
                                                is_watermark = ls_watermark
                                                iv_max       = 100 ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_changes-refs ) exp = 1 msg = 'Only the later line' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( ls_changes-refs[ table_line = gc-doc_new ] ) )
                                          msg = 'Reference of the later line' ).
        cl_abap_unit_assert=>assert_equals( act = ls_changes-watermark-wm_seq exp = 2 msg = 'Watermark at line 2' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a returns lot document entered after the watermark gives its payment documents (SELW1)
  METHOD returns_by_return_document.
    DATA lt_returns TYPE STANDARD TABLE OF dfkkrp WITH EMPTY KEY.
    DATA ls_return TYPE dfkkrp.
    TRY.
        given_header( iv_opbel = gc-ret_doc iv_time = gc-late ).
        ls_return-opbel = gc-ret_doc.
        ls_return-selw1 = gc-doc_old.
        INSERT ls_return INTO TABLE lt_returns.
        go_env->insert_test_data( lt_returns ).
        DATA(ls_changes) = mo_cut->get_changes( iv_source    = zif_cd_ops_payout_types=>gc_source-returns
                                                is_watermark = watermark( zif_cd_ops_payout_types=>gc_source-returns )
                                                iv_max       = 100 ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( ls_changes-docno[ table_line = gc-doc_old ] ) )
                                          msg = 'Payment document of the returns lot item' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a G/L clearing document entered after the watermark gives the XREF2 of its cleared lines
  METHOD gl_clearing_of_xref2.
    DATA lt_headers TYPE STANDARD TABLE OF bkpf WITH EMPTY KEY.
    DATA ls_header TYPE bkpf.
    DATA lt_lines TYPE STANDARD TABLE OF bseg WITH EMPTY KEY.
    DATA ls_line TYPE bseg.
    TRY.
        ls_header-bukrs = gc-bukrs.
        ls_header-belnr = gc-gl_doc.
        ls_header-gjahr = gc-gjahr.
        ls_header-cpudt = gc-day.
        ls_header-cputm = gc-late.
        INSERT ls_header INTO TABLE lt_headers.
        go_env->insert_test_data( lt_headers ).
        ls_line-bukrs = gc-bukrs.
        ls_line-belnr = gc-gl_doc.
        ls_line-gjahr = gc-gjahr.
        ls_line-buzei = 1.
        ls_line-augbl = gc-gl_doc.
        ls_line-auggj = gc-gjahr.
        ls_line-xref2 = gc-doc_old.
        INSERT ls_line INTO TABLE lt_lines.
        go_env->insert_test_data( lt_lines ).
        DATA(ls_changes) = mo_cut->get_changes( iv_source    = zif_cd_ops_payout_types=>gc_source-gl
                                                is_watermark = watermark( zif_cd_ops_payout_types=>gc_source-gl )
                                                iv_max       = 100 ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( ls_changes-docno[ table_line = gc-doc_old ] ) )
                                          msg = 'XREF2 of the cleared line' ).
        cl_abap_unit_assert=>assert_equals( act = ls_changes-watermark-wm_key+4(10) exp = gc-gl_doc
                                            msg = 'Watermark at the clearing document' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the recheck reads current versions that are not final (IN_FLIGHT ...), never a closed one
  " or a final outcome; the end of the list resets the cursor
  METHOD recheck_only_open_not_final.
    TRY.
        mo_cut->save_versions( it_close  = VALUE #( )
                               it_insert = VALUE #( ( version( iv_augbl = gc-doc_old
                                                               iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ) )
                                                    ( version( iv_augbl = gc-doc_new
                                                               iv_outcome = zif_cd_ops_payout_types=>gc_outcome-cleared ) )
                                                    ( version( iv_augbl    = gc-doc_nofin
                                                               iv_outcome  = zif_cd_ops_payout_types=>gc_outcome-in_flight
                                                               iv_valid_to = gc-now ) ) ) ).
        DATA(ls_changes) = mo_cut->get_changes( iv_source    = zif_cd_ops_payout_types=>gc_source-recheck
                                                is_watermark = VALUE #( source = zif_cd_ops_payout_types=>gc_source-recheck )
                                                iv_max       = 100 ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_changes-docno ) exp = 1 msg = 'Only the open IN_FLIGHT' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( ls_changes-docno[ table_line = gc-doc_old ] ) )
                                          msg = 'The open payment not final' ).
        cl_abap_unit_assert=>assert_initial( act = ls_changes-watermark-wm_key msg = 'End of list: cursor reset' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a statement reference that is a cheque number gives the cheque's payment document
  METHOD cheque_of_statement_ref.
    DATA lt_cheques TYPE STANDARD TABLE OF dfkkcr WITH EMPTY KEY.
    DATA ls_cheque TYPE dfkkcr.
    TRY.
        ls_cheque-ztnum = gc-cheque.
        ls_cheque-doc1r = gc-doc_old.
        INSERT ls_cheque INTO TABLE lt_cheques.
        go_env->insert_test_data( lt_cheques ).
        DATA(lt_docno) = mo_cut->get_cheque_documents( VALUE #( ( CONV #( gc-cheque ) ) ) ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_docno[ table_line = gc-doc_old ] ) )
                                          msg = 'Payment document of the cheque' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: closing sets VALID_TO of the current version, inserting adds the new one; current
  " versions are read by payment document (2026-11-08); FIN items by payment document
  METHOD versions_closed_inserted.
    TRY.
        given_item( iv_augbl = gc-doc_old iv_fin = gc-fin ).
        DATA(ls_first) = version( iv_augbl = gc-doc_old iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        mo_cut->save_versions( it_close = VALUE #( ) it_insert = VALUE #( ( ls_first ) ) ).
        DATA(ls_closed) = ls_first.
        ls_closed-valid_to = gc-now.
        DATA(ls_second) = version( iv_augbl = gc-doc_old iv_outcome = zif_cd_ops_payout_types=>gc_outcome-cleared ).
        ls_second-valid_from = gc-now.
        mo_cut->save_versions( it_close = VALUE #( ( ls_closed ) ) it_insert = VALUE #( ( ls_second ) ) ).
        DATA(lt_open) = mo_cut->get_open_versions( VALUE #( ( gc-doc_old ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_open ) exp = 1 msg = 'One current version' ).
        cl_abap_unit_assert=>assert_equals( act = lt_open[ 1 ]-outcome exp = zif_cd_ops_payout_types=>gc_outcome-cleared
                                            msg = 'The new outcome is current' ).
        SELECT COUNT(*) FROM zcd_pay_outcome INTO @DATA(lv_versions).
        cl_abap_unit_assert=>assert_equals( act = lv_versions exp = 2 msg = 'History kept' ).
        DATA(lt_items) = mo_cut->get_fin_items( VALUE #( ( gc-doc_old ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 1 msg = 'FIN item of the payment' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD watermark_round_trip.
    TRY.
        DATA(ls_watermark) = watermark( zif_cd_ops_payout_types=>gc_source-documents ).
        ls_watermark-wm_key = gc-doc_new.
        mo_cut->save_watermark( ls_watermark ).
        ls_watermark-wm_time = gc-late.
        ls_watermark-current_to = gc-now.
        mo_cut->save_watermark( ls_watermark ).
        DATA(lt_watermarks) = mo_cut->get_watermarks( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_watermarks ) exp = 1 msg = 'One row per source' ).
        cl_abap_unit_assert=>assert_equals( act = lt_watermarks[ 1 ]-wm_time exp = gc-late msg = 'Latest watermark kept' ).
        cl_abap_unit_assert=>assert_equals( act = lt_watermarks[ 1 ]-current_to exp = CONV timestampl( gc-now )
                                            msg = 'Processed-to instant kept' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD given_payment.
    DATA lt_payments TYPE STANDARD TABLE OF dpayh WITH EMPTY KEY.
    DATA ls_payment TYPE dpayh.
    ls_payment-laufd             = iv_laufd.
    ls_payment-laufi             = gc-run.
    ls_payment-doc1r             = iv_doc.
    ls_payment-bukrs             = gc-bukrs.
    ls_payment-pymet             = gc_agg-wire.
    ls_payment-hbkid             = gc_agg-bank.
    ls_payment-valut             = iv_valut.
    ls_payment-rwbtr             = gc_agg-amount.
    ls_payment-waers             = iv_currency.
    ls_payment-zz_payment_status = iv_status.
    INSERT ls_payment INTO TABLE lt_payments.
    go_env->insert_test_data( lt_payments ).
  ENDMETHOD.


  METHOD given_country.
    DATA lt_t001 TYPE STANDARD TABLE OF t001 WITH EMPTY KEY.
    DATA ls_t001 TYPE t001.
    DATA lt_tfk042z TYPE STANDARD TABLE OF tfk042z WITH EMPTY KEY.
    DATA ls_tfk042z TYPE tfk042z.
    ls_t001-bukrs = gc-bukrs.
    ls_t001-land1 = gc_agg-country.
    INSERT ls_t001 INTO TABLE lt_t001.
    go_env->insert_test_data( lt_t001 ).
    ls_tfk042z-land1 = gc_agg-country.
    ls_tfk042z-zlsch = gc_agg-wire.
    INSERT ls_tfk042z INTO TABLE lt_tfk042z.
    go_env->insert_test_data( lt_tfk042z ).
  ENDMETHOD.


  METHOD query.
    INSERT gc_agg-wire INTO TABLE rs_query-methods.
    rs_query-all_ages = VALUE #( sign   = zif_cd_ops_types=>gc_range-sign_include
                                 option = zif_cd_ops_types=>gc_range-option_equal
                                 ( low = zif_cd_ops_payout_types=>gc_outcome-in_flight )
                                 ( low = zif_cd_ops_payout_types=>gc_outcome-undetermined )
                                 ( low = zif_cd_ops_payout_types=>gc_outcome-inconsistent ) ).
    rs_query-recent = VALUE #( sign   = zif_cd_ops_types=>gc_range-sign_include
                               option = zif_cd_ops_types=>gc_range-option_equal
                               ( low = zif_cd_ops_payout_types=>gc_outcome-cleared ) ).
    rs_query-final_from = gc-day.
    rs_query-lag_limit  = gc_agg-lag_limit.
  ENDMETHOD.


  " Rule (2026-11-08): the payment document of a payment run is picked up also without an item with a
  " FIN (e.g. a collection) - every payment of a watched class gets a version
  METHOD payment_doc_without_fin.
    TRY.
        given_header( iv_opbel = gc-doc_nofin iv_time = gc-late ).
        given_payment( gc-doc_nofin ).
        DATA(ls_changes) = mo_cut->get_changes( iv_source    = zif_cd_ops_payout_types=>gc_source-documents
                                                is_watermark = watermark( zif_cd_ops_payout_types=>gc_source-documents )
                                                iv_max       = 100 ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( ls_changes-docno[ table_line = gc-doc_nofin ] ) )
                                          msg = 'Payment document without FIN picked up' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a version marked PAY_STATUS_PENDING is rechecked in every run, also when the cursor of the
  " recheck has passed it
  METHOD recheck_pending_first.
    TRY.
        DATA(ls_pending) = version( iv_augbl = gc-doc_old iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        ls_pending-finding = zif_cd_ops_payout_types=>gc_code-status_pending.
        mo_cut->save_versions( it_close = VALUE #( ) it_insert = VALUE #( ( ls_pending ) ) ).
        DATA(ls_changes) = mo_cut->get_changes( iv_source    = zif_cd_ops_payout_types=>gc_source-recheck
                                                is_watermark = VALUE #( source = zif_cd_ops_payout_types=>gc_source-recheck
                                                                        wm_key = gc-doc_new )
                                                iv_max       = 100 ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( ls_changes-docno[ table_line = gc-doc_old ] ) )
                                          msg = 'Pending payment rechecked before the cursor' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a planned package is claimed once; finished D keeps its counts; the run abandons what is
  " still planned (an abandoned package cannot be claimed); rows of other runs are deleted
  METHOD package_rows_life_cycle.
    DATA ls_first TYPE zif_cd_ops_payout_types=>ty_package.
    TRY.
        ls_first-run_id = '000000000000000000000000000000B1'.
        ls_first-source = zif_cd_ops_payout_types=>gc_source-documents.
        ls_first-pkg_no = 1.
        INSERT gc-doc_old INTO TABLE ls_first-docno.
        DATA(ls_second) = ls_first.
        ls_second-pkg_no = 2.
        DATA(ls_other) = ls_first.
        ls_other-run_id = '000000000000000000000000000000B2'.
        mo_cut->save_packages( VALUE #( ( ls_first ) ( ls_second ) ( ls_other ) ) ).
        cl_abap_unit_assert=>assert_true( act = mo_cut->claim_package( ls_first ) msg = 'Planned package claimed' ).
        ls_first-status    = zif_cd_ops_payout_types=>gc_pkg_status-done.
        ls_first-evaluated = 1.
        mo_cut->finish_package( ls_first ).
        mo_cut->abandon_packages( ls_first-run_id ).
        cl_abap_unit_assert=>assert_false( act = mo_cut->claim_package( ls_second ) msg = 'Abandoned: not claimed' ).
        mo_cut->delete_packages( ls_first-run_id ).
        DATA(lt_rows) = mo_cut->get_packages( ls_first-run_id ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'Rows of the run kept' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-status exp = zif_cd_ops_payout_types=>gc_pkg_status-done
                                            msg = 'Package 1 done' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-documents exp = 1 msg = 'Documents planned' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-status exp = zif_cd_ops_payout_types=>gc_pkg_status-abandoned
                                            msg = 'Package 2 abandoned' ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_packages( ls_other-run_id ) msg = 'Other run deleted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the versions a run wrote with a finding come with the method and flow indicator of their
  " payment (aggregated findings of parallel packages)
  METHOD new_versions_with_method.
    TRY.
        given_country( ).
        given_payment( gc-doc_old ).
        DATA(ls_ambiguous) = version( iv_augbl = gc-doc_old iv_outcome = zif_cd_ops_payout_types=>gc_outcome-ambiguous ).
        ls_ambiguous-finding = zif_cd_ops_payout_types=>gc_code-source_ambiguous.
        mo_cut->save_versions( it_close = VALUE #( ) it_insert = VALUE #( ( ls_ambiguous ) ) ).
        DATA(lt_new) = mo_cut->get_new_versions( iv_valid_from = gc-from
                                                 iv_finding    = zif_cd_ops_payout_types=>gc_code-source_ambiguous ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_new ) exp = 1 msg = 'The ambiguous version of the run' ).
        cl_abap_unit_assert=>assert_equals( act = lt_new[ 1 ]-pymet exp = gc_agg-wire msg = 'Method of the payment' ).
        cl_abap_unit_assert=>assert_false( act = lt_new[ 1 ]-xeinz msg = 'Disbursement' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the FIN / source rows of one payment count it once, its amount once; currencies apart
  METHOD groups_count_payment_once.
    TRY.
        given_country( ).
        given_payment( gc-doc_old ).
        given_payment( iv_doc = gc_agg-doc_eur iv_currency = gc_agg-eur ).
        DATA(ls_row) = version( iv_augbl = gc-doc_old iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        DATA(ls_row2) = ls_row.
        ls_row2-fin_id = gc_agg-fin2.
        DATA(ls_row3) = ls_row.
        ls_row3-fin_id = gc_agg-fin3.
        DATA(ls_eur) = version( iv_augbl = gc_agg-doc_eur iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        mo_cut->save_versions( it_close = VALUE #( ) it_insert = VALUE #( ( ls_row ) ( ls_row2 ) ( ls_row3 ) ( ls_eur ) ) ).
        DATA(lt_groups) = mo_cut->get_outcome_groups( query( ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_groups ) exp = 2 msg = 'One group per currency' ).
        DATA(ls_usd) = lt_groups[ currency = gc_agg-usd ].
        cl_abap_unit_assert=>assert_equals( act = ls_usd-payments exp = 1 msg = 'Three FIN rows, one payment' ).
        cl_abap_unit_assert=>assert_equals( act = ls_usd-amount exp = abs( gc_agg-amount ) msg = 'Amount once, positive' ).
        cl_abap_unit_assert=>assert_equals( act = ls_usd-due exp = abap_true msg = 'Valid since before the lag limit' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (2026-11-08): a payment not final is counted however old (no look-back window); a final
  " outcome only from FINAL_FROM
  METHOD groups_keep_old_in_flight.
    TRY.
        given_country( ).
        given_payment( iv_doc = gc-doc_old iv_laufd = gc_agg-old_day iv_valut = gc_agg-old_day ).
        given_payment( iv_doc = gc_agg-doc_final iv_laufd = gc_agg-old_day ).
        DATA(ls_old) = version( iv_augbl = gc-doc_old iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        ls_old-laufd = gc_agg-old_day.
        DATA(ls_final) = version( iv_augbl = gc_agg-doc_final iv_outcome = zif_cd_ops_payout_types=>gc_outcome-cleared ).
        ls_final-laufd = gc_agg-old_day.
        mo_cut->save_versions( it_close = VALUE #( ) it_insert = VALUE #( ( ls_old ) ( ls_final ) ) ).
        DATA(lt_groups) = mo_cut->get_outcome_groups( query( ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_groups ) exp = 1 msg = 'Only the old payment in flight' ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-outcome exp = zif_cd_ops_payout_types=>gc_outcome-in_flight
                                            msg = 'In flight since September' ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-valut exp = gc_agg-old_day msg = 'Value date for the age' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the examples are the first N payments of a partition, oldest value date first
  METHOD examples_first_n_oldest.
    TRY.
        given_country( ).
        given_payment( iv_doc = gc-doc_old iv_valut = gc_agg-old_day ).
        given_payment( iv_doc = gc-doc_new ).
        given_payment( iv_doc = gc_agg-doc_eur ).
        mo_cut->save_versions( it_close  = VALUE #( )
                               it_insert = VALUE #( ( version( iv_augbl = gc-doc_old
                                                               iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ) )
                                                    ( version( iv_augbl = gc-doc_new
                                                               iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ) )
                                                    ( version( iv_augbl = gc_agg-doc_eur
                                                               iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ) ) ) ).
        DATA(lt_examples) = mo_cut->get_outcome_examples( is_query = query( ) iv_rows = 2 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_examples ) exp = 2 msg = 'First 2 of the partition' ).
        cl_abap_unit_assert=>assert_equals( act = lt_examples[ 1 ]-doc1r exp = gc-doc_old msg = 'Oldest value date first' ).
        cl_abap_unit_assert=>assert_equals( act = lt_examples[ 2 ]-doc1r exp = gc-doc_new msg = 'Then by document' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: candidate rows filter by the live payment status and come oldest run first
  METHOD rows_by_payment_status.
    TRY.
        given_country( ).
        given_payment( iv_doc = gc-doc_old iv_status = gc_agg-issued ).
        given_payment( iv_doc = gc-doc_new iv_status = gc_agg-confirmed ).
        mo_cut->save_versions( it_close  = VALUE #( )
                               it_insert = VALUE #( ( version( iv_augbl = gc-doc_old
                                                               iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ) )
                                                    ( version( iv_augbl = gc-doc_new
                                                               iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ) ) ) ).
        DATA(ls_query) = query( ).
        ls_query-statuses = VALUE #( ( sign = zif_cd_ops_types=>gc_range-sign_include
                                       option = zif_cd_ops_types=>gc_range-option_equal low = gc_agg-issued ) ).
        DATA(lt_rows) = mo_cut->get_outcome_rows( is_query = ls_query iv_max = 100 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'Only the ISSUED payment' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-doc1r exp = gc-doc_old msg = 'The ISSUED payment' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a payment whose current versions all say AMBIGUOUS is listed for the live evaluation; one
  " with another current version is counted from that one
  METHOD ambiguous_only_payments.
    TRY.
        given_country( ).
        given_payment( gc-doc_old ).
        given_payment( gc-doc_new ).
        DATA(ls_ambiguous) = version( iv_augbl = gc-doc_old iv_outcome = zif_cd_ops_payout_types=>gc_outcome-ambiguous ).
        DATA(ls_mixed) = version( iv_augbl = gc-doc_new iv_outcome = zif_cd_ops_payout_types=>gc_outcome-ambiguous ).
        DATA(ls_known) = version( iv_augbl = gc-doc_new iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        ls_known-fin_id = gc_agg-fin2.
        mo_cut->save_versions( it_close = VALUE #( ) it_insert = VALUE #( ( ls_ambiguous ) ( ls_mixed ) ( ls_known ) ) ).
        DATA(lt_docno) = mo_cut->get_ambiguous_only( is_query = query( ) iv_max = 100 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_docno ) exp = 1 msg = 'Only the AMBIGUOUS-only payment' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_docno[ table_line = gc-doc_old ] ) )
                                          msg = 'The payment without another outcome' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: payment runs since the date without a current version are not yet snapshotted
  METHOD unsnapshotted_runs.
    TRY.
        given_payment( gc-doc_old ).
        given_payment( gc-doc_new ).
        given_payment( iv_doc = gc_agg-doc_eur iv_laufd = gc_agg-old_day ).
        mo_cut->save_versions( it_close  = VALUE #( )
                               it_insert = VALUE #( ( version( iv_augbl = gc-doc_old
                                                               iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ) ) ) ).
        DATA(lt_docno) = mo_cut->get_unsnapshotted( it_methods = VALUE #( ( gc_agg-wire ) )
                                                    iv_from    = gc-day
                                                    iv_max     = 100 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_docno ) exp = 1 msg = 'One payment not snapshotted' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_docno[ table_line = gc-doc_new ] ) )
                                          msg = 'The payment without version, in the window' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
