*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_cfg_checks.clas.abap
*& Purpose:
*& Field checks of the configuration apps, shared by all four behaviour
*& pools: DDIC name syntax, table / field existence (RTTI), plug-in class
*& implements its payment engine area interface, allowed values, time windows,
*& threshold order, rule groups without active rules, alert destinations the
*& channel cannot deliver to (the channel plug-in decides; e-mail = shared SO23
*& lists). No own SQL: RTTI reads dictionary metadata, channels come from the
*& alert DAO of ZCL_CD_OPS_FACTORY. Messages are chosen by the caller. The
*& configuration check of the customer posting areas reads them through
*& ZCL_CD_OPS_POSTAREA and the rule groups through the EBS configuration DAO.
*& Modification log:
*& 2026-11-06 | Initial version (RAP configuration apps, design 5).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | PCRE instead of the obsolete POSIX regex in matches( ).
*& 2026-11-07 | CHANNEL_CLASS / INVALID_DESTINATION: alert destinations checked by their channel (SO23 lists).
*& 2026-11-08 | CHECK_POSTING_AREAS: configuration check of the customer posting areas ZRSN, ZPMC, ZBTM,
*&            | ZBTR (FQC0 checks domains only) - the checks of the former app entities and the posting
*&            | area's own (generic keys, lengths, blank keys, one class per payment method, empty area).
*& 2026-11-10 | LOOKUP_APPROVED: a lookup field of rule R21 must be approved in ZCD_OPS_TABWL (EBS / LOOKUP),
*&            | read through the EBS SAP DAO (the same check as at runtime).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - config apps: field checks</p>
CLASS zcl_cd_ops_cfg_checks DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Letters, digits, _ and / only, at most 30 characters (case-insensitive)
    CLASS-METHODS is_valid_name
      IMPORTING
        iv_name         TYPE zif_cd_ops_cfg_types=>ty_name
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    "! Transparent table or view of the ABAP dictionary
    CLASS-METHODS table_exists
      IMPORTING
        iv_table         TYPE zif_cd_ops_cfg_types=>ty_name
      RETURNING
        VALUE(rv_exists) TYPE abap_bool.

    CLASS-METHODS field_exists
      IMPORTING
        iv_table         TYPE zif_cd_ops_cfg_types=>ty_name
        iv_field         TYPE zif_cd_ops_cfg_types=>ty_name
      RETURNING
        VALUE(rv_exists) TYPE abap_bool.

    "! The field of the table is approved for the EBS lookup rule R21 (ZCD_OPS_TABWL, EBS / LOOKUP,
    "! field-level) - the same check as at runtime (ZIF_CD_EBS_SAP_DAO=>IS_LOOKUP_FIELD_APPROVED)
    CLASS-METHODS lookup_approved
      IMPORTING
        iv_table           TYPE zif_cd_ops_cfg_types=>ty_name
        iv_field           TYPE zif_cd_ops_cfg_types=>ty_name
      RETURNING
        VALUE(rv_approved) TYPE abap_bool.

    "! Global class exists and implements the interface (plug-in contract)
    CLASS-METHODS implements
      IMPORTING
        iv_class          TYPE zif_cd_ops_cfg_types=>ty_name
        iv_interface      TYPE zif_cd_ops_cfg_types=>ty_name
      RETURNING
        VALUE(rv_matches) TYPE abap_bool.

    "! iv_list: comma-separated values; a leading comma allows blank
    CLASS-METHODS in_list
      IMPORTING
        iv_value          TYPE zif_cd_ops_cfg_types=>ty_value
        iv_list           TYPE zif_cd_ops_cfg_types=>ty_value_list
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

    "! Both times set or both empty (a window may cross midnight)
    CLASS-METHODS window_complete
      IMPORTING
        iv_from            TYPE t
        iv_to              TYPE t
      RETURNING
        VALUE(rv_complete) TYPE abap_bool.

    "! Higher is worse: amber < red; lower is worse: amber > red.
    "! Not checked when either threshold is zero (not maintained).
    CLASS-METHODS thresholds_ordered
      IMPORTING
        iv_amber           TYPE zif_cd_ops_cfg_types=>ty_amount
        iv_red             TYPE zif_cd_ops_cfg_types=>ty_amount
        iv_higher_is_worse TYPE abap_bool
      RETURNING
        VALUE(rv_ordered)  TYPE abap_bool.

    "! Names of it_needed that are not in it_available (each once)
    CLASS-METHODS missing_names
      IMPORTING
        it_needed         TYPE zif_cd_ops_cfg_types=>ty_names
        it_available      TYPE zif_cd_ops_cfg_types=>ty_names
      RETURNING
        VALUE(rt_missing) TYPE zif_cd_ops_cfg_types=>ty_names.

    "! Plug-in class of an alert channel (active configuration); blank = unknown channel
    CLASS-METHODS channel_class
      IMPORTING
        iv_channel      TYPE zif_cd_ops_types=>ty_channel
      RETURNING
        VALUE(rv_class) TYPE zif_cd_ops_types=>ty_class_name.

    "! Entries of iv_destination the channel class cannot deliver to (blank = fine).
    "! Not checked here (blank): no class or a class that is not a channel - the
    "! class check of the channel row reports those.
    CLASS-METHODS invalid_destination
      IMPORTING
        iv_class          TYPE zif_cd_ops_types=>ty_class_name
        iv_destination    TYPE zif_cd_ops_types=>ty_alert_dest
      RETURNING
        VALUE(rv_invalid) TYPE string.

    "! Configuration check of the customer posting areas ZRSN, ZPMC, ZBTM and ZBTR (FQC0 checks
    "! only the domains of the values): what the configuration apps checked before plus what a
    "! posting area adds - '*' where its reader cannot apply it, a value longer than its reader
    "! takes, a blank key that must be a value or '*', allowed values per key and usage, roles
    "! per usage, LIFECYCLE scope form, method class of a scope present, one class per payment
    "! method, calendar of a house-bank entry, rule group with an active rule in ZCD_BTC_RULE,
    "! RECON scheme BAI2, an empty posting area. One message per finding (entry and message).
    CLASS-METHODS check_posting_areas
      RETURNING
        VALUE(rt_messages) TYPE zif_cd_ops_postarea_types=>tt_check_message.

  PRIVATE SECTION.
    "! A key or result field of a posting area (keys first, then results, in FQC0 order)
    TYPES:
      BEGIN OF ty_field,
        name     TYPE zif_cd_ops_cfg_types=>ty_name,
        "! Characters the reader takes (0 = no limit)
        length   TYPE i,
        "! '*' allowed - the reader applies it as FQC0 does
        generic  TYPE abap_bool,
        "! A key that must hold a value or '*'
        required TYPE abap_bool,
      END OF ty_field.
    TYPES tt_field TYPE STANDARD TABLE OF ty_field WITH EMPTY KEY.

    "! Layout of the posting area of a purpose (setup guide, Implementation_Order.md)
    TYPES:
      BEGIN OF ty_layout,
        purpose TYPE zif_cd_ops_postarea_types=>ty_purpose,
        area    TYPE zif_cd_ops_postarea_types=>ty_area,
        keys    TYPE tt_field,
        results TYPE tt_field,
      END OF ty_layout.

    CLASS-METHODS layout
      IMPORTING
        iv_purpose       TYPE zif_cd_ops_postarea_types=>ty_purpose
      RETURNING
        VALUE(rs_layout) TYPE ty_layout.

    "! '*' where the reader cannot apply it, blank keys, values longer than the reader takes,
    "! an area without entries
    CLASS-METHODS check_layout
      IMPORTING
        is_layout   TYPE ty_layout
        it_entries  TYPE zif_cd_ops_postarea_types=>tt_entry
      CHANGING
        ct_messages TYPE zif_cd_ops_postarea_types=>tt_check_message.

    "! ZRSN: NOC flag X or blank
    CLASS-METHODS check_reasons
      IMPORTING
        is_layout   TYPE ty_layout
        it_entries  TYPE zif_cd_ops_postarea_types=>tt_entry
      CHANGING
        ct_messages TYPE zif_cd_ops_postarea_types=>tt_check_message.

    "! ZPMC: flow, ageing basis of a class entry, calendar of a house-bank entry, the class entry
    "! of a house-bank entry and one class per payment method, one ageing basis / calendar per class
    CLASS-METHODS check_pm_classes
      IMPORTING
        is_layout   TYPE ty_layout
        it_entries  TYPE zif_cd_ops_postarea_types=>tt_entry
      CHANGING
        ct_messages TYPE zif_cd_ops_postarea_types=>tt_check_message.

    "! ZBTM: allowed values, ISO code parts, rule group with an active rule in ZCD_BTC_RULE
    CLASS-METHODS check_btc_map
      IMPORTING
        is_layout   TYPE ty_layout
        it_entries  TYPE zif_cd_ops_postarea_types=>tt_entry
      CHANGING
        ct_messages TYPE zif_cd_ops_postarea_types=>tt_check_message.

    "! ZBTR: usage, scheme, ISO code parts; LIFECYCLE scope form, method class in ZPMC, role
    "! required and not a reconciliation role, compare amount; RECON role, scheme BAI2, no compare
    CLASS-METHODS check_btc_roles
      IMPORTING
        is_layout   TYPE ty_layout
        it_entries  TYPE zif_cd_ops_postarea_types=>tt_entry
        is_classes  TYPE ty_layout
        it_classes  TYPE zif_cd_ops_postarea_types=>tt_entry
      CHANGING
        ct_messages TYPE zif_cd_ops_postarea_types=>tt_check_message.

    "! ISO codes need family and sub-family, other schemes leave both blank
    CLASS-METHODS check_code_parts
      IMPORTING
        is_layout   TYPE ty_layout
        is_entry    TYPE zif_cd_ops_postarea_types=>ty_entry
      CHANGING
        ct_messages TYPE zif_cd_ops_postarea_types=>tt_check_message.

    "! Message 413 when the value of the field is not in the list ('*' is the layout check's)
    CLASS-METHODS check_value
      IMPORTING
        is_layout   TYPE ty_layout
        is_entry    TYPE zif_cd_ops_postarea_types=>ty_entry
        iv_name     TYPE zif_cd_ops_cfg_types=>ty_name
        iv_list     TYPE string
      CHANGING
        ct_messages TYPE zif_cd_ops_postarea_types=>tt_check_message.

    CLASS-METHODS add_message
      IMPORTING
        is_layout   TYPE ty_layout
        is_entry    TYPE zif_cd_ops_postarea_types=>ty_entry
        iv_number   TYPE zif_cd_ops_cfg_types=>ty_msg_number
        iv_v1       TYPE csequence OPTIONAL
        iv_v2       TYPE csequence OPTIONAL
        iv_v3       TYPE csequence OPTIONAL
        iv_severity TYPE zif_cd_ops_types=>ty_severity DEFAULT zif_cd_ops_types=>gc_severity-error
      CHANGING
        ct_messages TYPE zif_cd_ops_postarea_types=>tt_check_message.

    "! Value of a named key or result field of the layout (blank when the layout has none)
    CLASS-METHODS value
      IMPORTING
        is_layout       TYPE ty_layout
        is_entry        TYPE zif_cd_ops_postarea_types=>ty_entry
        iv_name         TYPE zif_cd_ops_cfg_types=>ty_name
      RETURNING
        VALUE(rv_value) TYPE string.

    "! Value at a position of the entry (1-8 keys, 9-16 results)
    CLASS-METHODS value_at
      IMPORTING
        is_entry        TYPE zif_cd_ops_postarea_types=>ty_entry
        iv_position     TYPE i
      RETURNING
        VALUE(rv_value) TYPE string.

    "! Key values of the entry separated by '/' (trailing blank keys dropped)
    CLASS-METHODS entry_text
      IMPORTING
        is_entry       TYPE zif_cd_ops_postarea_types=>ty_entry
      RETURNING
        VALUE(rv_text) TYPE string.

    "! Characters of a character-like field of a reader's structure
    CLASS-METHODS length_of
      IMPORTING
        iv_field         TYPE any
      RETURNING
        VALUE(rv_length) TYPE i.

    "! Comma list of the values; iv_blank: blank allowed (leading comma, as IN_LIST reads it)
    CLASS-METHODS list
      IMPORTING
        it_values      TYPE string_table
        iv_blank       TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rv_list) TYPE string.
    "! DDIC / class name: letters, digits, underscore, namespace slashes, max 30
    CONSTANTS gc_name_pattern TYPE string VALUE `^[A-Z/][A-Z0-9_/]{0,29}$`.
    CLASS-METHODS describe
      IMPORTING
        iv_name        TYPE zif_cd_ops_cfg_types=>ty_name
      RETURNING
        VALUE(ro_type) TYPE REF TO cl_abap_typedescr.

