*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_dao.clas.abap
*& Purpose:
*& FMON repository - the only FMON class with SQL: customizing reads,
*& file registry (ZCD_FMON_FILE), idempotent event trail (ZCD_FMON_EVENT)
*& and the dynamic read of configured, DDIC-validated legacy tables.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | ATC-equivalent fixes: ORDER BY, CHECK before FOR ALL ENTRIES, sy-subrc, keyless SORT.
*& 2026-11-06 | insert_event: duplicate key re-checked against the business key; EVENT_NO retried (parallel writers).
*& 2026-11-06 | Audit A04 version-checked save (conflicts returned), A05/A49 event key per file
*&              instance, A49 reference lookup by date, A50 open-file upper bound,
*&              A51 approved tables + S_TABU_NAM at the read boundary, A52 half-open range.
*& 2026-11-06 | Performance fix 8: count_legacy - GROUP BY the query fields with COUNT(*) on the same
*&            | validated path as read_legacy (shared select_legacy).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Modern-syntax sweep: INSERT INTO TABLE.
*& 2026-11-07 | get_deadlines (ZCD_FMON_DEADL); SLA and calendar rows read active only (production deactivates).
*& 2026-11-07 | Regenerated files (user 2026-11-07): GEN_GROUP in every registry read, get_group_files
*&            | (index GRP), GROUP_FIELDS of the source rows.
*& 2026-11-08 | get_group_acks: files of generation groups (index GRP) with their ACK_RECEIVED events in one
*&            | statement (LEFT OUTER JOIN ZCD_FMON_EVENT) - status lag of HCK A_INFLIGHT, file-level ACK.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - repository (all FMON SQL)</p>
"! Legacy tables (ZCDT_REGUT, ZCD_ACH_ACK, ZCD_WIRE_ACK, ZCD_CHECK_HIST,
"! ZCD_ACH_RTRV_LOG, ZCD_STRP_POUT_LOG, DFKKRP, DFKKNRK/DFKKNRP, ...) are
"! never named here: READ_LEGACY receives table and field names from
"! customizing after ZCL_CD_FMON_QUERY validated them against the DDIC.
CLASS zcl_cd_fmon_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_dao.

  PRIVATE SECTION.

    "! Rows as read: they exist in the DB, version = CHANGED_AT (audit A04)
    METHODS mark_loaded
      CHANGING
        ct_files TYPE zif_cd_fmon_types=>tt_file.

    "! Table and fields approved in ZCD_FMON_TABWL and display authorisation (audit A51)
    METHODS check_read_allowed
      IMPORTING
        is_query TYPE zif_cd_fmon_types=>ty_query
      RAISING
        zcx_cd_ops_error.

    "! Attempts at a free EVENT_NO when a parallel writer took the same number
    CONSTANTS gc_insert_attempts TYPE i VALUE 3.

    "! The business event (SRC_ID + SRC_KEY + STAGE) is already recorded
    METHODS event_exists
      IMPORTING
        is_event         TYPE zif_cd_fmon_types=>ty_event
      RETURNING
        VALUE(rv_exists) TYPE abap_bool.

    "! Fix 8: alias of the row count in the grouped read and its SQL expression
    CONSTANTS gc_count_alias TYPE string VALUE `ROW_COUNT`.
    CONSTANTS gc_count_expression TYPE string VALUE `, COUNT(*) AS ROW_COUNT`.

    "! The validated dynamic read of read_legacy; with iv_count the rows are grouped by the
    "! query fields and counted (fix 8) instead of returned one by one
    METHODS select_legacy
      IMPORTING
        is_query         TYPE zif_cd_fmon_types=>ty_query
        iv_count         TYPE abap_bool
      RETURNING
        VALUE(rt_counts) TYPE zif_cd_fmon_types=>tt_raw_count
      RAISING
        zcx_cd_ops_error.

    "! Fix 8: result table of the grouped read - the query fields with their DDIC types plus
    "! ROW_COUNT (INT8)
    METHODS count_table
      IMPORTING
        iv_table       TYPE string
        is_query       TYPE zif_cd_fmon_types=>ty_query
      RETURNING
        VALUE(rr_rows) TYPE REF TO data
      RAISING
        zcx_cd_ops_error.

    "! De-duplicated, comma-separated field list (strict mode) for the dynamic SELECT
    METHODS field_list
      IMPORTING
        is_query         TYPE zif_cd_fmon_types=>ty_query
      RETURNING
        VALUE(rv_fields) TYPE string
      RAISING
        zcx_cd_ops_error.

