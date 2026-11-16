*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cfg_preview.clas.testclasses.abap
*& Purpose:
*& Unit tests of the configuration preview and rollback (build Q) with a
*& catalogue double: dunning planned from 1 March is shown as switched on
*& between a February and a March date, a process without change is not
*& listed; the rollback of a planned row is its deletion, of an effective
*& row a new row from today (never back-dated) with the state of the day
*& before, of a date without an activation row nothing; a customer layer
*& switched off by an override takes its links out and the preview names
*& them; a new link ambiguous by design is shown; a rule switched off is a
*& removed line with a new configuration version. No database. Does not
*& prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-16 | Initial version (build Q: configuration preview and rollback).
*&---------------------------------------------------------------------*
CLASS ltd_catalog DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_catalog PARTIALLY IMPLEMENTED.
    "! The activation rows of one process: effective from, active
    TYPES:
      BEGIN OF ty_row,
        valid_from TYPE d,
        active     TYPE abap_bool,
      END OF ty_row.
    TYPES tt_row TYPE SORTED TABLE OF ty_row WITH UNIQUE KEY valid_from.
    DATA mt_rows TYPE tt_row.
    CONSTANTS gc_process TYPE zif_ca_ops_cat_types=>ty_process_id VALUE 'ZT_DUNNING'.
    CONSTANTS gc_steady TYPE zif_ca_ops_cat_types=>ty_process_id VALUE 'ZT_STEADY'.
ENDCLASS.

CLASS ltd_catalog IMPLEMENTATION.
  METHOD zif_ca_ops_catalog~state.
    " the latest row on or before the day decides, else the default (inactive)
    rs_state = VALUE #( process_id = iv_process_id source = zif_ca_ops_cat_types=>gc_source-default ).
    IF iv_process_id <> gc_process.
      RETURN.
    ENDIF.
    LOOP AT mt_rows ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE valid_from <= iv_date.
      rs_state-active     = <ls_row>-active.
      rs_state-valid_from = <ls_row>-valid_from.
      rs_state-source     = zif_ca_ops_cat_types=>gc_source-activation.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_ca_ops_catalog~states.
    INSERT zif_ca_ops_catalog~state( iv_process_id = gc_process iv_date = iv_date ) INTO TABLE rt_states.
    INSERT zif_ca_ops_catalog~state( iv_process_id = gc_steady iv_date = iv_date ) INTO TABLE rt_states.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_cfg_preview DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        feb    TYPE d VALUE '20270215',
        go     TYPE d VALUE '20270301',
        today  TYPE d VALUE '20270310',
        later  TYPE d VALUE '20270401',
        cust   TYPE zif_ca_ops_link_types=>ty_layer_id VALUE 'XX',
        std    TYPE zif_ca_ops_link_types=>ty_layer_id VALUE 'ZS',
        link   TYPE zif_ca_ops_link_types=>ty_link_id VALUE 'XX_ITEM_TO_REQ',
      END OF gc.

    DATA mo_catalog TYPE REF TO ltd_catalog.
    DATA mo_cut TYPE REF TO zif_ca_ops_cfg_preview.

    METHODS setup.
    METHODS registry
      RETURNING
        VALUE(rs_registry) TYPE zif_ca_ops_link_types=>ty_registry.

    METHODS planned_row_shown_on_date   FOR TESTING.
    METHODS rollback_of_planned_deletes FOR TESTING.
    METHODS rollback_of_effective_row   FOR TESTING.
    METHODS rollback_without_row        FOR TESTING.
    METHODS layer_off_previewed         FOR TESTING.
    METHODS new_ambiguity_previewed     FOR TESTING.
    METHODS rule_off_changes_version    FOR TESTING.
ENDCLASS.


