*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_lot_reader.clas.abap
*& Purpose:
*& Generic returns / NOC lot completeness reader. Table and field names
*& (e.g. DFKKNRK/DFKKNRP KEYN1, POSNA) come from ZCD_FMON_LOTCFG and are
*& DDIC-validated; counts done vs open items per registered file.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Audit A38: one row beyond the cap is read; reaching it marks the batch truncated.
*& 2026-11-06 | Performance fix 8: item counts by a grouped COUNT(*) per link / lot and status (exact, no cap);
*&            | is_done stays in ABAP per distinct status; open keys sampled only for links with open items.
*& 2026-11-08 | Table consolidation: approved tables read from ZCD_OPS_TABWL (area FMON, purpose SOURCE; was
*&            | ZCD_FMON_TABWL).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - returns/NOC lot completeness reader</p>
"! Two shapes: header table links lot to file and items are read by lot key
"! (HDR_* fields), or the item table carries the file link (ITEM_LINK_FIELD).
"! An item is done when its status is in DONE_VALUES; every other item is an
"! unaccounted transaction (requirements baseline: "no silent suspense").
CLASS zcl_cd_fmon_lot_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_lot_reader.

  PRIVATE SECTION.
    CONSTANTS gc_max_keys TYPE i VALUE 5.
    "! A query of this read returned more rows than the cap (audit A38)
    DATA mv_truncated TYPE abap_bool.

    TYPES:
      BEGIN OF ty_count,
        link      TYPE zif_cd_fmon_types=>ty_key_value,
        total     TYPE i,
        done      TYPE i,
        open      TYPE i,
        "! Fix 8: open item keys sampled so far (at most gc_max_keys)
        sampled   TYPE i,
        open_keys TYPE string,
      END OF ty_count.
    TYPES tt_count TYPE SORTED TABLE OF ty_count WITH UNIQUE KEY link.

    TYPES:
      BEGIN OF ty_lot_link,
        lot_key TYPE zif_cd_fmon_types=>ty_key_value,
        link    TYPE zif_cd_fmon_types=>ty_key_value,
      END OF ty_lot_link.
    TYPES tt_lot_link TYPE SORTED TABLE OF ty_lot_link WITH UNIQUE KEY lot_key.

    METHODS check_config
      IMPORTING
        is_cfg TYPE zif_cd_fmon_types=>ty_lotcfg
      RAISING
        zcx_ca_ops_error.

    METHODS link_of
      IMPORTING
        is_cfg         TYPE zif_cd_fmon_types=>ty_lotcfg
        is_file        TYPE zif_cd_fmon_types=>ty_file
      RETURNING
        VALUE(rv_link) TYPE zif_cd_fmon_types=>ty_key_value.

    "! Reads one row beyond iv_max_rows; more rows than the cap set MV_TRUNCATED (unless
    "! iv_counts_exact: the counts come from the grouped read) and the surplus is dropped.
    "! iv_max_rows = 0 reads without cap.
    METHODS run_query
      IMPORTING
        is_query        TYPE zif_cd_fmon_types=>ty_query
        iv_max_rows     TYPE i
        iv_counts_exact TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rt_rows)  TYPE zif_cd_fmon_types=>tt_raw_row
      RAISING
        zcx_ca_ops_error.

    "! Fix 8: grouped COUNT(*) on the same validated read path (no cap - one row per group)
    METHODS run_count
      IMPORTING
        is_query         TYPE zif_cd_fmon_types=>ty_query
      RETURNING
        VALUE(rt_counts) TYPE zif_cd_fmon_types=>tt_raw_count
      RAISING
        zcx_ca_ops_error.

    "! Header shape: lots of the files (lot key -> file link); capped as before
    METHODS read_lots
      IMPORTING
        is_cfg          TYPE zif_cd_fmon_types=>ty_lotcfg
        it_links        TYPE zif_cd_fmon_types=>tt_key_value
        iv_max_rows     TYPE i
      RETURNING
        VALUE(rt_lots)  TYPE tt_lot_link
      RAISING
        zcx_ca_ops_error.

    "! Item query: by file link (item shape) or by lot key (header shape); with
    "! iv_keys also the item key (sample read), else only link / lot and status (count)
    METHODS item_query
      IMPORTING
        is_cfg          TYPE zif_cd_fmon_types=>ty_lotcfg
        it_values       TYPE zif_cd_fmon_types=>tt_key_value
        iv_keys         TYPE abap_bool
      RETURNING
        VALUE(rs_query) TYPE zif_cd_fmon_types=>ty_query.

    "! File link of an item row: its own link field, or the link of its lot (header shape)
    METHODS item_link
      IMPORTING
        is_cfg         TYPE zif_cd_fmon_types=>ty_lotcfg
        is_row         TYPE zif_cd_fmon_types=>ty_raw_row
        it_lots        TYPE tt_lot_link
      RETURNING
        VALUE(rv_link) TYPE zif_cd_fmon_types=>ty_key_value.

    "! Exact total / done / open per file link from the grouped read; open keys (at most
    "! gc_max_keys per link) from a read of the links or lots that have open items only
    METHODS count_items
      IMPORTING
        is_cfg           TYPE zif_cd_fmon_types=>ty_lotcfg
        it_links         TYPE zif_cd_fmon_types=>tt_key_value
        iv_max_rows      TYPE i
      RETURNING
        VALUE(rt_counts) TYPE tt_count
      RAISING
        zcx_ca_ops_error.

