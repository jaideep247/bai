*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_adapter_generic.clas.abap
*& Purpose:
*& Generic legacy source adapter: maps an existing custom table (e.g.
*& ZCDT_REGUT, ZCD_ACH_ACK) to file status records purely from ZCD_FMON_SRC
*& / ZCD_FMON_SRCMAP; names are DDIC-validated before the DAO reads.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A39/A52: payment key, malformed rows flagged (not counted), half-open range.
*& 2026-11-06 | Rows without a usable file reference are quarantined (audit A100).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - generic legacy source adapter</p>
"! No field name of any legacy table is coded here: the structures of the
"! existing custom tables are unverified, so every name comes from
"! customizing and is checked by ZCL_CD_FMON_QUERY=>VALIDATE.
"! Date/time fields are read in the configured time zone; timestamp fields
"! are taken as UTC (SAP convention).
CLASS zcl_cd_fmon_adapter_generic DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_adapter.

    "! Build the DDIC-checked query for a source (pure)
    "! @raising zcx_cd_ops_error | 204 a required field role is not configured
    CLASS-METHODS build_query
      IMPORTING
        is_request      TYPE zif_cd_fmon_types=>ty_read_request
      RETURNING
        VALUE(rs_query) TYPE zif_cd_fmon_types=>ty_query
      RAISING
        zcx_cd_ops_error.

    "! Translate one legacy row into a status record (pure).
    "! Stage: SRCMAP row of the value, else the '*' row, else blank (unmapped);
    "! a source without status field reports its DEFAULT_STAGE.
    CLASS-METHODS to_record
      IMPORTING
        is_request       TYPE zif_cd_fmon_types=>ty_read_request
        is_raw           TYPE zif_cd_fmon_types=>ty_raw_row
      RETURNING
        VALUE(rs_record) TYPE zif_cd_fmon_types=>ty_src_record.

  PRIVATE SECTION.
    "! Columns of ZCD_FMON_SRC named in configuration messages (one of each pair is required)
    CONSTANTS:
      BEGIN OF gc_cfg_fields,
        file   TYPE string VALUE `FILE_KEY_FIELD/FILE_NAME_FIELD`,
        date   TYPE string VALUE `DATE_FIELD/TS_FIELD`,
        status TYPE string VALUE `STATUS_FIELD/DEFAULT_STAGE`,
      END OF gc_cfg_fields.

    "! First malformed field wins; the record keeps its reference for the finding
    CLASS-METHODS mark_malformed
      IMPORTING
        iv_role   TYPE zif_cd_fmon_types=>ty_role
      CHANGING
        cs_record TYPE zif_cd_fmon_types=>ty_src_record.

    CLASS-METHODS map_stage
      IMPORTING
        is_request      TYPE zif_cd_fmon_types=>ty_read_request
        iv_status       TYPE zif_cd_fmon_types=>ty_status_value
      RETURNING
        VALUE(rv_stage) TYPE zif_cd_fmon_types=>ty_stage.

ENDCLASS.