CLASS ltc_cfg_preview IMPLEMENTATION.

  METHOD setup.
    mo_catalog = NEW #( ).
    " dunning goes live on 1 March
    INSERT VALUE #( valid_from = gc-go active = abap_true ) INTO TABLE mo_catalog->mt_rows.
    mo_cut = NEW zcl_ca_ops_cfg_preview( mo_catalog ).
  ENDMETHOD.


  " A standard document, a customer request table and the customer's "to one" link item -> request
  METHOD registry.
    rs_registry-layers = VALUE #( ( layer_id = gc-std layer_kind = 'S' layer_rank = 10 id_prefix = 'ZS_' active = abap_true )
                                  ( layer_id = gc-cust layer_kind = 'C' layer_rank = 30 id_prefix = 'XX_'
                                    active = abap_true ) ).
    rs_registry-objects = VALUE #( ( object_id = 'ZS_ITEM' layer_id = gc-std source_name = 'ZITEM' source_kind = 'T'
                                     key_fields = 'DOCNO' active = abap_true )
                                   ( object_id = 'XX_REQUEST' layer_id = gc-cust source_name = 'ZXX_REQ'
                                     source_kind = 'T' key_fields = 'REQ_ID' active = abap_true ) ).
    rs_registry-fields = VALUE #( ( object_id = 'XX_REQUEST' field_name = 'FEEDER' layer_id = gc-cust
                                    source_name = 'ZXX_REQ' evidence = 'C' )
                                  ( object_id = 'XX_REQUEST' field_name = 'REQ_ID' layer_id = gc-cust
                                    source_name = 'ZXX_REQ' evidence = 'C' )
                                  ( object_id = 'ZS_ITEM' field_name = 'DOCNO' layer_id = gc-std
                                    source_name = 'ZITEM' evidence = 'C' )
                                  ( object_id = 'ZS_ITEM' field_name = 'ZZXX_REQ' layer_id = gc-cust
                                    source_name = 'ZITEM' evidence = 'C' ) ).
    rs_registry-links = VALUE #( ( link_id = gc-link layer_id = gc-cust from_object = 'ZS_ITEM' to_object = 'XX_REQUEST'
                                   cardinality = 'N1' quality = 'C' active = abap_true ) ).
    rs_registry-conds = VALUE #( ( link_id = gc-link cond_no = 1 cond_kind = 'EQ' from_ref = 'ZITEM-ZZXX_REQ'
                                   to_ref = 'ZXX_REQ-REQ_ID' ) ).
  ENDMETHOD.


  " Rule: a row planned for 1 March shows the process switching on between February and March
  METHOD planned_row_shown_on_date.
    DATA(lt_changes) = mo_cut->catalogue( iv_from = gc-feb iv_to = gc-later ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_changes ) exp = 1 msg = 'Only the process that changes' ).
    cl_abap_unit_assert=>assert_equals( act = lt_changes[ 1 ]-object_id exp = ltd_catalog=>gc_process msg = 'Dunning' ).
    cl_abap_unit_assert=>assert_equals( act = lt_changes[ 1 ]-change exp = zif_ca_ops_gate_types=>gc_change-switched_on
                                        msg = 'Switched on' ).
    cl_abap_unit_assert=>assert_initial( act = mo_cut->catalogue( iv_from = gc-go iv_to = gc-later )
                                         msg = 'Nothing changes after the row took effect' ).
  ENDMETHOD.


  " Rule: a row still planned is deleted before it takes effect - nothing has happened yet
  METHOD rollback_of_planned_deletes.
    DATA(ls_rollback) = mo_cut->catalogue_rollback( iv_process_id  = ltd_catalog=>gc_process
                                                    iv_change_from = gc-go
                                                    iv_today       = gc-feb ).
    cl_abap_unit_assert=>assert_equals( act = ls_rollback-action exp = zif_ca_ops_gate_types=>gc_action-delete_planned
                                        msg = 'Delete the planned row' ).
  ENDMETHOD.


  " Rule: an effective row is answered by a new row with the state of the day before, from today at the
  " earliest (the history stays; never back-dated); the approver is the app's four-eyes rule
  METHOD rollback_of_effective_row.
    DATA(ls_rollback) = mo_cut->catalogue_rollback( iv_process_id   = ltd_catalog=>gc_process
                                                    iv_change_from  = gc-go
                                                    iv_today        = gc-today
                                                    iv_restore_from = gc-feb ).
    cl_abap_unit_assert=>assert_equals( act = ls_rollback-action exp = zif_ca_ops_gate_types=>gc_action-new_row
                                        msg = 'A new row' ).
    cl_abap_unit_assert=>assert_false( act = ls_rollback-active msg = 'The state before: inactive' ).
    cl_abap_unit_assert=>assert_equals( act = ls_rollback-valid_from exp = gc-today msg = 'Never back-dated' ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_rollback-reason msg = 'The reason of the new row' ).
  ENDMETHOD.


  METHOD rollback_without_row.
    DATA(ls_rollback) = mo_cut->catalogue_rollback( iv_process_id  = ltd_catalog=>gc_process
                                                    iv_change_from = gc-feb
                                                    iv_today       = gc-today ).
    cl_abap_unit_assert=>assert_equals( act = ls_rollback-action exp = zif_ca_ops_gate_types=>gc_action-none
                                        msg = 'No activation row from that date: nothing to roll back' ).
  ENDMETHOD.


  " Rule: switching the customer layer off (an override row, or GATE_LINK_LAYERS_OFF) takes its links out
  METHOD layer_off_previewed.
    DATA(ls_current) = registry( ).
    DATA(ls_proposed) = zcl_ca_ops_link_registry=>switch_off_layers( is_registry = ls_current
                                                                     it_layers   = VALUE #( ( CONV #( gc-cust ) ) ) ).
    DATA(lt_changes) = mo_cut->links( is_current = ls_current is_proposed = ls_proposed ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_changes[ kind      = zif_ca_ops_gate_types=>gc_kind-link
                                                                             object_id = gc-link
                                                                             change    = zif_ca_ops_gate_types=>gc_change-switched_off ] ) )
                                      msg = 'The link of the layer is switched off' ).
  ENDMETHOD.


  " Rule: a change that makes a "to one" link ambiguous by design is shown before it is transported
  METHOD new_ambiguity_previewed.
    DATA(ls_current) = registry( ).
    DATA(ls_proposed) = ls_current.
    ls_proposed-objects[ object_id = 'XX_REQUEST' ]-identity_fields = 'FEEDER,REQ_ID'.
    DATA(lt_changes) = mo_cut->links( is_current = ls_current is_proposed = ls_proposed ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_changes[ kind   = zif_ca_ops_gate_types=>gc_kind-ambiguous
                                                                             change = zif_ca_ops_gate_types=>gc_change-added ] ) )
                                      msg = 'Newly ambiguous by design' ).
  ENDMETHOD.


  " Rule: a rule switched off is a removed line; the findings carry a new configuration version
  METHOD rule_off_changes_version.
    DATA(lt_before) = VALUE string_table( ( `BRK_RULE|*|FICA_RETURNS|1|RETURNS` ) ( `BRK_RULE|*|FICA_TIMING|2|TIMING` ) ).
    DATA(lt_after) = VALUE string_table( ( `BRK_RULE|*|FICA_TIMING|2|TIMING` ) ).
    DATA(lt_changes) = mo_cut->rule_set( iv_kind   = zif_ca_ops_gate_types=>gc_rule_set-break
                                         it_before = lt_before
                                         it_after  = lt_after ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_changes[ change = zif_ca_ops_gate_types=>gc_change-removed ] ) )
                                      msg = 'The removed rule line' ).
    DATA(ls_version) = lt_changes[ kind = zif_ca_ops_gate_types=>gc_kind-version ].
    cl_abap_unit_assert=>assert_differs( act = ls_version-after exp = ls_version-before msg = 'A new version' ).
  ENDMETHOD.

ENDCLASS.
