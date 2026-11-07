*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_trace_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the payment trace read repository (standard-table key
*& reads): open items by FIN number and row cap, bank lines by reference
*& and posting date, cheques by payment document, monitored files by
*& reference within the business-date window, G/L documents by AWTYP /
*& AWKEY / company code, clearing lines by document key and XREF2, and the
*& FOR ALL ENTRIES guard. Reads delegated to the FMON reader and the EBS
*& repository are tested there. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (360 degree payment trace).
*& 2026-11-06 | Return / NOC reasons: NOC lot items by INFOF through the shared EBS read, capped.
*& 2026-11-06 | ltc_trace_dao_reads: partners, clearing items, headers, file events, method kind (gap closure).
*& 2026-11-07 | Cheque by payment document carries the encashment date BANCD (check A_INFLIGHT).
*&---------------------------------------------------------------------*
CLASS ltc_trace_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        fin       TYPE zif_cd_ops_trace_types=>ty_fin VALUE 'FIN0001',
        other_fin TYPE zif_cd_ops_trace_types=>ty_fin VALUE 'FIN0002',
        item      TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000100001',
        payment   TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000200001',
        other_doc TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000200002',
        ztnum     TYPE zif_cd_ops_trace_types=>ty_ref VALUE '0000123456',
        bukrs     TYPE zif_cd_ops_trace_types=>ty_bukrs VALUE 'US01',
        fikey     TYPE c LENGTH 12 VALUE 'FK20261102',
        awtyp     TYPE zif_cd_ops_trace_types=>ty_key_value VALUE 'FKKSU',
        other_typ TYPE c LENGTH 5 VALUE 'BKPF',
        belnr     TYPE c LENGTH 10 VALUE '0100000001',
        gjahr     TYPE n LENGTH 4 VALUE '2026',
        file_ref  TYPE zif_cd_ops_trace_types=>ty_file_ref VALUE 'ACH_PNC_20261102_001',
        from      TYPE d VALUE '20261028',
        to        TYPE d VALUE '20261107',
      END OF gc_test.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ops_trace_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS insert_items.
    METHODS insert_bank_and_cheques.
    METHODS insert_files_and_gl.

    METHODS items_found_by_fin_number   FOR TESTING.
    METHODS items_stop_at_row_cap       FOR TESTING.
    METHODS bank_lines_by_ref_and_date  FOR TESTING.
    METHODS cheque_by_payment_document  FOR TESTING.
    METHODS fmon_file_in_date_window    FOR TESTING.
    METHODS gl_document_by_awtyp_awkey  FOR TESTING.
    METHODS gl_line_by_key_and_xref2    FOR TESTING.
    METHODS empty_keys_read_nothing     FOR TESTING.
    METHODS noc_items_by_infof_capped   FOR TESTING.
ENDCLASS.


