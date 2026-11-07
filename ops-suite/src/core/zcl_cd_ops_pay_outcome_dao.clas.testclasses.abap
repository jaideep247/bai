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
                                   ( 'DFKKCR' ) ( 'ZCD_PAY_OUTCOME' ) ( 'ZCD_PAY_OUTWM' ) ) ).
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
  " versions are read by FIN; FIN items by payment document
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
        DATA(lt_open) = mo_cut->get_open_versions( VALUE #( ( gc-fin ) ) ).
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
        mo_cut->save_watermark( ls_watermark ).
        DATA(lt_watermarks) = mo_cut->get_watermarks( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_watermarks ) exp = 1 msg = 'One row per source' ).
        cl_abap_unit_assert=>assert_equals( act = lt_watermarks[ 1 ]-wm_time exp = gc-late msg = 'Latest watermark kept' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