ENDCLASS.



CLASS zcl_cd_fmon_lot_reader IMPLEMENTATION.

  METHOD zif_cd_fmon_lot_reader~read.
    DATA lt_links TYPE zif_cd_fmon_types=>tt_key_value.
    DATA ls_status TYPE zif_cd_fmon_types=>ty_lot_status.

    CLEAR mv_truncated.
    check_config( is_cfg ).

    DATA lt_seen TYPE HASHED TABLE OF zif_cd_fmon_types=>ty_key_value WITH UNIQUE KEY table_line.
    LOOP AT it_files ASSIGNING FIELD-SYMBOL(<ls_link_file>).
      DATA(lv_link) = link_of( is_cfg  = is_cfg
                               is_file = <ls_link_file> ).
      " Links in first-seen order (standard table for the IN list), de-duplicated by hash
      IF lv_link IS NOT INITIAL.
        INSERT lv_link INTO TABLE lt_seen.
        IF sy-subrc = 0.
          INSERT lv_link INTO TABLE lt_links.
        ENDIF.
      ENDIF.
    ENDLOOP.

    DATA(lt_counts) = count_items( is_cfg      = is_cfg
                                   it_links    = lt_links
                                   iv_max_rows = iv_max_rows ).

    LOOP AT it_files ASSIGNING FIELD-SYMBOL(<ls_file>).
      CLEAR ls_status.
      ls_status-file_id  = <ls_file>-file_id.
      ls_status-lot_type = is_cfg-lot_type.
      ls_status-sla_days = is_cfg-noc_sla_days.
      " A capped lot read applies to the whole batch: no file's completion is proven
      ls_status-truncated = mv_truncated.
      READ TABLE lt_counts ASSIGNING FIELD-SYMBOL(<ls_count>) WITH TABLE KEY link = link_of( is_cfg  = is_cfg
                                                                                              is_file = <ls_file> ).
      IF sy-subrc = 0.
        ls_status-found       = xsdbool( <ls_count>-total > 0 ).
        ls_status-total_items = <ls_count>-total.
        ls_status-done_items  = <ls_count>-done.
        ls_status-open_items  = <ls_count>-open.
        ls_status-open_keys   = <ls_count>-open_keys.
      ENDIF.
      INSERT ls_status INTO TABLE rt_status.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_config.
    DATA(lv_missing) = COND string(
      WHEN is_cfg-item_table IS INITIAL        THEN `ITEM_TABLE`
      WHEN is_cfg-item_key_field IS INITIAL    THEN `ITEM_KEY_FIELD`
      WHEN is_cfg-item_status_field IS INITIAL THEN `ITEM_STATUS_FIELD`
      WHEN is_cfg-hdr_table IS NOT INITIAL AND is_cfg-hdr_lot_field IS INITIAL  THEN `HDR_LOT_FIELD`
      WHEN is_cfg-hdr_table IS NOT INITIAL AND is_cfg-hdr_link_field IS INITIAL THEN `HDR_LINK_FIELD`
      WHEN is_cfg-hdr_table IS NOT INITIAL AND is_cfg-item_lot_field IS INITIAL THEN `ITEM_LOT_FIELD`
      WHEN is_cfg-hdr_table IS INITIAL AND is_cfg-item_link_field IS INITIAL    THEN `ITEM_LINK_FIELD` ).
    IF lv_missing IS NOT INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e208(zcd_ops) WITH is_cfg-iface_id is_cfg-lot_type lv_missing.
    ENDIF.
  ENDMETHOD.


  METHOD link_of.
    rv_link = condense( COND string( WHEN is_cfg-link_by = zif_cd_fmon_types=>gc_link_by-ref
                                     THEN is_file-file_ref
                                     ELSE is_file-file_name ) ).
  ENDMETHOD.


  METHOD run_query.
    DATA(lt_fields) = zcl_cd_fmon_factory=>get_ddic( )->describe_table( is_query-table_name ).
    zcl_cd_fmon_query=>validate( is_query  = is_query
                                 it_fields = lt_fields ).
    DATA(ls_query) = is_query.
    ls_query-max_rows = COND #( WHEN iv_max_rows > 0 THEN iv_max_rows + 1 ).
    rt_rows = zcl_cd_fmon_factory=>get_dao( )->read_legacy( ls_query ).
    IF iv_max_rows > 0 AND lines( rt_rows ) > iv_max_rows.
      IF iv_counts_exact = abap_false.
        mv_truncated = abap_true.
      ENDIF.
      DELETE rt_rows FROM iv_max_rows + 1.
    ENDIF.
  ENDMETHOD.


  METHOD run_count.
    " Same validation as run_query; ZCD_OPS_TABWL (FMON / SOURCE) and S_TABU_NAM are checked in the DAO
    DATA(lt_fields) = zcl_cd_fmon_factory=>get_ddic( )->describe_table( is_query-table_name ).
    zcl_cd_fmon_query=>validate( is_query  = is_query
                                 it_fields = lt_fields ).
    rt_counts = zcl_cd_fmon_factory=>get_dao( )->count_legacy( is_query ).
  ENDMETHOD.


  METHOD read_lots.
    DATA ls_query TYPE zif_cd_fmon_types=>ty_query.
    ls_query-table_name = to_upper( condense( is_cfg-hdr_table ) ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-lot_key
                                            iv_field = is_cfg-hdr_lot_field
                                  CHANGING  cs_query = ls_query ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-file_link
                                            iv_field = is_cfg-hdr_link_field
                                  CHANGING  cs_query = ls_query ).
    ls_query-in_field  = to_upper( condense( is_cfg-hdr_link_field ) ).
    ls_query-in_values = it_links.
    LOOP AT run_query( is_query = ls_query iv_max_rows = iv_max_rows ) ASSIGNING FIELD-SYMBOL(<ls_header>).
      " First link of a lot wins, as before
      INSERT VALUE #( lot_key = <ls_header>-lot_key
                      link    = <ls_header>-file_link ) INTO TABLE rt_lots.
    ENDLOOP.
  ENDMETHOD.


  METHOD item_query.
    rs_query-table_name = to_upper( condense( is_cfg-item_table ) ).
    IF is_cfg-hdr_table IS INITIAL.
      zcl_cd_fmon_query=>add_field( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-file_link
                                              iv_field = is_cfg-item_link_field
                                    CHANGING  cs_query = rs_query ).
    ENDIF.
    " The lot key is a group of the count in the header shape and part of the open key
    IF is_cfg-hdr_table IS NOT INITIAL OR iv_keys = abap_true.
      zcl_cd_fmon_query=>add_field( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-lot_key
                                              iv_field = is_cfg-item_lot_field
                                    CHANGING  cs_query = rs_query ).
    ENDIF.
    IF iv_keys = abap_true.
      zcl_cd_fmon_query=>add_field( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-item_key
                                              iv_field = is_cfg-item_key_field
                                    CHANGING  cs_query = rs_query ).
    ENDIF.
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-item_status
                                            iv_field = is_cfg-item_status_field
                                  CHANGING  cs_query = rs_query ).
    rs_query-in_field  = to_upper( condense( COND #( WHEN is_cfg-hdr_table IS INITIAL THEN is_cfg-item_link_field
                                                     ELSE is_cfg-item_lot_field ) ) ).
    rs_query-in_values = it_values.
  ENDMETHOD.


  METHOD item_link.
    IF is_cfg-hdr_table IS INITIAL.
      rv_link = condense( is_row-file_link ).
      RETURN.
    ENDIF.
    " An item whose lot has no header row keeps an empty link (never matches a file)
    rv_link = condense( VALUE #( it_lots[ lot_key = CONV #( is_row-lot_key ) ]-link OPTIONAL ) ).
  ENDMETHOD.


  METHOD count_items.
    DATA lt_lots TYPE tt_lot_link.
    DATA lt_values TYPE zif_cd_fmon_types=>tt_key_value.
    DATA lt_open_values TYPE zif_cd_fmon_types=>tt_key_value.
    DATA lt_open_seen TYPE HASHED TABLE OF zif_cd_fmon_types=>ty_key_value WITH UNIQUE KEY table_line.
    DATA lt_status_done TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA lt_status_open TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    IF it_links IS INITIAL.
      RETURN.
    ENDIF.
    IF is_cfg-hdr_table IS INITIAL.
      lt_values = it_links.
    ELSE.
      " 1) lots of the files from the header table (capped: a cut-off marks the batch truncated)
      lt_lots = read_lots( is_cfg = is_cfg it_links = it_links iv_max_rows = iv_max_rows ).
      LOOP AT lt_lots ASSIGNING FIELD-SYMBOL(<ls_lot>).
        INSERT CONV zif_cd_fmon_types=>ty_key_value( <ls_lot>-lot_key ) INTO TABLE lt_values.
      ENDLOOP.
      IF lt_values IS INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    " 2) Fix 8: exact counts - one row per link / lot and status, no item row cap
    LOOP AT run_count( item_query( is_cfg = is_cfg it_values = lt_values iv_keys = abap_false ) )
         ASSIGNING FIELD-SYMBOL(<ls_group>).
      DATA(lv_link) = item_link( is_cfg = is_cfg is_row = <ls_group>-row it_lots = lt_lots ).
      READ TABLE rt_counts ASSIGNING FIELD-SYMBOL(<ls_count>) WITH TABLE KEY link = lv_link.
      IF sy-subrc <> 0.
        INSERT VALUE #( link = lv_link ) INTO TABLE rt_counts ASSIGNING <ls_count>.
      ENDIF.
      <ls_count>-total += <ls_group>-row_count.
      " is_done( ) (UPPER, condense, blank token) stays in ABAP - applied once per distinct status
      IF zcl_cd_fmon_rules=>is_done( iv_status      = <ls_group>-row-item_status
                                     iv_done_values = is_cfg-done_values ) = abap_true.
        <ls_count>-done += <ls_group>-row_count.
        INSERT <ls_group>-row-item_status INTO TABLE lt_status_done.
      ELSE.
        <ls_count>-open += <ls_group>-row_count.
        INSERT <ls_group>-row-item_status INTO TABLE lt_status_open.
        DATA(lv_value) = CONV zif_cd_fmon_types=>ty_key_value(
          COND #( WHEN is_cfg-hdr_table IS INITIAL THEN <ls_group>-row-file_link ELSE <ls_group>-row-lot_key ) ).
        INSERT lv_value INTO TABLE lt_open_seen.
        IF sy-subrc = 0.
          INSERT lv_value INTO TABLE lt_open_values.
        ENDIF.
      ENDIF.
    ENDLOOP.
    IF lt_open_values IS INITIAL.
      RETURN.
    ENDIF.

    " 3) open item keys (at most gc_max_keys per link): only links / lots with open items are
    "    read; the counts are exact, so a capped sample read never marks the batch truncated
    LOOP AT run_query( is_query        = item_query( is_cfg = is_cfg it_values = lt_open_values iv_keys = abap_true )
                       iv_max_rows     = iv_max_rows
                       iv_counts_exact = abap_true ) ASSIGNING FIELD-SYMBOL(<ls_item>).
      IF line_exists( lt_status_done[ table_line = <ls_item>-item_status ] ).
        CONTINUE.
      ENDIF.
      IF NOT line_exists( lt_status_open[ table_line = <ls_item>-item_status ] )
         AND zcl_cd_fmon_rules=>is_done( iv_status      = <ls_item>-item_status
                                         iv_done_values = is_cfg-done_values ) = abap_true.
        CONTINUE.
      ENDIF.
      READ TABLE rt_counts ASSIGNING <ls_count>
           WITH TABLE KEY link = item_link( is_cfg = is_cfg is_row = <ls_item> it_lots = lt_lots ).
      IF sy-subrc <> 0 OR <ls_count>-sampled >= gc_max_keys.
        CONTINUE.
      ENDIF.
      <ls_count>-sampled += 1.
      DATA(lv_key) = COND string( WHEN <ls_item>-lot_key IS INITIAL THEN <ls_item>-item_key
                                  ELSE |{ <ls_item>-lot_key }/{ <ls_item>-item_key }| ).
      <ls_count>-open_keys = COND #( WHEN <ls_count>-open_keys IS INITIAL THEN lv_key
                                     ELSE |{ <ls_count>-open_keys }, { lv_key }| ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
