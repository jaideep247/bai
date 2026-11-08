*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pay_outcome_dao.clas.abap
*& Purpose:
*& All SQL of the incremental payment outcome snapshot. Change reads per
*& evidence source after its watermark (tuple order, package size, never
*& one SELECT per payment): DOCUMENTS = payment / clearing documents by
*& DFKKKO entry date / time that are DFKKOP-AUGBL of items with a FIN;
*& REVERSALS = those documents reversed (DFKKKO-STBEL) by the entry time
*& of the reversal; STATEMENT = statement lines by FEBEP-KUKEY / ESNUM
*& (statement references FEBEP-CHECT); RETURNS = returns lot documents by
*& DFKKKO entry time (DFKKRP-OPBEL) with DFKKRP-SELW1 = AUGBL; GL = G/L
*& clearing documents by BKPF entry time with BSEG lines whose clearing is
*& that document and whose XREF2 carries the payment document; RECHECK =
*& current versions of outcomes that are not final, by AUGBL after the
*& cursor (index OUT). Versions: current versions by FIN (index FIN),
*& closed by UPDATE FROM TABLE and inserted FROM TABLE (no commit). Reads
*& business tables only; writes ZCD_PAY_OUTCOME and ZCD_PAY_OUTWM only.
*& Modification log:
*& 2026-11-07 | Initial version (incremental 5-minute payment outcome snapshot).
*& 2026-11-08 | RECHECK reads the outcomes that are not final by the one definition
*&            | (ZCL_CD_OPS_PAY_OUTCOME=>FINAL_OUTCOMES; same set as before).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment outcome - snapshot SQL</p>
CLASS zcl_cd_ops_pay_outcome_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_pay_outcome_dao.

  PRIVATE SECTION.
    TYPES ty_docno TYPE c LENGTH 12.
    "! G/L clearing document key in the watermark: company code, document, fiscal year
    TYPES:
      BEGIN OF ty_gl_key,
        bukrs TYPE c LENGTH 4,
        belnr TYPE c LENGTH 10,
        gjahr TYPE n LENGTH 4,
      END OF ty_gl_key.

    METHODS documents
      IMPORTING
        is_watermark      TYPE zif_cd_ops_payout_types=>ty_watermark
        iv_max            TYPE i
      RETURNING
        VALUE(rs_changes) TYPE zif_cd_ops_payout_types=>ty_changes.

    METHODS reversals
      IMPORTING
        is_watermark      TYPE zif_cd_ops_payout_types=>ty_watermark
        iv_max            TYPE i
      RETURNING
        VALUE(rs_changes) TYPE zif_cd_ops_payout_types=>ty_changes.

    METHODS statement
      IMPORTING
        is_watermark      TYPE zif_cd_ops_payout_types=>ty_watermark
        iv_max            TYPE i
      RETURNING
        VALUE(rs_changes) TYPE zif_cd_ops_payout_types=>ty_changes.

    METHODS returns
      IMPORTING
        is_watermark      TYPE zif_cd_ops_payout_types=>ty_watermark
        iv_max            TYPE i
      RETURNING
        VALUE(rs_changes) TYPE zif_cd_ops_payout_types=>ty_changes.

    METHODS gl
      IMPORTING
        is_watermark      TYPE zif_cd_ops_payout_types=>ty_watermark
        iv_max            TYPE i
      RETURNING
        VALUE(rs_changes) TYPE zif_cd_ops_payout_types=>ty_changes.

    METHODS recheck
      IMPORTING
        is_watermark      TYPE zif_cd_ops_payout_types=>ty_watermark
        iv_max            TYPE i
      RETURNING
        VALUE(rs_changes) TYPE zif_cd_ops_payout_types=>ty_changes.

    CLASS-METHODS to_db
      IMPORTING
        is_version   TYPE zif_cd_ops_payout_types=>ty_version
      RETURNING
        VALUE(rs_db) TYPE zcd_pay_outcome.

ENDCLASS.



