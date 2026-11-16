*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cfg_preview.clas.abap
*& Purpose:
*& Preview and rollback of configuration changes (ZIF_CA_OPS_CFG_PREVIEW,
*& build Q): catalogue states at two dates (ZIF_CA_OPS_CATALOG, the one
*& activation rule of the runner, the dashboard and the review), the
*& rollback proposal of one activation row (a planned row is deleted
*& before it takes effect; an effective row is answered by a new row from
*& a date with the state before it - history kept, approver required in
*& the app), the difference of two link registries as the walker sees them
*& (ZCL_CA_OPS_LINK_REGISTRY=>EFFECTIVE: effective links, links ambiguous
*& by design, problems) and of two rule sets (lines and the configuration
*& version a finding records). Pure apart from the catalogue it is given:
*& no database, nothing written.
*& Modification log:
*& 2026-11-16 | Initial version (build Q: configuration preview and rollback).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - configuration preview and rollback</p>
"! A rollback is a proposal, never an automatic change: the user creates (or deletes) the activation row in the
"! configuration app on a customizing request, with an approver who is not the user saving (four-eyes, 240).
CLASS zcl_ca_ops_cfg_preview DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_cfg_preview.

    "! @parameter io_catalog | The process catalogue (default ZCL_CA_OPS_FACTORY=>GET_CATALOG; a double in tests)
    METHODS constructor
      IMPORTING
        io_catalog TYPE REF TO zif_ca_ops_catalog OPTIONAL.

  PRIVATE SECTION.
    TYPES tt_link_ids TYPE SORTED TABLE OF zif_ca_ops_link_types=>ty_link_id WITH UNIQUE KEY table_line.
    TYPES tt_texts TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

    DATA mo_catalog TYPE REF TO zif_ca_ops_catalog.

    "! Links of the chains of an effective registry (the links a walk follows)
    METHODS effective_links
      IMPORTING
        is_effective   TYPE zif_ca_ops_link_types=>ty_effective
      RETURNING
        VALUE(rt_ids)  TYPE tt_link_ids.

    "! Text of every problem (or note) of a registry, for the set comparison
    METHODS problem_texts
      IMPORTING
        it_problems     TYPE zif_ca_ops_link_types=>tt_problem
      RETURNING
        VALUE(rt_texts) TYPE tt_texts.

    METHODS on_off
      IMPORTING
        iv_active      TYPE abap_bool
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.



