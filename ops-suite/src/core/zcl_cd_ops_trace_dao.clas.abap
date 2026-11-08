*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_trace_dao.clas.abap
*& Purpose:
*& SQL of the 360 degree payment trace. Standard tables are read only along
*& the confirmed join paths (DFKKOP-ZZ_FIN_TRANS_NUM / AUGBL, DFKKCR-DOC1R,
*& FEBEP-CHECT, DFKKKO-FIKEY = DFKKSUMC-FIKEY = BKPF-AWKEY, BSEG by document
*& key). Reads that already exist are reused, not copied: DPAYH, DFKKCR by
*& cheque number, DFKKRP returns and the ACH retrieval log through the EBS
*& read repository; custom sources whose field names are not confirmed
*& (request log, clearing-reset history, ZCDT_REGUT, ACK and cheque
*& history, BUT000 source field) through the file monitoring reader, which
*& validates names against the DDIC, ZCD_OPS_TABWL (FMON / SOURCE) and S_TABU_NAM and
*& binds values. No dynamic SQL of its own. Every read is keyed and capped.
*& Read-only: no INSERT / UPDATE / DELETE. Unconfirmed fields: VERIFY-SE11.
*& Modification log:
*& 2026-11-06 | Initial version (360 degree payment trace).
*& 2026-11-06 | Reuse of the FMON reader and the EBS reads; FMON files by business date.
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Return / NOC reasons: RLGRD with the returns (shared EBS read); NOC items through the
*&            | shared EBS read DFKKNRP by INFOF, capped like the cheque read.
*& 2026-11-07 | get_checks_by_doc also reads the encashment date BANCD (in-flight check A_INFLIGHT).
*& 2026-11-07 | get_checks_by_doc reads DFKKCR-STATE (confirmed) instead of BANCD; bank lines with VORGC / VGEXT.
*& 2026-11-07 | get_bank_lines with the statement account (FEBKO BUKRS / HBKID / HKTID, join by KUKEY) for the
*&            | cheque link by number and house bank account (design review).
*& 2026-11-07 | read_configured_set: configured source for many keys in one read (payment outcome).
*& 2026-11-08 | Table consolidation: approved tables read from ZCD_OPS_TABWL (area FMON, purpose SOURCE; was
*&            | ZCD_FMON_TABWL).
*& 2026-11-08 | READ_CONFIGURED_AFTER (keyset paging through the file monitoring reader); set reads also return the
*&            | date, time, requested payment date and amount of the request log.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment trace - read repository (SQL)</p>
CLASS zcl_cd_ops_trace_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_trace_dao.

  PRIVATE SECTION.
    CONSTANTS gc_bpext_field TYPE zif_cd_fmon_types=>ty_fieldname VALUE 'BPEXT'.
    CONSTANTS gc_partner_field TYPE zif_cd_fmon_types=>ty_fieldname VALUE 'PARTNER'.

    "! Query of the file monitoring reader: one key field (IN), fields by role
    METHODS run_query
      IMPORTING
        is_query       TYPE zif_cd_fmon_types=>ty_query
      RETURNING
        VALUE(rt_rows) TYPE zif_cd_fmon_types=>tt_raw_row
      RAISING
        zcx_cd_ops_error.

    "! Request log fields of a set / watermark read: date, time, requested payment date, amount
    CLASS-METHODS add_request_fields
      IMPORTING
        is_source TYPE zif_cd_ops_trace_types=>ty_source_cfg
      CHANGING
        cs_query  TYPE zif_cd_fmon_types=>ty_query.

    "! Rows of a set / watermark read by role
    CLASS-METHODS to_rows
      IMPORTING
        it_raw         TYPE zif_cd_fmon_types=>tt_raw_row
      RETURNING
        VALUE(rt_rows) TYPE zif_cd_ops_trace_types=>tt_cfg_row.

    CLASS-METHODS same_value
      IMPORTING
        iv_left        TYPE clike
        iv_right       TYPE clike
      RETURNING
        VALUE(rv_same) TYPE abap_bool.