ENDCLASS.



CLASS zcl_cd_fmon_dao IMPLEMENTATION.

  METHOD zif_cd_fmon_dao~get_ifaces.
    SELECT iface_id, direction, file_type, source_sys, target_sys, pay_method, lob, bank_key,
           name_pattern, min_bytes, max_bytes, ack_expected, ack_level, owner, active, description
      FROM zcd_fmon_iface
      WHERE active = @abap_true
      INTO CORRESPONDING FIELDS OF TABLE @rt_ifaces.
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~get_slas.
    SELECT iface_id, stage, max_minutes, basis, severity
      FROM zcd_fmon_sla
      WHERE active = @abap_true
      INTO CORRESPONDING FIELDS OF TABLE @rt_slas.
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~get_calendars.
    SELECT iface_id, day_type, expected_count, window_from, window_to, fcal_id
      FROM zcd_fmon_cal
      WHERE active = @abap_true
      INTO CORRESPONDING FIELDS OF TABLE @rt_cals.
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~get_deadlines.
    SELECT iface_id, stage, day_type, due_time, severity, active, description
      FROM zcd_fmon_deadl
      WHERE active = @abap_true
      INTO CORRESPONDING FIELDS OF TABLE @rt_deadlines.
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~get_sources.
    SELECT src_id, iface_id, table_name, file_key_field, file_name_field, date_field, time_field,
           ts_field, status_field, count_field, amount_field, size_field, checksum_field,
           source_field, lob_field, default_stage, adapter_class, active, description, group_fields
      FROM zcd_fmon_src
      WHERE active = @abap_true
      INTO CORRESPONDING FIELDS OF TABLE @rt_sources.
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~get_source_maps.
    SELECT src_id, status_value, stage, info
      FROM zcd_fmon_srcmap
      INTO CORRESPONDING FIELDS OF TABLE @rt_maps.
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~get_lot_configs.
    SELECT iface_id, lot_type, hdr_table, hdr_lot_field, hdr_link_field, item_table,
           item_lot_field, item_key_field, item_status_field, item_link_field, link_by,
           done_values, noc_sla_days, active
      FROM zcd_fmon_lotcfg
      WHERE active = @abap_true
      INTO CORRESPONDING FIELDS OF TABLE @rt_cfgs.
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~get_checks.
    SELECT check_id, class_name, severity, active, params, description
      FROM zcd_fmon_chk
      WHERE active = @abap_true
      INTO CORRESPONDING FIELDS OF TABLE @rt_checks.
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~find_files_by_ref.
    CHECK it_keys IS NOT INITIAL.
    SELECT file_id, iface_id, file_ref, direction, file_type, source_sys, lob, pay_method, file_name,
           business_date, size_bytes, size_known, record_count, control_total, checksum, stage, outcome,
           unprocessed_count, ack_count, ack_amount, nack_count, origin_rows, first_event_at,
           last_event_at, src_id, src_key, created_at, changed_at, changed_by, gen_group
      FROM zcd_fmon_file
      FOR ALL ENTRIES IN @it_keys
      WHERE iface_id       = @it_keys-iface_id
        AND file_ref       = @it_keys-file_ref
        AND business_date >= @iv_since
      INTO CORRESPONDING FIELDS OF TABLE @rt_files.
    mark_loaded( CHANGING ct_files = rt_files ).
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~get_group_files.
    CHECK it_keys IS NOT INITIAL.
    " index GRP: MANDT, IFACE_ID, GEN_GROUP - the generations of the payment runs in the run
    SELECT file_id, iface_id, file_ref, direction, file_type, source_sys, lob, pay_method, file_name,
           business_date, size_bytes, size_known, record_count, control_total, checksum, stage, outcome,
           unprocessed_count, ack_count, ack_amount, nack_count, origin_rows, first_event_at,
           last_event_at, src_id, src_key, created_at, changed_at, changed_by, gen_group
      FROM zcd_fmon_file
      FOR ALL ENTRIES IN @it_keys
      WHERE iface_id       = @it_keys-iface_id
        AND gen_group      = @it_keys-gen_group
        AND business_date >= @iv_since
      INTO CORRESPONDING FIELDS OF TABLE @rt_files.
    SORT rt_files BY file_id.
    mark_loaded( CHANGING ct_files = rt_files ).
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~get_group_acks.
    CHECK it_keys IS NOT INITIAL.
    " index GRP (MANDT, IFACE_ID, GEN_GROUP) for the files, the event key (FILE_ID) for their ACKs;
    " a file without ACK event comes back once with ACK_AT initial (it may be the latest generation)
    SELECT f~file_id, f~iface_id, f~gen_group, f~file_ref, f~file_name, f~first_event_at,
           e~event_at AS ack_at
      FROM zcd_fmon_file AS f
        LEFT OUTER JOIN zcd_fmon_event AS e
          ON  e~file_id = f~file_id
          AND e~stage   = @zif_cd_fmon_types=>gc_stage-ack
      FOR ALL ENTRIES IN @it_keys
      WHERE f~iface_id       = @it_keys-iface_id
        AND f~gen_group      = @it_keys-gen_group
        AND f~business_date >= @iv_since
      INTO CORRESPONDING FIELDS OF TABLE @rt_acks.
    SORT rt_acks BY file_id ack_at.
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~get_eval_files.
    DATA lv_no_outcome TYPE zif_cd_fmon_types=>ty_stage.
    IF iv_iface_id IS INITIAL.
      SELECT file_id, iface_id, file_ref, direction, file_type, source_sys, lob, pay_method, file_name,
             business_date, size_bytes, size_known, record_count, control_total, checksum, stage, outcome,
             unprocessed_count, ack_count, ack_amount, nack_count, origin_rows, first_event_at,
             last_event_at, src_id, src_key, created_at, changed_at, changed_by, gen_group
        FROM zcd_fmon_file
        WHERE business_date BETWEEN @iv_date_from AND @iv_date_to
           OR ( business_date >= @iv_open_since
                AND business_date <= @iv_date_to
                AND ( outcome = @lv_no_outcome OR outcome = @zif_cd_fmon_types=>gc_stage-partially ) )
        ORDER BY business_date, file_id
        INTO CORRESPONDING FIELDS OF TABLE @rt_files.
    ELSE.
      SELECT file_id, iface_id, file_ref, direction, file_type, source_sys, lob, pay_method, file_name,
             business_date, size_bytes, size_known, record_count, control_total, checksum, stage, outcome,
             unprocessed_count, ack_count, ack_amount, nack_count, origin_rows, first_event_at,
             last_event_at, src_id, src_key, created_at, changed_at, changed_by, gen_group
        FROM zcd_fmon_file
        WHERE iface_id = @iv_iface_id
          AND ( business_date BETWEEN @iv_date_from AND @iv_date_to
                OR ( business_date >= @iv_open_since
                     AND business_date <= @iv_date_to
                     AND ( outcome = @lv_no_outcome OR outcome = @zif_cd_fmon_types=>gc_stage-partially ) ) )
        ORDER BY business_date, file_id
        INTO CORRESPONDING FIELDS OF TABLE @rt_files.
    ENDIF.
    mark_loaded( CHANGING ct_files = rt_files ).
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~get_history.
    DATA lt_by_sum TYPE zif_cd_fmon_types=>tt_file.

    IF it_names IS NOT INITIAL.
      SELECT file_id, iface_id, file_ref, direction, file_type, source_sys, lob, pay_method, file_name,
             business_date, size_bytes, size_known, record_count, control_total, checksum, stage, outcome,
             unprocessed_count, ack_count, ack_amount, nack_count, origin_rows, first_event_at,
             last_event_at, src_id, src_key, created_at, changed_at, changed_by, gen_group
        FROM zcd_fmon_file
        FOR ALL ENTRIES IN @it_names
        WHERE file_name      = @it_names-table_line
          AND business_date >= @iv_since
        INTO CORRESPONDING FIELDS OF TABLE @rt_files.
    ENDIF.

    IF it_checksums IS NOT INITIAL.
      SELECT file_id, iface_id, file_ref, direction, file_type, source_sys, lob, pay_method, file_name,
             business_date, size_bytes, size_known, record_count, control_total, checksum, stage, outcome,
             unprocessed_count, ack_count, ack_amount, nack_count, origin_rows, first_event_at,
             last_event_at, src_id, src_key, created_at, changed_at, changed_by, gen_group
        FROM zcd_fmon_file
        FOR ALL ENTRIES IN @it_checksums
        WHERE checksum       = @it_checksums-table_line
          AND business_date >= @iv_since
        INTO CORRESPONDING FIELDS OF TABLE @lt_by_sum.
      INSERT LINES OF lt_by_sum INTO TABLE rt_files.
    ENDIF.

    SORT rt_files BY file_id.
    DELETE ADJACENT DUPLICATES FROM rt_files COMPARING file_id.
    mark_loaded( CHANGING ct_files = rt_files ).
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~get_events.
    CHECK it_file_ids IS NOT INITIAL.
    SELECT file_id, event_no, stage, event_at, src_id, src_key, record_count, amount, info,
           created_by, created_at
      FROM zcd_fmon_event
      FOR ALL ENTRIES IN @it_file_ids
      WHERE file_id = @it_file_ids-table_line
      INTO CORRESPONDING FIELDS OF TABLE @rt_events.
    SORT rt_events BY file_id event_no.
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~save_files.
    DATA ls_db TYPE zcd_fmon_file.
    DATA lv_current TYPE timestampl.

    CHECK it_files IS NOT INITIAL.
    LOOP AT it_files INTO DATA(ls_file).
      ls_db = CORRESPONDING #( ls_file ).
      IF ls_file-db_exists = abap_false.
        INSERT zcd_fmon_file FROM @ls_db.                "#EC CI_IMUD_NESTED
        IF sy-subrc <> 0.
          RAISE EXCEPTION TYPE zcx_cd_ops_error
            MESSAGE e010(zcd_ops) WITH 'ZCD_FMON_FILE'.
        ENDIF.
        CONTINUE.
      ENDIF.
      " Audit A04: lock the row and compare its version with the one this run read;
      " a newer row written meanwhile (manual status, other process) is never overwritten
      SELECT SINGLE FOR UPDATE changed_at                "#EC CI_SEL_NESTED
        FROM zcd_fmon_file
        WHERE file_id = @ls_file-file_id
        INTO @lv_current.
      IF sy-subrc <> 0 OR lv_current <> ls_file-db_version.
        INSERT ls_file-file_id INTO TABLE rt_conflicts.
        CONTINUE.
      ENDIF.
      UPDATE zcd_fmon_file FROM @ls_db.                  "#EC CI_IMUD_NESTED
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e010(zcd_ops) WITH 'ZCD_FMON_FILE'.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD mark_loaded.
    LOOP AT ct_files ASSIGNING FIELD-SYMBOL(<ls_file>).
      <ls_file>-db_exists  = abap_true.
      <ls_file>-db_version = <ls_file>-changed_at.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~insert_event.
    DATA ls_db TYPE zcd_fmon_event.

    IF event_exists( is_event ) = abap_true.
      RETURN.
    ENDIF.

    ls_db = CORRESPONDING #( is_event ).
    ls_db-created_by = sy-uname.
    ls_db-created_at = zcl_cd_ops_factory=>get_clock( )->now( ).

    " EVENT_NO is MAX + 1 per file, so a parallel writer can take the same number and
    " the primary key rejects the insert (sy-subrc 4). sy-subrc 4 alone does not say
    " which key was hit: re-check the business key - recorded means idempotent,
    " otherwise retry with a new number. Any other database error raises
    " CX_SY_OPEN_SQL_DB and the whole LUW is rolled back.
    DO gc_insert_attempts TIMES.
      " Bounded retry (gc_insert_attempts), repeated only after a key collision
      SELECT MAX( event_no )                             "#EC CI_SEL_NESTED
        FROM zcd_fmon_event
        WHERE file_id = @is_event-file_id
        INTO @DATA(lv_last_no).
      ls_db-event_no = lv_last_no + 1.
      INSERT zcd_fmon_event FROM @ls_db.
      IF sy-subrc = 0.
        rv_inserted = abap_true.
        RETURN.
      ENDIF.
      IF event_exists( is_event ) = abap_true.
        RETURN.
      ENDIF.
    ENDDO.

    RAISE EXCEPTION TYPE zcx_cd_ops_error
      MESSAGE e010(zcd_ops) WITH 'ZCD_FMON_EVENT'.
  ENDMETHOD.


  METHOD event_exists.
    " Unique secondary index SRC: FILE_ID / SRC_ID / SRC_KEY / STAGE - at most one row;
    " the file instance is part of the key (audit A49: same reference, other business date)
    SELECT file_id
      FROM zcd_fmon_event
      WHERE file_id = @is_event-file_id
        AND src_id  = @is_event-src_id
        AND src_key = @is_event-src_key
        AND stage   = @is_event-stage
      ORDER BY file_id
      INTO TABLE @DATA(lt_existing)
      UP TO 1 ROWS.
    rv_exists = xsdbool( lt_existing IS NOT INITIAL ).
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~read_legacy.
    LOOP AT select_legacy( is_query = is_query iv_count = abap_false ) ASSIGNING FIELD-SYMBOL(<ls_read>).
      INSERT <ls_read>-row INTO TABLE rt_rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~count_legacy.
    rt_counts = select_legacy( is_query = is_query iv_count = abap_true ).
  ENDMETHOD.


  METHOD select_legacy.
    DATA lr_rows TYPE REF TO data.
    DATA ls_raw TYPE zif_cd_fmon_types=>ty_raw_count.
    DATA lt_in TYPE RANGE OF zif_cd_fmon_types=>ty_key_value.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <ls_row> TYPE any.
    FIELD-SYMBOLS <lv_source> TYPE simple.
    FIELD-SYMBOLS <lv_target> TYPE string.

    " Defence in depth: the caller validated against the DDIC; re-check syntax
    IF zcl_cd_fmon_query=>is_valid_name( is_query-table_name ) = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e202(zcd_ops) WITH is_query-table_name.
    ENDIF.
    DATA(lv_table)  = to_upper( condense( CONV string( is_query-table_name ) ) ).
    check_read_allowed( is_query ).
    DATA(lv_fields) = field_list( is_query ).

    " Host variables referenced by name from the dynamic WHERE condition below
    DATA(lv_date_from) = is_query-date_from ##NEEDED.
    DATA(lv_date_to)   = is_query-date_to ##NEEDED.
    DATA(lv_ts_from)   = is_query-ts_from ##NEEDED.
    DATA(lv_ts_to)     = is_query-ts_to ##NEEDED.
    lt_in = VALUE #( FOR lv_value IN is_query-in_values ( sign = 'I' option = 'EQ' low = lv_value ) ).

    DATA(lv_where) = ``.
    IF is_query-date_field IS NOT INITIAL
       AND zcl_cd_fmon_query=>is_valid_name( is_query-date_field ) = abap_true.
      lv_where = COND #( WHEN is_query-date_kind = zif_cd_fmon_types=>gc_date_kind-date
                         THEN |{ is_query-date_field } BETWEEN @LV_DATE_FROM AND @LV_DATE_TO|
                         " Audit A52: half-open timestamp range [from, to)
                         ELSE |{ is_query-date_field } >= @LV_TS_FROM AND { is_query-date_field }|
                           && zif_cd_fmon_types=>gc_ts_window_upper ).
    ENDIF.
    IF is_query-in_field IS NOT INITIAL
       AND zcl_cd_fmon_query=>is_valid_name( is_query-in_field ) = abap_true.
      CHECK lt_in IS NOT INITIAL.
      lv_where = COND #( WHEN lv_where IS INITIAL THEN |{ is_query-in_field } IN @LT_IN|
                         ELSE |{ lv_where } AND { is_query-in_field } IN @LT_IN| ).
    ENDIF.
    IF lv_where IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e209(zcd_ops) WITH is_query-table_name.
    ENDIF.
    " UP TO n ROWS needs a defined order on HANA: the validated date field, else the IN field
    DATA(lv_order) = COND string( WHEN is_query-date_field IS NOT INITIAL THEN is_query-date_field
                                  ELSE is_query-in_field ).

    TRY.
        IF iv_count = abap_true.
          " Fix 8: one row per distinct combination of the fields, with the number of rows
          lr_rows = count_table( iv_table = lv_table is_query = is_query ).
          ASSIGN lr_rows->* TO <lt_rows>.
          DATA(lv_select) = lv_fields && gc_count_expression.
          SELECT (lv_select)
            FROM (lv_table)
            WHERE (lv_where)
            GROUP BY (lv_fields)
            ORDER BY (lv_fields)
            INTO CORRESPONDING FIELDS OF TABLE @<lt_rows>.
        ELSE.
          CREATE DATA lr_rows TYPE STANDARD TABLE OF (lv_table).
          ASSIGN lr_rows->* TO <lt_rows>.
          SELECT (lv_fields)
            FROM (lv_table)
            WHERE (lv_where)
            ORDER BY (lv_order)
            INTO CORRESPONDING FIELDS OF TABLE @<lt_rows>
            UP TO @is_query-max_rows ROWS.
        ENDIF.
      CATCH cx_sy_create_data_error cx_sy_dynamic_osql_error INTO DATA(lx_sql).
        DATA(lv_text) = lx_sql->get_text( ).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e205(zcd_ops) WITH lv_table lv_text
          EXPORTING
            previous = lx_sql.
    ENDTRY.

    LOOP AT <lt_rows> ASSIGNING <ls_row>.
      CLEAR ls_raw.
      LOOP AT is_query-fields ASSIGNING FIELD-SYMBOL(<ls_field>).
        ASSIGN COMPONENT <ls_field>-field OF STRUCTURE <ls_row> TO <lv_source>.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        ASSIGN COMPONENT <ls_field>-role OF STRUCTURE ls_raw-row TO <lv_target>.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        " Unformatted text: dates YYYYMMDD, times HHMMSS, numbers with leading sign
        <lv_target> = condense( |{ <lv_source> }| ).
      ENDLOOP.
      IF iv_count = abap_true.
        ASSIGN COMPONENT gc_count_alias OF STRUCTURE <ls_row> TO <lv_source>.
        IF sy-subrc = 0.
          ls_raw-row_count = <lv_source>.
        ENDIF.
      ENDIF.
      INSERT ls_raw INTO TABLE rt_counts.
    ENDLOOP.
  ENDMETHOD.


  METHOD count_table.
    DATA lo_descr TYPE REF TO cl_abap_typedescr.
    DATA lo_struct TYPE REF TO cl_abap_structdescr.
    DATA lo_type TYPE REF TO cl_abap_datadescr.
    DATA lt_components TYPE cl_abap_structdescr=>component_table.
    DATA lt_names TYPE SORTED TABLE OF zif_cd_fmon_types=>ty_fieldname WITH UNIQUE KEY table_line.
    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = iv_table
      RECEIVING
        p_descr_ref    = lo_descr
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e202(zcd_ops) WITH iv_table.
    ENDIF.
    TRY.
        lo_struct ?= lo_descr.
      CATCH cx_sy_move_cast_error.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e202(zcd_ops) WITH iv_table.
    ENDTRY.
    LOOP AT is_query-fields ASSIGNING FIELD-SYMBOL(<ls_field>).
      INSERT <ls_field>-field INTO TABLE lt_names.
    ENDLOOP.
    LOOP AT lt_names ASSIGNING FIELD-SYMBOL(<lv_name>).
      lo_struct->get_component_type(
        EXPORTING
          p_name                 = <lv_name>
        RECEIVING
          p_descr_ref            = lo_type
        EXCEPTIONS
          component_not_found    = 1
          unsupported_input_type = 2
          OTHERS                 = 3 ).
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e201(zcd_ops) WITH <lv_name> iv_table.
      ENDIF.
      INSERT VALUE #( name = <lv_name> type = lo_type ) INTO TABLE lt_components.
    ENDLOOP.
    INSERT VALUE #( name = gc_count_alias type = cl_abap_elemdescr=>get_int8( ) ) INTO TABLE lt_components.
    TRY.
        DATA(lo_table) = cl_abap_tabledescr=>create( p_line_type = cl_abap_structdescr=>create( lt_components ) ).
        CREATE DATA rr_rows TYPE HANDLE lo_table.
      CATCH cx_sy_struct_creation cx_sy_table_creation cx_sy_create_data_error INTO DATA(lx_type).
        DATA(lv_text) = lx_type->get_text( ).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e205(zcd_ops) WITH iv_table lv_text
          EXPORTING
            previous = lx_type.
    ENDTRY.
  ENDMETHOD.


  METHOD check_read_allowed.
    DATA lt_allow TYPE zif_cd_fmon_types=>tt_tab_allow.
    DATA(lv_table) = CONV zif_cd_fmon_types=>ty_tabname( to_upper( condense( CONV string( is_query-table_name ) ) ) ).
    SELECT table_name, field_name
      FROM zcd_fmon_tabwl
      WHERE table_name = @lv_table
        AND active     = @abap_true
      ORDER BY table_name, field_name
      INTO CORRESPONDING FIELDS OF TABLE @lt_allow.
    zcl_cd_fmon_query=>check_approved( is_query = is_query
                                       it_allow = lt_allow ).
    IF zcl_cd_fmon_factory=>get_ddic( )->may_read( lv_table ) = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e245(zcd_ops) WITH lv_table.
    ENDIF.
  ENDMETHOD.


  METHOD field_list.
    DATA lt_names TYPE SORTED TABLE OF zif_cd_fmon_types=>ty_fieldname WITH UNIQUE KEY table_line.
    LOOP AT is_query-fields ASSIGNING FIELD-SYMBOL(<ls_field>).
      IF zcl_cd_fmon_query=>is_valid_name( <ls_field>-field ) = abap_false.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e202(zcd_ops) WITH <ls_field>-field.
      ENDIF.
      INSERT <ls_field>-field INTO TABLE lt_names.
    ENDLOOP.
    rv_fields = concat_lines_of( table = lt_names sep = `, ` ).
  ENDMETHOD.

ENDCLASS.
