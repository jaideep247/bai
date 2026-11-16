*&---------------------------------------------------------------------*
*& Artifact: zcd_ops_postarea_copy.prog.abap
*& Purpose:
*& Migration step of the typed product mapping tables (product review
*& 2026-11-15): copies the stored FQC0 entries of one purpose (posting area
*& ZRSN / ZPMC / ZBTM / ZBTR, TFK033D read-only) into a new mapping version
*& of its typed table (ZCD_OPS_MAP*), and shows every entry with its status
*& (ZCL_CD_OPS_POSTAREA_COPY=>PLAN). Test mode (default) writes nothing.
*& Update mode writes only COPY rows of an unused version, after the client
*& policy of the configuration apps (changeable client, customizing request
*& where changes are recorded) and authorisation ZCA_OPS change (02) of area
*& CD_OPS; rows recorded on the request, one commit through the store. The
*& copy changes no behaviour: the source (POSTAREA_SOURCE_*) and the active
*& version (POSTAREA_VERSION_*) stay parameters (FICA_Posting_Areas.md).
*& Modification log:
*& 2026-11-15 | Initial version (typed product mapping tables, migration step).
*&---------------------------------------------------------------------*
REPORT zcd_ops_postarea_copy.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.
  PARAMETERS p_purp TYPE zif_cd_ops_postarea_types=>ty_purpose OBLIGATORY.
  PARAMETERS p_vers TYPE zif_cd_ops_postarea_types=>ty_version OBLIGATORY.
  PARAMETERS p_test AS CHECKBOX DEFAULT abap_true.
  PARAMETERS p_req TYPE trkorr.
SELECTION-SCREEN END OF BLOCK b01.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS main.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_column,
        status TYPE lvc_fname VALUE 'STATUS',
      END OF gc_column.

    DATA mt_rows TYPE zif_cd_ops_postarea_types=>tt_copy_row.

    "! Client policy, request and authorisation before anything is written
    METHODS may_write
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

    METHODS write_rows
      RAISING
        zcx_ca_ops_error.

    METHODS display.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD main.
    IF zcl_ca_ops_factory=>get_auth( )->is_allowed( iv_activity = zif_ca_ops_auth=>gc_activity-display
                                                     iv_area     = zif_cd_ops_types=>gc_pe_area-core ) = abap_false.
      MESSAGE s041(zcd_ops) WITH |{ zif_ca_ops_auth=>gc_object } { zif_cd_ops_types=>gc_pe_area-core }|
                                 zif_ca_ops_auth=>gc_activity-display DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    mt_rows = zcl_cd_ops_postarea_copy=>plan( iv_purpose = p_purp iv_version = p_vers ).
    DATA(lv_copy) = zcl_cd_ops_postarea_copy=>count( it_rows   = mt_rows
                                                     iv_status = zif_cd_ops_postarea_types=>gc_copy-copy ).
    DATA(lv_table) = zcl_cd_ops_postarea_layout=>table_of( p_purp ).
    IF zcl_cd_ops_postarea_copy=>count( it_rows   = mt_rows
                                        iv_status = zif_cd_ops_postarea_types=>gc_copy-version_used ) > 0.
      MESSAGE s447(zcd_ops) WITH p_vers lv_table DISPLAY LIKE 'W'.
    ELSEIF p_test = abap_false AND lv_copy > 0.
      IF may_write( ) = abap_false.
        RETURN.
      ENDIF.
      DATA(lo_store) = zcl_ca_ops_factory=>get_store( ).
      TRY.
          write_rows( ).
          lo_store->commit( ).
          MESSAGE s446(zcd_ops) WITH lv_copy lv_table p_vers.
        CATCH zcx_ca_ops_error INTO DATA(lx_error).
          lo_store->rollback( ).
          MESSAGE lx_error TYPE 'S' DISPLAY LIKE 'E'.
          RETURN.
      ENDTRY.
    ELSE.
      MESSAGE s445(zcd_ops) WITH lv_copy lv_table p_vers lines( mt_rows ) - lv_copy.
    ENDIF.
    IF sy-batch = abap_false.
      display( ).
    ENDIF.
  ENDMETHOD.


  METHOD may_write.
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
    IF lo_gate->is_authorized( iv_area  = zif_cd_ops_types=>gc_pe_area-core
                               iv_actvt = zif_ca_ops_cfg_types=>gc_actvt-change ) = abap_false.
      MESSAGE s407(zcd_ops) WITH zif_ca_ops_cfg_types=>gc_actvt-change zif_cd_ops_types=>gc_pe_area-core
              DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    rv_allowed = abap_true.
  ENDMETHOD.


  METHOD write_rows.
    zcl_cd_ops_postarea_copy=>write( EXPORTING iv_purpose = p_purp
                                               iv_version = p_vers
                                     IMPORTING er_rows    = DATA(lr_rows)
                                     CHANGING  ct_rows    = mt_rows ).
    " Customizing rows on the request (no-op where the client does not record changes)
    zcl_ca_ops_cfg_factory=>get_gate( )->record(
      iv_request   = p_req
      it_relations = VALUE #( ( entity = zcl_cd_ops_postarea_layout=>entity_of( p_purp )
                                table  = zcl_cd_ops_postarea_layout=>table_of( p_purp ) ) )
      ir_create    = lr_rows ).
  ENDMETHOD.


  METHOD display.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = mt_rows ).
        lo_alv->get_functions( )->set_all( abap_true ).
        DATA(lo_columns) = lo_alv->get_columns( ).
        lo_columns->set_optimize( abap_true ).
        DATA(lo_column) = lo_columns->get_column( gc_column-status ).
        lo_column->set_short_text( CONV #( TEXT-c01 ) ).
        lo_column->set_medium_text( CONV #( TEXT-c01 ) ).
        lo_column->set_long_text( CONV #( TEXT-c01 ) ).
        lo_alv->display( ).
      CATCH cx_salv_msg cx_salv_not_found cx_salv_data_error INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  NEW lcl_app( )->main( ).
