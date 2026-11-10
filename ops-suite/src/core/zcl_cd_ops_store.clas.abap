*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_store.clas.abap
*& Purpose:
*& Repository for the shared result/exception store. The only class that
*& writes ZCD_OPS_RUN and ZCD_OPS_FINDING. Findings of severity B/E/W are
*& created as owned exceptions (status OPEN) with an SLA due date taken from
*& the parameters SLA_DAYS_<area>_<severity> / SLA_DAYS_DEFAULT (ZCA_PARAM,
*& read through ZCL_CD_OPS_FACTORY=>GET_PARAMS).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | rollback( ) added.
*& 2026-11-06 | Exception carry-forward in save_findings; reconcile( ) auto-resolves.
*& 2026-11-06 | Carry-forward keeps a pending waiver request (exceptions app).
*& 2026-11-06 | Webhook key peArea (rename regression fixed); column names in comments.
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | get_stale_runs: running runs older than a limit, own run excluded (audit A06).
*& 2026-11-06 | Parameter cache is run-scoped: start_run takes a fresh snapshot (audit A64).
*& 2026-11-06 | Performance fix 5: carry-forward reads by (OBJECT_TYPE, OBJECT_KEY) pairs; earlier rows found
*&            | by binary search on the sorted read (newest first kept), not a nested WHERE scan.
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-07 | Implements ZIF_CD_OPS_PARAMS (via ZIF_CD_OPS_STORE): get_range (I / EQ rows of the list);
*&            | SLA parameter names / default from ZIF_CD_OPS_TYPES.
*& 2026-11-07 | Parameters moved to ZCA_PARAM: ZCD_OPS_PARAM reads removed; start_run renews the
*&            | snapshot of ZCL_CD_OPS_FACTORY=>GET_PARAMS (A64), SLA days read there.
*& 2026-11-10 | Lost update with the exceptions app (concurrency review): every write sets LAST_CHANGED_AT;
*&            | supersede (carry-forward) and resolve (reconcile) write a row only while its disposition and
*&            | stamp are the ones read (one keyed UPDATE per exception, sy-dbcnt compared); a row a user changed
*&            | meanwhile is read again and carried forward / resolved once more from what the user left, and if
*&            | it changes again it is left for the next run with an information finding EXC_CHANGED_DEFERRED -
*&            | a waiver, assignment or resolution is never overwritten. Findings inserted accepting duplicate
*&            | keys with a count check; numbering continues after the run's highest finding number.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - DB store (ZCD_OPS_RUN / FINDING)</p>
"! Repository for the shared result/exception store. The only class that
"! writes ZCD_OPS_RUN and ZCD_OPS_FINDING. Findings of severity B/E/W are
"! created as owned exceptions (status OPEN) with an SLA due date taken from
"! parameter SLA_DAYS_<payment engine area>_<severity> (fallback SLA_DAYS_DEFAULT, 1; ZCA_PARAM).
CLASS zcl_cd_ops_store DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_store.

    CONSTANTS:
      BEGIN OF gc_disposition,
        open        TYPE c LENGTH 1 VALUE 'O',
        information TYPE c LENGTH 1 VALUE 'I',
      END OF gc_disposition.

  PRIVATE SECTION.
    TYPES tt_db_finding TYPE STANDARD TABLE OF zcd_ops_finding WITH EMPTY KEY.
    "! An exception object of the run: type and key
    TYPES:
      BEGIN OF ty_object,
        object_type TYPE zcd_ops_finding-object_type,
        object_key  TYPE zcd_ops_finding-object_key,
      END OF ty_object.
    TYPES tt_object TYPE SORTED TABLE OF ty_object WITH UNIQUE KEY object_type object_key.
    "! One exception carried forward: object type, key and check code
    TYPES:
      BEGIN OF ty_block,
        object_type TYPE zcd_ops_finding-object_type,
        object_key  TYPE zcd_ops_finding-object_key,
        check_code  TYPE zcd_ops_finding-check_code,
      END OF ty_block.
    TYPES tt_block TYPE SORTED TABLE OF ty_block WITH UNIQUE KEY object_type object_key check_code.

    "! New exceptions inherit from the open / assigned / waived exception of an
    "! earlier run (same payment engine area, object type, object key, check code), which is
    "! superseded. Only rows with disposition O are candidates. A superseded row is written only while it
    "! is as read; a row a user changed meanwhile is read and carried forward once more, and if it changed
    "! again the new row stays information and an information finding says so (the user's change wins)
    METHODS carry_forward
      IMPORTING
        iv_today TYPE d
      CHANGING
        cs_run   TYPE zif_cd_ops_types=>ty_run
        ct_new   TYPE tt_db_finding
      RAISING
        zcx_cd_ops_error.

    "! The open / assigned / waived exceptions of earlier runs of the objects, newest first per block
    "! (type, key, check code)
    METHODS read_prev
      IMPORTING
        is_run         TYPE zif_cd_ops_types=>ty_run
        it_keys        TYPE tt_object
      RETURNING
        VALUE(rt_prev) TYPE tt_db_finding.

    "! Inherit and supersede (guarded) for the new open exceptions found in ct_prev; the exceptions whose
    "! earlier row was changed by someone else meanwhile
    METHODS supersede
      IMPORTING
        is_run              TYPE zif_cd_ops_types=>ty_run
        iv_today            TYPE d
        iv_now              TYPE timestampl
      CHANGING
        ct_prev             TYPE tt_db_finding
        ct_new              TYPE tt_db_finding
      RETURNING
        VALUE(rt_conflicts) TYPE tt_block.

    "! Supersede one earlier row only while its disposition and change stamp are the ones read
    "! (optimistic lock against the exceptions app); abap_false = changed meanwhile, nothing written
    METHODS guarded_supersede
      IMPORTING
        is_read        TYPE zcd_ops_finding
        iv_run_id      TYPE zif_cd_ops_types=>ty_run_id
        iv_now         TYPE timestampl
      RETURNING
        VALUE(rv_done) TYPE abap_bool.

    "! Resolve one exception only while its disposition and change stamp are the ones read; abap_false =
    "! changed meanwhile, nothing written
    METHODS guarded_resolve
      IMPORTING
        is_read        TYPE zcd_ops_finding
        is_change      TYPE zcd_ops_finding
      RETURNING
        VALUE(rv_done) TYPE abap_bool.

    "! The objects of exceptions (for a read by type and key)
    CLASS-METHODS objects_of
      IMPORTING
        it_blocks         TYPE tt_block
      RETURNING
        VALUE(rt_objects) TYPE tt_object.

    "! Resolve the rows (guarded); the rows changed meanwhile
    METHODS resolve_rows
      IMPORTING
        is_run            TYPE zif_cd_ops_types=>ty_run
        it_open           TYPE tt_db_finding
      RETURNING
        VALUE(rt_changed) TYPE tt_db_finding.

    "! Information finding of an exception left for the next run (changed by a user twice during the run)
    METHODS deferred
      IMPORTING
        is_row            TYPE zcd_ops_finding
        iv_finding_no     TYPE i
        iv_now            TYPE timestampl
      RETURNING
        VALUE(rs_finding) TYPE zcd_ops_finding.

    "! Highest finding number of the run in the store (reconcile may have written information findings)
    METHODS last_finding_no
      IMPORTING
        iv_run_id    TYPE zif_cd_ops_types=>ty_run_id
      RETURNING
        VALUE(rv_no) TYPE i.

    METHODS inherit
      IMPORTING
        is_prev  TYPE zcd_ops_finding
        iv_today TYPE d
      CHANGING
        cs_new   TYPE zcd_ops_finding.

    METHODS sla_days
      IMPORTING
        iv_pe_area      TYPE zif_cd_ops_types=>ty_pe_area
        iv_severity    TYPE zif_cd_ops_types=>ty_severity
      RETURNING
        VALUE(rv_days) TYPE i.

    METHODS map_run_to_db
      IMPORTING
        is_run       TYPE zif_cd_ops_types=>ty_run
      RETURNING
        VALUE(rs_db) TYPE zcd_ops_run.

    METHODS map_run_from_db
      IMPORTING
        is_db         TYPE zcd_ops_run
      RETURNING
        VALUE(rs_run) TYPE zif_cd_ops_types=>ty_run.

