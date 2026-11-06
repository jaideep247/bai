*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_lot_reader.clas.testclasses.abap
*& Purpose:
*& Application tests of the returns/NOC lot reader with LTD_* DAO and
*& DDIC doubles (header -> item join, completeness counting, config gaps).
*& Static ABAP Unit only; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | ATC-equivalent fixes: ORDER BY, CHECK before FOR ALL ENTRIES, sy-subrc, keyless SORT.
*& 2026-11-06 | Audit A38: row cap detection (truncated status).
*& 2026-11-06 | Performance fix 8: counts from the grouped read (exact beyond the item cap), truncation only
*&            | from the lot read, open keys read only for links with open items.
*&---------------------------------------------------------------------*
CLASS ltd_ddic DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_ddic.
ENDCLASS.


CLASS ltd_ddic IMPLEMENTATION.
  METHOD zif_cd_fmon_ddic~describe_table.
    " Every configured name exists: field validation itself is proven in ZCL_CD_FMON_QUERY
    DATA ls_field TYPE zif_cd_fmon_types=>ty_ddic_field.
    DATA(lt_names) = VALUE string_table( ( `LOTNO` ) ( `FILEREF` ) ( `ITEMNO` ) ( `ITEMSTAT` ) ).
    LOOP AT lt_names INTO DATA(lv_name).
      ls_field-fieldname = lv_name.
      ls_field-inttype   = 'C'.
      INSERT ls_field INTO TABLE rt_fields.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_dao PARTIALLY IMPLEMENTED.
    DATA mt_header TYPE zif_cd_fmon_types=>tt_raw_row.
    DATA mt_items TYPE zif_cd_fmon_types=>tt_raw_row.
    DATA mt_queries TYPE STANDARD TABLE OF zif_cd_fmon_types=>ty_query WITH EMPTY KEY.
    DATA mv_counts TYPE i.
ENDCLASS.


CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_fmon_dao~read_legacy.
    INSERT is_query INTO TABLE mt_queries.
    rt_rows = COND #( WHEN is_query-table_name = 'ZLOT_HDR' THEN mt_header ELSE mt_items ).
    IF is_query-max_rows > 0 AND lines( rt_rows ) > is_query-max_rows.
      DELETE rt_rows FROM is_query-max_rows + 1.
    ENDIF.
  ENDMETHOD.
  " Fix 8: GROUP BY the query's fields (by role), COUNT(*) - as the database does it
  METHOD zif_cd_fmon_dao~count_legacy.
    DATA ls_group TYPE zif_cd_fmon_types=>ty_raw_count.
    FIELD-SYMBOLS <lv_from> TYPE string.
    FIELD-SYMBOLS <lv_to> TYPE string.
    INSERT is_query INTO TABLE mt_queries.
    mv_counts += 1.
    LOOP AT mt_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      CLEAR ls_group.
      LOOP AT is_query-fields ASSIGNING FIELD-SYMBOL(<ls_field>).
        UNASSIGN: <lv_from>, <lv_to>.
        ASSIGN COMPONENT <ls_field>-role OF STRUCTURE <ls_item> TO <lv_from>.
        IF <lv_from> IS NOT ASSIGNED.
          CONTINUE.
        ENDIF.
        ASSIGN COMPONENT <ls_field>-role OF STRUCTURE ls_group-row TO <lv_to>.
        IF <lv_to> IS ASSIGNED.
          <lv_to> = <lv_from>.
        ENDIF.
      ENDLOOP.
      READ TABLE rt_counts ASSIGNING FIELD-SYMBOL(<ls_count>) WITH KEY row = ls_group-row.
      IF sy-subrc = 0.
        <ls_count>-row_count += 1.
      ELSE.
        ls_group-row_count = 1.
        INSERT ls_group INTO TABLE rt_counts.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_lot_reader DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_flags,
        open_items   TYPE i,
        no_status_field TYPE abap_bool,
      END OF ty_flags.

    CONSTANTS gc_file TYPE zif_cd_fmon_types=>ty_file_name VALUE 'ACH_RET_20261102'.
    CONSTANTS gc_lot TYPE string VALUE `0000004711`.

    DATA mo_dao TYPE REF TO ltd_dao.
    DATA ms_cfg TYPE zif_cd_fmon_types=>ty_lotcfg.
    DATA mt_files TYPE zif_cd_fmon_types=>tt_file.

    METHODS setup.
    METHODS teardown.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.

    METHODS act
      RETURNING
        VALUE(rt_status) TYPE zif_cd_fmon_types=>tt_lot_status
      RAISING
        zcx_cd_ops_error.

    METHODS one_open_item_is_counted FOR TESTING.
    METHODS lot_items_read_by_lot_key FOR TESTING.
    METHODS incomplete_config_is_refused FOR TESTING.
    METHODS row_cap_marks_truncated FOR TESTING.
    METHODS below_cap_is_complete FOR TESTING.
    METHODS item_counts_exact_beyond_cap FOR TESTING.
    METHODS no_open_items_no_key_read FOR TESTING.

