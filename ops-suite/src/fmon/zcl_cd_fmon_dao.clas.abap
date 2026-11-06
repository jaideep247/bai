*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_dao.clas.abap
*& Purpose:
*& FMON repository - the only FMON class with SQL: customizing reads,
*& file registry (ZCD_FMON_FILE), idempotent event trail (ZCD_FMON_EVENT)
*& and the dynamic read of configured, DDIC-validated legacy tables.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
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
    TYPES ty_db_files TYPE STANDARD TABLE OF zcd_fmon_file WITH EMPTY KEY.

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
      INTO CORRESPONDING FIELDS OF TABLE @rt_slas.
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~get_calendars.
    SELECT iface_id, day_type, expected_count, window_from, window_to, fcal_id
      FROM zcd_fmon_cal
      INTO CORRESPONDING FIELDS OF TABLE @rt_cals.
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~get_sources.
    SELECT src_id, iface_id, table_name, file_key_field, file_name_field, date_field, time_field,
           ts_field, status_field, count_field, amount_field, size_field, checksum_field,
           source_field, lob_field, default_stage, adapter_class, active, description
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
    IF it_keys IS INITIAL.
      RETURN.
    ENDIF.
    SELECT file_id, iface_id, file_ref, direction, file_type, source_sys, lob, pay_method, file_name,
           business_date, size_bytes, size_known, record_count, control_total, checksum, stage, outcome,
           unprocessed_count, ack_count, ack_amount, nack_count, origin_rows, first_event_at,
           last_event_at, src_id, src_key, created_at, changed_at, changed_by
      FROM zcd_fmon_file
      FOR ALL ENTRIES IN @it_keys
      WHERE iface_id = @it_keys-iface_id
        AND file_ref = @it_keys-file_ref
      INTO CORRESPONDING FIELDS OF TABLE @rt_files.
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~get_eval_files.
    DATA lv_no_outcome TYPE zif_cd_fmon_types=>ty_stage.
    IF iv_iface_id IS INITIAL.
      SELECT file_id, iface_id, file_ref, direction, file_type, source_sys, lob, pay_method, file_name,
             business_date, size_bytes, size_known, record_count, control_total, checksum, stage, outcome,
             unprocessed_count, ack_count, ack_amount, nack_count, origin_rows, first_event_at,
             last_event_at, src_id, src_key, created_at, changed_at, changed_by
        FROM zcd_fmon_file
        WHERE business_date BETWEEN @iv_date_from AND @iv_date_to
           OR ( business_date >= @iv_open_since
                AND ( outcome = @lv_no_outcome OR outcome = @zif_cd_fmon_types=>gc_stage-partially ) )
        INTO CORRESPONDING FIELDS OF TABLE @rt_files.
    ELSE.
      SELECT file_id, iface_id, file_ref, direction, file_type, source_sys, lob, pay_method, file_name,
             business_date, size_bytes, size_known, record_count, control_total, checksum, stage, outcome,
             unprocessed_count, ack_count, ack_amount, nack_count, origin_rows, first_event_at,
             last_event_at, src_id, src_key, created_at, changed_at, changed_by
        FROM zcd_fmon_file
        WHERE iface_id = @iv_iface_id
          AND ( business_date BETWEEN @iv_date_from AND @iv_date_to
                OR ( business_date >= @iv_open_since
                     AND ( outcome = @lv_no_outcome OR outcome = @zif_cd_fmon_types=>gc_stage-partially ) ) )
        INTO CORRESPONDING FIELDS OF TABLE @rt_files.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~get_history.
    DATA lt_by_sum TYPE zif_cd_fmon_types=>tt_file.

    IF it_names IS NOT INITIAL.
      SELECT file_id, iface_id, file_ref, direction, file_type, source_sys, lob, pay_method, file_name,
             business_date, size_bytes, size_known, record_count, control_total, checksum, stage, outcome,
             unprocessed_count, ack_count, ack_amount, nack_count, origin_rows, first_event_at,
             last_event_at, src_id, src_key, created_at, changed_at, changed_by
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
             last_event_at, src_id, src_key, created_at, changed_at, changed_by
        FROM zcd_fmon_file
        FOR ALL ENTRIES IN @it_checksums
        WHERE checksum       = @it_checksums-table_line
          AND business_date >= @iv_since
        INTO CORRESPONDING FIELDS OF TABLE @lt_by_sum.
      APPEND LINES OF lt_by_sum TO rt_files.
    ENDIF.

    SORT rt_files BY file_id.
    DELETE ADJACENT DUPLICATES FROM rt_files COMPARING file_id.
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~get_events.
    IF it_file_ids IS INITIAL.
      RETURN.
    ENDIF.
    SELECT file_id, event_no, stage, event_at, src_id, src_key, record_count, amount, info,
           created_by, created_at
      FROM zcd_fmon_event
      FOR ALL ENTRIES IN @it_file_ids
      WHERE file_id = @it_file_ids-table_line
      INTO CORRESPONDING FIELDS OF TABLE @rt_events.
    SORT rt_events BY file_id event_no.
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~save_files.
    DATA lt_db TYPE ty_db_files.
    IF it_files IS INITIAL.
      RETURN.
    ENDIF.
    lt_db = CORRESPONDING #( it_files ).
    MODIFY zcd_fmon_file FROM TABLE @lt_db.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e010(zcd_ops) WITH 'ZCD_FMON_FILE'.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~insert_event.
    DATA ls_db TYPE zcd_fmon_event.

    SELECT SINGLE file_id
      FROM zcd_fmon_event
      WHERE src_id  = @is_event-src_id
        AND src_key = @is_event-src_key
        AND stage   = @is_event-stage
      INTO @DATA(lv_existing).
    IF sy-subrc = 0 AND lv_existing IS NOT INITIAL.
      RETURN.
    ENDIF.

    SELECT MAX( event_no )
      FROM zcd_fmon_event
      WHERE file_id = @is_event-file_id
      INTO @DATA(lv_last_no).

    ls_db = CORRESPONDING #( is_event ).
    ls_db-event_no   = lv_last_no + 1.
    ls_db-created_by = sy-uname.
    ls_db-created_at = zcl_cd_ops_factory=>get_clock( )->now( ).
    INSERT zcd_fmon_event FROM @ls_db.
    " sy-subrc 4 = the same event was written concurrently: still idempotent
    rv_inserted = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD zif_cd_fmon_dao~read_legacy.
    DATA lr_rows TYPE REF TO data.
    DATA ls_raw TYPE zif_cd_fmon_types=>ty_raw_row.
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
                         ELSE |{ is_query-date_field } BETWEEN @LV_TS_FROM AND @LV_TS_TO| ).
    ENDIF.
    IF is_query-in_field IS NOT INITIAL
       AND zcl_cd_fmon_query=>is_valid_name( is_query-in_field ) = abap_true.
      IF lt_in IS INITIAL.
        RETURN.
      ENDIF.
      lv_where = COND #( WHEN lv_where IS INITIAL THEN |{ is_query-in_field } IN @LT_IN|
                         ELSE |{ lv_where } AND { is_query-in_field } IN @LT_IN| ).
    ENDIF.
    IF lv_where IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e209(zcd_ops) WITH is_query-table_name.
    ENDIF.

    TRY.
        CREATE DATA lr_rows TYPE STANDARD TABLE OF (lv_table).
        ASSIGN lr_rows->* TO <lt_rows>.
        SELECT (lv_fields)
          FROM (lv_table)
          WHERE (lv_where)
          INTO CORRESPONDING FIELDS OF TABLE @<lt_rows>
          UP TO @is_query-max_rows ROWS.
      CATCH cx_sy_create_data_error cx_sy_dynamic_osql_error INTO DATA(lx_sql).
        DATA(lv_text) = lx_sql->get_text( ).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e205(zcd_ops) WITH lv_table lv_text
          EXPORTING
            previous = lx_sql.
    ENDTRY.

    LOOP AT <lt_rows> ASSIGNING <ls_row>.
      CLEAR ls_raw.
      LOOP AT is_query-fields INTO DATA(ls_field).
        ASSIGN COMPONENT ls_field-field OF STRUCTURE <ls_row> TO <lv_source>.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        ASSIGN COMPONENT ls_field-role OF STRUCTURE ls_raw TO <lv_target>.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        " Unformatted text: dates YYYYMMDD, times HHMMSS, numbers with leading sign
        <lv_target> = condense( |{ <lv_source> }| ).
      ENDLOOP.
      INSERT ls_raw INTO TABLE rt_rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD field_list.
    DATA lt_names TYPE SORTED TABLE OF zif_cd_fmon_types=>ty_fieldname WITH UNIQUE KEY table_line.
    LOOP AT is_query-fields INTO DATA(ls_field).
      IF zcl_cd_fmon_query=>is_valid_name( ls_field-field ) = abap_false.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e202(zcd_ops) WITH ls_field-field.
      ENDIF.
      INSERT ls_field-field INTO TABLE lt_names.
    ENDLOOP.
    rv_fields = concat_lines_of( table = lt_names sep = `, ` ).
  ENDMETHOD.

ENDCLASS.