CLASS ltc_trace_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'DFKKOP' ) ( 'FEBEP' ) ( 'DFKKCR' ) ( 'ZCD_FMON_FILE' )
                                   ( 'DFKKSUMC' ) ( 'BKPF' ) ( 'BSEG' ) ( 'DFKKNRP' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    insert_items( ).
    insert_bank_and_cheques( ).
    insert_files_and_gl( ).
    mo_cut = NEW zcl_cd_ops_trace_dao( ).
  ENDMETHOD.


  METHOD insert_items.
    DATA lt_op TYPE STANDARD TABLE OF dfkkop WITH EMPTY KEY.
    DATA ls_op TYPE dfkkop.
    ls_op-opbel            = gc_test-item.
    ls_op-opupk            = '0001'.
    ls_op-bukrs            = gc_test-bukrs.
    ls_op-augbl            = gc_test-payment.
    ls_op-zz_fin_trans_num = gc_test-fin.
    INSERT ls_op INTO TABLE lt_op.
    ls_op-opupk = '0002'.
    INSERT ls_op INTO TABLE lt_op.
    ls_op-opbel            = '000000100002'.
    ls_op-opupk            = '0001'.
    ls_op-zz_fin_trans_num = gc_test-other_fin.
    INSERT ls_op INTO TABLE lt_op.
    go_env->insert_test_data( lt_op ).
  ENDMETHOD.


  METHOD insert_bank_and_cheques.
    DATA lt_febep TYPE STANDARD TABLE OF febep WITH EMPTY KEY.
    DATA ls_febep TYPE febep.
    DATA lt_cr TYPE STANDARD TABLE OF dfkkcr WITH EMPTY KEY.
    DATA ls_cr TYPE dfkkcr.
    " In the window, by reference
    ls_febep-kukey = '00000101'.
    ls_febep-esnum = '00001'.
    ls_febep-chect = gc_test-payment.
    ls_febep-budat = '20261103'.
    INSERT ls_febep INTO TABLE lt_febep.
    " Same reference, posted before the window (an older attempt)
    ls_febep-kukey = '00000090'.
    ls_febep-budat = '20261001'.
    INSERT ls_febep INTO TABLE lt_febep.
    " Other reference
    ls_febep-kukey = '00000102'.
    ls_febep-chect = gc_test-other_doc.
    ls_febep-budat = '20261103'.
    INSERT ls_febep INTO TABLE lt_febep.
    go_env->insert_test_data( lt_febep ).
    ls_cr-hbkid = 'JPMC1'.
    ls_cr-hktid = 'CHK01'.
    ls_cr-ztnum = gc_test-ztnum.
    ls_cr-doc1r = gc_test-payment.
    ls_cr-bancd = '20261104'.
    INSERT ls_cr INTO TABLE lt_cr.
    go_env->insert_test_data( lt_cr ).
  ENDMETHOD.


  METHOD insert_files_and_gl.
    DATA lt_file TYPE STANDARD TABLE OF zcd_fmon_file WITH EMPTY KEY.
    DATA ls_file TYPE zcd_fmon_file.
    DATA lt_sumc TYPE STANDARD TABLE OF dfkksumc WITH EMPTY KEY.
    DATA ls_sumc TYPE dfkksumc.
    DATA lt_bkpf TYPE STANDARD TABLE OF bkpf WITH EMPTY KEY.
    DATA ls_bkpf TYPE bkpf.
    DATA lt_bseg TYPE STANDARD TABLE OF bseg WITH EMPTY KEY.
    DATA ls_bseg TYPE bseg.
    " Same daily reference: one instance in the window, one a month earlier
    ls_file-file_id       = '00000000000000000000000000000001'.
    ls_file-iface_id      = 'ACH_PNC_DISB_OUT'.
    ls_file-file_ref      = gc_test-file_ref.
    ls_file-business_date = '20261102'.
    INSERT ls_file INTO TABLE lt_file.
    ls_file-file_id       = '00000000000000000000000000000002'.
    ls_file-business_date = '20261002'.
    INSERT ls_file INTO TABLE lt_file.
    go_env->insert_test_data( lt_file ).
    ls_sumc-fikey = gc_test-fikey.
    ls_sumc-bukrs = gc_test-bukrs.
    INSERT ls_sumc INTO TABLE lt_sumc.
    go_env->insert_test_data( lt_sumc ).
    ls_bkpf-bukrs = gc_test-bukrs.
    ls_bkpf-belnr = gc_test-belnr.
    ls_bkpf-gjahr = gc_test-gjahr.
    ls_bkpf-awtyp = gc_test-awtyp.
    ls_bkpf-awkey = gc_test-fikey.
    INSERT ls_bkpf INTO TABLE lt_bkpf.
    ls_bkpf-belnr = '0100000002'.
    ls_bkpf-awtyp = gc_test-other_typ.
    INSERT ls_bkpf INTO TABLE lt_bkpf.
    go_env->insert_test_data( lt_bkpf ).
    ls_bseg-bukrs = gc_test-bukrs.
    ls_bseg-belnr = gc_test-belnr.
    ls_bseg-gjahr = gc_test-gjahr.
    ls_bseg-buzei = '001'.
    ls_bseg-xref2 = gc_test-payment.
    INSERT ls_bseg INTO TABLE lt_bseg.
    ls_bseg-buzei = '002'.
    ls_bseg-xref2 = gc_test-other_doc.
    INSERT ls_bseg INTO TABLE lt_bseg.
    go_env->insert_test_data( lt_bseg ).
  ENDMETHOD.


  " Confirmed path: request FIN number = DFKKOP-ZZ_FIN_TRANS_NUM; other FINs not read
  METHOD items_found_by_fin_number.
    TRY.
        DATA(lt_items) = mo_cut->get_items_by_fin( iv_fin = gc_test-fin iv_max_rows = 50 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 2 msg = 'Both items of the FIN' ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-augbl exp = gc_test-payment
                                            msg = 'Clearing document read with the item' ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-fin exp = gc_test-fin msg = 'FIN number mapped' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Bounded read: never more rows than TRACE_MAX_ROWS
  METHOD items_stop_at_row_cap.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->get_items_by_fin( iv_fin = gc_test-fin iv_max_rows = 1 ) )
                                            exp = 1
                                            msg = 'Row cap applies' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Confirmed path FEBEP-CHECT = clearing reference, posted on or after the window start
  METHOD bank_lines_by_ref_and_date.
    TRY.
        DATA(lt_lines) = mo_cut->get_bank_lines( it_ref      = VALUE #( ( CONV #( gc_test-payment ) ) )
                                                 iv_from     = gc_test-from
                                                 iv_max_rows = 50 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 1 msg = 'One line in the window' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-kukey exp = '00000101' msg = 'The line of this reference' ).
        DATA(lt_all) = mo_cut->get_bank_lines( it_ref      = VALUE #( ( CONV #( gc_test-payment ) ) )
                                               iv_from     = VALUE #( )
                                               iv_max_rows = 50 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_all ) exp = 2
                                            msg = 'Without a start date every line of the reference' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Confirmed path method C: DFKKCR-DOC1R = DFKKOP-AUGBL
  METHOD cheque_by_payment_document.
    TRY.
        DATA(lt_checks) = mo_cut->get_checks_by_doc( VALUE #( ( gc_test-payment ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_checks ) exp = 1 msg = 'One cheque' ).
        cl_abap_unit_assert=>assert_equals( act = lt_checks[ 1 ]-ztnum exp = gc_test-ztnum msg = 'Cheque number' ).
        cl_abap_unit_assert=>assert_equals( act = lt_checks[ 1 ]-hbkid exp = 'JPMC1' msg = 'House bank kept' ).
        cl_abap_unit_assert=>assert_equals( act = lt_checks[ 1 ]-bancd exp = '20261104'
                                            msg = 'Encashment date read (VERIFY-DDIC BANCD)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A daily file name is one instance per business date: only the window's instance
  METHOD fmon_file_in_date_window.
    TRY.
        DATA(lt_files) = mo_cut->get_fmon_files( it_file_ref = VALUE #( ( gc_test-file_ref ) )
                                                 iv_from     = gc_test-from
                                                 iv_to       = gc_test-to ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_files ) exp = 1 msg = 'One instance in the window' ).
        cl_abap_unit_assert=>assert_equals( act = lt_files[ 1 ]-business_date exp = '20261102'
                                            msg = 'The instance of the payment run date' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " G/L transfer: BKPF-AWKEY = FIKEY with the configured AWTYP and company code
  METHOD gl_document_by_awtyp_awkey.
    TRY.
        DATA(lt_keys) = VALUE zif_cd_ops_trace_types=>tt_fikey( ( fikey = gc_test-fikey bukrs = gc_test-bukrs ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->get_summary_keys( lt_keys ) ) exp = 1
                                            msg = 'FIKEY summarised in DFKKSUMC' ).
        DATA(lt_docs) = mo_cut->get_gl_documents( it_fikey = lt_keys iv_awtyp = gc_test-awtyp ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_docs ) exp = 1 msg = 'Other AWTYP not read' ).
        cl_abap_unit_assert=>assert_equals( act = lt_docs[ 1 ]-belnr exp = gc_test-belnr msg = 'G/L document' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " BSEG by document key only; the line whose XREF2 carries the clearing reference
  METHOD gl_line_by_key_and_xref2.
    TRY.
        DATA(lt_lines) = mo_cut->get_gl_clearing_lines(
          it_keys  = VALUE #( ( bukrs = gc_test-bukrs belnr = gc_test-belnr gjahr = gc_test-gjahr ) )
          iv_xref2 = gc_test-payment ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 1 msg = 'Only the XREF2 line' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-buzei exp = '001' msg = 'Line 001' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " FOR ALL ENTRIES guard: an empty key list reads nothing
  METHOD empty_keys_read_nothing.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_bank_lines( it_ref      = VALUE #( )
                                                                           iv_from     = gc_test-from
                                                                           iv_max_rows = 50 )
                                             msg = 'No bank lines without a reference' ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_checks_by_doc( VALUE #( ) )
                                             msg = 'No cheques without a document' ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_fmon_files( it_file_ref = VALUE #( )
                                                                           iv_from     = gc_test-from
                                                                           iv_to       = gc_test-to )
                                             msg = 'No files without a reference' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.



  " Return / NOC reasons 2026-11-06: NOC lot items are found by an exact INFOF value (payment
  " document or reference) with their NOC reason FLGRD; INFOF is no key, so the result is
  " capped at the row cap + 1 (the engine shows ROW_CAP_REACHED)
  METHOD noc_items_by_infof_capped.
    DATA lt_nrp TYPE STANDARD TABLE OF dfkknrp WITH EMPTY KEY.
    DATA ls_nrp TYPE dfkknrp.
    TRY.
        ls_nrp-keyn1 = 'NOC000000001'.
        ls_nrp-infof = gc_test-payment.
        ls_nrp-flgrd = 'C01'.
        DO 3 TIMES.
          ls_nrp-posna = sy-index.
          INSERT ls_nrp INTO TABLE lt_nrp.
        ENDDO.
        ls_nrp-posna = 4.
        ls_nrp-infof = gc_test-other_doc.
        INSERT ls_nrp INTO TABLE lt_nrp.
        go_env->insert_test_data( lt_nrp ).
        DATA(lt_items) = mo_cut->get_noc_items( it_infof    = VALUE #( ( CONV #( gc_test-payment ) ) )
                                                iv_max_rows = 1 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 2
                                            msg = 'At most the row cap + 1 items of the INFOF value' ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-flgrd exp = 'C01'
                                            msg = 'The NOC reason must come from DFKKNRP-FLGRD' ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_noc_items( it_infof = VALUE #( ) iv_max_rows = 50 )
                                             msg = 'No NOC items without an INFOF value' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! OSQL tests of the partner, clearing, header, file-event and payment-method reads (BUT000,
"! DFKKOP, DFKKKO, ZCD_FMON_EVENT, TFK042Z and T001 doubled). The source-specific partner
"! read through the approved FMON reader is tested in ZCL_CD_FMON_DAO.
CLASS ltc_trace_dao_reads DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        bpext     TYPE zif_cd_ops_trace_types=>ty_key_value VALUE 'M0012345',
        partner_1 TYPE c LENGTH 10 VALUE '1000000001',
        partner_2 TYPE c LENGTH 10 VALUE '1000000002',
        other     TYPE c LENGTH 10 VALUE '1000000009',
        augbl     TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000012345',
        opbel_1   TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000000101',
        opbel_2   TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000000102',
        stbel     TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000000201',
        fikey     TYPE c LENGTH 12 VALUE 'FK2026110501',
        file_1    TYPE zif_cd_ops_trace_types=>ty_file_id VALUE '000000000000000000000000000000F1',
        file_2    TYPE zif_cd_ops_trace_types=>ty_file_id VALUE '000000000000000000000000000000F2',
        stage_snt TYPE c LENGTH 20 VALUE 'SENT',
        stage_ack TYPE c LENGTH 20 VALUE 'ACK',
        bukrs     TYPE zif_cd_ops_trace_types=>ty_bukrs VALUE 'US01',
        land1     TYPE c LENGTH 3 VALUE 'US',
        pymet_col TYPE zif_cd_ops_trace_types=>ty_pymet VALUE 'D',
        pymet_dis TYPE zif_cd_ops_trace_types=>ty_pymet VALUE 'C',
        pymet_unk TYPE zif_cd_ops_trace_types=>ty_pymet VALUE 'Z',
      END OF gc_test.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ops_trace_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS partners_by_bpext_capped FOR TESTING.
    METHODS items_by_clearing_document FOR TESTING.
    METHODS headers_by_document FOR TESTING.
    METHODS fmon_events_sorted_by_file FOR TESTING.
    METHODS method_kind_from_tfk042z FOR TESTING.
ENDCLASS.


CLASS ltc_trace_dao_reads IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'BUT000' ) ( 'DFKKOP' ) ( 'DFKKKO' ) ( 'ZCD_FMON_EVENT' )
                                   ( 'TFK042Z' ) ( 'T001' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_cd_ops_trace_dao( ).
  ENDMETHOD.


  " Rule: partners by external number (BPEXT) without source field, ordered and capped
  METHOD partners_by_bpext_capped.
    DATA lt_rows TYPE STANDARD TABLE OF but000 WITH EMPTY KEY.
    DATA ls_row TYPE but000.
    TRY.
        ls_row-partner = gc_test-partner_2.
        ls_row-bpext   = gc_test-bpext.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-partner = gc_test-partner_1.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-partner = gc_test-other.
        CLEAR ls_row-bpext.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_partners) = mo_cut->get_partners( iv_bpext = gc_test-bpext iv_max_rows = 10 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_partners ) exp = 2 msg = 'Both partners of the number' ).
        cl_abap_unit_assert=>assert_equals( act = lt_partners[ 1 ] exp = gc_test-partner_1
                                            msg = 'Ordered by partner' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->get_partners( iv_bpext    = gc_test-bpext
                                                                                iv_max_rows = 1 ) )
                                            exp = 1
                                            msg = 'Capped at the maximum' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: items cleared by the payment document (AUGBL), others not
  METHOD items_by_clearing_document.
    DATA lt_rows TYPE STANDARD TABLE OF dfkkop WITH EMPTY KEY.
    DATA ls_row TYPE dfkkop.
    TRY.
        ls_row-opbel = gc_test-opbel_1.
        ls_row-augbl = gc_test-augbl.
        ls_row-bukrs = gc_test-bukrs.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-opbel = gc_test-opbel_2.
        CLEAR ls_row-augbl.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_items) = mo_cut->get_items_by_clearing( iv_augbl = gc_test-augbl iv_max_rows = 10 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 1 msg = 'Only the cleared item' ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-opbel exp = gc_test-opbel_1
                                            msg = 'Cleared item returned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: headers (FIKEY, reversal) by document key; empty key list reads nothing
  METHOD headers_by_document.
    DATA lt_rows TYPE STANDARD TABLE OF dfkkko WITH EMPTY KEY.
    DATA ls_row TYPE dfkkko.
    DATA lt_docno TYPE zif_cd_ops_trace_types=>tt_docno.
    TRY.
        ls_row-opbel = gc_test-opbel_1.
        ls_row-fikey = gc_test-fikey.
        ls_row-stbel = gc_test-stbel.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-opbel = gc_test-opbel_2.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        INSERT gc_test-opbel_1 INTO TABLE lt_docno.
        DATA(lt_headers) = mo_cut->get_doc_headers( lt_docno ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_headers ) exp = 1 msg = 'Only the asked document' ).
        cl_abap_unit_assert=>assert_equals( act = lt_headers[ 1 ]-fikey exp = gc_test-fikey msg = 'FIKEY returned' ).
        cl_abap_unit_assert=>assert_equals( act = lt_headers[ 1 ]-stbel exp = gc_test-stbel
                                            msg = 'Reversal document returned' ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_doc_headers( VALUE #( ) )
                                             msg = 'Empty key list reads nothing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: events of the asked files, sorted by file and event number
  METHOD fmon_events_sorted_by_file.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_fmon_event WITH EMPTY KEY.
    DATA ls_row TYPE zcd_fmon_event.
    DATA lt_files TYPE zif_cd_ops_trace_types=>tt_file_id.
    TRY.
        ls_row-file_id  = gc_test-file_1.
        ls_row-event_no = 2.
        ls_row-stage    = gc_test-stage_ack.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-event_no = 1.
        ls_row-stage    = gc_test-stage_snt.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-file_id  = gc_test-file_2.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        INSERT gc_test-file_1 INTO TABLE lt_files.
        DATA(lt_events) = mo_cut->get_fmon_events( lt_files ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_events ) exp = 2 msg = 'Events of the asked file' ).
        cl_abap_unit_assert=>assert_equals( act = lt_events[ 1 ]-stage exp = gc_test-stage_snt
                                            msg = 'Sorted by event number' ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_fmon_events( VALUE #( ) )
                                             msg = 'Empty key list reads nothing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (confirmed): TFK042Z-XEINZ of the company code's country separates collections from
  " disbursements; an unknown or blank method is unknown
  METHOD method_kind_from_tfk042z.
    DATA lt_t001 TYPE STANDARD TABLE OF t001 WITH EMPTY KEY.
    DATA ls_t001 TYPE t001.
    DATA lt_z TYPE STANDARD TABLE OF tfk042z WITH EMPTY KEY.
    DATA ls_z TYPE tfk042z.
    TRY.
        ls_t001-bukrs = gc_test-bukrs.
        ls_t001-land1 = gc_test-land1.
        INSERT ls_t001 INTO TABLE lt_t001.
        go_env->insert_test_data( lt_t001 ).
        ls_z-land1 = gc_test-land1.
        ls_z-zlsch = gc_test-pymet_col.
        ls_z-xeinz = abap_true.
        INSERT ls_z INTO TABLE lt_z.
        ls_z-zlsch = gc_test-pymet_dis.
        ls_z-xeinz = abap_false.
        INSERT ls_z INTO TABLE lt_z.
        go_env->insert_test_data( lt_z ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_method_kind( iv_bukrs = gc_test-bukrs
                                                                          iv_pymet = gc_test-pymet_col )
                                            exp = zif_cd_ops_trace_types=>gc_kind-collection
                                            msg = 'XEINZ set: collection' ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_method_kind( iv_bukrs = gc_test-bukrs
                                                                          iv_pymet = gc_test-pymet_dis )
                                            exp = zif_cd_ops_trace_types=>gc_kind-disbursement
                                            msg = 'XEINZ blank: disbursement' ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_method_kind( iv_bukrs = gc_test-bukrs
                                                                          iv_pymet = gc_test-pymet_unk )
                                            exp = zif_cd_ops_trace_types=>gc_kind-unknown
                                            msg = 'Method not configured: unknown' ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_method_kind( iv_bukrs = gc_test-bukrs
                                                                          iv_pymet = space )
                                            exp = zif_cd_ops_trace_types=>gc_kind-unknown
                                            msg = 'No method: unknown' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