CLASS zcl_cd_fmon_adapter_generic IMPLEMENTATION.

  METHOD zif_cd_fmon_adapter~read.
    DATA(ls_query) = build_query( is_request ).
    DATA(lt_fields) = zcl_cd_fmon_factory=>get_ddic( )->describe_table( ls_query-table_name ).
    zcl_cd_fmon_query=>validate( is_query  = ls_query
                                 it_fields = lt_fields ).

    DATA(lt_rows) = zcl_cd_fmon_factory=>get_dao( )->read_legacy( ls_query ).
    LOOP AT lt_rows INTO DATA(ls_raw).
      DATA(ls_record) = to_record( is_request = is_request
                                   is_raw     = ls_raw ).
      IF ls_record-file_ref IS NOT INITIAL.
        INSERT ls_record INTO TABLE rt_records.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD build_query.
    DATA(ls_src) = is_request-src.

    IF ls_src-file_key_field IS INITIAL AND ls_src-file_name_field IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e204(zcd_ops) WITH ls_src-src_id gc_cfg_fields-file.
    ENDIF.
    IF ls_src-date_field IS INITIAL AND ls_src-ts_field IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e204(zcd_ops) WITH ls_src-src_id gc_cfg_fields-date.
    ENDIF.
    IF ls_src-status_field IS INITIAL AND ls_src-default_stage IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e204(zcd_ops) WITH ls_src-src_id gc_cfg_fields-status.
    ENDIF.

    rs_query-table_name = to_upper( condense( ls_src-table_name ) ).
    rs_query-max_rows   = is_request-max_rows.

    DATA(lt_roles) = VALUE zif_cd_fmon_types=>tt_qfield(
      ( role = zif_cd_fmon_types=>gc_role-file_key  field = ls_src-file_key_field )
      ( role = zif_cd_fmon_types=>gc_role-file_name field = ls_src-file_name_field )
      ( role = zif_cd_fmon_types=>gc_role-ev_date   field = ls_src-date_field )
      ( role = zif_cd_fmon_types=>gc_role-ev_time   field = ls_src-time_field )
      ( role = zif_cd_fmon_types=>gc_role-ev_ts     field = ls_src-ts_field )
      ( role = zif_cd_fmon_types=>gc_role-status    field = ls_src-status_field )
      ( role = zif_cd_fmon_types=>gc_role-rec_count field = ls_src-count_field )
      ( role = zif_cd_fmon_types=>gc_role-amount    field = ls_src-amount_field )
      ( role = zif_cd_fmon_types=>gc_role-size      field = ls_src-size_field )
      ( role = zif_cd_fmon_types=>gc_role-checksum  field = ls_src-checksum_field )
      ( role = zif_cd_fmon_types=>gc_role-source    field = ls_src-source_field )
      ( role = zif_cd_fmon_types=>gc_role-lob       field = ls_src-lob_field )
      ( role = zif_cd_fmon_types=>gc_role-item_key  field = ls_src-item_key_field ) ).
    LOOP AT lt_roles INTO DATA(ls_role).
      zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = ls_role-role
                                              iv_field = ls_role-field
                                    CHANGING  cs_query = rs_query ).
    ENDLOOP.

    IF ls_src-ts_field IS NOT INITIAL.
      rs_query-date_field = to_upper( condense( ls_src-ts_field ) ).
      rs_query-date_kind  = zif_cd_fmon_types=>gc_date_kind-timestamp.
      CONVERT DATE is_request-date_from TIME zif_cd_ops_types=>gc_time-day_start
        INTO TIME STAMP rs_query-ts_from TIME ZONE is_request-time_zone.
      " Audit A52: half-open range - up to (excluding) the next local midnight, so rows with
      " fractional seconds after 23:59:59 are read; the DAO compares with >= and <
      CONVERT DATE is_request-date_to + 1 TIME zif_cd_ops_types=>gc_time-day_start
        INTO TIME STAMP rs_query-ts_to TIME ZONE is_request-time_zone.
    ELSE.
      rs_query-date_field = to_upper( condense( ls_src-date_field ) ).
      rs_query-date_kind  = zif_cd_fmon_types=>gc_date_kind-date.
      rs_query-date_from  = is_request-date_from.
      rs_query-date_to    = is_request-date_to.
    ENDIF.
  ENDMETHOD.


  METHOD to_record.
    DATA lv_date TYPE d.
    DATA lv_time TYPE t.

    rs_record-src_id    = is_request-src-src_id.
    rs_record-iface_id  = is_request-src-iface_id.
    rs_record-file_name = is_raw-file_name.
    rs_record-file_ref  = zcl_cd_fmon_util=>normalize_ref( COND string( WHEN is_raw-file_key IS NOT INITIAL
                                                                        THEN is_raw-file_key
                                                                        ELSE is_raw-file_name ) ).
    IF rs_record-file_ref IS INITIAL.
      " Audit A100: a row without a usable reference is rejected, never correlated by a blank key
      mark_malformed( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-file_key CHANGING cs_record = rs_record ).
    ENDIF.
    rs_record-raw_status = is_raw-status.
    rs_record-stage = COND #( WHEN is_request-src-status_field IS INITIAL THEN is_request-src-default_stage
                              ELSE map_stage( is_request = is_request
                                              iv_status  = rs_record-raw_status ) ).

    " Audit A52: a required event time or a numeric field that does not convert makes the
    " row malformed - it is quarantined by the engine, never counted as a known zero
    TRY.
        IF is_raw-ev_ts IS NOT INITIAL.
          rs_record-event_at = is_raw-ev_ts.
          CONVERT TIME STAMP rs_record-event_at TIME ZONE is_request-time_zone
            INTO DATE rs_record-business_date TIME lv_time.
          IF sy-subrc > 4.
            mark_malformed( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-ev_ts CHANGING cs_record = rs_record ).
          ENDIF.
        ELSEIF is_raw-ev_date IS NOT INITIAL.
          lv_date = is_raw-ev_date.
          lv_time = COND #( WHEN is_raw-ev_time IS NOT INITIAL THEN is_raw-ev_time ELSE zif_cd_ops_types=>gc_time-day_start ).
          rs_record-business_date = lv_date.
          CONVERT DATE lv_date TIME lv_time
            INTO TIME STAMP rs_record-event_at TIME ZONE is_request-time_zone.
          IF sy-subrc > 4.
            mark_malformed( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-ev_date CHANGING cs_record = rs_record ).
          ENDIF.
        ELSE.
          mark_malformed( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-ev_date CHANGING cs_record = rs_record ).
        ENDIF.
      CATCH cx_sy_conversion_error.
        mark_malformed( EXPORTING iv_role = COND #( WHEN is_raw-ev_ts IS NOT INITIAL THEN zif_cd_fmon_types=>gc_role-ev_ts
                                                    ELSE zif_cd_fmon_types=>gc_role-ev_date )
                        CHANGING  cs_record = rs_record ).
    ENDTRY.
    IF is_request-src-count_field IS NOT INITIAL AND is_raw-rec_count IS NOT INITIAL.
      IF zcl_cd_fmon_util=>is_number( is_raw-rec_count ) = abap_true.
        rs_record-rec_count   = zcl_cd_ops_util=>to_decimal( is_raw-rec_count ).
        rs_record-count_known = abap_true.
      ELSE.
        mark_malformed( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-rec_count CHANGING cs_record = rs_record ).
      ENDIF.
    ENDIF.
    IF is_raw-amount IS NOT INITIAL AND zcl_cd_fmon_util=>is_number( is_raw-amount ) = abap_false.
      mark_malformed( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-amount CHANGING cs_record = rs_record ).
    ELSE.
      rs_record-amount = zcl_cd_ops_util=>to_decimal( is_raw-amount ).
    ENDIF.
    IF is_request-src-size_field IS NOT INITIAL AND is_raw-size IS NOT INITIAL.
      IF zcl_cd_fmon_util=>is_number( is_raw-size ) = abap_true.
        rs_record-size_bytes = zcl_cd_ops_util=>to_decimal( is_raw-size ).
        rs_record-size_known = abap_true.
      ELSE.
        mark_malformed( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-size CHANGING cs_record = rs_record ).
      ENDIF.
    ENDIF.
    rs_record-item_key   = is_raw-item_key.
    rs_record-checksum   = is_raw-checksum.
    rs_record-source_sys = to_upper( is_raw-source ).
    rs_record-lob        = to_upper( is_raw-lob ).
  ENDMETHOD.


  METHOD mark_malformed.
    IF cs_record-malformed = abap_false.
      cs_record-malformed      = abap_true.
      cs_record-malformed_role = iv_role.
    ENDIF.
  ENDMETHOD.


  METHOD map_stage.
    DATA(lv_status) = CONV zif_cd_fmon_types=>ty_status_value( condense( iv_status ) ).
    READ TABLE is_request-maps INTO DATA(ls_map)
      WITH TABLE KEY src_id = is_request-src-src_id status_value = lv_status.
    IF sy-subrc <> 0.
      lv_status = to_upper( lv_status ).
      READ TABLE is_request-maps INTO ls_map
        WITH TABLE KEY src_id = is_request-src-src_id status_value = lv_status.
    ENDIF.
    IF sy-subrc <> 0.
      READ TABLE is_request-maps INTO ls_map
        WITH TABLE KEY src_id = is_request-src-src_id status_value = zif_cd_fmon_types=>gc_wildcard.
    ENDIF.
    IF sy-subrc = 0.
      rv_stage = ls_map-stage.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