ENDCLASS.



CLASS zcl_cd_ops_store IMPLEMENTATION.

  METHOD zif_cd_ops_store~start_run.
    " A64: each run reads the parameters valid at its start (snapshot), never the buffer
    " of an earlier run in the same internal session
    zcl_cd_ops_factory=>get_params( )->refresh_params( ).
    DATA(lo_clock) = zcl_cd_ops_factory=>get_clock( ).
    TRY.
        rs_run-run_id = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error INTO DATA(lx_uuid).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e001(zcd_ops)
          EXPORTING
            previous = lx_uuid.
    ENDTRY.
    rs_run-pe_area     = iv_pe_area.
    rs_run-variant    = iv_variant.
    rs_run-test_mode  = iv_test_mode.
    rs_run-started_at = lo_clock->now( ).
    rs_run-status     = zif_cd_ops_types=>gc_run_status-running.
    rs_run-rag        = zif_cd_ops_types=>gc_rag-grey.
    rs_run-created_by = sy-uname.

    IF iv_test_mode = abap_true.
      RETURN.
    ENDIF.

    DATA(ls_db) = map_run_to_db( rs_run ).
    INSERT zcd_ops_run FROM @ls_db.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e010(zcd_ops) WITH 'ZCD_OPS_RUN'.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_store~save_findings.
    DATA lt_db TYPE STANDARD TABLE OF zcd_ops_finding WITH EMPTY KEY.
    DATA ls_db TYPE zcd_ops_finding.

    IF it_findings IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lo_clock) = zcl_cd_ops_factory=>get_clock( ).
    DATA(lv_today) = lo_clock->today( ).
    DATA(lv_now)   = lo_clock->now( ).
    DATA(lv_seq)   = cs_run-finding_count.
    IF cs_run-test_mode = abap_false.
      " Numbering continues after the highest number stored (a deferred information finding of reconcile)
      lv_seq = nmax( val1 = lv_seq val2 = last_finding_no( cs_run-run_id ) ).
    ENDIF.

    LOOP AT it_findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
      lv_seq += 1.
      CLEAR ls_db.
      ls_db-run_id      = cs_run-run_id.
      ls_db-finding_no  = lv_seq.
      ls_db-pe_area      = cs_run-pe_area.
      ls_db-object_type = <ls_finding>-object_type.
      ls_db-object_key  = <ls_finding>-object_key.
      ls_db-group1      = <ls_finding>-group1.
      ls_db-group2      = <ls_finding>-group2.
      ls_db-rule_id     = <ls_finding>-rule_id.
      ls_db-check_code  = <ls_finding>-check_code.
      ls_db-severity    = <ls_finding>-severity.
      ls_db-action      = <ls_finding>-action.
      ls_db-amount      = <ls_finding>-amount.
      ls_db-currency    = <ls_finding>-currency.
      ls_db-reference   = <ls_finding>-reference.
      ls_db-message     = <ls_finding>-message.
      ls_db-details     = <ls_finding>-details.
      ls_db-created_at  = lv_now.
      ls_db-created_by  = sy-uname.
      ls_db-last_changed_at = lv_now.
      ls_db-first_seen_at = lv_now.
      ls_db-occurrences   = 1.
      IF zcl_cd_ops_util=>severity_rank( <ls_finding>-severity ) >= 2.
        ls_db-disposition = gc_disposition-open.
        ls_db-due_date    = lv_today + sla_days( iv_pe_area   = cs_run-pe_area
                                                 iv_severity = <ls_finding>-severity ).
      ELSE.
        ls_db-disposition = gc_disposition-information.
      ENDIF.
      INSERT ls_db INTO TABLE lt_db.
    ENDLOOP.

    cs_run-finding_count = lv_seq.

    IF cs_run-test_mode = abap_true.
      RETURN.
    ENDIF.

    carry_forward( EXPORTING iv_today = lv_today
                   CHANGING  cs_run   = cs_run
                             ct_new   = lt_db ).

    " A duplicate key is a sy-subrc / count here, never CX_SY_OPEN_SQL_DB (the caller rolls back)
    INSERT zcd_ops_finding FROM TABLE @lt_db ACCEPTING DUPLICATE KEYS.
    IF sy-subrc <> 0 OR sy-dbcnt <> lines( lt_db ).
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e010(zcd_ops) WITH 'ZCD_OPS_FINDING'.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_store~finish_run.
    IF is_run-test_mode = abap_true.
      RETURN.
    ENDIF.
    DATA(ls_db) = map_run_to_db( is_run ).
    UPDATE zcd_ops_run FROM @ls_db.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e011(zcd_ops) WITH 'ZCD_OPS_RUN'.
    ENDIF.
  ENDMETHOD.


  METHOD carry_forward.
    DATA lt_keys TYPE tt_object.
    DATA ls_object TYPE ty_object.

    " Fix 5: the object type of every candidate is known - only (type, key) pairs are read
    LOOP AT ct_new ASSIGNING FIELD-SYMBOL(<ls_candidate>) WHERE disposition = zif_cd_ops_types=>gc_disposition-open.
      ls_object-object_type = <ls_candidate>-object_type.
      ls_object-object_key  = <ls_candidate>-object_key.
      INSERT ls_object INTO TABLE lt_keys.
    ENDLOOP.
    CHECK lt_keys IS NOT INITIAL.
    DATA(lt_original) = ct_new.
    DATA(lo_clock) = zcl_cd_ops_factory=>get_clock( ).

    DATA(lt_prev) = read_prev( is_run = cs_run it_keys = lt_keys ).
    CHECK lt_prev IS NOT INITIAL.
    DATA(lt_conflicts) = supersede( EXPORTING is_run   = cs_run
                                              iv_today = iv_today
                                              iv_now   = lo_clock->now( )
                                    CHANGING  ct_prev  = lt_prev
                                              ct_new   = ct_new ).
    IF lt_conflicts IS INITIAL.
      RETURN.
    ENDIF.

    " A user changed an earlier row between the read and the write (exceptions app): those exceptions are
    " read again and carried forward once more from what the user left - e.g. a waiver given meanwhile
    LOOP AT ct_new ASSIGNING FIELD-SYMBOL(<ls_redo>).
      IF line_exists( lt_conflicts[ object_type = <ls_redo>-object_type
                                    object_key  = <ls_redo>-object_key
                                    check_code  = <ls_redo>-check_code ] ).
        <ls_redo> = lt_original[ sy-tabix ].
      ENDIF.
    ENDLOOP.
    lt_prev = read_prev( is_run = cs_run it_keys = objects_of( lt_conflicts ) ).
    lt_conflicts = supersede( EXPORTING is_run   = cs_run
                                        iv_today = iv_today
                                        iv_now   = lo_clock->now( )
                              CHANGING  ct_prev  = lt_prev
                                        ct_new   = ct_new ).
    IF lt_conflicts IS INITIAL.
      RETURN.
    ENDIF.

    " Changed again: the user's disposition wins - the new row of the run stays information (the earlier
    " row remains the exception) and the next run carries it forward; said once per exception
    DATA(lv_now) = lo_clock->now( ).
    DATA(lt_info) = VALUE tt_db_finding( ).
    LOOP AT ct_new ASSIGNING FIELD-SYMBOL(<ls_left>) WHERE disposition <> zif_cd_ops_types=>gc_disposition-information.
      IF NOT line_exists( lt_conflicts[ object_type = <ls_left>-object_type
                                        object_key  = <ls_left>-object_key
                                        check_code  = <ls_left>-check_code ] ).
        CONTINUE.
      ENDIF.
      <ls_left> = lt_original[ sy-tabix ].
      <ls_left>-disposition = zif_cd_ops_types=>gc_disposition-information.
      CLEAR <ls_left>-due_date.
      cs_run-finding_count = cs_run-finding_count + 1.
      INSERT deferred( is_row = <ls_left> iv_finding_no = cs_run-finding_count iv_now = lv_now ) INTO TABLE lt_info.
    ENDLOOP.
    INSERT LINES OF lt_info INTO TABLE ct_new.
  ENDMETHOD.


  METHOD read_prev.
    CHECK it_keys IS NOT INITIAL.
    " index ZCD_OPS_FINDING~OBJ: MANDT, PE_AREA, OBJECT_KEY (fix 5; OBJECT_TYPE is a filter)
    SELECT run_id, finding_no, object_type, object_key, check_code, disposition, owner,
           due_date, resolution, created_at, first_seen_at, occurrences, superseded_by, waiver_until,
           waiver_req_by, waiver_req_at, waiver_reason, last_changed_at
      FROM zcd_ops_finding
      FOR ALL ENTRIES IN @it_keys
      WHERE pe_area      = @is_run-pe_area
        AND object_key  = @it_keys-object_key
        AND object_type = @it_keys-object_type
        AND run_id     <> @is_run-run_id
        AND disposition IN ( @zif_cd_ops_types=>gc_disposition-open,
                             @zif_cd_ops_types=>gc_disposition-assigned,
                             @zif_cd_ops_types=>gc_disposition-waived )
      INTO CORRESPONDING FIELDS OF TABLE @rt_prev.
    " newest first: the latest earlier row is the one inherited
    SORT rt_prev BY object_type object_key check_code created_at DESCENDING.
  ENDMETHOD.


  METHOD objects_of.
    LOOP AT it_blocks ASSIGNING FIELD-SYMBOL(<ls_block>).
      INSERT VALUE #( object_type = <ls_block>-object_type object_key = <ls_block>-object_key ) INTO TABLE rt_objects.
    ENDLOOP.
  ENDMETHOD.


  METHOD supersede.
    LOOP AT ct_new ASSIGNING FIELD-SYMBOL(<ls_new>) WHERE disposition = zif_cd_ops_types=>gc_disposition-open.
      DATA(lv_inherited) = abap_false.
      " Fix 5: first row of the (type, key, check) block by binary search on the sort order
      " above - a sorted key could not keep CREATED_AT descending inside the block
      READ TABLE ct_prev TRANSPORTING NO FIELDS
           WITH KEY object_type = <ls_new>-object_type
                    object_key  = <ls_new>-object_key
                    check_code  = <ls_new>-check_code
           BINARY SEARCH.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA(lv_first) = sy-tabix.
      LOOP AT ct_prev ASSIGNING FIELD-SYMBOL(<ls_prev>) FROM lv_first.
        IF <ls_prev>-object_type <> <ls_new>-object_type
           OR <ls_prev>-object_key <> <ls_new>-object_key
           OR <ls_prev>-check_code <> <ls_new>-check_code.
          EXIT.
        ENDIF.
        IF <ls_prev>-superseded_by IS NOT INITIAL.
          CONTINUE.
        ENDIF.
        IF lv_inherited = abap_false.
          inherit( EXPORTING is_prev  = <ls_prev>
                             iv_today = iv_today
                   CHANGING  cs_new   = <ls_new> ).
          lv_inherited = abap_true.
        ENDIF.
        <ls_prev>-superseded_by = is_run-run_id.
        " Guarded: only while disposition and stamp are as read - never over a user's waiver / owner
        IF guarded_supersede( is_read = <ls_prev> iv_run_id = is_run-run_id iv_now = iv_now ) = abap_false.
          INSERT VALUE #( object_type = <ls_new>-object_type
                          object_key  = <ls_new>-object_key
                          check_code  = <ls_new>-check_code ) INTO TABLE rt_conflicts.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD guarded_supersede.
    " One keyed UPDATE per exception the run supersedes (bounded by the run's own exceptions): ABAP SQL
    " has no set-based compare-and-set - an UPDATE FROM TABLE matches by key only and would overwrite a
    " user's change (Performance_Review.md section 10b)
    UPDATE zcd_ops_finding
      SET disposition     = @zif_cd_ops_types=>gc_disposition-superseded,
          superseded_by   = @iv_run_id,
          last_changed_at = @iv_now
      WHERE run_id          = @is_read-run_id
        AND finding_no      = @is_read-finding_no
        AND disposition     = @is_read-disposition
        AND last_changed_at = @is_read-last_changed_at.
    rv_done = xsdbool( sy-subrc = 0 AND sy-dbcnt = 1 ).
  ENDMETHOD.


  METHOD guarded_resolve.
    " One keyed UPDATE per exception the run resolves, as GUARDED_SUPERSEDE
    UPDATE zcd_ops_finding
      SET disposition     = @is_change-disposition,
          resolved_by     = @is_change-resolved_by,
          resolved_at     = @is_change-resolved_at,
          resolution      = @is_change-resolution,
          last_changed_at = @is_change-last_changed_at
      WHERE run_id          = @is_read-run_id
        AND finding_no      = @is_read-finding_no
        AND disposition     = @is_read-disposition
        AND last_changed_at = @is_read-last_changed_at.
    rv_done = xsdbool( sy-subrc = 0 AND sy-dbcnt = 1 ).
  ENDMETHOD.


  METHOD deferred.
    rs_finding-run_id          = is_row-run_id.
    rs_finding-finding_no      = iv_finding_no.
    rs_finding-pe_area         = is_row-pe_area.
    rs_finding-object_type     = is_row-object_type.
    rs_finding-object_key      = is_row-object_key.
    rs_finding-group1          = is_row-group1.
    rs_finding-group2          = is_row-group2.
    rs_finding-check_code      = zif_cd_ops_exc_types=>gc_code_deferred.
    rs_finding-severity        = zif_cd_ops_types=>gc_severity-info.
    rs_finding-action          = zif_cd_ops_types=>gc_action-notify.
    rs_finding-message         = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_exc_types=>gc_msg-changed_deferred
                                                        iv_v1    = is_row-object_key
                                                        iv_v2    = is_row-check_code ).
    rs_finding-disposition     = zif_cd_ops_types=>gc_disposition-information.
    rs_finding-occurrences     = 1.
    rs_finding-first_seen_at   = iv_now.
    rs_finding-created_at      = iv_now.
    rs_finding-created_by      = sy-uname.
    rs_finding-last_changed_at = iv_now.
  ENDMETHOD.


  METHOD last_finding_no.
    SELECT MAX( finding_no ) FROM zcd_ops_finding WHERE run_id = @iv_run_id INTO @rv_no.
  ENDMETHOD.


  METHOD inherit.
    cs_new-first_seen_at = COND #( WHEN is_prev-first_seen_at IS INITIAL THEN is_prev-created_at
                                   ELSE is_prev-first_seen_at ).
    cs_new-occurrences   = nmax( val1 = is_prev-occurrences val2 = 1 ) + 1.
    cs_new-owner         = is_prev-owner.
    CASE is_prev-disposition.
      WHEN zif_cd_ops_types=>gc_disposition-waived.
        IF is_prev-waiver_until IS INITIAL OR is_prev-waiver_until >= iv_today.
          " a valid waiver is not reopened by a re-run
          cs_new-disposition  = zif_cd_ops_types=>gc_disposition-waived.
          cs_new-waiver_until = is_prev-waiver_until.
          cs_new-resolution   = is_prev-resolution.
          cs_new-due_date     = is_prev-due_date.
        ENDIF.
        " expired waiver: the new row stays open with a fresh due date
      WHEN OTHERS.
        cs_new-disposition = is_prev-disposition.
        cs_new-due_date    = is_prev-due_date.
        " a waiver request waiting for the second user survives the re-run
        IF is_prev-waiver_req_by IS NOT INITIAL.
          cs_new-waiver_req_by = is_prev-waiver_req_by.
          cs_new-waiver_req_at = is_prev-waiver_req_at.
          cs_new-waiver_reason = is_prev-waiver_reason.
          cs_new-waiver_until  = is_prev-waiver_until.
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_cd_ops_store~reconcile.
    DATA lt_open TYPE tt_db_finding.

    IF is_run-test_mode = abap_true.
      RETURN.
    ENDIF.

    IF it_object_keys IS NOT INITIAL.
      " index ZCD_OPS_FINDING~OBJ: MANDT, PE_AREA, OBJECT_KEY (fix 5: the caller knows no object type)
      SELECT run_id, finding_no, pe_area, object_type, object_key, group1, group2, check_code, disposition,
             owner, due_date, resolution, created_at, first_seen_at, occurrences, superseded_by, waiver_until,
             last_changed_at
        FROM zcd_ops_finding
        FOR ALL ENTRIES IN @it_object_keys
        WHERE pe_area      = @is_run-pe_area
          AND object_key  = @it_object_keys-table_line
          AND run_id     <> @is_run-run_id
          AND disposition IN ( @zif_cd_ops_types=>gc_disposition-open,
                               @zif_cd_ops_types=>gc_disposition-assigned )
        INTO CORRESPONDING FIELDS OF TABLE @lt_open.
    ENDIF.
    IF it_groups IS NOT INITIAL.
      SELECT run_id, finding_no, pe_area, object_type, object_key, group1, group2, check_code, disposition,
             owner, due_date, resolution, created_at, first_seen_at, occurrences, superseded_by, waiver_until,
             last_changed_at
        FROM zcd_ops_finding
        FOR ALL ENTRIES IN @it_groups
        WHERE pe_area      = @is_run-pe_area
          AND group2      = @it_groups-table_line
          AND run_id     <> @is_run-run_id
          AND disposition IN ( @zif_cd_ops_types=>gc_disposition-open,
                               @zif_cd_ops_types=>gc_disposition-assigned )
        APPENDING CORRESPONDING FIELDS OF TABLE @lt_open.
    ENDIF.
    CHECK lt_open IS NOT INITIAL.
    SORT lt_open BY run_id finding_no.
    DELETE ADJACENT DUPLICATES FROM lt_open COMPARING run_id finding_no.

    DATA(lt_changed) = resolve_rows( is_run = is_run it_open = lt_open ).
    IF lt_changed IS INITIAL.
      RETURN.
    ENDIF.
    " A user changed these exceptions between the read and the write: read again - what is still open or
    " assigned is resolved once more; a waiver, resolution or new owner the user gave is never overwritten
    CLEAR lt_open.
    SELECT run_id, finding_no, pe_area, object_type, object_key, group1, group2, check_code, disposition,
           owner, due_date, resolution, created_at, first_seen_at, occurrences, superseded_by, waiver_until,
           last_changed_at
      FROM zcd_ops_finding
      FOR ALL ENTRIES IN @lt_changed
      WHERE run_id     = @lt_changed-run_id
        AND finding_no = @lt_changed-finding_no
        AND disposition IN ( @zif_cd_ops_types=>gc_disposition-open,
                             @zif_cd_ops_types=>gc_disposition-assigned )
      INTO CORRESPONDING FIELDS OF TABLE @lt_open.
    lt_changed = resolve_rows( is_run = is_run it_open = lt_open ).
    IF lt_changed IS INITIAL.
      RETURN.
    ENDIF.
    " Changed again: left for the next run, said once per exception (numbered after the run's highest)
    DATA(lv_now) = zcl_cd_ops_factory=>get_clock( )->now( ).
    DATA(lv_no) = last_finding_no( is_run-run_id ).
    DATA(lt_info) = VALUE tt_db_finding( ).
    LOOP AT lt_changed ASSIGNING FIELD-SYMBOL(<ls_changed>).
      lv_no = lv_no + 1.
      DATA(ls_info) = deferred( is_row = <ls_changed> iv_finding_no = lv_no iv_now = lv_now ).
      ls_info-run_id = is_run-run_id.
      INSERT ls_info INTO TABLE lt_info.
    ENDLOOP.
    INSERT zcd_ops_finding FROM TABLE @lt_info ACCEPTING DUPLICATE KEYS.
    IF sy-subrc <> 0 OR sy-dbcnt <> lines( lt_info ).
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e010(zcd_ops) WITH 'ZCD_OPS_FINDING'.
    ENDIF.
  ENDMETHOD.


  METHOD resolve_rows.
    DATA ls_change TYPE zcd_ops_finding.
    ls_change-disposition     = zif_cd_ops_types=>gc_disposition-resolved.
    ls_change-resolved_by     = sy-uname.
    ls_change-resolved_at     = zcl_cd_ops_factory=>get_clock( )->now( ).
    ls_change-last_changed_at = ls_change-resolved_at.
    ls_change-resolution      = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_types=>gc_msg-passed_on_rerun
                                                       iv_v1    = |{ is_run-run_id }| ).
    LOOP AT it_open ASSIGNING FIELD-SYMBOL(<ls_open>).
      IF guarded_resolve( is_read = <ls_open> is_change = ls_change ) = abap_false.
        INSERT <ls_open> INTO TABLE rt_changed.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ops_store~commit.
    COMMIT WORK.
  ENDMETHOD.


  METHOD zif_cd_ops_store~rollback.
    ROLLBACK WORK.
  ENDMETHOD.


  METHOD zif_cd_ops_store~get_last_run.
    DATA lt_db TYPE STANDARD TABLE OF zcd_ops_run WITH EMPTY KEY.
    IF iv_variant IS INITIAL.
      SELECT run_id, pe_area, variant, test_mode, started_at, ended_at, status, rag,
             total_items, passed_items, failed_items, blocked_items, warning_items,
             finding_count, runtime_ms, message, created_by
        FROM zcd_ops_run
        WHERE pe_area    = @iv_pe_area
          AND test_mode = @abap_false
          AND status   <> @zif_cd_ops_types=>gc_run_status-running
        ORDER BY started_at DESCENDING
        INTO CORRESPONDING FIELDS OF TABLE @lt_db
        UP TO 1 ROWS.
    ELSE.
      SELECT run_id, pe_area, variant, test_mode, started_at, ended_at, status, rag,
             total_items, passed_items, failed_items, blocked_items, warning_items,
             finding_count, runtime_ms, message, created_by
        FROM zcd_ops_run
        WHERE pe_area    = @iv_pe_area
          AND variant   = @iv_variant
          AND test_mode = @abap_false
          AND status   <> @zif_cd_ops_types=>gc_run_status-running
        ORDER BY started_at DESCENDING
        INTO CORRESPONDING FIELDS OF TABLE @lt_db
        UP TO 1 ROWS.
    ENDIF.
    READ TABLE lt_db INTO DATA(ls_db) INDEX 1.
    IF sy-subrc = 0.
      rs_run = map_run_from_db( ls_db ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_store~get_stale_runs.
    SELECT run_id, pe_area, variant, test_mode, started_at, ended_at, status, rag,
           total_items, passed_items, failed_items, blocked_items, warning_items,
           finding_count, runtime_ms, message, created_by
      FROM zcd_ops_run
      WHERE pe_area    = @iv_pe_area
        AND test_mode  = @abap_false
        AND status     = @zif_cd_ops_types=>gc_run_status-running
        AND started_at < @iv_started_before
        AND run_id    <> @iv_exclude_run
      ORDER BY started_at, run_id
      INTO TABLE @DATA(lt_db).
    LOOP AT lt_db ASSIGNING FIELD-SYMBOL(<ls_db>).
      DATA(ls_full) = CORRESPONDING zcd_ops_run( <ls_db> ).
      INSERT map_run_from_db( ls_full ) INTO TABLE rt_runs.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ops_store~get_runs_since.
    SELECT run_id, pe_area, variant, test_mode, started_at, ended_at, status, rag,
           total_items, passed_items, failed_items, blocked_items, warning_items,
           finding_count, runtime_ms, message, created_by
      FROM zcd_ops_run
      WHERE pe_area      = @iv_pe_area
        AND test_mode   = @abap_false
        AND started_at >= @iv_since
      ORDER BY started_at
      INTO TABLE @DATA(lt_db).
    LOOP AT lt_db ASSIGNING FIELD-SYMBOL(<ls_db>).
      DATA(ls_full) = CORRESPONDING zcd_ops_run( <ls_db> ).
      INSERT map_run_from_db( ls_full ) INTO TABLE rt_runs.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ops_store~get_findings.
    SELECT object_type, object_key, group1, group2, rule_id, check_code, severity,
           action, amount, currency, reference, message, details
      FROM zcd_ops_finding
      WHERE run_id = @iv_run_id
      ORDER BY finding_no
      INTO CORRESPONDING FIELDS OF TABLE @rt_findings.
  ENDMETHOD.


  METHOD sla_days.
    DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
    DATA(lv_value) = lo_params->get_param(
      iv_name    = CONV #( |{ zif_cd_ops_types=>gc_param_prefix-sla_days }{ iv_pe_area }_{ iv_severity }| )
      iv_default = lo_params->get_param( iv_name    = zif_cd_ops_types=>gc_param-sla_days_default
                                         iv_default = |{ zif_cd_ops_types=>gc_param_default-sla_days }| ) ).
    rv_days = zcl_cd_ops_util=>to_decimal( iv_value = lv_value iv_default = zif_cd_ops_types=>gc_param_default-sla_days ).
  ENDMETHOD.


  METHOD map_run_to_db.
    rs_db-run_id        = is_run-run_id.
    rs_db-pe_area        = is_run-pe_area.
    rs_db-variant       = is_run-variant.
    rs_db-test_mode     = is_run-test_mode.
    rs_db-started_at    = is_run-started_at.
    rs_db-ended_at      = is_run-ended_at.
    rs_db-status        = is_run-status.
    rs_db-rag           = is_run-rag.
    rs_db-total_items   = is_run-total_items.
    rs_db-passed_items  = is_run-passed_items.
    rs_db-failed_items  = is_run-failed_items.
    rs_db-blocked_items = is_run-blocked_items.
    rs_db-warning_items = is_run-warning_items.
    rs_db-finding_count = is_run-finding_count.
    rs_db-runtime_ms    = is_run-runtime_ms.
    rs_db-message       = is_run-message.
    rs_db-created_by    = is_run-created_by.
  ENDMETHOD.


  METHOD map_run_from_db.
    rs_run-run_id        = is_db-run_id.
    rs_run-pe_area        = is_db-pe_area.
    rs_run-variant       = is_db-variant.
    rs_run-test_mode     = is_db-test_mode.
    rs_run-started_at    = is_db-started_at.
    rs_run-ended_at      = is_db-ended_at.
    rs_run-status        = is_db-status.
    rs_run-rag           = is_db-rag.
    rs_run-total_items   = is_db-total_items.
    rs_run-passed_items  = is_db-passed_items.
    rs_run-failed_items  = is_db-failed_items.
    rs_run-blocked_items = is_db-blocked_items.
    rs_run-warning_items = is_db-warning_items.
    rs_run-finding_count = is_db-finding_count.
    rs_run-runtime_ms    = is_db-runtime_ms.
    rs_run-message       = is_db-message.
    rs_run-created_by    = is_db-created_by.
  ENDMETHOD.

ENDCLASS.
