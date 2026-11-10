*&---------------------------------------------------------------------*
*& Artifact: zcd_ops_pattern_migrate.prog.abap
*& Purpose:
*& One-off migration of the configured CP wildcard patterns to PCRE (user
*& decision 2026-11-06). Reads every pattern of the suite's own configuration
*& tables (ZCD_EBS_FLOW_PAT, ZCD_FMON_IFACE, ZCD_JOB_STEP, ZCA_OPS_ALRULE,
*& the pattern-list parameters of ZCD_HCK_DEF, ZCD_HCK_SUPPRESS), shows old ->
*& new per row (ZCL_CD_OPS_PATTERN_CHECK=>PLAN_MIGRATION). Test mode (default)
*& writes nothing. Update mode writes only rows with status CONVERT - never a
*& pattern that does not compile or does not fit the field - after the client
*& policy of the configuration apps (changeable client, customizing request
*& where changes are recorded) and authorisation ZCD_OPS change (02) per
*& payment engine area; change stamps set, customizing rows recorded on the
*& request (VERIFY-ADT: ZCL_CA_OPS_CFG_TRANSPORT), one commit through the store.
*& Modification log:
*& 2026-11-06 | Initial version (PCRE patterns: migration of existing rows).
*& 2026-11-10 | ZCD_OPS display (03) checked per payment engine area before its rows are read (B7);
*&            | an area without it is named in a message and left out.
*&---------------------------------------------------------------------*
REPORT zcd_ops_pattern_migrate.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.
  PARAMETERS p_test AS CHECKBOX DEFAULT abap_true.
  PARAMETERS p_req TYPE trkorr.