ENDCLASS.



CLASS zcl_cd_ops_trace_dao IMPLEMENTATION.

  METHOD zif_cd_ops_trace_dao~read_configured.
    DATA ls_query TYPE zif_cd_fmon_types=>ty_query.

    ls_query-table_name = to_upper( condense( is_source-table_name ) ).
    ls_query-in_field   = to_upper( condense( is_source-key_field ) ).
    ls_query-max_rows   = iv_max_rows.
    INSERT CONV #( is_key-key1 ) INTO TABLE ls_query-in_values.
    " Role names are the reader's; the mapping back below is the only place they matter
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-item_key
                                            iv_field = is_source-key_field
                                  CHANGING  cs_query = ls_query ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-source
                                            iv_field = is_source-key2_field
                                  CHANGING  cs_query = ls_query ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-file_key
                                            iv_field = is_source-ref_field
                                  CHANGING  cs_query = ls_query ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-status
                                            iv_field = is_source-status_field
                                  CHANGING  cs_query = ls_query ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-ev_date
                                            iv_field = is_source-date_field
                                  CHANGING  cs_query = ls_query ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-ev_time
                                            iv_field = is_source-time_field
                                  CHANGING  cs_query = ls_query ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-lot_key
                                            iv_field = is_source-info_field
                                  CHANGING  cs_query = ls_query ).

    LOOP AT run_query( ls_query ) ASSIGNING FIELD-SYMBOL(<ls_raw>).
      " The reader takes one key field; the second key is compared here (rows of one key)
      IF iv_match_key2 = abap_true AND is_source-key2_field IS NOT INITIAL
         AND same_value( iv_left = <ls_raw>-source iv_right = is_key-key2 ) = abap_false.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( key1    = <ls_raw>-item_key
                      key2    = <ls_raw>-source
                      ref     = <ls_raw>-file_key
                      status  = <ls_raw>-status
                      ev_date = <ls_raw>-ev_date
                      ev_time = <ls_raw>-ev_time
                      info    = <ls_raw>-lot_key ) INTO TABLE rt_rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ops_trace_dao~read_configured_set.
    DATA ls_query TYPE zif_cd_fmon_types=>ty_query.
    CHECK it_keys IS NOT INITIAL.
    ls_query-table_name = to_upper( condense( is_source-table_name ) ).
    ls_query-in_field   = to_upper( condense( is_source-key_field ) ).
    ls_query-max_rows   = iv_max_rows.
    LOOP AT it_keys ASSIGNING FIELD-SYMBOL(<lv_key>).
      INSERT CONV #( <lv_key> ) INTO TABLE ls_query-in_values.
    ENDLOOP.
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-item_key
                                            iv_field = is_source-key_field
                                  CHANGING  cs_query = ls_query ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-source
                                            iv_field = is_source-key2_field
                                  CHANGING  cs_query = ls_query ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-status
                                            iv_field = is_source-status_field
                                  CHANGING  cs_query = ls_query ).
    add_request_fields( EXPORTING is_source = is_source
                        CHANGING  cs_query  = ls_query ).
    rt_rows = to_rows( run_query( ls_query ) ).
  ENDMETHOD.


  METHOD zif_cd_ops_trace_dao~read_configured_after.
    DATA ls_query TYPE zif_cd_fmon_types=>ty_query.
    CHECK is_source-date_field IS NOT INITIAL AND is_source-key_field IS NOT INITIAL.
    " Keyset paging on (DATE, TIME, KEY) by the file monitoring reader (DDIC, approval, S_TABU_NAM)
    ls_query-table_name      = to_upper( condense( is_source-table_name ) ).
    ls_query-date_field      = to_upper( condense( is_source-date_field ) ).
    ls_query-date_kind       = zif_cd_fmon_types=>gc_date_kind-date.
    ls_query-date_from       = is_after-date.
    ls_query-date_to         = iv_date_to.
    ls_query-seek_key_field  = to_upper( condense( is_source-key_field ) ).
    ls_query-seek_time_field = to_upper( condense( is_source-time_field ) ).
    ls_query-seek_date       = is_after-date.
    ls_query-seek_time       = is_after-time.
    ls_query-seek_key        = is_after-key.
    ls_query-max_rows        = iv_max_rows.
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-item_key
                                            iv_field = is_source-key_field
                                  CHANGING  cs_query = ls_query ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-source
                                            iv_field = is_source-key2_field
                                  CHANGING  cs_query = ls_query ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-status
                                            iv_field = is_source-status_field
                                  CHANGING  cs_query = ls_query ).
    add_request_fields( EXPORTING is_source = is_source
                        CHANGING  cs_query  = ls_query ).
    rt_rows = to_rows( run_query( ls_query ) ).
  ENDMETHOD.


  METHOD add_request_fields.
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-ev_date
                                            iv_field = is_source-date_field
                                  CHANGING  cs_query = cs_query ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-ev_time
                                            iv_field = is_source-time_field
                                  CHANGING  cs_query = cs_query ).
    " The reader's role names are its own: GROUP_1 carries the requested payment date here
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-group_1
                                            iv_field = is_source-due_field
                                  CHANGING  cs_query = cs_query ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-amount
                                            iv_field = is_source-amount_field
                                  CHANGING  cs_query = cs_query ).
  ENDMETHOD.


  METHOD to_rows.
    LOOP AT it_raw ASSIGNING FIELD-SYMBOL(<ls_raw>).
      INSERT VALUE #( key1    = <ls_raw>-item_key
                      key2    = <ls_raw>-source
                      status  = <ls_raw>-status
                      ev_date = <ls_raw>-ev_date
                      ev_time = <ls_raw>-ev_time
                      due     = <ls_raw>-group_1
                      amount  = <ls_raw>-amount ) INTO TABLE rt_rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ops_trace_dao~get_partners.
    DATA ls_query TYPE zif_cd_fmon_types=>ty_query.

    IF iv_source_field IS INITIAL.
      " VERIFY-SE11 / index: BUT000 read by BPEXT (secondary index expected)
      SELECT partner
        FROM but000
        WHERE bpext = @iv_bpext
        ORDER BY partner
        INTO TABLE @rt_partners
        UP TO @iv_max_rows ROWS.
      RETURN.
    ENDIF.
    " The source field of BUT000 is landscape-specific (VERIFY-SE11): approved reader only
    ls_query-table_name = zif_cd_ops_trace_types=>gc_table-but000.
    ls_query-in_field   = gc_bpext_field.
    ls_query-max_rows   = iv_max_rows.
    INSERT CONV #( iv_bpext ) INTO TABLE ls_query-in_values.
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-file_key
                                            iv_field = gc_partner_field
                                  CHANGING  cs_query = ls_query ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-source
                                            iv_field = iv_source_field
                                  CHANGING  cs_query = ls_query ).
    LOOP AT run_query( ls_query ) ASSIGNING FIELD-SYMBOL(<ls_raw>).
      IF same_value( iv_left = <ls_raw>-source iv_right = iv_source ) = abap_true.
        INSERT CONV zif_cd_ops_trace_types=>ty_partner( <ls_raw>-file_key ) INTO TABLE rt_partners.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ops_trace_dao~get_items_by_fin.
    " Confirmed: request FIN number = DFKKOP-ZZ_FIN_TRANS_NUM. VERIFY-SE11: PYMET, AUGRD;
    " secondary index on ZZ_FIN_TRANS_NUM expected (performance check in QA1)
    SELECT opbel, opupw, opupk, opupz, bukrs, gpart, betrh, waers, budat, pymet,
           augbl, augdt, augrd, zz_fin_trans_num AS fin
      FROM dfkkop
      WHERE zz_fin_trans_num = @iv_fin
      ORDER BY opbel, opupw, opupk, opupz
      INTO CORRESPONDING FIELDS OF TABLE @rt_items
      UP TO @iv_max_rows ROWS.
  ENDMETHOD.


  METHOD zif_cd_ops_trace_dao~get_items_by_clearing.
    " Items cleared by the payment document (DFKKOP-AUGBL; standard index on AUGBL expected)
    SELECT opbel, opupw, opupk, opupz, bukrs, gpart, betrh, waers, budat, pymet,
           augbl, augdt, augrd, zz_fin_trans_num AS fin
      FROM dfkkop
      WHERE augbl = @iv_augbl
      ORDER BY opbel, opupw, opupk, opupz
      INTO CORRESPONDING FIELDS OF TABLE @rt_items
      UP TO @iv_max_rows ROWS.
  ENDMETHOD.


  METHOD zif_cd_ops_trace_dao~get_doc_headers.
    CHECK it_docno IS NOT INITIAL.
    " DFKKKO by key OPBEL. VERIFY-SE11: STBEL (reversal document), CPUDT, CPUTM
    SELECT opbel, fikey, stbel, budat, cpudt, cputm
      FROM dfkkko
      FOR ALL ENTRIES IN @it_docno
      WHERE opbel = @it_docno-table_line
      INTO CORRESPONDING FIELDS OF TABLE @rt_headers.
  ENDMETHOD.


  METHOD zif_cd_ops_trace_dao~get_bank_lines.
    CHECK it_ref IS NOT INITIAL.
    " Confirmed: FEBEP-CHECT = DFKKOP-AUGBL (E G H I J K L) / DFKKCR-ZTNUM (C); BUDAT always
    " filled. VERIFY-SE11: KWBTR, VORGC / VGEXT (BAI / CAMT code, as the EBS line read); secondary
    " index on CHECT expected (performance check in QA1). The statement account (FEBKO BUKRS /
    " HBKID / HKTID, as the EBS statement read) ties a cheque line to its house bank account
    SELECT p~kukey, p~esnum, p~chect, p~budat, p~kwbtr, p~vorgc, p~vgext, k~bukrs, k~hbkid, k~hktid
      FROM febep AS p
      INNER JOIN febko AS k ON k~kukey = p~kukey
      FOR ALL ENTRIES IN @it_ref
      WHERE p~chect = @it_ref-table_line
        AND p~budat >= @iv_from
      INTO CORRESPONDING FIELDS OF TABLE @rt_lines.
    SORT rt_lines BY kukey esnum.
    DATA(lv_first_over) = iv_max_rows + 1.
    IF lines( rt_lines ) >= lv_first_over.
      DELETE rt_lines FROM lv_first_over.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_trace_dao~get_payment_runs.
    " Shared EBS read: DPAYH by DOC1R, ZZ_PAYMENT_STATUS, proposal runs excluded, newest first
    DATA(lt_docno) = CORRESPONDING zif_cd_ebs_sap_dao=>tt_docno( it_docno ).
    rt_runs = CORRESPONDING #( zcl_cd_ebs_factory=>get_sap_dao( )->get_payments( lt_docno ) ).
  ENDMETHOD.


  METHOD zif_cd_ops_trace_dao~get_checks_by_doc.
    CHECK it_docno IS NOT INITIAL.
    " Confirmed: DFKKCR-DOC1R = DFKKOP-AUGBL; STATE = cheque status (B cashed, V voided, blank
    " open; user 2026-11-07, read for the morning report check A_INFLIGHT). VERIFY-DDIC: RWBTR,
    " CRSTATUS (as the EBS read)
    SELECT ztnum, hbkid, hktid, doc1r, rwbtr AS amount, crstatus, state
      FROM dfkkcr
      FOR ALL ENTRIES IN @it_docno
      WHERE doc1r = @it_docno-table_line
      INTO CORRESPONDING FIELDS OF TABLE @rt_checks.
    SORT rt_checks BY hbkid hktid ztnum.
  ENDMETHOD.


  METHOD zif_cd_ops_trace_dao~get_checks_by_number.
    " Shared EBS read: DFKKCR by ZTNUM (= FEBEP-CHECT, method C) with house bank and the
    " configured company-code field
    DATA(lt_ztnum) = VALUE zif_cd_ebs_sap_dao=>tt_ztnum( ( CONV #( iv_ztnum ) ) ).
    rt_checks = CORRESPONDING #( zcl_cd_ebs_factory=>get_sap_dao( )->get_checks( lt_ztnum ) ).
    SORT rt_checks BY hbkid hktid ztnum.
    DATA(lv_first_over) = iv_max_rows + 1.
    IF lines( rt_checks ) >= lv_first_over.
      DELETE rt_checks FROM lv_first_over.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_trace_dao~get_returns.
    " Shared EBS read: DFKKRP-SELW1 = DFKKOP-AUGBL with the lot status DFKKRK-STARS
    DATA(lt_docno) = CORRESPONDING zif_cd_ebs_sap_dao=>tt_docno( it_docno ).
    rt_returns = CORRESPONDING #( zcl_cd_ebs_factory=>get_sap_dao( )->get_return_items( lt_docno ) ).
  ENDMETHOD.


  METHOD zif_cd_ops_trace_dao~get_noc_items.
    " Shared EBS read: DFKKNRP by INFOF (payment document or reference, confirmed 2026-11-06)
    " with the NOC reason FLGRD; INFOF is no key - exact values only, result capped
    DATA(lt_infof) = CORRESPONDING zif_cd_ebs_sap_dao=>tt_infof( it_infof ).
    rt_items = CORRESPONDING #( zcl_cd_ebs_factory=>get_sap_dao( )->get_noc_items( lt_infof ) ).
    DATA(lv_first_over) = iv_max_rows + 1.
    IF lines( rt_items ) >= lv_first_over.
      DELETE rt_items FROM lv_first_over.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_trace_dao~get_retrievals.
    " Shared EBS read: ZCD_ACH_RTRV_LOG by AUGBL, status field EBS_RTRV_STATUS_FIELD
    " (DDIC-validated there; raises for an unknown name)
    DATA(lt_docno) = CORRESPONDING zif_cd_ebs_sap_dao=>tt_docno( it_docno ).
    rt_retrievals = CORRESPONDING #( zcl_cd_ebs_factory=>get_sap_dao( )->get_retrievals( lt_docno ) ).
  ENDMETHOD.


  METHOD zif_cd_ops_trace_dao~get_fmon_files.
    CHECK it_file_ref IS NOT INITIAL.
    " FMON registry by business date (index BDT) and reference
    SELECT file_id, iface_id, file_ref, file_name, business_date, stage, outcome
      FROM zcd_fmon_file
      FOR ALL ENTRIES IN @it_file_ref
      WHERE business_date BETWEEN @iv_from AND @iv_to
        AND file_ref = @it_file_ref-table_line
      INTO CORRESPONDING FIELDS OF TABLE @rt_files.
    SORT rt_files BY file_ref business_date.
  ENDMETHOD.


  METHOD zif_cd_ops_trace_dao~get_fmon_events.
    CHECK it_file_id IS NOT INITIAL.
    SELECT file_id, event_no, stage, event_at, src_id, src_key
      FROM zcd_fmon_event
      FOR ALL ENTRIES IN @it_file_id
      WHERE file_id = @it_file_id-table_line
      INTO CORRESPONDING FIELDS OF TABLE @rt_events.
    SORT rt_events BY file_id event_no.
  ENDMETHOD.


  METHOD zif_cd_ops_trace_dao~get_summary_keys.
    CHECK it_fikey IS NOT INITIAL.
    " Confirmed: DFKKSUMC-FIKEY = DFKKKO-FIKEY. VERIFY-DDIC: DFKKSUMC-BUKRS (as ZCL_CD_HCK_DAO)
    SELECT fikey, bukrs
      FROM dfkksumc
      FOR ALL ENTRIES IN @it_fikey
      WHERE fikey = @it_fikey-fikey
        AND bukrs = @it_fikey-bukrs
      INTO CORRESPONDING FIELDS OF TABLE @rt_fikey.
  ENDMETHOD.


  METHOD zif_cd_ops_trace_dao~get_gl_documents.
    CHECK it_fikey IS NOT INITIAL.
    " Confirmed: BKPF-AWKEY = FIKEY; AWTYP / BUKRS / STBLG as ZCL_CD_HCK_DAO=>GET_FIKEYS_WITHOUT_GL
    " (A43). Reversed documents are returned and filtered by the caller. VERIFY-SE11: CPUDT, CPUTM
    SELECT bukrs, belnr, gjahr, awkey, budat, cpudt, cputm, stblg
      FROM bkpf
      FOR ALL ENTRIES IN @it_fikey
      WHERE awtyp = @iv_awtyp
        AND awkey = @it_fikey-fikey
        AND bukrs = @it_fikey-bukrs
      INTO CORRESPONDING FIELDS OF TABLE @rt_docs.
    SORT rt_docs BY bukrs belnr gjahr.
  ENDMETHOD.


  METHOD zif_cd_ops_trace_dao~get_gl_clearing_lines.
    CHECK it_keys IS NOT INITIAL.
    " Key access only (BUKRS / BELNR / GJAHR) - never BSEG by XREF2 (full scan);
    " confirmed: BSEG-XREF2 = DFKKOP-AUGBL
    SELECT bukrs, belnr, gjahr, buzei, hkont, xref2, augbl, augdt
      FROM bseg
      FOR ALL ENTRIES IN @it_keys
      WHERE bukrs = @it_keys-bukrs
        AND belnr = @it_keys-belnr
        AND gjahr = @it_keys-gjahr
        AND xref2 = @iv_xref2
      INTO CORRESPONDING FIELDS OF TABLE @rt_lines.
    SORT rt_lines BY bukrs belnr gjahr buzei.
  ENDMETHOD.


  METHOD zif_cd_ops_trace_dao~get_method_kind.
    " Confirmed: TFK042Z-XEINZ separates collections from disbursements.
    " VERIFY-SE11: TFK042Z key LAND1 / ZLSCH, country from T001-LAND1
    rv_kind = zif_cd_ops_trace_types=>gc_kind-unknown.
    IF iv_pymet IS INITIAL.
      RETURN.
    ENDIF.
    SELECT z~xeinz
      FROM tfk042z AS z
      INNER JOIN t001 AS t ON t~land1 = z~land1
      WHERE t~bukrs = @iv_bukrs
        AND z~zlsch = @iv_pymet
      ORDER BY z~land1, z~zlsch
      INTO TABLE @DATA(lt_kind)
      UP TO 1 ROWS.
    IF lt_kind IS INITIAL.
      RETURN.
    ENDIF.
    rv_kind = COND #( WHEN lt_kind[ 1 ]-xeinz IS NOT INITIAL THEN zif_cd_ops_trace_types=>gc_kind-collection
                      ELSE zif_cd_ops_trace_types=>gc_kind-disbursement ).
  ENDMETHOD.


  METHOD run_query.
    zcl_cd_fmon_query=>validate( is_query  = is_query
                                 it_fields = zcl_cd_fmon_factory=>get_ddic( )->describe_table( is_query-table_name ) ).
    rt_rows = zcl_cd_fmon_factory=>get_dao( )->read_legacy( is_query ).
  ENDMETHOD.


  METHOD same_value.
    rv_same = xsdbool( to_upper( condense( CONV string( iv_left ) ) ) = to_upper( condense( CONV string( iv_right ) ) ) ).
  ENDMETHOD.

ENDCLASS.