CLASS zcl_ca_ops_cfg_preview IMPLEMENTATION.

  METHOD constructor.
    mo_catalog = COND #( WHEN io_catalog IS BOUND THEN io_catalog ELSE zcl_ca_ops_factory=>get_catalog( ) ).
  ENDMETHOD.


  METHOD zif_ca_ops_cfg_preview~catalogue.
    DATA(lt_before) = mo_catalog->states( iv_from ).
    DATA(lt_after) = mo_catalog->states( iv_to ).
    LOOP AT lt_after ASSIGNING FIELD-SYMBOL(<ls_after>).
      READ TABLE lt_before ASSIGNING FIELD-SYMBOL(<ls_before>) WITH TABLE KEY process_id = <ls_after>-process_id.
      DATA(lv_before) = COND abap_bool( WHEN sy-subrc = 0 THEN <ls_before>-active ).
      IF lv_before = <ls_after>-active.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( kind      = zif_ca_ops_gate_types=>gc_kind-catalogue
                      object_id = <ls_after>-process_id
                      change    = COND #( WHEN <ls_after>-active = abap_true
                                          THEN zif_ca_ops_gate_types=>gc_change-switched_on
                                          ELSE zif_ca_ops_gate_types=>gc_change-switched_off )
                      before    = on_off( lv_before )
                      after     = on_off( <ls_after>-active )
                      detail    = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_gate_types=>gc_msg-process_detail
                                                         iv_v1    = <ls_after>-source
                                                         iv_v2    = <ls_after>-valid_from
                                                         iv_v3    = <ls_after>-reason
                                                         iv_v4    = <ls_after>-approved_by ) ) INTO TABLE rt_changes.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_cfg_preview~catalogue_rollback.
    rs_rollback-process_id  = iv_process_id.
    rs_rollback-change_from = iv_change_from.
    " the row to undo: the activation row of the process effective from that date
    DATA(ls_changed) = mo_catalog->state( iv_process_id = iv_process_id iv_date = iv_change_from ).
    IF ls_changed-source <> zif_ca_ops_cat_types=>gc_source-activation OR ls_changed-valid_from <> iv_change_from.
      rs_rollback-action = zif_ca_ops_gate_types=>gc_action-none.
      rs_rollback-text   = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_gate_types=>gc_msg-nothing
                                                  iv_v1    = iv_process_id
                                                  iv_v2    = iv_change_from ).
      RETURN.
    ENDIF.
    " still planned: nothing has happened yet - delete the row before it takes effect
    IF iv_change_from > iv_today.
      rs_rollback-action = zif_ca_ops_gate_types=>gc_action-delete_planned.
      rs_rollback-text   = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_gate_types=>gc_msg-delete_planned
                                                  iv_v1    = iv_process_id
                                                  iv_v2    = iv_change_from ).
      RETURN.
    ENDIF.
    " effective: a new row restores the state the process had the day before (the history stays, never back-dated)
    DATA(lv_day_before) = CONV d( iv_change_from - 1 ).
    rs_rollback-action     = zif_ca_ops_gate_types=>gc_action-new_row.
    rs_rollback-active     = mo_catalog->state( iv_process_id = iv_process_id
                                                iv_date       = lv_day_before )-active.
    rs_rollback-valid_from = COND #( WHEN iv_restore_from > iv_today THEN iv_restore_from ELSE iv_today ).
    rs_rollback-reason     = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_gate_types=>gc_msg-reason
                                                    iv_v1    = iv_process_id
                                                    iv_v2    = iv_change_from ).
    rs_rollback-text       = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_gate_types=>gc_msg-new_row
                                                    iv_v1    = iv_process_id
                                                    iv_v2    = iv_change_from
                                                    iv_v3    = rs_rollback-valid_from
                                                    iv_v4    = on_off( rs_rollback-active ) ).
  ENDMETHOD.


  METHOD zif_ca_ops_cfg_preview~links.
    DATA lt_all TYPE tt_link_ids.

    DATA(ls_before) = zcl_ca_ops_link_registry=>effective( is_current ).
    DATA(ls_after) = zcl_ca_ops_link_registry=>effective( is_proposed ).
    DATA(lt_on_before) = effective_links( ls_before ).
    DATA(lt_on_after) = effective_links( ls_after ).
    LOOP AT is_current-links ASSIGNING FIELD-SYMBOL(<ls_link>).
      INSERT <ls_link>-link_id INTO TABLE lt_all.
    ENDLOOP.
    LOOP AT is_proposed-links ASSIGNING <ls_link>.
      INSERT <ls_link>-link_id INTO TABLE lt_all.
    ENDLOOP.

    LOOP AT lt_all ASSIGNING FIELD-SYMBOL(<lv_link>).
      DATA(lv_before) = xsdbool( line_exists( lt_on_before[ table_line = <lv_link> ] ) ).
      DATA(lv_after) = xsdbool( line_exists( lt_on_after[ table_line = <lv_link> ] ) ).
      IF lv_before = lv_after.
        CONTINUE.
      ENDIF.
      DATA(ls_link) = VALUE zif_ca_ops_link_types=>ty_link( is_proposed-links[ link_id = <lv_link> ]
                               DEFAULT VALUE #( is_current-links[ link_id = <lv_link> ] OPTIONAL ) ).
      INSERT VALUE #( kind      = zif_ca_ops_gate_types=>gc_kind-link
                      object_id = <lv_link>
                      change    = COND #( WHEN lv_after = abap_true THEN zif_ca_ops_gate_types=>gc_change-switched_on
                                          ELSE zif_ca_ops_gate_types=>gc_change-switched_off )
                      before    = on_off( lv_before )
                      after     = on_off( lv_after )
                      detail    = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_gate_types=>gc_msg-link_detail
                                                         iv_v1    = ls_link-from_object
                                                         iv_v2    = ls_link-to_object
                                                         iv_v3    = ls_link-layer_id
                                                         iv_v4    = ls_link-cardinality ) ) INTO TABLE rt_changes.
    ENDLOOP.

    " notes (ambiguous by design) and problems that appear or disappear
    DATA(lt_notes_before) = problem_texts( ls_before-notes ).
    DATA(lt_notes_after) = problem_texts( ls_after-notes ).
    DATA(lt_problems_before) = problem_texts( ls_before-problems ).
    DATA(lt_problems_after) = problem_texts( ls_after-problems ).
    LOOP AT lt_notes_after ASSIGNING FIELD-SYMBOL(<lv_text>).
      IF NOT line_exists( lt_notes_before[ table_line = <lv_text> ] ).
        INSERT VALUE #( kind = zif_ca_ops_gate_types=>gc_kind-ambiguous change = zif_ca_ops_gate_types=>gc_change-added
                        detail = <lv_text> ) INTO TABLE rt_changes.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_notes_before ASSIGNING <lv_text>.
      IF NOT line_exists( lt_notes_after[ table_line = <lv_text> ] ).
        INSERT VALUE #( kind = zif_ca_ops_gate_types=>gc_kind-ambiguous change = zif_ca_ops_gate_types=>gc_change-removed
                        detail = <lv_text> ) INTO TABLE rt_changes.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_problems_after ASSIGNING <lv_text>.
      IF NOT line_exists( lt_problems_before[ table_line = <lv_text> ] ).
        INSERT VALUE #( kind = zif_ca_ops_gate_types=>gc_kind-problem change = zif_ca_ops_gate_types=>gc_change-added
                        detail = <lv_text> ) INTO TABLE rt_changes.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_problems_before ASSIGNING <lv_text>.
      IF NOT line_exists( lt_problems_after[ table_line = <lv_text> ] ).
        INSERT VALUE #( kind = zif_ca_ops_gate_types=>gc_kind-problem change = zif_ca_ops_gate_types=>gc_change-removed
                        detail = <lv_text> ) INTO TABLE rt_changes.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_cfg_preview~rule_set.
    LOOP AT it_after ASSIGNING FIELD-SYMBOL(<lv_line>).
      IF NOT line_exists( it_before[ table_line = <lv_line> ] ).
        INSERT VALUE #( kind = zif_ca_ops_gate_types=>gc_kind-line object_id = iv_kind
                        change = zif_ca_ops_gate_types=>gc_change-added after = <lv_line> ) INTO TABLE rt_changes.
      ENDIF.
    ENDLOOP.
    LOOP AT it_before ASSIGNING <lv_line>.
      IF NOT line_exists( it_after[ table_line = <lv_line> ] ).
        INSERT VALUE #( kind = zif_ca_ops_gate_types=>gc_kind-line object_id = iv_kind
                        change = zif_ca_ops_gate_types=>gc_change-removed before = <lv_line> ) INTO TABLE rt_changes.
      ENDIF.
    ENDLOOP.
    " the configuration version the findings of the rule set record before and after the change
    DATA(lv_before) = CONV string( zcl_ca_ops_cfg_version=>of_lines( it_before ) ).
    DATA(lv_after) = CONV string( zcl_ca_ops_cfg_version=>of_lines( it_after ) ).
    IF lv_before <> lv_after.
      INSERT VALUE #( kind   = zif_ca_ops_gate_types=>gc_kind-version
                      object_id = iv_kind
                      change = zif_ca_ops_gate_types=>gc_change-changed
                      before = lv_before
                      after  = lv_after
                      detail = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_gate_types=>gc_msg-version
                                                      iv_v1    = iv_kind
                                                      iv_v2    = lines( rt_changes ) ) ) INTO TABLE rt_changes.
    ENDIF.
  ENDMETHOD.


  METHOD effective_links.
    LOOP AT is_effective-chains ASSIGNING FIELD-SYMBOL(<ls_chain>).
      LOOP AT <ls_chain>-links ASSIGNING FIELD-SYMBOL(<lv_link>).
        INSERT <lv_link> INTO TABLE rt_ids.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD problem_texts.
    LOOP AT it_problems ASSIGNING FIELD-SYMBOL(<ls_problem>).
      INSERT zcl_ca_ops_util=>text( iv_msgno = <ls_problem>-msgno
                                    iv_v1    = <ls_problem>-v1
                                    iv_v2    = <ls_problem>-v2
                                    iv_v3    = <ls_problem>-v3
                                    iv_v4    = <ls_problem>-v4 ) INTO TABLE rt_texts.
    ENDLOOP.
  ENDMETHOD.


  METHOD on_off.
    rv_text = COND #( WHEN iv_active = abap_true THEN zif_ca_ops_gate_types=>gc_change-switched_on
                      ELSE zif_ca_ops_gate_types=>gc_change-switched_off ).
  ENDMETHOD.

ENDCLASS.