ENDCLASS.


CLASS ltc_lot_reader IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    zcl_cd_fmon_injector=>inject_dao( mo_dao ).
    zcl_cd_fmon_injector=>inject_ddic( NEW ltd_ddic( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_fmon_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_file TYPE zif_cd_fmon_types=>ty_file.
    DATA ls_row TYPE zif_cd_fmon_types=>ty_raw_row.
    CLEAR: ms_cfg, mt_files, mo_dao->mt_header, mo_dao->mt_items.

    ms_cfg-iface_id          = zif_cd_fmon_types=>gc_wildcard.
    ms_cfg-lot_type          = zif_cd_fmon_types=>gc_lot_type-returns.
    ms_cfg-hdr_table         = 'ZLOT_HDR'.
    ms_cfg-hdr_lot_field     = 'LOTNO'.
    ms_cfg-hdr_link_field    = 'FILEREF'.
    ms_cfg-item_table        = 'ZLOT_ITEM'.
    ms_cfg-item_lot_field    = 'LOTNO'.
    ms_cfg-item_key_field    = 'ITEMNO'.
    ms_cfg-item_status_field = COND #( WHEN is_flags-no_status_field = abap_false THEN 'ITEMSTAT' ).
    ms_cfg-link_by           = zif_cd_fmon_types=>gc_link_by-name.
    ms_cfg-done_values       = 'X'.
    ms_cfg-active            = abap_true.

    ls_file-file_id   = CONV zif_cd_fmon_types=>ty_file_id( 1 ).
    ls_file-file_name = gc_file.
    INSERT ls_file INTO TABLE mt_files.

    ls_row-lot_key   = gc_lot.
    ls_row-file_link = gc_file.
    INSERT ls_row INTO TABLE mo_dao->mt_header.

    CLEAR ls_row.
    ls_row-lot_key = gc_lot.
    DO 3 TIMES.
      ls_row-item_key    = |{ sy-index }|.
      ls_row-item_status = COND #( WHEN sy-index <= 3 - is_flags-open_items THEN `X` ELSE `` ).
      INSERT ls_row INTO TABLE mo_dao->mt_items.
    ENDDO.
  ENDMETHOD.


  METHOD act.
    rt_status = zcl_cd_fmon_factory=>get_lot_reader( )->read( is_cfg   = ms_cfg
                                                              it_files = mt_files ).
  ENDMETHOD.


  " Rule: every item of the file's lot is counted; an item whose status is not
  " in the done list is open (whole returned table asserted).
  METHOD one_open_item_is_counted.
    DATA lt_exp TYPE zif_cd_fmon_types=>tt_lot_status.
    DATA ls_exp TYPE zif_cd_fmon_types=>ty_lot_status.
    TRY.
        configure_scenario( VALUE #( open_items = 1 ) ).
        ls_exp-file_id     = CONV zif_cd_fmon_types=>ty_file_id( 1 ).
        ls_exp-lot_type    = zif_cd_fmon_types=>gc_lot_type-returns.
        ls_exp-found       = abap_true.
        ls_exp-total_items = 3.
        ls_exp-done_items  = 2.
        ls_exp-open_items  = 1.
        ls_exp-open_keys   = |{ gc_lot }/3|.
        INSERT ls_exp INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals( act = act( ) exp = lt_exp
                                            msg = '3 items, 2 done must give 1 open item' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: items are selected by the lot keys found in the header for the file (no free WHERE).
  METHOD lot_items_read_by_lot_key.
    TRY.
        configure_scenario( VALUE #( ) ).
        act( ).
        DATA(ls_items) = VALUE #( mo_dao->mt_queries[ 2 ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_items-in_values
                                            exp = VALUE zif_cd_fmon_types=>tt_key_value( ( CONV #( gc_lot ) ) )
                                            msg = 'Item read must be restricted to the lot key' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a lot row without item status field is refused (message 208), nothing is read.
  METHOD incomplete_config_is_refused.
    DATA lv_msgno TYPE symsgno.
    configure_scenario( VALUE #( no_status_field = abap_true ) ).
    TRY.
        act( ).
      CATCH zcx_cd_ops_error INTO DATA(lx).
        lv_msgno = lx->if_t100_message~t100key-msgno.
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = lv_msgno exp = '208'
                                        msg = 'Missing item status field must raise 208' ).
    cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_queries
                                         msg = 'No table may be read' ).
  ENDMETHOD.


  " Audit A38: when the lot (header) scan reaches the row cap, lots of the file may lie beyond
  " it - the status says truncated, so no outcome is derived from the partial count.
  " Fix 8: the item counts are exact (grouped read), only the lot read can be cut off
  METHOD row_cap_marks_truncated.
    DATA ls_row TYPE zif_cd_fmon_types=>ty_raw_row.
    TRY.
        configure_scenario( VALUE #( open_items = 0 ) ).
        ls_row-lot_key   = |{ gc_lot }9|.
        ls_row-file_link = gc_file.
        INSERT ls_row INTO TABLE mo_dao->mt_header.
        DATA(lt_status) = zcl_cd_fmon_factory=>get_lot_reader( )->read( is_cfg      = ms_cfg
                                                                        it_files    = mt_files
                                                                        iv_max_rows = 1 ).
        cl_abap_unit_assert=>assert_true( act = VALUE #( lt_status[ 1 ]-truncated OPTIONAL )
                                          msg = '2 lots with a cap of 1 must be marked truncated' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( mo_dao->mt_queries[ 1 ]-max_rows OPTIONAL ) exp = 2
                                            msg = 'One row beyond the cap must be requested to detect truncation' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Fix 8 (A38 where counts are exact): 3 items with an item cap of 2 are all counted from the
  " grouped read - the batch is complete, not truncated
  METHOD item_counts_exact_beyond_cap.
    TRY.
        configure_scenario( VALUE #( open_items = 1 ) ).
        DATA(lt_status) = zcl_cd_fmon_factory=>get_lot_reader( )->read( is_cfg      = ms_cfg
                                                                        it_files    = mt_files
                                                                        iv_max_rows = 2 ).
        cl_abap_unit_assert=>assert_false( act = VALUE #( lt_status[ 1 ]-truncated OPTIONAL )
                                           msg = 'Exact counts: an item cap reached by the key sample is no truncation' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_status[ 1 ]-total_items OPTIONAL ) exp = 3
                                            msg = 'All 3 items must be counted' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_status[ 1 ]-open_items OPTIONAL ) exp = 1
                                            msg = 'The open item beyond the cap must be counted' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Fix 8: a lot with every item done is counted without reading a single item row
  METHOD no_open_items_no_key_read.
    TRY.
        configure_scenario( VALUE #( open_items = 0 ) ).
        DATA(lt_status) = act( ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_status[ 1 ]-done_items OPTIONAL ) exp = 3
                                            msg = 'All 3 items must be done' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_queries ) exp = 2
                                            msg = 'Lot read and grouped count only - no item key read' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_counts exp = 1
                                            msg = 'One grouped count for the batch' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A38: a scan below the cap is complete
  METHOD below_cap_is_complete.
    TRY.
        configure_scenario( VALUE #( open_items = 0 ) ).
        DATA(lt_status) = zcl_cd_fmon_factory=>get_lot_reader( )->read( is_cfg      = ms_cfg
                                                                        it_files    = mt_files
                                                                        iv_max_rows = 10 ).
        cl_abap_unit_assert=>assert_false( act = VALUE #( lt_status[ 1 ]-truncated OPTIONAL )
                                           msg = '3 items with a cap of 10 must not be truncated' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