CLASS zcl_cd_ops_pay_outcome_dao IMPLEMENTATION.

  METHOD zif_cd_ops_pay_outcome_dao~get_watermarks.
    SELECT source, wm_date, wm_time, wm_key, wm_seq, updated_at, last_rows
      FROM zcd_pay_outwm
      ORDER BY source
      INTO CORRESPONDING FIELDS OF TABLE @rt_watermarks.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~save_watermark.
    DATA ls_db TYPE zcd_pay_outwm.
    ls_db-source     = is_watermark-source.
    ls_db-wm_date    = is_watermark-wm_date.
    ls_db-wm_time    = is_watermark-wm_time.
    ls_db-wm_key     = is_watermark-wm_key.
    ls_db-wm_seq     = is_watermark-wm_seq.
    ls_db-updated_at = is_watermark-updated_at.
    ls_db-last_rows  = is_watermark-last_rows.
    MODIFY zcd_pay_outwm FROM @ls_db.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e010(zcd_ops) WITH zif_cd_ops_payout_types=>gc_table-watermark.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~get_changes.
    IF iv_max <= 0.
      rs_changes-watermark = is_watermark.
      RETURN.
    ENDIF.
    rs_changes = SWITCH #( iv_source
                           WHEN zif_cd_ops_payout_types=>gc_source-documents
                             THEN documents( is_watermark = is_watermark iv_max = iv_max )
                           WHEN zif_cd_ops_payout_types=>gc_source-reversals
                             THEN reversals( is_watermark = is_watermark iv_max = iv_max )
                           WHEN zif_cd_ops_payout_types=>gc_source-statement
                             THEN statement( is_watermark = is_watermark iv_max = iv_max )
                           WHEN zif_cd_ops_payout_types=>gc_source-returns
                             THEN returns( is_watermark = is_watermark iv_max = iv_max )
                           WHEN zif_cd_ops_payout_types=>gc_source-gl
                             THEN gl( is_watermark = is_watermark iv_max = iv_max )
                           WHEN zif_cd_ops_payout_types=>gc_source-recheck
                             THEN recheck( is_watermark = is_watermark iv_max = iv_max ) ).
    rs_changes-watermark-source = iv_source.
  ENDMETHOD.


  METHOD documents.
    DATA(lv_key) = CONV ty_docno( is_watermark-wm_key ).
    " New payment runs (DPAYH-DOC1R = AUGBL) and new clearings: the payment / clearing document
    " entered after the watermark (DFKKKO CPUDT / CPUTM, VERIFY-SE11 as the trace) that clears an
    " item with a FIN number. VERIFY index: DFKKKO by CPUDT (HANA column store: date predicate)
    SELECT k~opbel, k~cpudt, k~cputm
      FROM dfkkko AS k
      WHERE ( k~cpudt > @is_watermark-wm_date
           OR ( k~cpudt = @is_watermark-wm_date AND k~cputm > @is_watermark-wm_time )
           OR ( k~cpudt = @is_watermark-wm_date AND k~cputm = @is_watermark-wm_time AND k~opbel > @lv_key ) )
        AND EXISTS ( SELECT opbel FROM dfkkop
                       WHERE augbl = k~opbel
                         AND zz_fin_trans_num <> @space )
      ORDER BY k~cpudt, k~cputm, k~opbel
      INTO TABLE @DATA(lt_docs)
      UP TO @iv_max ROWS.
    rs_changes-watermark = is_watermark.
    LOOP AT lt_docs ASSIGNING FIELD-SYMBOL(<ls_doc>).
      INSERT CONV #( <ls_doc>-opbel ) INTO TABLE rs_changes-docno.
      rs_changes-watermark-wm_date = <ls_doc>-cpudt.
      rs_changes-watermark-wm_time = <ls_doc>-cputm.
      rs_changes-watermark-wm_key  = <ls_doc>-opbel.
    ENDLOOP.
    rs_changes-more = xsdbool( lines( lt_docs ) >= iv_max ).
  ENDMETHOD.


  METHOD reversals.
    DATA(lv_key) = CONV ty_docno( is_watermark-wm_key ).
    " A changed clearing of a payment already judged: the payment document's reversal document
    " (DFKKKO-STBEL, VERIFY-SE11) entered after the watermark
    SELECT o~opbel, r~opbel AS reversal, r~cpudt, r~cputm
      FROM dfkkko AS r
      INNER JOIN dfkkko AS o ON o~stbel = r~opbel
      WHERE ( r~cpudt > @is_watermark-wm_date
           OR ( r~cpudt = @is_watermark-wm_date AND r~cputm > @is_watermark-wm_time )
           OR ( r~cpudt = @is_watermark-wm_date AND r~cputm = @is_watermark-wm_time AND r~opbel > @lv_key ) )
        AND EXISTS ( SELECT opbel FROM dfkkop
                       WHERE augbl = o~opbel
                         AND zz_fin_trans_num <> @space )
      ORDER BY r~cpudt, r~cputm, r~opbel
      INTO TABLE @DATA(lt_docs)
      UP TO @iv_max ROWS.
    rs_changes-watermark = is_watermark.
    LOOP AT lt_docs ASSIGNING FIELD-SYMBOL(<ls_doc>).
      INSERT CONV #( <ls_doc>-opbel ) INTO TABLE rs_changes-docno.
      rs_changes-watermark-wm_date = <ls_doc>-cpudt.
      rs_changes-watermark-wm_time = <ls_doc>-cputm.
      rs_changes-watermark-wm_key  = <ls_doc>-reversal.
    ENDLOOP.
    rs_changes-more = xsdbool( lines( lt_docs ) >= iv_max ).
  ENDMETHOD.


  METHOD statement.
    DATA lv_kukey TYPE n LENGTH 8.
    DATA lv_esnum TYPE n LENGTH 5.
    rs_changes-watermark = is_watermark.
    lv_kukey = is_watermark-wm_key.
    lv_esnum = is_watermark-wm_seq.
    IF lv_kukey IS INITIAL.
      " First run: from the first statement line posted on or after the watermark date
      " (FEBEP-BUDAT always filled, confirmed)
      SELECT MIN( kukey ) FROM febep WHERE budat >= @is_watermark-wm_date INTO @DATA(lv_first).
      IF lv_first IS INITIAL.
        RETURN.
      ENDIF.
      lv_kukey = lv_first - 1.
      lv_esnum = 0.
    ENDIF.
    " Statement lines imported after the watermark: FEBEP key order (KUKEY ascending number
    " range, VERIFY), the reference FEBEP-CHECT = AUGBL (methods E G H I J K L) or = cheque number
    SELECT kukey, esnum, chect
      FROM febep
      WHERE ( kukey > @lv_kukey OR ( kukey = @lv_kukey AND esnum > @lv_esnum ) )
        AND chect <> @space
      ORDER BY kukey, esnum
      INTO TABLE @DATA(lt_lines)
      UP TO @iv_max ROWS.
    LOOP AT lt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      INSERT CONV #( <ls_line>-chect ) INTO TABLE rs_changes-refs.
      rs_changes-watermark-wm_key = <ls_line>-kukey.
      rs_changes-watermark-wm_seq = <ls_line>-esnum.
    ENDLOOP.
    IF lt_lines IS INITIAL AND is_watermark-wm_key IS INITIAL.
      rs_changes-watermark-wm_key = lv_kukey.
    ENDIF.
    rs_changes-more = xsdbool( lines( lt_lines ) >= iv_max ).
  ENDMETHOD.


  METHOD returns.
    DATA(lv_key) = CONV ty_docno( is_watermark-wm_key ).
    " Returns lots: the return document of the lot items (DFKKRP-OPBEL) entered after the
    " watermark; the payment document = DFKKRP-SELW1 (confirmed)
    SELECT k~opbel, k~cpudt, k~cputm
      FROM dfkkko AS k
      WHERE ( k~cpudt > @is_watermark-wm_date
           OR ( k~cpudt = @is_watermark-wm_date AND k~cputm > @is_watermark-wm_time )
           OR ( k~cpudt = @is_watermark-wm_date AND k~cputm = @is_watermark-wm_time AND k~opbel > @lv_key ) )
        AND EXISTS ( SELECT opbel FROM dfkkrp
                       WHERE opbel = k~opbel
                         AND selw1 <> @space )
      ORDER BY k~cpudt, k~cputm, k~opbel
      INTO TABLE @DATA(lt_docs)
      UP TO @iv_max ROWS.
    rs_changes-watermark = is_watermark.
    rs_changes-more = xsdbool( lines( lt_docs ) >= iv_max ).
    IF lt_docs IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT lt_docs ASSIGNING FIELD-SYMBOL(<ls_doc>).
      rs_changes-watermark-wm_date = <ls_doc>-cpudt.
      rs_changes-watermark-wm_time = <ls_doc>-cputm.
      rs_changes-watermark-wm_key  = <ls_doc>-opbel.
    ENDLOOP.
    SELECT selw1
      FROM dfkkrp
      FOR ALL ENTRIES IN @lt_docs
      WHERE opbel = @lt_docs-opbel
        AND selw1 <> @space
      INTO TABLE @DATA(lt_items).
    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      INSERT CONV #( <ls_item>-selw1 ) INTO TABLE rs_changes-docno.
    ENDLOOP.
  ENDMETHOD.


  METHOD gl.
    DATA ls_key TYPE ty_gl_key.
    ls_key-bukrs = is_watermark-wm_key(4).
    ls_key-belnr = is_watermark-wm_key+4(10).
    ls_key-gjahr = is_watermark-wm_key+14(4).
    " G/L clearing of the XREF2 line: clearing documents entered after the watermark (BKPF CPUDT /
    " CPUTM, VERIFY index) whose cleared BSEG lines carry XREF2 (= AUGBL, the stable key)
    SELECT h~bukrs, h~belnr, h~gjahr, h~cpudt, h~cputm
      FROM bkpf AS h
      WHERE ( h~cpudt > @is_watermark-wm_date
           OR ( h~cpudt = @is_watermark-wm_date AND h~cputm > @is_watermark-wm_time )
           OR ( h~cpudt = @is_watermark-wm_date AND h~cputm = @is_watermark-wm_time AND h~bukrs > @ls_key-bukrs )
           OR ( h~cpudt = @is_watermark-wm_date AND h~cputm = @is_watermark-wm_time AND h~bukrs = @ls_key-bukrs
                AND h~belnr > @ls_key-belnr )
           OR ( h~cpudt = @is_watermark-wm_date AND h~cputm = @is_watermark-wm_time AND h~bukrs = @ls_key-bukrs
                AND h~belnr = @ls_key-belnr AND h~gjahr > @ls_key-gjahr ) )
      ORDER BY h~cpudt, h~cputm, h~bukrs, h~belnr, h~gjahr
      INTO TABLE @DATA(lt_docs)
      UP TO @iv_max ROWS.
    rs_changes-watermark = is_watermark.
    rs_changes-more = xsdbool( lines( lt_docs ) >= iv_max ).
    IF lt_docs IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT lt_docs ASSIGNING FIELD-SYMBOL(<ls_doc>).
      rs_changes-watermark-wm_date = <ls_doc>-cpudt.
      rs_changes-watermark-wm_time = <ls_doc>-cputm.
      CLEAR rs_changes-watermark-wm_key.
      rs_changes-watermark-wm_key(4)     = <ls_doc>-bukrs.
      rs_changes-watermark-wm_key+4(10)  = <ls_doc>-belnr.
      rs_changes-watermark-wm_key+14(4)  = <ls_doc>-gjahr.
    ENDLOOP.
    " VERIFY index: BSEG by BUKRS / AUGBL / AUGGJ (clearing document) - performance check in QA1
    SELECT xref2
      FROM bseg
      FOR ALL ENTRIES IN @lt_docs
      WHERE bukrs = @lt_docs-bukrs
        AND augbl = @lt_docs-belnr
        AND auggj = @lt_docs-gjahr
        AND xref2 <> @space
      INTO TABLE @DATA(lt_lines).
    LOOP AT lt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      INSERT CONV #( <ls_line>-xref2 ) INTO TABLE rs_changes-docno.
    ENDLOOP.
  ENDMETHOD.


  METHOD recheck.
    DATA(lv_cursor) = CONV ty_docno( is_watermark-wm_key ).
    " State without change stamp (DPAYH status, cheque register state, request log of an ambiguous
    " FIN): current versions whose outcome is not final, by AUGBL after the cursor (index OUT)
    DATA(lt_final) = zcl_cd_ops_pay_outcome=>final_outcomes( ).
    SELECT DISTINCT augbl
      FROM zcd_pay_outcome
      WHERE outcome NOT IN @lt_final
        AND valid_to = @zif_cd_ops_payout_types=>gc_valid_to_open
        AND augbl > @lv_cursor
      ORDER BY augbl
      INTO TABLE @DATA(lt_docs)
      UP TO @iv_max ROWS.
    rs_changes-watermark = is_watermark.
    LOOP AT lt_docs ASSIGNING FIELD-SYMBOL(<ls_doc>).
      INSERT CONV #( <ls_doc>-augbl ) INTO TABLE rs_changes-docno.
      rs_changes-watermark-wm_key = <ls_doc>-augbl.
    ENDLOOP.
    rs_changes-more = xsdbool( lines( lt_docs ) >= iv_max ).
    " End of the list: the next run starts again from the first payment
    IF rs_changes-more = abap_false.
      CLEAR rs_changes-watermark-wm_key.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~get_cheque_documents.
    CHECK it_refs IS NOT INITIAL.
    " Confirmed: DFKKCR-DOC1R = AUGBL; DFKKCR-ZTNUM = FEBEP-CHECT (cheque number as on the
    " statement; a statement that carries only the last characters is caught by RECHECK -
    " VERIFY ZTNUM layout)
    SELECT doc1r
      FROM dfkkcr
      FOR ALL ENTRIES IN @it_refs
      WHERE ztnum = @it_refs-table_line
      INTO TABLE @DATA(lt_cheques).
    LOOP AT lt_cheques ASSIGNING FIELD-SYMBOL(<ls_cheque>) WHERE doc1r IS NOT INITIAL.
      INSERT CONV #( <ls_cheque>-doc1r ) INTO TABLE rt_docno.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~get_fin_items.
    CHECK it_docno IS NOT INITIAL.
    " Confirmed: FIN = DFKKOP-ZZ_FIN_TRANS_NUM; items cleared by the payment document (AUGBL)
    SELECT augbl, bukrs, zz_fin_trans_num AS fin
      FROM dfkkop
      FOR ALL ENTRIES IN @it_docno
      WHERE augbl = @it_docno-table_line
        AND zz_fin_trans_num <> @space
      INTO TABLE @DATA(lt_items).
    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      INSERT VALUE #( augbl = <ls_item>-augbl bukrs = <ls_item>-bukrs fin = <ls_item>-fin ) INTO TABLE rt_items.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~get_open_versions.
    CHECK it_fin IS NOT INITIAL.
    SELECT fin_id, source, bukrs, augbl, laufd, laufi, valid_from, valid_to, outcome,
           evidence_kind, evidence_ref, finding, evaluated_at
      FROM zcd_pay_outcome
      FOR ALL ENTRIES IN @it_fin
      WHERE fin_id   = @it_fin-table_line
        AND valid_to = @zif_cd_ops_payout_types=>gc_valid_to_open
      INTO CORRESPONDING FIELDS OF TABLE @rt_versions.
    SORT rt_versions BY fin_id source bukrs augbl laufd laufi valid_from.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~save_versions.
    DATA lt_close TYPE STANDARD TABLE OF zcd_pay_outcome WITH EMPTY KEY.
    DATA lt_insert TYPE STANDARD TABLE OF zcd_pay_outcome WITH EMPTY KEY.
    LOOP AT it_close ASSIGNING FIELD-SYMBOL(<ls_close>).
      INSERT to_db( <ls_close> ) INTO TABLE lt_close.
    ENDLOOP.
    LOOP AT it_insert ASSIGNING FIELD-SYMBOL(<ls_insert>).
      INSERT to_db( <ls_insert> ) INTO TABLE lt_insert.
    ENDLOOP.
    IF lt_close IS NOT INITIAL.
      UPDATE zcd_pay_outcome FROM TABLE @lt_close.
      IF sy-dbcnt <> lines( lt_close ).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e011(zcd_ops) WITH zif_cd_ops_payout_types=>gc_table-outcome.
      ENDIF.
    ENDIF.
    IF lt_insert IS NOT INITIAL.
      INSERT zcd_pay_outcome FROM TABLE @lt_insert.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e010(zcd_ops) WITH zif_cd_ops_payout_types=>gc_table-outcome.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD to_db.
    rs_db-fin_id        = is_version-fin_id.
    rs_db-source        = is_version-source.
    rs_db-bukrs         = is_version-bukrs.
    rs_db-augbl         = is_version-augbl.
    rs_db-laufd         = is_version-laufd.
    rs_db-laufi         = is_version-laufi.
    rs_db-valid_from    = is_version-valid_from.
    rs_db-valid_to      = is_version-valid_to.
    rs_db-outcome       = is_version-outcome.
    rs_db-evidence_kind = is_version-evidence_kind.
    rs_db-evidence_ref  = is_version-evidence_ref.
    rs_db-finding       = is_version-finding.
    rs_db-evaluated_at  = is_version-evaluated_at.
  ENDMETHOD.

ENDCLASS.
