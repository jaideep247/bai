*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_flow_config.clas.abap
*& Purpose:
*& Cross-row rules of an account flow's configuration (pure, no database):
*& every active rule names an active stage of the flow (or OTHER) and only
*& criteria of its own line source, and at least one criterion (a rule
*& without one would hide the row OTHER); the flow has an active stage;
*& one account per company code and currency of a role that receives an
*& expected counter-posting (it lands on exactly one column); a role a stage names for its expected
*& postings or a tile row names is held by an account, and a tile row
*& names an active stage. The same rules as the offline
*& validator (tools/abaptools/flow_config.py). The dashboard shows the
*& configuration as it is - the problems are reported by the evaluation
*& and make it partial, they never change a figure.
*& Modification log:
*& 2026-11-15 | Initial version (build G: account flow reconciliation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - account flow configuration rules</p>
CLASS zcl_ca_ops_flow_config DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Problems of a flow's configuration (messages 324-329), empty = valid
    CLASS-METHODS validate
      IMPORTING
        is_config          TYPE zif_ca_ops_flow_types=>ty_config
      RETURNING
        VALUE(rt_problems) TYPE zif_ca_ops_flow_types=>tt_problem.

  PRIVATE SECTION.
    CLASS-METHODS validate_rules
      IMPORTING
        is_config   TYPE zif_ca_ops_flow_types=>ty_config
      CHANGING
        ct_problems TYPE zif_ca_ops_flow_types=>tt_problem.

    CLASS-METHODS validate_roles
      IMPORTING
        is_config   TYPE zif_ca_ops_flow_types=>ty_config
      CHANGING
        ct_problems TYPE zif_ca_ops_flow_types=>tt_problem.

    "! The role is held by an active account of the flow
    CLASS-METHODS role_held
      IMPORTING
        is_config      TYPE zif_ca_ops_flow_types=>ty_config
        iv_role        TYPE zif_ca_ops_flow_types=>ty_role
      RETURNING
        VALUE(rv_held) TYPE abap_bool.

ENDCLASS.



CLASS zcl_ca_ops_flow_config IMPLEMENTATION.

  METHOD validate.
    IF NOT line_exists( is_config-stages[ active = abap_true ] ).
      INSERT VALUE #( msgno = zif_ca_ops_flow_types=>gc_msg-no_stage v1 = is_config-flow-flow_id ) INTO TABLE rt_problems.
    ENDIF.
    validate_rules( EXPORTING is_config = is_config CHANGING ct_problems = rt_problems ).
    validate_roles( EXPORTING is_config = is_config CHANGING ct_problems = rt_problems ).
  ENDMETHOD.


  METHOD validate_rules.
    DATA lt_wrong TYPE STANDARD TABLE OF zif_ca_ops_flow_types=>ty_text WITH EMPTY KEY.

    LOOP AT is_config-rules ASSIGNING FIELD-SYMBOL(<ls_rule>) WHERE active = abap_true.
      IF <ls_rule>-stage_id <> zif_ca_ops_flow_types=>gc_stage-other
         AND NOT line_exists( is_config-stages[ stage_id = <ls_rule>-stage_id active = abap_true ] ).
        INSERT VALUE #( msgno = zif_ca_ops_flow_types=>gc_msg-rule_stage v1 = is_config-flow-flow_id
                        v2 = <ls_rule>-rule_id v3 = <ls_rule>-stage_id ) INTO TABLE ct_problems.
      ENDIF.
      CLEAR lt_wrong.
      IF <ls_rule>-line_source = zif_ca_ops_flow_types=>gc_source-journal.
        IF <ls_rule>-origin IS NOT INITIAL.
          INSERT zif_ca_ops_flow_types=>gc_criterion-origin INTO TABLE lt_wrong.
        ENDIF.
        IF <ls_rule>-main_trans IS NOT INITIAL.
          INSERT zif_ca_ops_flow_types=>gc_criterion-main_trans INTO TABLE lt_wrong.
        ENDIF.
        IF <ls_rule>-sub_trans IS NOT INITIAL.
          INSERT zif_ca_ops_flow_types=>gc_criterion-sub_trans INTO TABLE lt_wrong.
        ENDIF.
      ELSEIF <ls_rule>-ref_type IS NOT INITIAL.
        INSERT zif_ca_ops_flow_types=>gc_criterion-ref_type INTO TABLE lt_wrong.
      ENDIF.
      LOOP AT lt_wrong INTO DATA(lv_criterion).
        INSERT VALUE #( msgno = zif_ca_ops_flow_types=>gc_msg-rule_criterion v1 = is_config-flow-flow_id
                        v2 = <ls_rule>-rule_id v3 = lv_criterion v4 = <ls_rule>-line_source ) INTO TABLE ct_problems.
      ENDLOOP.
      IF <ls_rule>-ref_type IS INITIAL AND <ls_rule>-doc_type IS INITIAL AND <ls_rule>-origin IS INITIAL
         AND <ls_rule>-main_trans IS INITIAL AND <ls_rule>-sub_trans IS INITIAL
         AND <ls_rule>-debit_credit IS INITIAL.
        INSERT VALUE #( msgno = zif_ca_ops_flow_types=>gc_msg-rule_open v1 = is_config-flow-flow_id
                        v2 = <ls_rule>-rule_id ) INTO TABLE ct_problems.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD validate_roles.
    TYPES:
      BEGIN OF ty_slot,
        role     TYPE zif_ca_ops_flow_types=>ty_role,
        bukrs    TYPE bukrs,
        currency TYPE zif_ca_ops_types=>ty_currency,
        count    TYPE i,
      END OF ty_slot.
    DATA lt_slots TYPE SORTED TABLE OF ty_slot WITH UNIQUE KEY role bukrs currency.
    DATA lt_roles TYPE STANDARD TABLE OF zif_ca_ops_flow_types=>ty_role WITH EMPTY KEY.

    " one account per role, company code and currency only where an expected counter-posting lands (EXPECT_TO):
    " several clearing accounts (ACH, wire, cheque) are columns of one flow
    LOOP AT is_config-accounts ASSIGNING FIELD-SYMBOL(<ls_account>)
         WHERE active = abap_true AND role <> zif_ca_ops_flow_types=>gc_role-outside.
      IF NOT line_exists( is_config-stages[ expect_to = <ls_account>-role active = abap_true ] ).
        CONTINUE.
      ENDIF.
      READ TABLE lt_slots ASSIGNING FIELD-SYMBOL(<ls_slot>)
        WITH TABLE KEY role = <ls_account>-role bukrs = <ls_account>-bukrs currency = <ls_account>-currency.
      IF sy-subrc = 0.
        <ls_slot>-count += 1.
      ELSE.
        INSERT VALUE #( role = <ls_account>-role bukrs = <ls_account>-bukrs currency = <ls_account>-currency
                        count = 1 ) INTO TABLE lt_slots.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_slots ASSIGNING <ls_slot> WHERE count > 1.
      INSERT VALUE #( msgno = zif_ca_ops_flow_types=>gc_msg-role_twice v1 = is_config-flow-flow_id
                      v2 = <ls_slot>-count v3 = <ls_slot>-role v4 = |{ <ls_slot>-bukrs } { <ls_slot>-currency }| )
             INTO TABLE ct_problems.
    ENDLOOP.

    LOOP AT is_config-stages ASSIGNING FIELD-SYMBOL(<ls_stage>) WHERE active = abap_true.
      lt_roles = VALUE #( ( <ls_stage>-expect_from ) ( <ls_stage>-expect_to ) ).
      LOOP AT lt_roles INTO DATA(lv_role) WHERE table_line IS NOT INITIAL.
        IF role_held( is_config = is_config iv_role = lv_role ) = abap_false.
          INSERT VALUE #( msgno = zif_ca_ops_flow_types=>gc_msg-role_missing v1 = is_config-flow-flow_id
                          v2 = <ls_stage>-stage_id v3 = lv_role ) INTO TABLE ct_problems.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
    LOOP AT is_config-tiles ASSIGNING FIELD-SYMBOL(<ls_tile>) WHERE active = abap_true.
      IF NOT line_exists( is_config-stages[ stage_id = <ls_tile>-stage_id active = abap_true ] ).
        INSERT VALUE #( msgno = zif_ca_ops_flow_types=>gc_msg-rule_stage v1 = is_config-flow-flow_id
                        v2 = <ls_tile>-tile v3 = <ls_tile>-stage_id ) INTO TABLE ct_problems.
      ENDIF.
      IF role_held( is_config = is_config iv_role = <ls_tile>-role ) = abap_false.
        INSERT VALUE #( msgno = zif_ca_ops_flow_types=>gc_msg-role_missing v1 = is_config-flow-flow_id
                        v2 = <ls_tile>-stage_id v3 = <ls_tile>-role ) INTO TABLE ct_problems.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD role_held.
    rv_held = xsdbool( line_exists( is_config-accounts[ role = iv_role active = abap_true ] ) ).
  ENDMETHOD.

ENDCLASS.
