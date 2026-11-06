*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_lot_reader.clas.abap
*& Purpose:
*& Generic returns / NOC lot completeness reader. Table and field names
*& (e.g. DFKKNRK/DFKKNRP KEYN1, POSNA) come from ZCD_FMON_LOTCFG and are
*& DDIC-validated; counts done vs open items per registered file.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Audit A38: one row beyond the cap is read; reaching it marks the batch truncated.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - returns/NOC lot completeness reader</p>
"! Two shapes: header table links lot to file and items are read by lot key
"! (HDR_* fields), or the item table carries the file link (ITEM_LINK_FIELD).
"! An item is done when its status is in DONE_VALUES; every other item is an
"! unaccounted transaction (master prompt: "no silent suspense").
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
        zcx_cd_ops_error.

    METHODS link_of
      IMPORTING
        is_cfg         TYPE zif_cd_fmon_types=>ty_lotcfg
        is_file        TYPE zif_cd_fmon_types=>ty_file
      RETURNING
        VALUE(rv_link) TYPE zif_cd_fmon_types=>ty_key_value.

    "! Reads one row beyond iv_max_rows; more rows than the cap set MV_TRUNCATED and
    "! the surplus is dropped. iv_max_rows = 0 reads without cap.
    METHODS run_query
      IMPORTING
        is_query       TYPE zif_cd_fmon_types=>ty_query
        iv_max_rows    TYPE i
      RETURNING
        VALUE(rt_rows) TYPE zif_cd_fmon_types=>tt_raw_row
      RAISING
        zcx_cd_ops_error.

    METHODS read_items
      IMPORTING
        is_cfg          TYPE zif_cd_fmon_types=>ty_lotcfg
        it_links        TYPE zif_cd_fmon_types=>tt_key_value
        iv_max_rows     TYPE i
      RETURNING
        VALUE(rt_items) TYPE zif_cd_fmon_types=>tt_raw_row
      RAISING
        zcx_cd_ops_error.

    METHODS count_items
      IMPORTING
        is_cfg           TYPE zif_cd_fmon_types=>ty_lotcfg
        it_items         TYPE zif_cd_fmon_types=>tt_raw_row
      RETURNING
        VALUE(rt_counts) TYPE tt_count.

ENDCLASS.