SELECTION-SCREEN END OF BLOCK b01.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS main.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_column,
        table   TYPE lvc_fname VALUE 'TABLE',
        field   TYPE lvc_fname VALUE 'FIELD',
        row_key TYPE lvc_fname VALUE 'ROW_KEY',
        old     TYPE lvc_fname VALUE 'OLD',
        new     TYPE lvc_fname VALUE 'NEW',
        status  TYPE lvc_fname VALUE 'STATUS',
        message TYPE lvc_fname VALUE 'MESSAGE',
        key1    TYPE lvc_fname VALUE 'KEY1',
        key2    TYPE lvc_fname VALUE 'KEY2',
        is_list TYPE lvc_fname VALUE 'IS_LIST',
        length  TYPE lvc_fname VALUE 'MAX_LENGTH',
      END OF gc_column.

    DATA mt_rows TYPE zif_cd_ops_pattern_types=>tt_migration.

    "! Client policy, request and authorisation before anything is written
    METHODS may_write
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

    METHODS write_rows
      RAISING
        zcx_ca_ops_error.

    METHODS count
      IMPORTING
        iv_status       TYPE zif_cd_ops_pattern_types=>ty_status
      RETURNING
        VALUE(rv_count) TYPE i.

    METHODS display.
    METHODS set_text
      IMPORTING
        io_columns TYPE REF TO cl_salv_columns_table
        iv_name    TYPE lvc_fname
        iv_text    TYPE clike.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD main.
    DATA lt_areas TYPE zif_cd_ops_pattern_types=>tt_pe_area.
    " B7: rows of an area are read only with display authorisation for it (as ZCD_OPS_PATTERN_CHECK)
    DATA(lo_auth) = zcl_ca_ops_factory=>get_auth( ).
    LOOP AT VALUE zif_cd_ops_pattern_types=>tt_pe_area( ( zif_cd_ops_types=>gc_pe_area-core )
                                                        ( zif_cd_ops_types=>gc_pe_area-ebs )
                                                        ( zif_cd_ops_types=>gc_pe_area-file_monitor )
                                                        ( zif_cd_ops_types=>gc_pe_area-health_check ) )
         INTO DATA(lv_area).
      IF lo_auth->is_allowed( iv_activity = zif_ca_ops_auth=>gc_activity-display
                              iv_area  = lv_area ) = abap_true.
        INSERT lv_area INTO TABLE lt_areas.
      ELSE.
        MESSAGE s041(zcd_ops) WITH |{ zif_ca_ops_auth=>gc_object } { lv_area }| zif_ca_ops_auth=>gc_activity-display
                DISPLAY LIKE 'W'.
      ENDIF.
    ENDLOOP.
    IF lt_areas IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lo_dao) = zcl_cd_ops_factory=>get_pattern_dao( ).
    mt_rows = zcl_cd_ops_pattern_check=>plan_migration( lo_dao->get_migration_rows( lt_areas ) ).
    DATA(lv_convert) = count( zif_cd_ops_pattern_types=>gc_migration-convert ).

    IF p_test = abap_false AND lv_convert > 0.
      IF may_write( ) = abap_false.
        RETURN.
      ENDIF.
      DATA(lo_store) = zcl_ca_ops_factory=>get_store( ).
      TRY.
          write_rows( ).
          lo_store->commit( ).
        CATCH zcx_ca_ops_error INTO DATA(lx_error).
          lo_store->rollback( ).
          MESSAGE lx_error TYPE 'S' DISPLAY LIKE 'E'.
          RETURN.
      ENDTRY.
    ENDIF.

    MESSAGE s745(zcd_ops) WITH lv_convert
                               count( zif_cd_ops_pattern_types=>gc_migration-invalid )
                               + count( zif_cd_ops_pattern_types=>gc_migration-too_long )
                               lines( mt_rows ) - lv_convert
                               - count( zif_cd_ops_pattern_types=>gc_migration-invalid )
                               - count( zif_cd_ops_pattern_types=>gc_migration-too_long )
                               p_test.
    IF sy-batch = abap_false.
      display( ).
    ENDIF.
  ENDMETHOD.


  METHOD may_write.
    DATA lt_areas TYPE SORTED TABLE OF zif_ca_ops_types=>ty_area WITH UNIQUE KEY table_line.
    DATA(lo_gate) = zcl_ca_ops_cfg_factory=>get_gate( ).
    IF lo_gate->decision( )-update_allowed = abap_false.
      MESSAGE s748(zcd_ops) DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    DATA(ls_message) = lo_gate->check_request( p_req ).
    IF ls_message-number IS NOT INITIAL.
      MESSAGE ID zif_cd_ops_types=>gc_message_class TYPE 'S' NUMBER ls_message-number
              WITH ls_message-v1 ls_message-v2 ls_message-v3 DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    LOOP AT mt_rows ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE status = zif_cd_ops_pattern_types=>gc_migration-convert.
      INSERT zcl_cd_ops_pattern_check=>pe_area_of_table( <ls_row>-table ) INTO TABLE lt_areas.
    ENDLOOP.
    LOOP AT lt_areas ASSIGNING FIELD-SYMBOL(<lv_area>).
      IF lo_gate->is_authorized( iv_area = <lv_area>
                                 iv_actvt   = zif_ca_ops_cfg_types=>gc_actvt-change ) = abap_false.
        MESSAGE s407(zcd_ops) WITH zif_ca_ops_cfg_types=>gc_actvt-change <lv_area> DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
    ENDLOOP.
    rv_allowed = abap_true.
  ENDMETHOD.


  METHOD write_rows.
    DATA(lo_gate) = zcl_ca_ops_cfg_factory=>get_gate( ).
    DATA(lt_written) = zcl_cd_ops_factory=>get_pattern_dao( )->write_migration( mt_rows ).
    " Customizing rows on the request (no-op where the client does not record changes);
    " suppressions are application data and are not transported
    LOOP AT lt_written ASSIGNING FIELD-SYMBOL(<ls_written>).
      DATA(lv_entity) = zcl_cd_ops_pattern_check=>entity_of_table( <ls_written>-table ).
      IF lv_entity IS INITIAL.
        CONTINUE.
      ENDIF.
      lo_gate->record( iv_request   = p_req
                       it_relations = VALUE #( ( entity = lv_entity table = <ls_written>-table ) )
                       ir_create    = <ls_written>-created
                       ir_update    = <ls_written>-updated
                       ir_delete    = <ls_written>-deleted ).
    ENDLOOP.
    LOOP AT mt_rows ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE status = zif_cd_ops_pattern_types=>gc_migration-convert.
      <ls_row>-status = zif_cd_ops_pattern_types=>gc_migration-written.
    ENDLOOP.
  ENDMETHOD.


  METHOD count.
    rv_count = REDUCE #( INIT lv_count = 0
                         FOR ls_row IN mt_rows WHERE ( status = iv_status )
                         NEXT lv_count = lv_count + 1 ).
  ENDMETHOD.


  METHOD display.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = mt_rows ).
        lo_alv->get_functions( )->set_all( abap_true ).
        DATA(lo_columns) = lo_alv->get_columns( ).
        lo_columns->set_optimize( abap_true ).
        lo_columns->get_column( gc_column-key1 )->set_technical( abap_true ).
        lo_columns->get_column( gc_column-key2 )->set_technical( abap_true ).
        lo_columns->get_column( gc_column-is_list )->set_technical( abap_true ).
        set_text( io_columns = lo_columns iv_name = gc_column-table iv_text = TEXT-c01 ).
        set_text( io_columns = lo_columns iv_name = gc_column-field iv_text = TEXT-c02 ).
        set_text( io_columns = lo_columns iv_name = gc_column-row_key iv_text = TEXT-c03 ).
        set_text( io_columns = lo_columns iv_name = gc_column-old iv_text = TEXT-c04 ).
        set_text( io_columns = lo_columns iv_name = gc_column-new iv_text = TEXT-c05 ).
        set_text( io_columns = lo_columns iv_name = gc_column-status iv_text = TEXT-c06 ).
        set_text( io_columns = lo_columns iv_name = gc_column-message iv_text = TEXT-c07 ).
        set_text( io_columns = lo_columns iv_name = gc_column-length iv_text = TEXT-c08 ).
        lo_alv->display( ).
      CATCH cx_salv_msg cx_salv_not_found cx_salv_data_error INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD set_text.
    TRY.
        DATA(lo_column) = io_columns->get_column( iv_name ).
        lo_column->set_short_text( CONV #( iv_text ) ).
        lo_column->set_medium_text( CONV #( iv_text ) ).
        lo_column->set_long_text( CONV #( iv_text ) ).
      CATCH cx_salv_not_found ##NO_HANDLER.
        " Column of the row type only - nothing to label
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  NEW lcl_app( )->main( ).
