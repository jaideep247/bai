*&---------------------------------------------------------------------*
*& Artifact: zca_ops_cfg_preview.prog.abap
*& Purpose:
*& Configuration preview and rollback (build Q, docs/EXTENSION_AND_GATE_
*& PROOF.md section 4) - what a pending change will alter, before it
*& takes effect, through ZIF_CA_OPS_CFG_PREVIEW:
*&   catalogue  the processes whose activation changes between two dates
*&              (planned rows of ZCA_OPS_CATACT taking effect)
*&   rollback   the rollback of one activation row: delete a planned row,
*&              or the new row (date, state before, reason) to create in
*&              the configuration app with an approver (four-eyes)
*&   link       a layer (L) or link (K) of the link registry switched on
*&              or off: the effective links, the links ambiguous by design
*&              and the problems that change
*&   rule       a break bucket rule or a flow stage rule of an area
*&              switched off: the lines removed and the configuration
*&              version the findings will record
*& Authorisation ZCA_OPS 03 for CA_OPS. Read only: nothing is written; a
*& change is made in ZUI_CA_OPS_CFG on a customizing request.
*& Modification log:
*& 2026-11-16 | Initial version (build Q: configuration preview and rollback).
*&---------------------------------------------------------------------*
REPORT zca_ops_cfg_preview.