CLASS zcl_cd_fmon_lot_reader IMPLEMENTATION.

  METHOD zif_cd_fmon_lot_reader~read.
    DATA lt_links TYPE zif_cd_fmon_types=>tt_key_value.
    DATA ls_status TYPE zif_cd_fmon_types=>ty_lot_status.

    CLEAR mv_truncated.
    check_config( is_cfg ).

    LOOP AT it_files INTO DATA(ls_file).
      DATA(lv_link) = link_of( is_cfg  = is_cfg
                               is_file = ls_file ).
      IF lv_link IS NOT INITIAL AND NOT line_exists( lt_links[ table_line = lv_link ] ).
        INSERT lv_link INTO TABLE lt_links.
      ENDIF.
    ENDLOOP.

    DATA(lt_counts) = count_items( is_cfg   = is_cfg
                                   it_items = read_items( is_cfg      = is_cfg
                                                          it_links    = lt_links
                                                          iv_max_rows = iv_max_rows ) ).

    LOOP AT it_files INTO ls_file.
      CLEAR ls_status.
      ls_status-file_id  = ls_file-file_id.
      ls_status-lot_type = is_cfg-lot_type.
      ls_status-sla_days = is_cfg-noc_sla_days.
      " The cap applies to the whole batch: no file's completion is proven
      ls_status-truncated = mv_truncated.
      READ TABLE lt_counts INTO DATA(ls_count) WITH TABLE KEY link = link_of( is_cfg  = is_cfg
                                                                               is_file = ls_file ).
      IF sy-subrc = 0.
        ls_status-found       = xsdbool( ls_count-total > 0 ).
        ls_status-total_items = ls_count-total.
        ls_status-done_items  = ls_count-done.
        ls_status-open_items  = ls_count-open.
        ls_status-open_keys   = ls_count-open_keys.
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
      mv_truncated = abap_true.
      DELETE rt_rows FROM iv_max_rows + 1.
    ENDIF.
  ENDMETHOD.


  METHOD read_items.
    DATA ls_query TYPE zif_cd_fmon_types=>ty_query.
    DATA lt_lot_link TYPE tt_lot_link.
    DATA lt_lot_keys TYPE zif_cd_fmon_types=>tt_key_value.

    IF it_links IS INITIAL.
      RETURN.
    ENDIF.

    IF is_cfg-hdr_table IS INITIAL.
      ls_query-table_name = to_upper( condense( is_cfg-item_table ) ).
      zcl_cd_fmon_query=>add_field( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-file_link
                                              iv_field = is_cfg-item_link_field
                                    CHANGING  cs_query = ls_query ).
      zcl_cd_fmon_query=>add_field( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-lot_key
                                              iv_field = is_cfg-item_lot_field
                                    CHANGING  cs_query = ls_query ).
      zcl_cd_fmon_query=>add_field( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-item_key
                                              iv_field = is_cfg-item_key_field
                                    CHANGING  cs_query = ls_query ).
      zcl_cd_fmon_query=>add_field( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-item_status
                                              iv_field = is_cfg-item_status_field
                                    CHANGING  cs_query = ls_query ).
      ls_query-in_field  = to_upper( condense( is_cfg-item_link_field ) ).
      ls_query-in_values = it_links.
      rt_items = run_query( is_query = ls_query iv_max_rows = iv_max_rows ).
      RETURN.
    ENDIF.

    " 1) lots of the files from the header table
    ls_query-table_name = to_upper( condense( is_cfg-hdr_table ) ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-lot_key
                                            iv_field = is_cfg-hdr_lot_field
                                  CHANGING  cs_query = ls_query ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-file_link
                                            iv_field = is_cfg-hdr_link_field
                                  CHANGING  cs_query = ls_query ).
    ls_query-in_field  = to_upper( condense( is_cfg-hdr_link_field ) ).
    ls_query-in_values = it_links.
    LOOP AT run_query( is_query = ls_query iv_max_rows = iv_max_rows ) INTO DATA(ls_header).
      INSERT VALUE #( lot_key = ls_header-lot_key
                      link    = ls_header-file_link ) INTO TABLE lt_lot_link.
      IF sy-subrc = 0.
        INSERT CONV zif_cd_fmon_types=>ty_key_value( ls_header-lot_key ) INTO TABLE lt_lot_keys.
      ENDIF.
    ENDLOOP.
    IF lt_lot_keys IS INITIAL.
      RETURN.
    ENDIF.

    " 2) items of those lots
    CLEAR ls_query.
    ls_query-table_name = to_upper( condense( is_cfg-item_table ) ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-lot_key
                                            iv_field = is_cfg-item_lot_field
                                  CHANGING  cs_query = ls_query ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-item_key
                                            iv_field = is_cfg-item_key_field
                                  CHANGING  cs_query = ls_query ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role = zif_cd_fmon_types=>gc_role-item_status
                                            iv_field = is_cfg-item_status_field
                                  CHANGING  cs_query = ls_query ).
    ls_query-in_field  = to_upper( condense( is_cfg-item_lot_field ) ).
    ls_query-in_values = lt_lot_keys.
    rt_items = run_query( is_query = ls_query iv_max_rows = iv_max_rows ).
    LOOP AT rt_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      READ TABLE lt_lot_link INTO DATA(ls_lot_link) WITH TABLE KEY lot_key = CONV #( <ls_item>-lot_key ).
      IF sy-subrc = 0.
        <ls_item>-file_link = ls_lot_link-link.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD count_items.
    LOOP AT it_items INTO DATA(ls_item).
      DATA(lv_link) = CONV zif_cd_fmon_types=>ty_key_value( condense( ls_item-file_link ) ).
      READ TABLE rt_counts ASSIGNING FIELD-SYMBOL(<ls_count>) WITH TABLE KEY link = lv_link.
      IF sy-subrc <> 0.
        INSERT VALUE #( link = lv_link ) INTO TABLE rt_counts ASSIGNING <ls_count>.
      ENDIF.
      <ls_count>-total += 1.
      IF zcl_cd_fmon_rules=>is_done( iv_status      = ls_item-item_status
                                     iv_done_values = is_cfg-done_values ) = abap_true.
        <ls_count>-done += 1.
      ELSE.
        <ls_count>-open += 1.
        IF <ls_count>-open <= gc_max_keys.
          DATA(lv_key) = COND string( WHEN ls_item-lot_key IS INITIAL THEN ls_item-item_key
                                      ELSE |{ ls_item-lot_key }/{ ls_item-item_key }| ).
          <ls_count>-open_keys = COND #( WHEN <ls_count>-open_keys IS INITIAL THEN lv_key
                                         ELSE |{ <ls_count>-open_keys }, { lv_key }| ).
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
