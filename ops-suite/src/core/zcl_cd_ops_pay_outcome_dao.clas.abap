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
*& current rows of outcomes that are not final, by AUGBL after the cursor
*& (index OUT); NIGHTLY / NIGHTLYREQ = every current row of a payment /
*& request after the cursor. The worklist (open payments, open requests,
*& exceptions): every row of payments (index DOC) and requests (index FIN),
*& deleted / closed / updated / inserted FROM TABLE (no commit). Request
*& items (DFKKOP by FIN with their payment run), due requests with item
*& sums (A_PRQ_NOT_PAID). Every worklist write is optimistic: under the guard
*& row of ZCD_PAY_OUTWM the rows the judgement was based on are compared
*& with the current rows first. Reads business tables only; writes
*& ZCD_PAY_OUTCOME, ZCD_PAY_OUTWM, ZCD_PAY_OUTPKG and ZCD_PAY_OUTPKGM only.
*& Modification log:
*& 2026-11-07 | Initial version (incremental 5-minute payment outcome snapshot).
*& 2026-11-08 | RECHECK reads the outcomes that are not final by the one definition
*&            | (ZCL_CD_OPS_PAY_OUTCOME=>FINAL_OUTCOMES; same set as before).
*& 2026-11-08 | Scale (2 million payments a peak day): DOCUMENTS / REVERSALS also pick up payment documents
*&            | without an item with a FIN (DPAYH-DOC1R, e.g. collections); RECHECK rechecks every version
*&            | marked PAY_STATUS_PENDING first (the status job's update is seen within one run);
*&            | current versions by payment document (index DOC); CURRENT_TO of the watermark; parallel
*&            | package rows ZCD_PAY_OUTPKG (claim by SELECT FOR UPDATE); versions of a run with their
*&            | method; A_INFLIGHT reads on HANA - current versions grouped per payment (CTE) joined to
*&            | DPAYH by key, examples per partition (ROW_NUMBER), candidate rows, AMBIGUOUS-only
*&            | payments, payment runs not yet snapshotted. Never one SELECT per payment.
*& 2026-11-08 | Exceptions-only worklist (user decision 2026-11-08): every row of payments and requests
*&            | (GET_VERSIONS, GET_REQUEST_VERSIONS), request keys of FINs, DELETE of open rows and in-place UPDATE
*&            | (SAVE_VERSIONS; FLOW_CLASS, DUE_DATE), request items (DFKKOP by FIN with the payment run, payment
*&            | block SPZAH VERIFY-SE11), due requests with item sums (A_PRQ_NOT_PAID), NIGHTLY / NIGHTLYREQ cursors
*&            | over the current rows, SWEEP upper date of every change read, package rows deleted per mode's
*&            | sources, not yet snapshotted = entered after the DOCUMENTS watermark (no NOT EXISTS on the
*&            | worklist).
*& 2026-11-10 | Concurrency review: SAVE_VERSIONS locks the worklist guard row (ZCD_PAY_OUTWM WORKLIST, SELECT
*&            | SINGLE FOR UPDATE), reads the current rows of the entities written again (one keyed read per kind)
*&            | and writes nothing on a stale judgement (780) or a second current row of a key (781); INSERT FROM
*&            | TABLE accepting duplicate keys with a count check (a duplicate raised CX_SY_OPEN_SQL_DB, the
*&            | sy-subrc check never fired); package rows with the mode and members (ZCD_PAY_OUTPKGM), GET_PACKAGE,
*&            | DELETE_PACKAGES per mode; SAVE_FAILURES; SAVE_WATERMARK keeps FAIL_COUNT.
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
    "! No upper date bound of a change read (FAST, NIGHTLY)
    CONSTANTS gc_open_date TYPE d VALUE '99991231'.
    "! Cursor of NIGHTLYREQ in the watermark key: FIN (35 characters), then the source
    CONSTANTS gc_fin_length TYPE i VALUE 35.
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
        iv_to             TYPE d
      RETURNING
        VALUE(rs_changes) TYPE zif_cd_ops_payout_types=>ty_changes.

    METHODS reversals
      IMPORTING
        is_watermark      TYPE zif_cd_ops_payout_types=>ty_watermark
        iv_max            TYPE i
        iv_to             TYPE d
      RETURNING
        VALUE(rs_changes) TYPE zif_cd_ops_payout_types=>ty_changes.

    METHODS statement
      IMPORTING
        is_watermark      TYPE zif_cd_ops_payout_types=>ty_watermark
        iv_max            TYPE i
        iv_to             TYPE d
      RETURNING
        VALUE(rs_changes) TYPE zif_cd_ops_payout_types=>ty_changes.

    METHODS returns
      IMPORTING
        is_watermark      TYPE zif_cd_ops_payout_types=>ty_watermark
        iv_max            TYPE i
        iv_to             TYPE d
      RETURNING
        VALUE(rs_changes) TYPE zif_cd_ops_payout_types=>ty_changes.

    METHODS gl
      IMPORTING
        is_watermark      TYPE zif_cd_ops_payout_types=>ty_watermark
        iv_max            TYPE i
        iv_to             TYPE d
      RETURNING
        VALUE(rs_changes) TYPE zif_cd_ops_payout_types=>ty_changes.

    METHODS recheck
      IMPORTING
        is_watermark      TYPE zif_cd_ops_payout_types=>ty_watermark
        iv_max            TYPE i
      RETURNING
        VALUE(rs_changes) TYPE zif_cd_ops_payout_types=>ty_changes.

    "! NIGHTLY: every current worklist row of a payment, by AUGBL after the cursor
    METHODS nightly
      IMPORTING
        is_watermark      TYPE zif_cd_ops_payout_types=>ty_watermark
        iv_max            TYPE i
      RETURNING
        VALUE(rs_changes) TYPE zif_cd_ops_payout_types=>ty_changes.

    "! NIGHTLYREQ: every current worklist row of a payment request, by FIN + source after the cursor
    METHODS nightly_requests
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

    "! What a judgement saw of a current row: key, start, evaluation, outcome and finding
    TYPES:
      BEGIN OF ty_stamp,
        fin_id       TYPE zif_cd_ops_trace_types=>ty_fin,
        source       TYPE zif_cd_ops_trace_types=>ty_source,
        bukrs        TYPE zif_cd_ops_trace_types=>ty_bukrs,
        augbl        TYPE zif_cd_ops_trace_types=>ty_docno,
        laufd        TYPE d,
        laufi        TYPE c LENGTH 6,
        valid_from   TYPE zif_cd_ops_payout_types=>ty_timestamp,
        evaluated_at TYPE zif_cd_ops_payout_types=>ty_timestamp,
        outcome      TYPE zif_cd_ops_payout_types=>ty_outcome,
        finding      TYPE zif_cd_ops_types=>ty_check_code,
      END OF ty_stamp.
    TYPES tt_stamp TYPE SORTED TABLE OF ty_stamp WITH NON-UNIQUE KEY table_line.
    "! Rows closed or deleted by a write, by key and start
    TYPES tt_retired TYPE SORTED TABLE OF ty_stamp
                     WITH NON-UNIQUE KEY fin_id source bukrs augbl laufd laufi valid_from.
    "! Current rows by worklist key (FIN, source, company code, payment document, payment run)
    TYPES tt_current TYPE SORTED TABLE OF zif_cd_ops_payout_types=>ty_version
                     WITH NON-UNIQUE KEY fin_id source bukrs augbl laufd laufi.

    "! Lock the guard row of the worklist (ZCD_PAY_OUTWM, source WORKLIST) until the caller's commit or
    "! rollback; the first write ever creates it
    "! @raising zcx_cd_ops_error | the guard row could not be locked
    METHODS lock_worklist
      RAISING
        zcx_cd_ops_error.

    "! Under the guard: the current rows of every entity written must be the current rows the judgement
    "! was based on, and no row inserted as current may meet a current row of its key that stays
    "! @raising zcx_cd_ops_error | 780 stale judgement, 781 second current row
    METHODS validate
      IMPORTING
        it_basis  TYPE zif_cd_ops_payout_types=>tt_version
        it_close  TYPE zif_cd_ops_payout_types=>tt_version
        it_insert TYPE zif_cd_ops_payout_types=>tt_version
        it_delete TYPE zif_cd_ops_payout_types=>tt_version
        it_update TYPE zif_cd_ops_payout_types=>tt_version
      RAISING
        zcx_cd_ops_error.

    "! Entity of a row for a message: the payment document, else FIN / source of the request
    CLASS-METHODS entity_text
      IMPORTING
        is_stamp       TYPE ty_stamp
      RETURNING
        VALUE(rv_text) TYPE string.

    "! Payment method range of a query (an empty method list reads nothing)
    CLASS-METHODS method_range
      IMPORTING
        it_methods      TYPE zif_cd_hck_runtime_types=>tt_pymet
      RETURNING
        VALUE(rt_range) TYPE zif_cd_ops_payout_types=>tt_pymet_range.

ENDCLASS.



CLASS zcl_cd_ops_pay_outcome_dao IMPLEMENTATION.

  METHOD zif_cd_ops_pay_outcome_dao~get_watermarks.
    SELECT source, wm_date, wm_time, wm_key, wm_seq, updated_at, last_rows, current_to, fail_count
      FROM zcd_pay_outwm
      WHERE source <> @zif_cd_ops_payout_types=>gc_guard_source
      ORDER BY source
      INTO CORRESPONDING FIELDS OF TABLE @rt_watermarks.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~save_watermark.
    DATA ls_db TYPE zcd_pay_outwm.
    " The position only: the count of failed runs belongs to the run (SAVE_FAILURES), never to a package
    UPDATE zcd_pay_outwm
      SET wm_date    = @is_watermark-wm_date,
          wm_time    = @is_watermark-wm_time,
          wm_key     = @is_watermark-wm_key,
          wm_seq     = @is_watermark-wm_seq,
          updated_at = @is_watermark-updated_at,
          last_rows  = @is_watermark-last_rows,
          current_to = @is_watermark-current_to
      WHERE source = @is_watermark-source.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.
    " First watermark of the source
    ls_db-source     = is_watermark-source.
    ls_db-wm_date    = is_watermark-wm_date.
    ls_db-wm_time    = is_watermark-wm_time.
    ls_db-wm_key     = is_watermark-wm_key.
    ls_db-wm_seq     = is_watermark-wm_seq.
    ls_db-updated_at = is_watermark-updated_at.
    ls_db-last_rows  = is_watermark-last_rows.
    ls_db-current_to = is_watermark-current_to.
    INSERT zcd_pay_outwm FROM @ls_db.
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
    " SWEEP: the last date of the range (FAST / NIGHTLY: no upper bound)
    DATA(lv_to) = COND d( WHEN iv_to IS INITIAL THEN gc_open_date ELSE iv_to ).
    rs_changes = SWITCH #( iv_source
                           WHEN zif_cd_ops_payout_types=>gc_source-documents
                             THEN documents( is_watermark = is_watermark iv_max = iv_max iv_to = lv_to )
                           WHEN zif_cd_ops_payout_types=>gc_source-reversals
                             THEN reversals( is_watermark = is_watermark iv_max = iv_max iv_to = lv_to )
                           WHEN zif_cd_ops_payout_types=>gc_source-statement
                             THEN statement( is_watermark = is_watermark iv_max = iv_max iv_to = lv_to )
                           WHEN zif_cd_ops_payout_types=>gc_source-returns
                             THEN returns( is_watermark = is_watermark iv_max = iv_max iv_to = lv_to )
                           WHEN zif_cd_ops_payout_types=>gc_source-gl
                             THEN gl( is_watermark = is_watermark iv_max = iv_max iv_to = lv_to )
                           WHEN zif_cd_ops_payout_types=>gc_source-recheck
                             THEN recheck( is_watermark = is_watermark iv_max = iv_max )
                           WHEN zif_cd_ops_payout_types=>gc_source-nightly
                             THEN nightly( is_watermark = is_watermark iv_max = iv_max )
                           WHEN zif_cd_ops_payout_types=>gc_source-nightly_req
                             THEN nightly_requests( is_watermark = is_watermark iv_max = iv_max ) ).
    rs_changes-watermark-source = iv_source.
  ENDMETHOD.


  METHOD documents.
    DATA(lv_key) = CONV ty_docno( is_watermark-wm_key ).
    " New payment runs (DPAYH-DOC1R = AUGBL) and new clearings: the payment / clearing document
    " entered after the watermark (DFKKKO CPUDT / CPUTM, VERIFY-SE11 as the trace) that is the payment
    " document of a payment run (also without an item with a FIN, e.g. a collection - 2026-11-08) or
    " clears an item with a FIN number. VERIFY index: DFKKKO by CPUDT (HANA column store: date
    " predicate), DPAYH by DOC1R
    SELECT k~opbel, k~cpudt, k~cputm
      FROM dfkkko AS k
      WHERE ( k~cpudt > @is_watermark-wm_date
           OR ( k~cpudt = @is_watermark-wm_date AND k~cputm > @is_watermark-wm_time )
           OR ( k~cpudt = @is_watermark-wm_date AND k~cputm = @is_watermark-wm_time AND k~opbel > @lv_key ) )
        AND k~cpudt <= @iv_to
        AND ( EXISTS ( SELECT doc1r FROM dpayh
                         WHERE doc1r = k~opbel
                           AND xvorl = @space )
           OR EXISTS ( SELECT opbel FROM dfkkop
                         WHERE augbl = k~opbel
                           AND zz_fin_trans_num <> @space ) )
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
        AND r~cpudt <= @iv_to
        AND ( EXISTS ( SELECT doc1r FROM dpayh
                         WHERE doc1r = o~opbel
                           AND xvorl = @space )
           OR EXISTS ( SELECT opbel FROM dfkkop
                         WHERE augbl = o~opbel
                           AND zz_fin_trans_num <> @space ) )
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
        AND budat <= @iv_to
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
        AND k~cpudt <= @iv_to
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
        AND h~cpudt <= @iv_to
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
    " First every payment whose bank evidence decides but whose payment status the hourly job has not
    " updated yet (marker PAY_STATUS_PENDING, index OUT): the update is seen within one run, so the
    " morning report's PAY_STATUS_LAG never reports a status the job has already moved
    SELECT DISTINCT augbl
      FROM zcd_pay_outcome
      WHERE outcome  = @zif_cd_ops_payout_types=>gc_outcome-in_flight
        AND valid_to = @zif_cd_ops_payout_types=>gc_valid_to_open
        AND finding  = @zif_cd_ops_payout_types=>gc_code-status_pending
      ORDER BY augbl
      INTO TABLE @DATA(lt_pending)
      UP TO @iv_max ROWS.
    LOOP AT lt_pending ASSIGNING FIELD-SYMBOL(<ls_pending>).
      INSERT CONV #( <ls_pending>-augbl ) INTO TABLE rs_changes-docno.
    ENDLOOP.
    DATA(lv_rest) = nmax( val1 = 1 val2 = iv_max - lines( lt_pending ) ).
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
      UP TO @lv_rest ROWS.
    rs_changes-watermark = is_watermark.
    LOOP AT lt_docs ASSIGNING FIELD-SYMBOL(<ls_doc>).
      INSERT CONV #( <ls_doc>-augbl ) INTO TABLE rs_changes-docno.
      rs_changes-watermark-wm_key = <ls_doc>-augbl.
    ENDLOOP.
    rs_changes-more = xsdbool( lines( lt_docs ) >= lv_rest ).
    " End of the list: the next run starts again from the first payment
    IF rs_changes-more = abap_false.
      CLEAR rs_changes-watermark-wm_key.
    ENDIF.
  ENDMETHOD.


  METHOD nightly.
    DATA(lv_cursor) = CONV ty_docno( is_watermark-wm_key ).
    " Every current worklist row of a payment (open and exceptions; index DOC): time passing makes a
    " payment late without new evidence
    SELECT DISTINCT augbl
      FROM zcd_pay_outcome
      WHERE valid_to = @zif_cd_ops_payout_types=>gc_valid_to_open
        AND augbl    > @lv_cursor
      ORDER BY augbl
      INTO TABLE @DATA(lt_docs)
      UP TO @iv_max ROWS.
    rs_changes-watermark = is_watermark.
    LOOP AT lt_docs ASSIGNING FIELD-SYMBOL(<ls_doc>).
      INSERT CONV #( <ls_doc>-augbl ) INTO TABLE rs_changes-docno.
      rs_changes-watermark-wm_key = <ls_doc>-augbl.
    ENDLOOP.
    rs_changes-more = xsdbool( lines( lt_docs ) >= iv_max ).
    " End of the list: the next night starts again from the first payment
    IF rs_changes-more = abap_false.
      CLEAR rs_changes-watermark-wm_key.
    ENDIF.
  ENDMETHOD.


  METHOD nightly_requests.
    DATA lv_fin TYPE zif_cd_ops_trace_types=>ty_fin.
    DATA lv_source TYPE zif_cd_ops_trace_types=>ty_source.
    lv_fin    = is_watermark-wm_key(gc_fin_length).
    lv_source = is_watermark-wm_key+gc_fin_length.
    " Every current worklist row of a payment request (payment document blank; index FIN): a request
    " passes its due date without new evidence
    SELECT DISTINCT fin_id, source
      FROM zcd_pay_outcome
      WHERE valid_to = @zif_cd_ops_payout_types=>gc_valid_to_open
        AND augbl    = @space
        AND ( fin_id > @lv_fin OR ( fin_id = @lv_fin AND source > @lv_source ) )
      ORDER BY fin_id, source
      INTO TABLE @DATA(lt_requests)
      UP TO @iv_max ROWS.
    rs_changes-watermark = is_watermark.
    LOOP AT lt_requests ASSIGNING FIELD-SYMBOL(<ls_request>).
      INSERT VALUE #( fin = <ls_request>-fin_id source = <ls_request>-source ) INTO TABLE rs_changes-requests.
      CLEAR rs_changes-watermark-wm_key.
      rs_changes-watermark-wm_key(gc_fin_length) = <ls_request>-fin_id.
      rs_changes-watermark-wm_key+gc_fin_length  = <ls_request>-source.
    ENDLOOP.
    rs_changes-more = xsdbool( lines( lt_requests ) >= iv_max ).
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


  METHOD zif_cd_ops_pay_outcome_dao~get_versions.
    CHECK it_docno IS NOT INITIAL.
    " Every row of the payment documents, current and closed (index DOC): the worklist holds open
    " payments and exceptions only, so a payment has few rows; also the row of a payment without FIN
    " (FIN_ID blank) and of a FIN that is no longer on the payment
    SELECT fin_id, source, bukrs, augbl, laufd, laufi, valid_from, valid_to, outcome,
           evidence_kind, evidence_ref, finding, severity, evaluated_at, flow_class, due_date
      FROM zcd_pay_outcome
      FOR ALL ENTRIES IN @it_docno
      WHERE augbl = @it_docno-table_line
      INTO CORRESPONDING FIELDS OF TABLE @rt_versions.
    SORT rt_versions BY fin_id source bukrs augbl laufd laufi valid_from.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~get_request_versions.
    CHECK it_keys IS NOT INITIAL.
    " Rows of the payment requests: payment document blank (index FIN)
    SELECT fin_id, source, bukrs, augbl, laufd, laufi, valid_from, valid_to, outcome,
           evidence_kind, evidence_ref, finding, severity, evaluated_at, flow_class, due_date
      FROM zcd_pay_outcome
      FOR ALL ENTRIES IN @it_keys
      WHERE fin_id = @it_keys-fin
        AND source = @it_keys-source
        AND augbl  = @space
      INTO CORRESPONDING FIELDS OF TABLE @rt_versions.
    SORT rt_versions BY fin_id source bukrs augbl laufd laufi valid_from.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~get_request_keys.
    CHECK it_fin IS NOT INITIAL.
    SELECT fin_id, source
      FROM zcd_pay_outcome
      FOR ALL ENTRIES IN @it_fin
      WHERE fin_id   = @it_fin-table_line
        AND augbl    = @space
        AND valid_to = @zif_cd_ops_payout_types=>gc_valid_to_open
      INTO TABLE @DATA(lt_rows).
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      INSERT VALUE #( fin = <ls_row>-fin_id source = <ls_row>-source ) INTO TABLE rt_keys.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~get_request_items.
    CHECK it_fin IS NOT INITIAL.
    " Confirmed: FIN = DFKKOP-ZZ_FIN_TRANS_NUM (secondary index expected, as the trace). The payment
    " run of the clearing document: DPAYH-DOC1R = AUGBL without proposal runs, the latest run date.
    " VERIFY-SE11: DFKKOP-SPZAH is the payment block of the item (Release_Readiness.md section 5)
    " (no aggregate with FOR ALL ENTRIES: an item paid in two runs is reduced to its latest run below)
    SELECT o~zz_fin_trans_num AS fin, o~opbel, o~opupw, o~opupk, o~opupz, o~bukrs, o~augbl, o~spzah,
           o~betrw AS amount, o~waers AS currency, p~laufd
      FROM dfkkop AS o
      LEFT OUTER JOIN dpayh AS p ON  p~doc1r = o~augbl
                                 AND p~xvorl = @space
      FOR ALL ENTRIES IN @it_fin
      WHERE o~zz_fin_trans_num = @it_fin-table_line
      INTO TABLE @DATA(lt_rows).
    SORT lt_rows BY fin opbel opupw opupk opupz laufd DESCENDING.
    DELETE ADJACENT DUPLICATES FROM lt_rows COMPARING fin opbel opupw opupk opupz.
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      INSERT VALUE #( fin      = <ls_row>-fin
                      opbel    = <ls_row>-opbel
                      bukrs    = <ls_row>-bukrs
                      augbl    = <ls_row>-augbl
                      spzah    = <ls_row>-spzah
                      amount   = <ls_row>-amount
                      currency = <ls_row>-currency
                      laufd    = <ls_row>-laufd ) INTO TABLE rt_items.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~get_due_requests.
    CHECK iv_max > 0.
    " Current request rows due before the date (open: the nightly has not judged them yet; not paid),
    " each with the sum of the items of its FIN per currency (DFKKOP by FIN). Exceptions only: the
    " request rows of the worklist, bounded by iv_max
    WITH
      +req AS ( SELECT fin_id, source, outcome, evidence_kind, due_date, evidence_ref
                  FROM zcd_pay_outcome
                  WHERE valid_to = @zif_cd_ops_payout_types=>gc_valid_to_open
                    AND augbl    = @space
                    AND due_date < @iv_before
                    AND ( outcome = @zif_cd_ops_payout_types=>gc_outcome-req_open
                       OR outcome = @zif_cd_ops_payout_types=>gc_outcome-req_not_paid ) ),
      +amt AS ( SELECT r~fin_id, o~waers, SUM( o~betrw ) AS amount
                  FROM +req AS r
                  INNER JOIN dfkkop AS o ON o~zz_fin_trans_num = r~fin_id
                  GROUP BY r~fin_id, o~waers )
      SELECT r~fin_id, r~source, r~outcome, r~evidence_kind AS stage, r~due_date, r~evidence_ref,
             a~waers AS currency, a~amount
        FROM +req AS r
        LEFT OUTER JOIN +amt AS a ON a~fin_id = r~fin_id
        ORDER BY r~due_date, r~source, r~evidence_kind, r~fin_id
        INTO CORRESPONDING FIELDS OF TABLE @rt_rows
        UP TO @iv_max ROWS.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~save_versions.
    DATA lt_close TYPE STANDARD TABLE OF zcd_pay_outcome WITH EMPTY KEY.
    DATA lt_insert TYPE STANDARD TABLE OF zcd_pay_outcome WITH EMPTY KEY.
    DATA lt_delete TYPE STANDARD TABLE OF zcd_pay_outcome WITH EMPTY KEY.
    DATA lt_update TYPE STANDARD TABLE OF zcd_pay_outcome WITH EMPTY KEY.
    LOOP AT it_close ASSIGNING FIELD-SYMBOL(<ls_close>).
      INSERT to_db( <ls_close> ) INTO TABLE lt_close.
    ENDLOOP.
    LOOP AT it_insert ASSIGNING FIELD-SYMBOL(<ls_insert>).
      INSERT to_db( <ls_insert> ) INTO TABLE lt_insert.
    ENDLOOP.
    LOOP AT it_delete ASSIGNING FIELD-SYMBOL(<ls_delete>).
      INSERT to_db( <ls_delete> ) INTO TABLE lt_delete.
    ENDLOOP.
    LOOP AT it_update ASSIGNING FIELD-SYMBOL(<ls_update>).
      INSERT to_db( <ls_update> ) INTO TABLE lt_update.
    ENDLOOP.
    IF lt_close IS INITIAL AND lt_insert IS INITIAL AND lt_delete IS INITIAL AND lt_update IS INITIAL.
      RETURN.
    ENDIF.
    " Optimistic concurrency (review 2026-11-10): the judgement read the rows without a lock, and FAST,
    " NIGHTLY, SWEEP and the parallel units run at the same time (own run locks - FAST is never held up
    " by a nightly run). Under the guard the current rows are read again: a stale judgement writes
    " nothing (the caller rolls back, the next run judges again) - never two current rows of a key, never
    " a cleared payment that keeps an open exception, never last writer wins
    lock_worklist( ).
    validate( it_basis  = it_basis
              it_close  = it_close
              it_insert = it_insert
              it_delete = it_delete
              it_update = it_update ).
    " Open rows of payments that left the worklist (clean, or an exception now): no history. A row
    " already removed means the evaluation is stale: the package fails and is judged again
    IF lt_delete IS NOT INITIAL.
      DELETE zcd_pay_outcome FROM TABLE @lt_delete.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e011(zcd_ops) WITH zif_cd_ops_payout_types=>gc_table-outcome.
      ENDIF.
    ENDIF.
    " An open row changed in place: the row must still be there (else a concurrent run changed it - the
    " package fails and is retried)
    IF lt_update IS NOT INITIAL.
      UPDATE zcd_pay_outcome FROM TABLE @lt_update.
      IF sy-dbcnt <> lines( lt_update ).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e011(zcd_ops) WITH zif_cd_ops_payout_types=>gc_table-outcome.
      ENDIF.
    ENDIF.
    IF lt_close IS NOT INITIAL.
      UPDATE zcd_pay_outcome FROM TABLE @lt_close.
      IF sy-dbcnt <> lines( lt_close ).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e011(zcd_ops) WITH zif_cd_ops_payout_types=>gc_table-outcome.
      ENDIF.
    ENDIF.
    IF lt_insert IS NOT INITIAL.
      " A duplicate key is a sy-subrc / count here, not CX_SY_OPEN_SQL_DB: the package fails closed
      INSERT zcd_pay_outcome FROM TABLE @lt_insert ACCEPTING DUPLICATE KEYS.
      IF sy-subrc <> 0 OR sy-dbcnt <> lines( lt_insert ).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e010(zcd_ops) WITH zif_cd_ops_payout_types=>gc_table-outcome.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD lock_worklist.
    DATA ls_guard TYPE zcd_pay_outwm.
    " One guard row for every writer of the worklist, held from the re-read of the current rows to the
    " commit of the package (seconds): validation and write are one step for every other writer. Per-row
    " locks would need one SELECT SINGLE FOR UPDATE per payment (ABAP SQL locks several rows only by
    " changing them). VERIFY-ADT: lock wait of a parallel unit on the guard (QA1 VOL-01)
    SELECT SINGLE FOR UPDATE source
      FROM zcd_pay_outwm
      WHERE source = @zif_cd_ops_payout_types=>gc_guard_source
      INTO @DATA(lv_guard).
    IF sy-subrc = 0 AND lv_guard IS NOT INITIAL.
      RETURN.
    ENDIF.
    " First write ever: the new row is locked by its insert until the commit
    ls_guard-source = zif_cd_ops_payout_types=>gc_guard_source.
    INSERT zcd_pay_outwm FROM @ls_guard.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.
    " Created by a parallel first writer meanwhile (its commit released it): lock that row
    SELECT SINGLE FOR UPDATE source
      FROM zcd_pay_outwm
      WHERE source = @zif_cd_ops_payout_types=>gc_guard_source
      INTO @lv_guard.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e012(zcd_ops) WITH zif_cd_ops_payout_types=>gc_table-watermark.
    ENDIF.
  ENDMETHOD.


  METHOD validate.
    DATA lt_docno TYPE zif_cd_ops_trace_types=>tt_docno.
    DATA lt_requests TYPE zif_cd_ops_payout_types=>tt_req_key.
    DATA lt_written TYPE zif_cd_ops_payout_types=>tt_version.
    DATA lt_now TYPE tt_current.
    DATA lt_then TYPE tt_stamp.
    DATA lt_seen TYPE tt_stamp.
    DATA lt_retired TYPE tt_retired.
    DATA lt_new_keys TYPE tt_current.
    DATA lt_changed TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
    INSERT LINES OF it_close INTO TABLE lt_written.
    INSERT LINES OF it_insert INTO TABLE lt_written.
    INSERT LINES OF it_delete INTO TABLE lt_written.
    INSERT LINES OF it_update INTO TABLE lt_written.
    " The entities written: payment documents and requests (FIN + source, payment document blank)
    LOOP AT lt_written ASSIGNING FIELD-SYMBOL(<ls_written>).
      IF <ls_written>-augbl IS NOT INITIAL.
        INSERT <ls_written>-augbl INTO TABLE lt_docno.
      ELSE.
        INSERT VALUE #( fin = <ls_written>-fin_id source = <ls_written>-source ) INTO TABLE lt_requests.
      ENDIF.
    ENDLOOP.
    " Their current rows now: one keyed read per kind (index DOC / FIN), never one per payment
    DATA(lt_read) = zif_cd_ops_pay_outcome_dao~get_versions( lt_docno ).
    INSERT LINES OF zif_cd_ops_pay_outcome_dao~get_request_versions( lt_requests ) INTO TABLE lt_read.
    LOOP AT lt_read ASSIGNING FIELD-SYMBOL(<ls_read>) WHERE valid_to = zif_cd_ops_payout_types=>gc_valid_to_open.
      INSERT <ls_read> INTO TABLE lt_now.
      INSERT CORRESPONDING ty_stamp( <ls_read> ) INTO TABLE lt_seen.
    ENDLOOP.
    " ... and the current rows the judgement saw of the same entities
    LOOP AT it_basis ASSIGNING FIELD-SYMBOL(<ls_basis>) WHERE valid_to = zif_cd_ops_payout_types=>gc_valid_to_open.
      IF ( <ls_basis>-augbl IS NOT INITIAL AND line_exists( lt_docno[ table_line = <ls_basis>-augbl ] ) )
         OR ( <ls_basis>-augbl IS INITIAL
              AND line_exists( lt_requests[ fin = <ls_basis>-fin_id source = <ls_basis>-source ] ) ).
        INSERT CORRESPONDING ty_stamp( <ls_basis> ) INTO TABLE lt_then.
      ENDIF.
    ENDLOOP.
    IF lt_seen <> lt_then.
      " Another run closed, inserted or re-evaluated a row of these entities after this judgement
      LOOP AT lt_then ASSIGNING FIELD-SYMBOL(<ls_then>).
        IF NOT line_exists( lt_seen[ table_line = <ls_then> ] ).
          INSERT entity_text( <ls_then> ) INTO TABLE lt_changed.
        ENDIF.
      ENDLOOP.
      LOOP AT lt_seen ASSIGNING FIELD-SYMBOL(<ls_seen>).
        IF NOT line_exists( lt_then[ table_line = <ls_seen> ] ).
          INSERT entity_text( <ls_seen> ) INTO TABLE lt_changed.
        ENDIF.
      ENDLOOP.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e780(zcd_ops) WITH lines( lt_changed ) VALUE #( lt_changed[ 1 ] OPTIONAL ).
    ENDIF.
    " Never a second current row of a key: before a row is inserted as current, every current row of its
    " key is closed or deleted in the same write, and no key is inserted as current twice
    LOOP AT it_close ASSIGNING FIELD-SYMBOL(<ls_close>).
      INSERT CORRESPONDING ty_stamp( <ls_close> ) INTO TABLE lt_retired.
    ENDLOOP.
    LOOP AT it_delete ASSIGNING FIELD-SYMBOL(<ls_delete>).
      INSERT CORRESPONDING ty_stamp( <ls_delete> ) INTO TABLE lt_retired.
    ENDLOOP.
    LOOP AT it_insert ASSIGNING FIELD-SYMBOL(<ls_new>) WHERE valid_to = zif_cd_ops_payout_types=>gc_valid_to_open.
      IF line_exists( lt_new_keys[ fin_id = <ls_new>-fin_id source = <ls_new>-source bukrs = <ls_new>-bukrs
                                   augbl = <ls_new>-augbl laufd = <ls_new>-laufd laufi = <ls_new>-laufi ] ).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e781(zcd_ops) WITH entity_text( CORRESPONDING #( <ls_new> ) ).
      ENDIF.
      INSERT <ls_new> INTO TABLE lt_new_keys.
      LOOP AT lt_now ASSIGNING FIELD-SYMBOL(<ls_now>)
           WHERE fin_id = <ls_new>-fin_id AND source = <ls_new>-source AND bukrs = <ls_new>-bukrs
             AND augbl = <ls_new>-augbl AND laufd = <ls_new>-laufd AND laufi = <ls_new>-laufi.
        IF NOT line_exists( lt_retired[ fin_id = <ls_now>-fin_id source = <ls_now>-source bukrs = <ls_now>-bukrs
                                        augbl = <ls_now>-augbl laufd = <ls_now>-laufd laufi = <ls_now>-laufi
                                        valid_from = <ls_now>-valid_from ] ).
          RAISE EXCEPTION TYPE zcx_cd_ops_error
            MESSAGE e781(zcd_ops) WITH entity_text( CORRESPONDING #( <ls_new> ) ).
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD entity_text.
    rv_text = COND #( WHEN is_stamp-augbl IS NOT INITIAL THEN |{ is_stamp-augbl }|
                      ELSE |{ is_stamp-fin_id } / { is_stamp-source }| ).
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
    rs_db-severity      = is_version-severity.
    rs_db-evaluated_at  = is_version-evaluated_at.
    rs_db-flow_class    = is_version-flow_class.
    rs_db-due_date      = is_version-due_date.
  ENDMETHOD.


  METHOD method_range.
    rt_range = VALUE #( FOR lv_method IN it_methods ( sign   = zif_cd_ops_types=>gc_range-sign_include
                                                      option = zif_cd_ops_types=>gc_range-option_equal
                                                      low    = lv_method ) ).
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~save_packages.
    DATA lt_db TYPE STANDARD TABLE OF zcd_pay_outpkg WITH EMPTY KEY.
    DATA ls_db TYPE zcd_pay_outpkg.
    DATA lt_members TYPE STANDARD TABLE OF zcd_pay_outpkgm WITH EMPTY KEY.
    DATA ls_member TYPE zcd_pay_outpkgm.
    CHECK it_packages IS NOT INITIAL.
    LOOP AT it_packages ASSIGNING FIELD-SYMBOL(<ls_package>).
      CLEAR ls_db.
      ls_db-run_id    = <ls_package>-run_id.
      ls_db-source    = <ls_package>-source.
      ls_db-pkg_no    = <ls_package>-pkg_no.
      ls_db-run_mode  = <ls_package>-mode.
      ls_db-status    = zif_cd_ops_payout_types=>gc_pkg_status-planned.
      ls_db-documents = lines( <ls_package>-docno ) + lines( <ls_package>-requests ).
      INSERT ls_db INTO TABLE lt_db.
      " The members: the unit of the package re-reads them by its key (2026-11-10)
      LOOP AT <ls_package>-docno ASSIGNING FIELD-SYMBOL(<lv_docno>).
        CLEAR ls_member.
        ls_member-run_id = <ls_package>-run_id.
        ls_member-source = <ls_package>-source.
        ls_member-pkg_no = <ls_package>-pkg_no.
        ls_member-augbl  = <lv_docno>.
        INSERT ls_member INTO TABLE lt_members.
      ENDLOOP.
      LOOP AT <ls_package>-requests ASSIGNING FIELD-SYMBOL(<ls_request>).
        CLEAR ls_member.
        ls_member-run_id     = <ls_package>-run_id.
        ls_member-source     = <ls_package>-source.
        ls_member-pkg_no     = <ls_package>-pkg_no.
        ls_member-fin_id     = <ls_request>-fin.
        ls_member-req_source = <ls_request>-source.
        INSERT ls_member INTO TABLE lt_members.
      ENDLOOP.
    ENDLOOP.
    INSERT zcd_pay_outpkg FROM TABLE @lt_db ACCEPTING DUPLICATE KEYS.
    IF sy-subrc <> 0 OR sy-dbcnt <> lines( lt_db ).
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e010(zcd_ops) WITH zif_cd_ops_payout_types=>gc_table-package.
    ENDIF.
    IF lt_members IS INITIAL.
      RETURN.
    ENDIF.
    INSERT zcd_pay_outpkgm FROM TABLE @lt_members ACCEPTING DUPLICATE KEYS.
    IF sy-subrc <> 0 OR sy-dbcnt <> lines( lt_members ).
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e010(zcd_ops) WITH zif_cd_ops_payout_types=>gc_table-member.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~get_package.
    rs_package-run_id = is_key-run_id.
    rs_package-source = is_key-source.
    rs_package-pkg_no = is_key-pkg_no.
    rs_package-run_at = is_key-run_at.
    SELECT augbl, fin_id, req_source
      FROM zcd_pay_outpkgm
      WHERE run_id = @is_key-run_id
        AND source = @is_key-source
        AND pkg_no = @is_key-pkg_no
      ORDER BY augbl, fin_id, req_source
      INTO TABLE @DATA(lt_members).
    LOOP AT lt_members ASSIGNING FIELD-SYMBOL(<ls_member>).
      IF <ls_member>-augbl IS NOT INITIAL.
        INSERT CONV #( <ls_member>-augbl ) INTO TABLE rs_package-docno.
      ELSE.
        INSERT VALUE #( fin = <ls_member>-fin_id source = <ls_member>-req_source ) INTO TABLE rs_package-requests.
      ENDIF.
    ENDLOOP.
    rs_package-documents = lines( lt_members ).
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~claim_package.
    " The row stays locked until the unit's commit: the run cannot abandon a package whose versions
    " are being written, and an abandoned package is never written
    SELECT SINGLE FOR UPDATE status
      FROM zcd_pay_outpkg
      WHERE run_id = @is_package-run_id
        AND source = @is_package-source
        AND pkg_no = @is_package-pkg_no
      INTO @DATA(lv_status).
    rv_claimed = xsdbool( sy-subrc = 0 AND lv_status = zif_cd_ops_payout_types=>gc_pkg_status-planned ).
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~finish_package.
    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.
    UPDATE zcd_pay_outpkg
      SET status      = @is_package-status,
          evaluated   = @is_package-evaluated,
          inserted    = @is_package-inserted,
          closed      = @is_package-closed,
          message     = @is_package-message,
          finished_at = @lv_now
      WHERE run_id = @is_package-run_id
        AND source = @is_package-source
        AND pkg_no = @is_package-pkg_no.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e011(zcd_ops) WITH zif_cd_ops_payout_types=>gc_table-package.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~get_packages.
    SELECT run_id, source, pkg_no, run_mode AS mode, status, documents, evaluated, inserted, closed, message
      FROM zcd_pay_outpkg
      WHERE run_id = @iv_run_id
      ORDER BY source, pkg_no
      INTO CORRESPONDING FIELDS OF TABLE @rt_packages.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~abandon_packages.
    UPDATE zcd_pay_outpkg
      SET status = @zif_cd_ops_payout_types=>gc_pkg_status-abandoned
      WHERE run_id = @iv_run_id
        AND status = @zif_cd_ops_payout_types=>gc_pkg_status-planned.
    rv_count = sy-dbcnt.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~delete_packages.
    " Only the earlier runs of the mode whose run lock is held (they have ended): SWEEP reads the same
    " evidence sources as FAST, so the mode decides, never the source (review 2026-11-10). Rows without a
    " mode were written before the mode existed - their runs have ended long since
    DELETE FROM zcd_pay_outpkgm
      WHERE run_id IN ( SELECT run_id FROM zcd_pay_outpkg
                          WHERE ( run_mode = @iv_mode OR run_mode = @space )
                            AND run_id <> @iv_keep_run_id ).
    rv_count = sy-dbcnt.
    DELETE FROM zcd_pay_outpkg
      WHERE ( run_mode = @iv_mode OR run_mode = @space )
        AND run_id <> @iv_keep_run_id.
    rv_count = rv_count + sy-dbcnt.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~save_failures.
    DATA ls_db TYPE zcd_pay_outwm.
    UPDATE zcd_pay_outwm
      SET fail_count = @iv_count
      WHERE source = @iv_source.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.
    " The source failed before its first watermark: a row without position (its next run is a first run)
    ls_db-source     = iv_source.
    ls_db-fail_count = iv_count.
    INSERT zcd_pay_outwm FROM @ls_db.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e010(zcd_ops) WITH zif_cd_ops_payout_types=>gc_table-watermark.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~get_new_versions.
    " The versions of one run carry its time as VALID_FROM (index OUT: VALID_TO, then filtered)
    SELECT o~fin_id, o~source, o~bukrs, o~augbl, o~laufd, o~laufi, o~valid_from, o~valid_to, o~outcome,
           o~evidence_kind, o~evidence_ref, o~finding, o~severity, o~evaluated_at, o~flow_class, o~due_date,
           p~pymet, z~xeinz
      FROM zcd_pay_outcome AS o
      INNER JOIN dpayh AS p ON  p~laufd = o~laufd
                            AND p~laufi = o~laufi
                            AND p~doc1r = o~augbl
      INNER JOIN t001 AS t ON t~bukrs = p~bukrs
      INNER JOIN tfk042z AS z ON  z~land1 = t~land1
                              AND z~zlsch = p~pymet
      WHERE o~valid_to   = @zif_cd_ops_payout_types=>gc_valid_to_open
        AND o~valid_from = @iv_valid_from
        AND o~finding    = @iv_finding
        AND p~xvorl      = @space
      ORDER BY o~laufd, o~augbl, o~fin_id, o~source
      INTO TABLE @DATA(lt_rows).
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      INSERT VALUE #( version = CORRESPONDING #( <ls_row> )
                      pymet   = <ls_row>-pymet
                      xeinz   = <ls_row>-xeinz ) INTO TABLE rt_versions.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~get_outcome_groups.
    DATA(lt_methods) = method_range( is_query-methods ).
    CHECK lt_methods IS NOT INITIAL.
    " One row per payment (the FIN / source rows of a payment carry the same verdict; the company code
    " comes from DPAYH, so a payment over several company codes counts once), then grouped with its
    " DPAYH values on HANA: one result row per group, never one per payment. Indexes: ZCD_PAY_OUTCOME
    " OUT (OUTCOME, VALID_TO); DPAYH primary key (VERIFY-SE11: LAUFD + LAUFI + DOC1R identify one row
    " without proposal runs)
    WITH
      +cur AS ( SELECT augbl, laufd, laufi, outcome, finding, severity, MIN( valid_from ) AS since
                  FROM zcd_pay_outcome
                  WHERE valid_to = @zif_cd_ops_payout_types=>gc_valid_to_open
                    AND ( outcome IN @is_query-all_ages
                       OR ( outcome IN @is_query-recent AND laufd >= @is_query-final_from ) )
                    AND finding IN @is_query-findings
                    AND laufd IN @is_query-days
                  GROUP BY augbl, laufd, laufi, outcome, finding, severity ),
      +due AS ( SELECT augbl, laufd, laufi, outcome, finding, severity,
                       CASE WHEN since <= @is_query-lag_limit THEN @abap_true ELSE @abap_false END AS due
                  FROM +cur )
      SELECT z~xeinz, p~pymet, p~hbkid, c~laufd, c~laufi, p~valut, p~waers AS currency, c~outcome,
             c~finding, c~severity, p~zz_payment_status AS pay_status, c~due,
             COUNT(*) AS payments, SUM( abs( p~rwbtr ) ) AS amount
        FROM +due AS c
        INNER JOIN dpayh AS p ON  p~laufd = c~laufd
                              AND p~laufi = c~laufi
                              AND p~doc1r = c~augbl
        INNER JOIN t001 AS t ON t~bukrs = p~bukrs
        INNER JOIN tfk042z AS z ON  z~land1 = t~land1
                                AND z~zlsch = p~pymet
        WHERE p~xvorl = @space
          AND p~pymet IN @lt_methods
          AND p~zz_payment_status IN @is_query-statuses
        GROUP BY z~xeinz, p~pymet, p~hbkid, c~laufd, c~laufi, p~valut, p~waers, c~outcome, c~finding,
                 c~severity, p~zz_payment_status, c~due
        ORDER BY c~laufd, p~pymet, p~hbkid, c~laufi, p~valut
        INTO CORRESPONDING FIELDS OF TABLE @rt_groups.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~get_outcome_examples.
    DATA(lt_methods) = method_range( is_query-methods ).
    CHECK lt_methods IS NOT INITIAL.
    CHECK iv_rows > 0.
    " The first iv_rows payments of each partition (value date, then document): at most iv_rows x
    " partitions rows, whatever the number of payments. VERIFY-ADT: ROW_NUMBER in a common table
    " expression over a join (ABAP SQL 7.58)
    WITH
      +cur AS ( SELECT augbl, laufd, laufi, outcome, finding, severity, MIN( valid_from ) AS since,
                       MAX( evidence_ref ) AS evidence_ref
                  FROM zcd_pay_outcome
                  WHERE valid_to = @zif_cd_ops_payout_types=>gc_valid_to_open
                    AND ( outcome IN @is_query-all_ages
                       OR ( outcome IN @is_query-recent AND laufd >= @is_query-final_from ) )
                    AND finding IN @is_query-findings
                    AND laufd IN @is_query-days
                  GROUP BY augbl, laufd, laufi, outcome, finding, severity ),
      +due AS ( SELECT augbl, laufd, laufi, outcome, finding, severity, evidence_ref,
                       CASE WHEN since <= @is_query-lag_limit THEN @abap_true ELSE @abap_false END AS due
                  FROM +cur ),
      +ranked AS ( SELECT c~augbl AS doc1r, c~laufd, c~laufi, p~bukrs, z~xeinz, p~pymet, p~hbkid, p~valut,
                          p~waers AS currency, abs( p~rwbtr ) AS amount, c~outcome, c~finding, c~severity,
                          p~zz_payment_status AS pay_status, c~due, c~evidence_ref,
                          row_number( ) OVER( PARTITION BY z~xeinz, p~pymet, p~hbkid, c~laufd, c~laufi, c~outcome,
                                                           c~finding, p~zz_payment_status, c~due
                                              ORDER BY p~valut, c~augbl ) AS rn
                     FROM +due AS c
                     INNER JOIN dpayh AS p ON  p~laufd = c~laufd
                                           AND p~laufi = c~laufi
                                           AND p~doc1r = c~augbl
                     INNER JOIN t001 AS t ON t~bukrs = p~bukrs
                     INNER JOIN tfk042z AS z ON  z~land1 = t~land1
                                             AND z~zlsch = p~pymet
                     WHERE p~xvorl = @space
                       AND p~pymet IN @lt_methods
                       AND p~zz_payment_status IN @is_query-statuses )
      SELECT doc1r, laufd, laufi, bukrs, xeinz, pymet, hbkid, valut, currency, amount, outcome, finding,
             severity, pay_status, due, evidence_ref
        FROM +ranked
        WHERE rn <= @iv_rows
        ORDER BY laufd, valut, doc1r
        INTO CORRESPONDING FIELDS OF TABLE @rt_examples.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~get_outcome_rows.
    DATA(lt_methods) = method_range( is_query-methods ).
    CHECK lt_methods IS NOT INITIAL.
    CHECK iv_max > 0.
    WITH
      +cur AS ( SELECT augbl, laufd, laufi, outcome, finding, severity
                  FROM zcd_pay_outcome
                  WHERE valid_to = @zif_cd_ops_payout_types=>gc_valid_to_open
                    AND ( outcome IN @is_query-all_ages
                       OR ( outcome IN @is_query-recent AND laufd >= @is_query-final_from ) )
                    AND finding IN @is_query-findings
                    AND laufd IN @is_query-days
                  GROUP BY augbl, laufd, laufi, outcome, finding, severity )
      SELECT c~augbl AS doc1r, c~laufd, c~laufi, p~bukrs, z~xeinz, p~pymet, p~hbkid, p~valut,
             p~waers AS currency, abs( p~rwbtr ) AS amount, c~outcome, c~finding, c~severity,
             p~zz_payment_status AS pay_status
        FROM +cur AS c
        INNER JOIN dpayh AS p ON  p~laufd = c~laufd
                              AND p~laufi = c~laufi
                              AND p~doc1r = c~augbl
        INNER JOIN t001 AS t ON t~bukrs = p~bukrs
        INNER JOIN tfk042z AS z ON  z~land1 = t~land1
                                AND z~zlsch = p~pymet
        WHERE p~xvorl = @space
          AND p~pymet IN @lt_methods
          AND p~zz_payment_status IN @is_query-statuses
        ORDER BY c~laufd, c~augbl
        INTO CORRESPONDING FIELDS OF TABLE @rt_rows
        UP TO @iv_max ROWS.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~get_ambiguous_only.
    DATA(lt_methods) = method_range( is_query-methods ).
    CHECK lt_methods IS NOT INITIAL.
    CHECK iv_max > 0.
    " AMBIGUOUS replaces the evaluated outcome per FIN and source: a payment without any other current
    " version has no stored outcome A_INFLIGHT could count - it is evaluated live (bounded)
    SELECT DISTINCT o~augbl, o~laufd
      FROM zcd_pay_outcome AS o
      WHERE o~valid_to = @zif_cd_ops_payout_types=>gc_valid_to_open
        AND o~outcome  = @zif_cd_ops_payout_types=>gc_outcome-ambiguous
        AND NOT EXISTS ( SELECT augbl FROM zcd_pay_outcome
                           WHERE augbl    = o~augbl
                             AND laufd    = o~laufd
                             AND laufi    = o~laufi
                             AND valid_to = @zif_cd_ops_payout_types=>gc_valid_to_open
                             AND outcome <> @zif_cd_ops_payout_types=>gc_outcome-ambiguous )
        AND EXISTS ( SELECT doc1r FROM dpayh
                       WHERE laufd = o~laufd
                         AND laufi = o~laufi
                         AND doc1r = o~augbl
                         AND xvorl = @space
                         AND pymet IN @lt_methods )
      ORDER BY o~laufd, o~augbl
      INTO TABLE @DATA(lt_docs)
      UP TO @iv_max ROWS.
    LOOP AT lt_docs ASSIGNING FIELD-SYMBOL(<ls_doc>).
      INSERT CONV #( <ls_doc>-augbl ) INTO TABLE rt_docno.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome_dao~get_unsnapshotted.
    DATA(lt_methods) = method_range( it_methods ).
    CHECK lt_methods IS NOT INITIAL.
    CHECK iv_max > 0.
    IF is_after-wm_date IS INITIAL.
      " Before the first snapshot run: the payment runs of the look-back window (DPAYH by LAUFD)
      SELECT p~doc1r, p~laufd
        FROM dpayh AS p
        WHERE p~laufd >= @iv_from
          AND p~xvorl  = @space
          AND p~doc1r <> @space
          AND p~pymet IN @lt_methods
        ORDER BY p~laufd, p~doc1r
        INTO TABLE @DATA(lt_first)
        UP TO @iv_max ROWS.
      LOOP AT lt_first ASSIGNING FIELD-SYMBOL(<ls_first>).
        INSERT CONV #( <ls_first>-doc1r ) INTO TABLE rt_docno.
      ENDLOOP.
      RETURN.
    ENDIF.
    " Not reached yet: the payment document entered after the DOCUMENTS watermark (DFKKKO CPUDT /
    " CPUTM / OPBEL - the order the snapshot reads in); a clean payment has no row, so "no row" is never
    " the test (2026-11-08)
    DATA(lv_key) = CONV ty_docno( is_after-wm_key ).
    SELECT p~doc1r, k~cpudt, k~cputm
      FROM dpayh AS p
      INNER JOIN dfkkko AS k ON k~opbel = p~doc1r
      WHERE p~xvorl  = @space
        AND p~doc1r <> @space
        AND p~pymet IN @lt_methods
        AND ( k~cpudt > @is_after-wm_date
           OR ( k~cpudt = @is_after-wm_date AND k~cputm > @is_after-wm_time )
           OR ( k~cpudt = @is_after-wm_date AND k~cputm = @is_after-wm_time AND k~opbel > @lv_key ) )
      ORDER BY k~cpudt, k~cputm, p~doc1r
      INTO TABLE @DATA(lt_docs)
      UP TO @iv_max ROWS.
    LOOP AT lt_docs ASSIGNING FIELD-SYMBOL(<ls_doc>).
      INSERT CONV #( <ls_doc>-doc1r ) INTO TABLE rt_docno.
    ENDLOOP.
  ENDMETHOD.


ENDCLASS.