ENDCLASS.



CLASS zcl_cd_ops_cfg_checks IMPLEMENTATION.

  METHOD is_valid_name.
    DATA(lv_name) = to_upper( condense( iv_name ) ).
    rv_valid = xsdbool( matches( val = lv_name pcre = gc_name_pattern ) ).
  ENDMETHOD.


  METHOD describe.
    IF is_valid_name( iv_name ) = abap_false.
      RETURN.
    ENDIF.
    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = to_upper( condense( iv_name ) )
      RECEIVING
        p_descr_ref    = ro_type
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    IF sy-subrc <> 0.
      CLEAR ro_type.
    ENDIF.
  ENDMETHOD.


  METHOD table_exists.
    DATA(lo_type) = describe( iv_table ).
    IF lo_type IS NOT BOUND.
      RETURN.
    ENDIF.
    rv_exists = xsdbool( lo_type->kind = cl_abap_typedescr=>kind_struct
                         AND lo_type->is_ddic_type( ) = abap_true ).
  ENDMETHOD.


  METHOD lookup_approved.
    rv_approved = zcl_cd_ebs_factory=>get_sap_dao( )->is_lookup_field_approved( iv_table = iv_table
                                                                                iv_field = iv_field ).
  ENDMETHOD.


  METHOD field_exists.
    DATA lo_struct TYPE REF TO cl_abap_structdescr.
    DATA lt_fields TYPE ddfields.

    IF table_exists( iv_table ) = abap_false OR is_valid_name( iv_field ) = abap_false.
      RETURN.
    ENDIF.
    TRY.
        lo_struct = CAST cl_abap_structdescr( describe( iv_table ) ).
      CATCH cx_sy_move_cast_error.
        RETURN.
    ENDTRY.
    lo_struct->get_ddic_field_list(
      RECEIVING
        p_field_list = lt_fields
      EXCEPTIONS
        not_found    = 1
        no_ddic_type = 2
        OTHERS       = 3 ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    rv_exists = xsdbool( line_exists( lt_fields[ fieldname = to_upper( condense( iv_field ) ) ] ) ).
  ENDMETHOD.


  METHOD implements.
    DATA lo_class TYPE REF TO cl_abap_classdescr.

    DATA(lo_type) = describe( iv_class ).
    IF lo_type IS NOT BOUND.
      RETURN.
    ENDIF.
    TRY.
        lo_class = CAST cl_abap_classdescr( lo_type ).
      CATCH cx_sy_move_cast_error.
        RETURN.
    ENDTRY.
    rv_matches = xsdbool( line_exists( lo_class->interfaces[ name = to_upper( condense( iv_interface ) ) ] ) ).
  ENDMETHOD.


  METHOD in_list.
    DATA lt_values TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    SPLIT iv_list AT ',' INTO TABLE lt_values.
    rv_allowed = xsdbool( line_exists( lt_values[ table_line = condense( iv_value ) ] ) ).
  ENDMETHOD.


  METHOD window_complete.
    rv_complete = xsdbool( xsdbool( iv_from IS INITIAL ) = xsdbool( iv_to IS INITIAL ) ).
  ENDMETHOD.


  METHOD thresholds_ordered.
    IF iv_amber IS INITIAL OR iv_red IS INITIAL.
      rv_ordered = abap_true.
      RETURN.
    ENDIF.
    rv_ordered = COND #( WHEN iv_higher_is_worse = abap_true THEN xsdbool( iv_amber < iv_red )
                         ELSE xsdbool( iv_amber > iv_red ) ).
  ENDMETHOD.


  METHOD missing_names.
    LOOP AT it_needed ASSIGNING FIELD-SYMBOL(<lv_name>).
      IF NOT line_exists( it_available[ table_line = <lv_name> ] )
         AND NOT line_exists( rt_missing[ table_line = <lv_name> ] ).
        INSERT <lv_name> INTO TABLE rt_missing.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.



  METHOD channel_class.
    DATA(lt_channels) = zcl_cd_ops_factory=>get_alert_dao( )->get_channels( ).
    READ TABLE lt_channels ASSIGNING FIELD-SYMBOL(<ls_channel>)
      WITH KEY channel = to_upper( condense( iv_channel ) ).
    IF sy-subrc = 0.
      rv_class = <ls_channel>-class_name.
    ENDIF.
  ENDMETHOD.


  METHOD invalid_destination.
    DATA lo_channel TYPE REF TO zif_cd_ops_alert_channel.
    IF iv_class IS INITIAL OR iv_destination IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        lo_channel = CAST zif_cd_ops_alert_channel(
          zcl_cd_ops_factory=>get_plugin( iv_class_name = iv_class
                                          iv_interface  = zif_cd_ops_types=>gc_plugin_intf-alert_channel ) ).
      CATCH zcx_cd_ops_error.
        RETURN.
    ENDTRY.
    rv_invalid = lo_channel->check_destination( iv_destination ).
  ENDMETHOD.


  METHOD check_posting_areas.
    DATA lt_purposes TYPE STANDARD TABLE OF zif_cd_ops_postarea_types=>ty_purpose WITH EMPTY KEY.

    DATA(lo_reader) = zcl_cd_ops_postarea_factory=>get_reader( ).
    DATA(ls_classes) = layout( zif_cd_ops_postarea_types=>gc_purpose-pm_class ).
    DATA(lt_classes) = lo_reader->entries( zif_cd_ops_postarea_types=>gc_purpose-pm_class ).
    lt_purposes = VALUE #( ( zif_cd_ops_postarea_types=>gc_purpose-reason )
                           ( zif_cd_ops_postarea_types=>gc_purpose-pm_class )
                           ( zif_cd_ops_postarea_types=>gc_purpose-btc_map )
                           ( zif_cd_ops_postarea_types=>gc_purpose-btc_role ) ).
    LOOP AT lt_purposes ASSIGNING FIELD-SYMBOL(<lv_purpose>).
      DATA(ls_layout) = layout( <lv_purpose> ).
      DATA(lt_entries) = lo_reader->entries( <lv_purpose> ).
      check_layout( EXPORTING is_layout   = ls_layout
                              it_entries  = lt_entries
                    CHANGING  ct_messages = rt_messages ).
      CASE <lv_purpose>.
        WHEN zif_cd_ops_postarea_types=>gc_purpose-reason.
          check_reasons( EXPORTING is_layout   = ls_layout
                                   it_entries  = lt_entries
                         CHANGING  ct_messages = rt_messages ).
        WHEN zif_cd_ops_postarea_types=>gc_purpose-pm_class.
          check_pm_classes( EXPORTING is_layout   = ls_layout
                                      it_entries  = lt_entries
                            CHANGING  ct_messages = rt_messages ).
        WHEN zif_cd_ops_postarea_types=>gc_purpose-btc_map.
          check_btc_map( EXPORTING is_layout   = ls_layout
                                   it_entries  = lt_entries
                         CHANGING  ct_messages = rt_messages ).
        WHEN OTHERS.
          check_btc_roles( EXPORTING is_layout   = ls_layout
                                     it_entries  = lt_entries
                                     is_classes  = ls_classes
                                     it_classes  = lt_classes
                           CHANGING  ct_messages = rt_messages ).
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD layout.
    " The reader's own types give the lengths: a value longer than its reader takes is a finding,
    " never truncated (VERIFY-SE11: TFK033D KEYnn / FUNnn hold at least these lengths)
    DATA ls_reason TYPE zif_cd_ebs_types=>ty_reason_map.
    DATA ls_map    TYPE zif_cd_ebs_types=>ty_btc_map.
    DATA ls_class  TYPE zif_cd_hck_runtime_types=>ty_pm_class.
    DATA ls_role   TYPE zif_cd_hck_runtime_types=>ty_btc_role_row.
    DATA lv_pymet  TYPE zif_cd_hck_runtime_types=>ty_pymet.
    DATA lv_usage  TYPE zif_cd_hck_types=>ty_btc_usage.
    DATA lv_set    TYPE zif_cd_hck_recon_types=>ty_set_id.

    rs_layout-purpose = iv_purpose.
    rs_layout-area    = zcl_cd_ops_postarea_factory=>get_reader( )->area( iv_purpose ).
    CASE iv_purpose.
      WHEN zif_cd_ops_postarea_types=>gc_purpose-reason.
        rs_layout-keys = VALUE #( ( name = zif_cd_ops_postarea_types=>gc_field-reason
                                    length = length_of( ls_reason-reason ) generic = abap_true required = abap_true ) ).
        rs_layout-results = VALUE #( ( name = zif_cd_ops_postarea_types=>gc_field-fica_reason
                                       length = length_of( ls_reason-fica_reason ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-is_noc
                                       length = length_of( ls_reason-is_noc ) ) ).
      WHEN zif_cd_ops_postarea_types=>gc_purpose-pm_class.
        rs_layout-keys = VALUE #( ( name = zif_cd_ops_postarea_types=>gc_field-flow
                                    length = length_of( ls_class-flow ) required = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-pay_method
                                    length = length_of( lv_pymet ) required = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-house_bank
                                    length = length_of( ls_class-hbkid ) generic = abap_true required = abap_true ) ).
        rs_layout-results = VALUE #( ( name = zif_cd_ops_postarea_types=>gc_field-method_class
                                       length = length_of( ls_class-method_class ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-age_basis
                                       length = length_of( ls_class-age_basis ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-calendar
                                       length = length_of( ls_class-calendar ) ) ).
      WHEN zif_cd_ops_postarea_types=>gc_purpose-btc_map.
        rs_layout-keys = VALUE #( ( name = zif_cd_ops_postarea_types=>gc_field-scheme
                                    length = length_of( ls_map-scheme ) required = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-code
                                    length = length_of( ls_map-btc_code ) required = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-family
                                    length = length_of( ls_map-btc_code ) )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-sub_family
                                    length = length_of( ls_map-btc_code ) generic = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-bank_key
                                    length = length_of( ls_map-bank_key ) generic = abap_true required = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-flow
                                    length = length_of( ls_map-flow_type ) generic = abap_true required = abap_true ) ).
        rs_layout-results = VALUE #( ( name = zif_cd_ops_postarea_types=>gc_field-category
                                       length = length_of( ls_map-category ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-rule_group
                                       length = length_of( ls_map-rule_group ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-exp_cdi
                                       length = length_of( ls_map-exp_cdi ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-pay_method
                                       length = length_of( ls_map-pay_method ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-posting_rule
                                       length = length_of( ls_map-posting_rule ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-action
                                       length = length_of( ls_map-action ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-disposition
                                       length = length_of( ls_map-disposition ) ) ).
      WHEN zif_cd_ops_postarea_types=>gc_purpose-btc_role.
        rs_layout-keys = VALUE #( ( name = zif_cd_ops_postarea_types=>gc_field-usage
                                    length = length_of( lv_usage ) required = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-scope
                                    length = length_of( lv_set ) required = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-scheme
                                    length = length_of( ls_role-scheme ) required = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-code
                                    length = length_of( ls_role-btc_code ) required = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-family
                                    length = length_of( ls_role-btc_code ) )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-sub_family
                                    length = length_of( ls_role-btc_code ) ) ).
        rs_layout-results = VALUE #( ( name = zif_cd_ops_postarea_types=>gc_field-role
                                       length = length_of( ls_role-role ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-compare_amount
                                       length = length_of( ls_role-compare_amount ) ) ).
    ENDCASE.
  ENDMETHOD.


  METHOD check_layout.
    IF it_entries IS INITIAL.
      add_message( EXPORTING is_layout   = is_layout
                             is_entry    = VALUE #( )
                             iv_number   = zif_cd_ops_cfg_types=>gc_msg-area_empty
                             iv_v1       = is_layout-area
                             iv_severity = zif_cd_ops_types=>gc_severity-warning
                   CHANGING  ct_messages = ct_messages ).
      RETURN.
    ENDIF.
    LOOP AT it_entries ASSIGNING FIELD-SYMBOL(<ls_entry>).
      LOOP AT is_layout-keys ASSIGNING FIELD-SYMBOL(<ls_key>).
        DATA(lv_key_index) = sy-tabix.
        DATA(lv_value) = value_at( is_entry = <ls_entry> iv_position = lv_key_index ).
        IF lv_value = zif_cd_ops_postarea_types=>gc_generic.
          IF <ls_key>-generic = abap_false.
            add_message( EXPORTING is_layout   = is_layout
                                   is_entry    = <ls_entry>
                                   iv_number   = zif_cd_ops_cfg_types=>gc_msg-generic_key
                                   iv_v1       = <ls_key>-name
                         CHANGING  ct_messages = ct_messages ).
          ENDIF.
        ELSEIF lv_value IS INITIAL AND <ls_key>-required = abap_true.
          add_message( EXPORTING is_layout   = is_layout
                                 is_entry    = <ls_entry>
                                 iv_number   = zif_cd_ops_cfg_types=>gc_msg-key_blank
                                 iv_v1       = <ls_key>-name
                       CHANGING  ct_messages = ct_messages ).
        ELSEIF strlen( lv_value ) > <ls_key>-length.
          add_message( EXPORTING is_layout   = is_layout
                                 is_entry    = <ls_entry>
                                 iv_number   = zif_cd_ops_cfg_types=>gc_msg-value_too_long
                                 iv_v1       = lv_value
                                 iv_v2       = <ls_key>-name
                                 iv_v3       = |{ <ls_key>-length }|
                       CHANGING  ct_messages = ct_messages ).
        ENDIF.
      ENDLOOP.
      LOOP AT is_layout-results ASSIGNING FIELD-SYMBOL(<ls_result>).
        DATA(lv_result_index) = zif_cd_ops_postarea_types=>gc_key_count + sy-tabix.
        lv_value = value_at( is_entry = <ls_entry> iv_position = lv_result_index ).
        IF strlen( lv_value ) > <ls_result>-length.
          add_message( EXPORTING is_layout   = is_layout
                                 is_entry    = <ls_entry>
                                 iv_number   = zif_cd_ops_cfg_types=>gc_msg-value_too_long
                                 iv_v1       = lv_value
                                 iv_v2       = <ls_result>-name
                                 iv_v3       = |{ <ls_result>-length }|
                       CHANGING  ct_messages = ct_messages ).
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_reasons.
    LOOP AT it_entries ASSIGNING FIELD-SYMBOL(<ls_entry>).
      check_value( EXPORTING is_layout   = is_layout
                             is_entry    = <ls_entry>
                             iv_name     = zif_cd_ops_postarea_types=>gc_field-is_noc
                             iv_list     = list( it_values = VALUE #( ( CONV #( abap_true ) ) ) iv_blank = abap_true )
                   CHANGING  ct_messages = ct_messages ).
    ENDLOOP.
  ENDMETHOD.


  METHOD check_pm_classes.
    TYPES:
      BEGIN OF ty_first,
        flow      TYPE string,
        method_class TYPE string,
        bank      TYPE string,
        age_basis TYPE string,
        calendar  TYPE string,
      END OF ty_first.
    DATA lt_first TYPE HASHED TABLE OF ty_first WITH UNIQUE KEY flow method_class bank.

    DATA(lv_flows) = list( VALUE #( ( CONV #( zif_cd_hck_runtime_types=>gc_flow-disbursement ) )
                                    ( CONV #( zif_cd_hck_runtime_types=>gc_flow-collection ) ) ) ).
    DATA(lv_bases) = list( VALUE #( ( CONV #( zif_cd_hck_runtime_types=>gc_age_basis-value_date ) )
                                    ( CONV #( zif_cd_hck_runtime_types=>gc_age_basis-issue_date ) ) ) ).
    LOOP AT it_entries ASSIGNING FIELD-SYMBOL(<ls_entry>).
      DATA(ls_first) = VALUE ty_first(
        flow      = value( is_layout = is_layout is_entry = <ls_entry> iv_name = zif_cd_ops_postarea_types=>gc_field-flow )
        method_class = value( is_layout = is_layout is_entry = <ls_entry>
                              iv_name   = zif_cd_ops_postarea_types=>gc_field-method_class )
        bank      = value( is_layout = is_layout is_entry = <ls_entry>
                           iv_name   = zif_cd_ops_postarea_types=>gc_field-house_bank )
        age_basis = value( is_layout = is_layout is_entry = <ls_entry>
                           iv_name   = zif_cd_ops_postarea_types=>gc_field-age_basis )
        calendar  = value( is_layout = is_layout is_entry = <ls_entry>
                           iv_name   = zif_cd_ops_postarea_types=>gc_field-calendar ) ).
      DATA(lv_method) = value( is_layout = is_layout is_entry = <ls_entry>
                               iv_name   = zif_cd_ops_postarea_types=>gc_field-pay_method ).
      check_value( EXPORTING is_layout   = is_layout
                             is_entry    = <ls_entry>
                             iv_name     = zif_cd_ops_postarea_types=>gc_field-flow
                             iv_list     = lv_flows
                   CHANGING  ct_messages = ct_messages ).
      IF ls_first-method_class IS INITIAL.
        add_message( EXPORTING is_layout   = is_layout
                               is_entry    = <ls_entry>
                               iv_number   = zif_cd_ops_cfg_types=>gc_msg-required
                               iv_v1       = zif_cd_ops_postarea_types=>gc_field-method_class
                               iv_v2       = zif_cd_ops_postarea_types=>gc_field-house_bank
                               iv_v3       = ls_first-bank
                     CHANGING  ct_messages = ct_messages ).
      ENDIF.
      IF ls_first-bank = zif_cd_ops_postarea_types=>gc_generic.
        " The class of the payment method: ageing basis (calendar optional - PARAM1 of A_INFLIGHT)
        check_value( EXPORTING is_layout   = is_layout
                               is_entry    = <ls_entry>
                               iv_name     = zif_cd_ops_postarea_types=>gc_field-age_basis
                               iv_list     = lv_bases
                     CHANGING  ct_messages = ct_messages ).
      ELSE.
        " A house bank overrides the calendar only: calendar present, no ageing basis, the class
        " entry ('*') of the payment method exists and names the same class
        IF ls_first-calendar IS INITIAL.
          add_message( EXPORTING is_layout   = is_layout
                                 is_entry    = <ls_entry>
                                 iv_number   = zif_cd_ops_cfg_types=>gc_msg-required
                                 iv_v1       = zif_cd_ops_postarea_types=>gc_field-calendar
                                 iv_v2       = zif_cd_ops_postarea_types=>gc_field-house_bank
                                 iv_v3       = ls_first-bank
                       CHANGING  ct_messages = ct_messages ).
        ENDIF.
        IF ls_first-age_basis IS NOT INITIAL.
          add_message( EXPORTING is_layout   = is_layout
                                 is_entry    = <ls_entry>
                                 iv_number   = zif_cd_ops_cfg_types=>gc_msg-must_be_blank
                                 iv_v1       = zif_cd_ops_postarea_types=>gc_field-age_basis
                                 iv_v2       = zif_cd_ops_postarea_types=>gc_field-house_bank
                                 iv_v3       = ls_first-bank
                       CHANGING  ct_messages = ct_messages ).
        ENDIF.
        READ TABLE it_entries ASSIGNING FIELD-SYMBOL(<ls_class_entry>)
          WITH KEY key01 = <ls_entry>-key01 key02 = <ls_entry>-key02 key03 = zif_cd_ops_postarea_types=>gc_generic.
        IF sy-subrc <> 0.
          add_message( EXPORTING is_layout   = is_layout
                                 is_entry    = <ls_entry>
                                 iv_number   = zif_cd_ops_cfg_types=>gc_msg-class_entry_none
                                 iv_v1       = lv_method
                                 iv_v2       = ls_first-flow
                                 iv_v3       = is_layout-area
                       CHANGING  ct_messages = ct_messages ).
        ELSEIF <ls_class_entry>-fun01 <> <ls_entry>-fun01.
          " One payment method, one class: the house bank names another class than the '*' entry
          add_message( EXPORTING is_layout   = is_layout
                                 is_entry    = <ls_entry>
                                 iv_number   = zif_cd_ops_cfg_types=>gc_msg-method_two_classes
                                 iv_v1       = lv_method
                                 iv_v2       = <ls_class_entry>-fun01
                                 iv_v3       = ls_first-method_class
                       CHANGING  ct_messages = ct_messages ).
        ENDIF.
        CLEAR ls_first-age_basis.
      ENDIF.
      " One ageing basis and calendar per class, one calendar per class and house bank
      READ TABLE lt_first ASSIGNING FIELD-SYMBOL(<ls_seen>)
        WITH TABLE KEY flow = ls_first-flow method_class = ls_first-method_class bank = ls_first-bank.
      IF sy-subrc <> 0.
        INSERT ls_first INTO TABLE lt_first.
      ELSEIF <ls_seen>-age_basis <> ls_first-age_basis OR <ls_seen>-calendar <> ls_first-calendar.
        add_message( EXPORTING is_layout   = is_layout
                               is_entry    = <ls_entry>
                               iv_number   = zif_cd_ops_cfg_types=>gc_msg-entries_differ
                               iv_v1       = COND #( WHEN <ls_seen>-calendar <> ls_first-calendar
                                                     THEN zif_cd_ops_postarea_types=>gc_field-calendar
                                                     ELSE zif_cd_ops_postarea_types=>gc_field-age_basis )
                               iv_v2       = |{ ls_first-flow }{ ls_first-method_class } { ls_first-bank }|
                               iv_v3       = |{ <ls_seen>-age_basis } { <ls_seen>-calendar }|
                     CHANGING  ct_messages = ct_messages ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_btc_map.
    DATA lt_groups TYPE zif_cd_ops_cfg_types=>ty_names.

    " Rule groups with an active assignment in ZCD_BTC_RULE (as the configuration app checked)
    LOOP AT zcl_cd_ebs_factory=>get_cfg_dao( )->get_rules( ) ASSIGNING FIELD-SYMBOL(<ls_rule>).
      INSERT CONV #( <ls_rule>-rule_group ) INTO TABLE lt_groups.
    ENDLOOP.
    DATA(lv_schemes) = list( VALUE #( ( CONV #( zif_cd_ebs_types=>gc_scheme-bai2 ) )
                                      ( CONV #( zif_cd_ebs_types=>gc_scheme-iso ) )
                                      ( CONV #( zif_cd_ebs_types=>gc_scheme-prtry ) ) ) ).
    DATA(lv_flows) = list( VALUE #( ( CONV #( zif_cd_ebs_types=>gc_flow-disbursement ) )
                                    ( CONV #( zif_cd_ebs_types=>gc_flow-collection ) )
                                    ( CONV #( zif_cd_ebs_types=>gc_flow-any ) ) ) ).
    DATA(lv_cdis) = list( it_values = VALUE #( ( CONV #( zif_cd_ebs_types=>gc_cdi-credit ) )
                                               ( CONV #( zif_cd_ebs_types=>gc_cdi-debit ) )
                                               ( CONV #( zif_cd_ebs_types=>gc_cdi-any ) ) )
                          iv_blank  = abap_true ).
    DATA(lv_actions) = list( it_values = VALUE #( ( CONV #( zif_cd_ops_types=>gc_action-auto_post ) )
                                                  ( CONV #( zif_cd_ops_types=>gc_action-exception ) )
                                                  ( CONV #( zif_cd_ops_types=>gc_action-block ) )
                                                  ( CONV #( zif_cd_ops_types=>gc_action-notify ) )
                                                  ( CONV #( zif_cd_ops_types=>gc_action-on_account ) ) )
                             iv_blank  = abap_true ).
    DATA(lv_dispositions) = list( it_values = VALUE #( ( CONV #( zif_cd_ebs_types=>gc_disposition-not_posted ) ) )
                                  iv_blank  = abap_true ).
    LOOP AT it_entries ASSIGNING FIELD-SYMBOL(<ls_entry>).
      check_value( EXPORTING is_layout = is_layout is_entry = <ls_entry>
                             iv_name   = zif_cd_ops_postarea_types=>gc_field-scheme iv_list = lv_schemes
                   CHANGING  ct_messages = ct_messages ).
      check_value( EXPORTING is_layout = is_layout is_entry = <ls_entry>
                             iv_name   = zif_cd_ops_postarea_types=>gc_field-flow iv_list = lv_flows
                   CHANGING  ct_messages = ct_messages ).
      check_value( EXPORTING is_layout = is_layout is_entry = <ls_entry>
                             iv_name   = zif_cd_ops_postarea_types=>gc_field-exp_cdi iv_list = lv_cdis
                   CHANGING  ct_messages = ct_messages ).
      check_value( EXPORTING is_layout = is_layout is_entry = <ls_entry>
                             iv_name   = zif_cd_ops_postarea_types=>gc_field-action iv_list = lv_actions
                   CHANGING  ct_messages = ct_messages ).
      check_value( EXPORTING is_layout = is_layout is_entry = <ls_entry>
                             iv_name   = zif_cd_ops_postarea_types=>gc_field-disposition iv_list = lv_dispositions
                   CHANGING  ct_messages = ct_messages ).
      check_code_parts( EXPORTING is_layout   = is_layout
                                  is_entry    = <ls_entry>
                        CHANGING  ct_messages = ct_messages ).
      " An entry that is not BLOCK needs a rule group (blank = category) with an active rule
      DATA(lv_group) = value( is_layout = is_layout is_entry = <ls_entry>
                              iv_name   = zif_cd_ops_postarea_types=>gc_field-rule_group ).
      IF lv_group IS INITIAL.
        lv_group = value( is_layout = is_layout is_entry = <ls_entry>
                          iv_name   = zif_cd_ops_postarea_types=>gc_field-category ).
      ENDIF.
      IF value( is_layout = is_layout is_entry = <ls_entry> iv_name = zif_cd_ops_postarea_types=>gc_field-action )
           <> zif_cd_ops_types=>gc_action-block
         AND missing_names( it_needed    = VALUE #( ( CONV #( lv_group ) ) )
                            it_available = lt_groups ) IS NOT INITIAL.
        add_message( EXPORTING is_layout   = is_layout
                               is_entry    = <ls_entry>
                               iv_number   = zif_cd_ops_cfg_types=>gc_msg-rule_group_empty
                               iv_v1       = lv_group
                     CHANGING  ct_messages = ct_messages ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_btc_roles.
    DATA lt_scopes TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

    " Method classes per flow that ZPMC knows (flow + class = the LIFECYCLE scope)
    LOOP AT it_classes ASSIGNING FIELD-SYMBOL(<ls_class>).
      DATA(lv_flow) = value( is_layout = is_classes is_entry = <ls_class>
                             iv_name   = zif_cd_ops_postarea_types=>gc_field-flow ).
      DATA(lv_class) = value( is_layout = is_classes is_entry = <ls_class>
                              iv_name   = zif_cd_ops_postarea_types=>gc_field-method_class ).
      INSERT |{ lv_flow }{ lv_class }| INTO TABLE lt_scopes.
    ENDLOOP.
    DATA(lv_usages) = list( VALUE #( ( CONV #( zif_cd_hck_types=>gc_btc_usage-lifecycle ) )
                                     ( CONV #( zif_cd_hck_types=>gc_btc_usage-recon ) ) ) ).
    DATA(lv_schemes) = list( VALUE #( ( CONV #( zif_cd_ebs_types=>gc_scheme-bai2 ) )
                                      ( CONV #( zif_cd_ebs_types=>gc_scheme-iso ) )
                                      ( CONV #( zif_cd_ebs_types=>gc_scheme-prtry ) ) ) ).
    DATA(lv_recon_roles) = list( VALUE #( ( CONV #( zif_cd_hck_recon_types=>gc_role-leg ) )
                                          ( CONV #( zif_cd_hck_recon_types=>gc_role-deposit ) )
                                          ( CONV #( zif_cd_hck_recon_types=>gc_role-cutoff ) )
                                          ( CONV #( zif_cd_hck_recon_types=>gc_role-redeposit ) )
                                          ( CONV #( zif_cd_hck_recon_types=>gc_role-cheque ) )
                                          ( CONV #( zif_cd_hck_recon_types=>gc_role-other ) )
                                          ( CONV #( zif_cd_hck_recon_types=>gc_role-ignore ) ) ) ).
    DATA(lv_compares) = list( it_values = VALUE #( ( CONV #( zif_cd_hck_runtime_types=>gc_compare-returns_lot ) )
                                                   ( CONV #( zif_cd_hck_runtime_types=>gc_compare-register ) )
                                                   ( CONV #( zif_cd_hck_runtime_types=>gc_compare-correction ) ) )
                              iv_blank  = abap_true ).
    LOOP AT it_entries ASSIGNING FIELD-SYMBOL(<ls_entry>).
      DATA(lv_usage) = value( is_layout = is_layout is_entry = <ls_entry> iv_name = zif_cd_ops_postarea_types=>gc_field-usage ).
      DATA(lv_scope) = value( is_layout = is_layout is_entry = <ls_entry> iv_name = zif_cd_ops_postarea_types=>gc_field-scope ).
      DATA(lv_role) = value( is_layout = is_layout is_entry = <ls_entry> iv_name = zif_cd_ops_postarea_types=>gc_field-role ).
      check_value( EXPORTING is_layout = is_layout is_entry = <ls_entry>
                             iv_name   = zif_cd_ops_postarea_types=>gc_field-usage iv_list = lv_usages
                   CHANGING  ct_messages = ct_messages ).
      check_value( EXPORTING is_layout = is_layout is_entry = <ls_entry>
                             iv_name   = zif_cd_ops_postarea_types=>gc_field-scheme iv_list = lv_schemes
                   CHANGING  ct_messages = ct_messages ).
      check_code_parts( EXPORTING is_layout   = is_layout
                                  is_entry    = <ls_entry>
                        CHANGING  ct_messages = ct_messages ).
      CASE lv_usage.
        WHEN zif_cd_hck_types=>gc_btc_usage-lifecycle.
          " SCOPE = flow + method class of ZPMC; an open list of roles, but never a reconciliation role
          IF zcl_cd_ops_util=>pcre_match( iv_value   = lv_scope
                                          iv_pattern = zif_cd_ops_postarea_types=>gc_scope_form ) = abap_false.
            add_message( EXPORTING is_layout   = is_layout
                                   is_entry    = <ls_entry>
                                   iv_number   = zif_cd_ops_cfg_types=>gc_msg-form_invalid
                                   iv_v1       = lv_scope
                                   iv_v2       = zif_cd_ops_postarea_types=>gc_field-scope
                                   iv_v3       = zif_cd_ops_postarea_types=>gc_scope_form
                         CHANGING  ct_messages = ct_messages ).
          ELSEIF NOT line_exists( lt_scopes[ table_line = lv_scope ] ).
            add_message( EXPORTING is_layout   = is_layout
                                   is_entry    = <ls_entry>
                                   iv_number   = zif_cd_ops_cfg_types=>gc_msg-class_unknown
                                   iv_v1       = substring( val = lv_scope off = 1 )
                                   iv_v2       = substring( val = lv_scope len = 1 )
                                   iv_v3       = is_classes-area
                         CHANGING  ct_messages = ct_messages ).
          ENDIF.
          IF lv_role IS INITIAL.
            add_message( EXPORTING is_layout   = is_layout
                                   is_entry    = <ls_entry>
                                   iv_number   = zif_cd_ops_cfg_types=>gc_msg-required
                                   iv_v1       = zif_cd_ops_postarea_types=>gc_field-role
                                   iv_v2       = zif_cd_ops_postarea_types=>gc_field-usage
                                   iv_v3       = lv_usage
                         CHANGING  ct_messages = ct_messages ).
          ELSEIF in_list( iv_value = CONV #( lv_role ) iv_list = lv_recon_roles ) = abap_true.
            add_message( EXPORTING is_layout   = is_layout
                                   is_entry    = <ls_entry>
                                   iv_number   = zif_cd_ops_cfg_types=>gc_msg-value_reserved
                                   iv_v1       = lv_role
                                   iv_v2       = zif_cd_ops_postarea_types=>gc_field-role
                                   iv_v3       = lv_recon_roles
                         CHANGING  ct_messages = ct_messages ).
          ENDIF.
          check_value( EXPORTING is_layout = is_layout is_entry = <ls_entry>
                                 iv_name   = zif_cd_ops_postarea_types=>gc_field-compare_amount iv_list = lv_compares
                       CHANGING  ct_messages = ct_messages ).
        WHEN zif_cd_hck_types=>gc_btc_usage-recon.
          " SCOPE = set id; the seven reconciliation roles, BAI2 type codes, nothing compared
          check_value( EXPORTING is_layout = is_layout is_entry = <ls_entry>
                                 iv_name   = zif_cd_ops_postarea_types=>gc_field-role iv_list = lv_recon_roles
                       CHANGING  ct_messages = ct_messages ).
          check_value( EXPORTING is_layout = is_layout is_entry = <ls_entry>
                                 iv_name   = zif_cd_ops_postarea_types=>gc_field-scheme
                                 iv_list   = list( VALUE #( ( CONV #( zif_cd_ebs_types=>gc_scheme-bai2 ) ) ) )
                       CHANGING  ct_messages = ct_messages ).
          IF value( is_layout = is_layout is_entry = <ls_entry>
                    iv_name   = zif_cd_ops_postarea_types=>gc_field-compare_amount ) IS NOT INITIAL.
            add_message( EXPORTING is_layout   = is_layout
                                   is_entry    = <ls_entry>
                                   iv_number   = zif_cd_ops_cfg_types=>gc_msg-must_be_blank
                                   iv_v1       = zif_cd_ops_postarea_types=>gc_field-compare_amount
                                   iv_v2       = zif_cd_ops_postarea_types=>gc_field-usage
                                   iv_v3       = lv_usage
                         CHANGING  ct_messages = ct_messages ).
          ENDIF.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_code_parts.
    DATA(lv_scheme) = value( is_layout = is_layout is_entry = is_entry iv_name = zif_cd_ops_postarea_types=>gc_field-scheme ).
    DATA(lt_parts) = VALUE zif_cd_ops_cfg_types=>ty_names( ( zif_cd_ops_postarea_types=>gc_field-family )
                                                           ( zif_cd_ops_postarea_types=>gc_field-sub_family ) ).
    LOOP AT lt_parts ASSIGNING FIELD-SYMBOL(<lv_part>).
      DATA(lv_value) = value( is_layout = is_layout is_entry = is_entry iv_name = <lv_part> ).
      IF lv_scheme = zif_cd_ebs_types=>gc_scheme-iso AND lv_value IS INITIAL.
        add_message( EXPORTING is_layout   = is_layout
                               is_entry    = is_entry
                               iv_number   = zif_cd_ops_cfg_types=>gc_msg-required
                               iv_v1       = <lv_part>
                               iv_v2       = zif_cd_ops_postarea_types=>gc_field-scheme
                               iv_v3       = lv_scheme
                     CHANGING  ct_messages = ct_messages ).
      ELSEIF lv_scheme <> zif_cd_ebs_types=>gc_scheme-iso AND lv_value IS NOT INITIAL.
        add_message( EXPORTING is_layout   = is_layout
                               is_entry    = is_entry
                               iv_number   = zif_cd_ops_cfg_types=>gc_msg-must_be_blank
                               iv_v1       = <lv_part>
                               iv_v2       = zif_cd_ops_postarea_types=>gc_field-scheme
                               iv_v3       = lv_scheme
                     CHANGING  ct_messages = ct_messages ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_value.
    DATA(lv_value) = value( is_layout = is_layout is_entry = is_entry iv_name = iv_name ).
    " A blank required key is reported once by the layout check (message 429)
    IF lv_value IS INITIAL AND line_exists( is_layout-keys[ name = iv_name required = abap_true ] ).
      RETURN.
    ENDIF.
    IF lv_value <> zif_cd_ops_postarea_types=>gc_generic
       AND in_list( iv_value = CONV #( lv_value ) iv_list = iv_list ) = abap_false.
      add_message( EXPORTING is_layout   = is_layout
                             is_entry    = is_entry
                             iv_number   = zif_cd_ops_cfg_types=>gc_msg-value_invalid
                             iv_v1       = lv_value
                             iv_v2       = iv_name
                             iv_v3       = iv_list
                   CHANGING  ct_messages = ct_messages ).
    ENDIF.
  ENDMETHOD.


  METHOD add_message.
    INSERT VALUE #( purpose  = is_layout-purpose
                    area     = is_layout-area
                    entry    = entry_text( is_entry )
                    severity = iv_severity
                    number   = iv_number
                    v1       = iv_v1
                    v2       = iv_v2
                    v3       = iv_v3 ) INTO TABLE ct_messages.
  ENDMETHOD.


  METHOD value.
    DATA(lv_position) = line_index( is_layout-keys[ name = iv_name ] ).
    IF lv_position = 0.
      lv_position = line_index( is_layout-results[ name = iv_name ] ).
      IF lv_position = 0.
        RETURN.
      ENDIF.
      lv_position += zif_cd_ops_postarea_types=>gc_key_count.
    ENDIF.
    rv_value = value_at( is_entry = is_entry iv_position = lv_position ).
  ENDMETHOD.


  METHOD value_at.
    ASSIGN COMPONENT iv_position OF STRUCTURE is_entry TO FIELD-SYMBOL(<lv_value>).
    IF sy-subrc = 0.
      rv_value = <lv_value>.
    ENDIF.
  ENDMETHOD.


  METHOD entry_text.
    DATA lt_keys TYPE string_table.
    DATA lv_position TYPE i.

    DO zif_cd_ops_postarea_types=>gc_key_count TIMES.
      lv_position = sy-index.
      INSERT value_at( is_entry = is_entry iv_position = lv_position ) INTO TABLE lt_keys.
    ENDDO.
    WHILE lt_keys IS NOT INITIAL AND lt_keys[ lines( lt_keys ) ] IS INITIAL.
      DELETE lt_keys INDEX lines( lt_keys ).
    ENDWHILE.
    rv_text = concat_lines_of( table = lt_keys sep = zif_cd_ops_postarea_types=>gc_key_separator ).
  ENDMETHOD.


  METHOD length_of.
    DESCRIBE FIELD iv_field LENGTH rv_length IN CHARACTER MODE.
  ENDMETHOD.


  METHOD list.
    rv_list = concat_lines_of( table = it_values sep = zif_cd_ops_postarea_types=>gc_list_sep ).
    IF iv_blank = abap_true.
      rv_list = |{ zif_cd_ops_postarea_types=>gc_list_sep }{ rv_list }|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