PARAMETERS p_cat RADIOBUTTON GROUP mode DEFAULT 'X'.
PARAMETERS p_from TYPE d DEFAULT sy-datum.
PARAMETERS p_to TYPE d.
PARAMETERS p_rb RADIOBUTTON GROUP mode.
PARAMETERS p_proc TYPE zif_ca_ops_cat_types=>ty_process_id.
PARAMETERS p_chg TYPE d.
PARAMETERS p_rest TYPE d.
PARAMETERS p_lnk RADIOBUTTON GROUP mode.
PARAMETERS p_tkind TYPE zif_ca_ops_link_types=>ty_flag1 DEFAULT 'L'.
PARAMETERS p_tid TYPE zif_ca_ops_link_types=>ty_object_id.
PARAMETERS p_on AS CHECKBOX.
PARAMETERS p_rul RADIOBUTTON GROUP mode.
PARAMETERS p_area TYPE zif_ca_ops_types=>ty_area.
PARAMETERS p_flow AS CHECKBOX.
PARAMETERS p_rule TYPE zif_ca_ops_brk_types=>ty_rule_id.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS main.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_column,
        kind      TYPE lvc_fname VALUE 'KIND',
        object_id TYPE lvc_fname VALUE 'OBJECT_ID',
        change    TYPE lvc_fname VALUE 'CHANGE',
        before    TYPE lvc_fname VALUE 'BEFORE',
        after     TYPE lvc_fname VALUE 'AFTER',
        detail    TYPE lvc_fname VALUE 'DETAIL',
      END OF gc_column.

    DATA mo_preview TYPE REF TO zif_ca_ops_cfg_preview.
    DATA mt_changes TYPE zif_ca_ops_gate_types=>tt_change.

    "! The registry rows with the layer or link of the selection switched on or off
    METHODS link_changes
      RETURNING
        VALUE(rt_changes) TYPE zif_ca_ops_gate_types=>tt_change.

    "! The rule set of the area before and after the rule of the selection is switched off
    METHODS rule_changes
      RETURNING
        VALUE(rt_changes) TYPE zif_ca_ops_gate_types=>tt_change.

    METHODS display.

    METHODS set_text
      IMPORTING
        io_columns TYPE REF TO cl_salv_columns_table
        iv_name    TYPE lvc_fname
        iv_text    TYPE clike.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD main.
    TRY.
        zcl_ca_ops_factory=>get_auth( )->check( iv_activity = zif_ca_ops_auth=>gc_activity-display
                                                iv_area     = zif_ca_ops_types=>gc_param_area ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        MESSAGE lx_error TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.
    mo_preview = NEW zcl_ca_ops_cfg_preview( ).

    IF p_rb = abap_true.
      DATA(ls_rollback) = mo_preview->catalogue_rollback( iv_process_id   = to_upper( p_proc )
                                                          iv_change_from  = p_chg
                                                          iv_today        = sy-datum
                                                          iv_restore_from = p_rest ).
      MESSAGE ls_rollback-text TYPE 'S'.
      RETURN.
    ENDIF.

    mt_changes = COND #( WHEN p_cat = abap_true THEN mo_preview->catalogue( iv_from = p_from iv_to = p_to )
                         WHEN p_lnk = abap_true THEN link_changes( )
                         WHEN p_rul = abap_true THEN rule_changes( ) ).
    DATA(lv_count) = lines( mt_changes ).
    MESSAGE s640(zca_ops) WITH lv_count.
    IF sy-batch = abap_false AND mt_changes IS NOT INITIAL.
      display( ).
    ENDIF.
  ENDMETHOD.


  METHOD link_changes.
    DATA(ls_current) = NEW zcl_ca_ops_link_dao( )->zif_ca_ops_link_dao~read_registry( ).
    DATA(ls_proposed) = ls_current.
    DATA(lv_id) = to_upper( p_tid ).
    IF p_tkind = zif_ca_ops_link_types=>gc_target_kind-layer.
      READ TABLE ls_proposed-layers ASSIGNING FIELD-SYMBOL(<ls_layer>)
           WITH TABLE KEY layer_id = CONV zif_ca_ops_link_types=>ty_layer_id( lv_id ).
      IF sy-subrc = 0.
        <ls_layer>-active = p_on.
      ENDIF.
      DELETE ls_proposed-activations WHERE target_kind = zif_ca_ops_link_types=>gc_target_kind-layer
                                       AND target_id   = lv_id.
    ELSE.
      DELETE ls_proposed-activations WHERE target_kind = zif_ca_ops_link_types=>gc_target_kind-link
                                       AND target_id   = lv_id.
      INSERT VALUE #( target_kind = zif_ca_ops_link_types=>gc_target_kind-link
                      target_id   = lv_id
                      active      = p_on ) INTO TABLE ls_proposed-activations.
    ENDIF.
    rt_changes = mo_preview->links( is_current = ls_current is_proposed = ls_proposed ).
  ENDMETHOD.


  METHOD rule_changes.
    DATA lt_before TYPE string_table.
    DATA lt_after TYPE string_table.

    DATA(lv_rule) = to_upper( p_rule ).
    IF p_flow = abap_true.
      DATA(lo_flow) = zcl_ca_ops_factory=>get_flow_dao( ).
      LOOP AT lo_flow->get_flows( p_area ) ASSIGNING FIELD-SYMBOL(<ls_flow>).
        DATA(ls_config) = lo_flow->get_config( <ls_flow> ).
        LOOP AT ls_config-rules ASSIGNING FIELD-SYMBOL(<ls_flow_rule>).
          DATA(lv_line) = zcl_ca_ops_cfg_version=>line( iv_kind = zif_ca_ops_gate_types=>gc_rule_set-flow
                                                        is_row  = <ls_flow_rule> ).
          INSERT lv_line INTO TABLE lt_before.
          IF <ls_flow_rule>-rule_id <> lv_rule.
            INSERT lv_line INTO TABLE lt_after.
          ENDIF.
        ENDLOOP.
      ENDLOOP.
      rt_changes = mo_preview->rule_set( iv_kind   = zif_ca_ops_gate_types=>gc_rule_set-flow
                                         it_before = lt_before
                                         it_after  = lt_after ).
      RETURN.
    ENDIF.
    LOOP AT zcl_ca_ops_factory=>get_brk_dao( )->get_rules( p_area ) ASSIGNING FIELD-SYMBOL(<ls_rule>).
      lv_line = zcl_ca_ops_cfg_version=>line( iv_kind = zif_ca_ops_gate_types=>gc_rule_set-break is_row = <ls_rule> ).
      INSERT lv_line INTO TABLE lt_before.
      IF <ls_rule>-rule_id <> lv_rule.
        INSERT lv_line INTO TABLE lt_after.
      ENDIF.
    ENDLOOP.
    rt_changes = mo_preview->rule_set( iv_kind   = zif_ca_ops_gate_types=>gc_rule_set-break
                                       it_before = lt_before
                                       it_after  = lt_after ).
  ENDMETHOD.


  METHOD display.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = mt_changes ).
        lo_alv->get_functions( )->set_all( abap_true ).
        DATA(lo_columns) = lo_alv->get_columns( ).
        lo_columns->set_optimize( abap_true ).
        set_text( io_columns = lo_columns iv_name = gc_column-kind iv_text = TEXT-c01 ).
        set_text( io_columns = lo_columns iv_name = gc_column-object_id iv_text = TEXT-c02 ).
        set_text( io_columns = lo_columns iv_name = gc_column-change iv_text = TEXT-c03 ).
        set_text( io_columns = lo_columns iv_name = gc_column-before iv_text = TEXT-c04 ).
        set_text( io_columns = lo_columns iv_name = gc_column-after iv_text = TEXT-c05 ).
        set_text( io_columns = lo_columns iv_name = gc_column-detail iv_text = TEXT-c06 ).
        lo_alv->display( ).
      CATCH cx_salv_msg INTO DATA(lx_salv).
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
