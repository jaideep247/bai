*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_store.clas.abap
*& Purpose:
*& Repository for the shared result/exception store. The only class that
*& writes ZCD_OPS_RUN and ZCD_OPS_FINDING. Findings of severity B/E/W are
*& created as owned exceptions (status OPEN) with an SLA due date taken from
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
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - DB store (ZCD_OPS_RUN/FINDING/PARAM)</p>
"! Repository for the shared result/exception store. The only class that
"! writes ZCD_OPS_RUN and ZCD_OPS_FINDING. Findings of severity B/E/W are
"! created as owned exceptions (status OPEN) with an SLA due date taken from
"! ZCD_OPS_PARAM SLA_DAYS_<payment engine area>_<severity> (fallback SLA_DAYS_DEFAULT, 1).
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
    "! Partial update: only the columns flagged in COL_IND are written (DETAILS, a
    "! STRING, is neither read with FOR ALL ENTRIES nor overwritten)
    TYPES ty_db_update TYPE zcd_ops_finding WITH INDICATORS col_ind TYPE abap_bool.
    TYPES tt_db_update TYPE STANDARD TABLE OF ty_db_update WITH EMPTY KEY.
    TYPES ty_param_cache TYPE SORTED TABLE OF zif_cd_ops_types=>ty_kv WITH UNIQUE KEY name.

    DATA mt_param_cache TYPE ty_param_cache.
    DATA mv_params_loaded TYPE abap_bool.

    METHODS load_params.

    "! New exceptions inherit from the open / assigned / waived exception of an
    "! earlier run (same payment engine area, object type, object key, check code), which is
    "! superseded. Only rows with disposition O are candidates.
    METHODS carry_forward
      IMPORTING
        is_run   TYPE zif_cd_ops_types=>ty_run
        iv_today TYPE d
      CHANGING
        ct_new   TYPE tt_db_finding
      RAISING
        zcx_cd_ops_error.

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
    " A64: each run reads the parameters valid at its start (snapshot), never the cache
    " of an earlier run in the same internal session
    zif_cd_ops_store~refresh_params( ).
    load_params( ).
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

    carry_forward( EXPORTING is_run   = cs_run
                             iv_today = lv_today
                   CHANGING  ct_new   = lt_db ).

    INSERT zcd_ops_finding FROM TABLE @lt_db.
    IF sy-subrc <> 0.
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
    TYPES:
      BEGIN OF ty_object,
        object_type TYPE zcd_ops_finding-object_type,
        object_key  TYPE zcd_ops_finding-object_key,
      END OF ty_object.
    DATA lt_keys TYPE SORTED TABLE OF ty_object WITH UNIQUE KEY object_type object_key.
    DATA ls_object TYPE ty_object.
    DATA lt_prev TYPE tt_db_finding.
    DATA lt_superseded TYPE tt_db_update.
    DATA ls_superseded TYPE ty_db_update.

    " Fix 5: the object type of every candidate is known - only (type, key) pairs are read
    LOOP AT ct_new ASSIGNING FIELD-SYMBOL(<ls_candidate>) WHERE disposition = zif_cd_ops_types=>gc_disposition-open.
      ls_object-object_type = <ls_candidate>-object_type.
      ls_object-object_key  = <ls_candidate>-object_key.
      INSERT ls_object INTO TABLE lt_keys.
    ENDLOOP.
    CHECK lt_keys IS NOT INITIAL.

    " index ZCD_OPS_FINDING~OBJ: MANDT, PE_AREA, OBJECT_KEY (fix 5; OBJECT_TYPE is a filter)
    SELECT run_id, finding_no, object_type, object_key, check_code, disposition, owner,
           due_date, resolution, created_at, first_seen_at, occurrences, superseded_by, waiver_until,
           waiver_req_by, waiver_req_at, waiver_reason
      FROM zcd_ops_finding
      FOR ALL ENTRIES IN @lt_keys
      WHERE pe_area      = @is_run-pe_area
        AND object_key  = @lt_keys-object_key
        AND object_type = @lt_keys-object_type
        AND run_id     <> @is_run-run_id
        AND disposition IN ( @zif_cd_ops_types=>gc_disposition-open,
                             @zif_cd_ops_types=>gc_disposition-assigned,
                             @zif_cd_ops_types=>gc_disposition-waived )
      INTO CORRESPONDING FIELDS OF TABLE @lt_prev.
    CHECK lt_prev IS NOT INITIAL.
    " newest first: the latest earlier row is the one inherited
    SORT lt_prev BY object_type object_key check_code created_at DESCENDING.

    LOOP AT ct_new ASSIGNING FIELD-SYMBOL(<ls_new>) WHERE disposition = zif_cd_ops_types=>gc_disposition-open.
      DATA(lv_inherited) = abap_false.
      " Fix 5: first row of the (type, key, check) block by binary search on the sort order
      " above - a sorted key could not keep CREATED_AT descending inside the block
      READ TABLE lt_prev TRANSPORTING NO FIELDS
           WITH KEY object_type = <ls_new>-object_type
                    object_key  = <ls_new>-object_key
                    check_code  = <ls_new>-check_code
           BINARY SEARCH.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA(lv_first) = sy-tabix.
      LOOP AT lt_prev ASSIGNING FIELD-SYMBOL(<ls_prev>) FROM lv_first.
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
        CLEAR ls_superseded.
        ls_superseded-run_id                = <ls_prev>-run_id.
        ls_superseded-finding_no            = <ls_prev>-finding_no.
        ls_superseded-disposition           = zif_cd_ops_types=>gc_disposition-superseded.
        ls_superseded-superseded_by         = is_run-run_id.
        ls_superseded-col_ind-disposition   = abap_true.
        ls_superseded-col_ind-superseded_by = abap_true.
        INSERT ls_superseded INTO TABLE lt_superseded.
      ENDLOOP.
    ENDLOOP.

    CHECK lt_superseded IS NOT INITIAL.
    UPDATE zcd_ops_finding FROM TABLE @lt_superseded INDICATORS SET STRUCTURE col_ind.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e011(zcd_ops) WITH 'ZCD_OPS_FINDING'.
    ENDIF.
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
      SELECT run_id, finding_no, object_type, object_key, check_code, disposition, owner,
             due_date, resolution, created_at, first_seen_at, occurrences, superseded_by, waiver_until
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
      SELECT run_id, finding_no, object_type, object_key, check_code, disposition, owner,
             due_date, resolution, created_at, first_seen_at, occurrences, superseded_by, waiver_until
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

    DATA lt_resolved TYPE tt_db_update.
    DATA ls_resolved TYPE ty_db_update.
    DATA(lv_now) = zcl_cd_ops_factory=>get_clock( )->now( ).
    LOOP AT lt_open ASSIGNING FIELD-SYMBOL(<ls_open>).
      CLEAR ls_resolved.
      ls_resolved-run_id              = <ls_open>-run_id.
      ls_resolved-finding_no          = <ls_open>-finding_no.
      ls_resolved-disposition         = zif_cd_ops_types=>gc_disposition-resolved.
      ls_resolved-resolved_by         = sy-uname.
      ls_resolved-resolved_at         = lv_now.
      ls_resolved-resolution          = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_types=>gc_msg-passed_on_rerun
                                                             iv_v1    = |{ is_run-run_id }| ).
      ls_resolved-col_ind-disposition = abap_true.
      ls_resolved-col_ind-resolved_by = abap_true.
      ls_resolved-col_ind-resolved_at = abap_true.
      ls_resolved-col_ind-resolution  = abap_true.
      INSERT ls_resolved INTO TABLE lt_resolved.
    ENDLOOP.
    UPDATE zcd_ops_finding FROM TABLE @lt_resolved INDICATORS SET STRUCTURE col_ind.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e011(zcd_ops) WITH 'ZCD_OPS_FINDING'.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_store~commit.
    COMMIT WORK.
  ENDMETHOD.


  METHOD zif_cd_ops_store~rollback.
    ROLLBACK WORK.
  ENDMETHOD.


  METHOD zif_cd_ops_store~refresh_params.
    CLEAR: mt_param_cache, mv_params_loaded.
  ENDMETHOD.


  METHOD zif_cd_ops_store~get_param.
    load_params( ).
    READ TABLE mt_param_cache INTO DATA(ls_param) WITH TABLE KEY name = iv_name.
    IF sy-subrc = 0 AND ls_param-value IS NOT INITIAL.
      rv_value = condense( CONV string( ls_param-value ) ).
    ELSE.
      rv_value = iv_default.
    ENDIF.
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


  METHOD load_params.
    IF mv_params_loaded = abap_true.
      RETURN.
    ENDIF.
    SELECT param_name AS name, param_value AS value
      FROM zcd_ops_param
      INTO CORRESPONDING FIELDS OF TABLE @mt_param_cache.
    mv_params_loaded = abap_true.
  ENDMETHOD.


  METHOD sla_days.
    DATA(lv_value) = zif_cd_ops_store~get_param(
      iv_name    = CONV #( |SLA_DAYS_{ iv_pe_area }_{ iv_severity }| )
      iv_default = zif_cd_ops_store~get_param( iv_name    = 'SLA_DAYS_DEFAULT'
                                               iv_default = `1` ) ).
    rv_days = zcl_cd_ops_util=>to_decimal( iv_value = lv_value iv_default = 1 ).
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
