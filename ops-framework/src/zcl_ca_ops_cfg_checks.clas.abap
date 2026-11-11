*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cfg_checks.clas.abap
*& Purpose:
*& Generic field checks of the configuration apps (the framework's own app
*& and every consumer app generated the same way): DDIC name syntax, table /
*& field existence (RTTI), plug-in class implements its interface, allowed
*& values, time windows, alert destinations the channel cannot deliver to
*& (the channel plug-in decides), area registered in ZCA_PARAM_AREA, a
*& parameter defined in ZCA_PARAM. No own SQL: RTTI reads dictionary
*& metadata, channels come from the alert DAO, areas and definitions from
*& the parameter framework. Messages are chosen by the caller.
*& Modification log:
*& 2026-11-06 | Initial version (RAP configuration apps, design 5).
*& 2026-11-06 | PCRE instead of the obsolete POSIX regex in matches( ).
*& 2026-11-07 | CHANNEL_CLASS / INVALID_DESTINATION: alert destinations checked by their channel.
*& 2026-11-10 | Moved from ZCL_CD_OPS_CFG_CHECKS to the reusable framework ZCA_OPS (generic checks only);
*&            | AREA_VALID (one area register) and PARAM_EXISTS (purge registry) added.
*& 2026-11-10 | TEMPLATE_VALID: e-mail template ID of a rule / channel (syntax, existence where the SMTG API
*&            | is available; message 436).
*& 2026-11-10 | USER_VALID, TEAM_VALID, URL_VALID: control register of the daily review (messages 437-439).
*& 2026-11-11 | LINK_VALID (runbook link of an active runbook row, required), KEY_FIELDS_VALID and
*&            | WINDOW_MIN_VALID (alert correlation rules; messages 153 / 154) - operations response features.
*& 2026-11-11 | FIELD_REF_VALID: TABLE-FIELD reference of a link condition of the link registry (message 225).
*& 2026-11-11 | APPROVER_VALID: approver of a process catalogue activation - a user of the client other than
*&            | the user saving the row (four-eyes, message 240).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - config apps: field checks</p>
CLASS zcl_ca_ops_cfg_checks DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Letters, digits, _ and / only, at most 30 characters (case-insensitive)
    CLASS-METHODS is_valid_name
      IMPORTING
        iv_name         TYPE zif_ca_ops_cfg_types=>ty_name
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    "! Transparent table or view of the ABAP dictionary
    CLASS-METHODS table_exists
      IMPORTING
        iv_table         TYPE zif_ca_ops_cfg_types=>ty_name
      RETURNING
        VALUE(rv_exists) TYPE abap_bool.

    CLASS-METHODS field_exists
      IMPORTING
        iv_table         TYPE zif_ca_ops_cfg_types=>ty_name
        iv_field         TYPE zif_ca_ops_cfg_types=>ty_name
      RETURNING
        VALUE(rv_exists) TYPE abap_bool.

    "! Global class exists and implements the interface (plug-in contract)
    CLASS-METHODS implements
      IMPORTING
        iv_class          TYPE zif_ca_ops_cfg_types=>ty_name
        iv_interface      TYPE zif_ca_ops_cfg_types=>ty_name
      RETURNING
        VALUE(rv_matches) TYPE abap_bool.

    "! iv_list: comma-separated values; a leading comma allows blank
    CLASS-METHODS in_list
      IMPORTING
        iv_value          TYPE zif_ca_ops_cfg_types=>ty_value
        iv_list           TYPE zif_ca_ops_cfg_types=>ty_value_list
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

    "! Both times set or both empty (a window may cross midnight)
    CLASS-METHODS window_complete
      IMPORTING
        iv_from            TYPE t
        iv_to              TYPE t
      RETURNING
        VALUE(rv_complete) TYPE abap_bool.

    "! Names of it_needed that are not in it_available (each once)
    CLASS-METHODS missing_names
      IMPORTING
        it_needed         TYPE zif_ca_ops_cfg_types=>ty_names
        it_available      TYPE zif_ca_ops_cfg_types=>ty_names
      RETURNING
        VALUE(rt_missing) TYPE zif_ca_ops_cfg_types=>ty_names.

    "! Plug-in class of an alert channel (active configuration); blank = unknown channel
    CLASS-METHODS channel_class
      IMPORTING
        iv_channel      TYPE zif_ca_ops_types=>ty_channel
      RETURNING
        VALUE(rv_class) TYPE zif_ca_ops_types=>ty_class_name.

    "! Entries of iv_destination the channel class cannot deliver to (blank = fine).
    "! Not checked here (blank): no class or a class that is not a channel - the
    "! class check of the channel row reports those.
    CLASS-METHODS invalid_destination
      IMPORTING
        iv_class          TYPE zif_ca_ops_types=>ty_class_name
        iv_destination    TYPE zif_ca_ops_types=>ty_alert_dest
      RETURNING
        VALUE(rv_invalid) TYPE string.

    "! Blank, * (every area) when iv_any_allowed, or an active parameter area of ZCA_PARAM_AREA
    CLASS-METHODS area_valid
      IMPORTING
        iv_area         TYPE zif_ca_ops_types=>ty_area
        iv_any_allowed  TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    "! The parameter is defined in the area of ZCA_PARAM (blank name: nothing to check)
    CLASS-METHODS param_exists
      IMPORTING
        iv_area          TYPE zif_ca_ops_types=>ty_area
        iv_name          TYPE zif_ca_ops_types=>ty_param_name
      RETURNING
        VALUE(rv_exists) TYPE abap_bool.

    "! E-mail template ID of an alert rule or channel: blank, or upper-case letters, digits,
    "! underscore and namespace slashes (at most 30); and, where the SAP e-mail template API is
    "! available, an existing template (ZIF_CA_OPS_MAIL_TEMPLATE=>EXISTS; else syntax only)
    CLASS-METHODS template_valid
      IMPORTING
        iv_template_id  TYPE zif_ca_ops_types=>ty_template_id
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    "! Owner / backup of a control: blank, or a user of this client (ZIF_CA_OPS_AUTH=>USER_EXISTS)
    CLASS-METHODS user_valid
      IMPORTING
        iv_user         TYPE syuname
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    "! Team of a control: blank, or one of the values of parameter CONTROL_TEAMS (case ignored)
    CLASS-METHODS team_valid
      IMPORTING
        iv_team         TYPE clike
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    "! Runbook link of a control: blank, or http(s):// without blanks (PCRE, whole value)
    CLASS-METHODS url_valid
      IMPORTING
        iv_url          TYPE clike
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    "! Runbook link of an active runbook row (ZCA_OPS_RUNBOOK): required, http(s):// without blanks - a row
    "! with a placeholder link is saved inactive
    CLASS-METHODS link_valid
      IMPORTING
        iv_url          TYPE clike
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    "! Key fields of a correlation rule: a comma list of finding fields of ZIF_CA_OPS_RESP_TYPES=>GC_KEY_FIELD
    CLASS-METHODS key_fields_valid
      IMPORTING
        iv_fields       TYPE clike
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    "! Window of a correlation rule: at least one minute
    CLASS-METHODS window_min_valid
      IMPORTING
        iv_minutes      TYPE i
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    "! Field reference of a link condition (link registry): TABLE-FIELD, the field a field of the runtime DDIC
    "! of the table or CDS view entity; blank is valid (a condition kind without that side)
    CLASS-METHODS field_ref_valid
      IMPORTING
        iv_ref          TYPE clike
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    "! Approver of a process catalogue activation: blank (the required check reports it), or a user of this
    "! client who is not the user saving the row (four-eyes: nobody approves their own activation change)
    CLASS-METHODS approver_valid
      IMPORTING
        iv_user         TYPE syuname
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

  PRIVATE SECTION.
    "! E-mail template ID (SMTG): VERIFY-ADT the allowed characters of a template ID
    CONSTANTS gc_template_pattern TYPE string VALUE `[A-Z/][A-Z0-9_/]{0,29}`.
    "! DDIC / class name: letters, digits, underscore, namespace slashes, max 30
    CONSTANTS gc_name_pattern TYPE string VALUE `^[A-Z/][A-Z0-9_/]{0,29}$`.
    CLASS-METHODS describe
      IMPORTING
        iv_name        TYPE zif_ca_ops_cfg_types=>ty_name
      RETURNING
        VALUE(ro_type) TYPE REF TO cl_abap_typedescr.

ENDCLASS.



CLASS zcl_ca_ops_cfg_checks IMPLEMENTATION.

  METHOD is_valid_name.
    DATA(lv_name) = to_upper( condense( iv_name ) ).
    rv_valid = xsdbool( matches( val = lv_name pcre = gc_name_pattern ) ).
  ENDMETHOD.


  METHOD table_exists.
    DATA(lo_type) = describe( iv_table ).
    IF lo_type IS NOT BOUND.
      RETURN.
    ENDIF.
    rv_exists = xsdbool( lo_type->kind = cl_abap_typedescr=>kind_struct
                         AND lo_type->is_ddic_type( ) = abap_true ).
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


  METHOD missing_names.
    LOOP AT it_needed ASSIGNING FIELD-SYMBOL(<lv_name>).
      IF NOT line_exists( it_available[ table_line = <lv_name> ] )
         AND NOT line_exists( rt_missing[ table_line = <lv_name> ] ).
        INSERT <lv_name> INTO TABLE rt_missing.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD channel_class.
    DATA(lt_channels) = zcl_ca_ops_factory=>get_alert_dao( )->get_channels( ).
    READ TABLE lt_channels ASSIGNING FIELD-SYMBOL(<ls_channel>)
      WITH KEY channel = to_upper( condense( iv_channel ) ).
    IF sy-subrc = 0.
      rv_class = <ls_channel>-class_name.
    ENDIF.
  ENDMETHOD.


  METHOD invalid_destination.
    DATA lo_channel TYPE REF TO zif_ca_ops_alert_channel.
    IF iv_class IS INITIAL OR iv_destination IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        lo_channel = CAST zif_ca_ops_alert_channel(
          zcl_ca_ops_factory=>get_plugin( iv_class_name = iv_class
                                          iv_interface  = zif_ca_ops_types=>gc_plugin_intf-alert_channel ) ).
      CATCH zcx_ca_ops_error.
        RETURN.
    ENDTRY.
    rv_invalid = lo_channel->check_destination( iv_destination ).
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


  METHOD area_valid.
    IF iv_area IS INITIAL OR ( iv_area = zif_ca_ops_types=>gc_area_any AND iv_any_allowed = abap_true ).
      rv_valid = abap_true.
      RETURN.
    ENDIF.
    TRY.
        zcl_ca_ops_factory=>get_params( )->check_area( iv_area ).
        rv_valid = abap_true.
      CATCH zcx_ca_ops_error.
        rv_valid = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD template_valid.
    IF iv_template_id IS INITIAL.
      rv_valid = abap_true.
      RETURN.
    ENDIF.
    " matched to the complete value; upper case only (the router reads the ID as it is stored)
    DATA(lv_id) = condense( iv_template_id ).
    IF lv_id <> to_upper( lv_id )
       OR zcl_ca_ops_util=>pcre_match( iv_value   = lv_id
                                       iv_pattern = gc_template_pattern ) = abap_false.
      RETURN.
    ENDIF.
    rv_valid = zcl_ca_ops_factory=>get_mail_template( )->exists( iv_template_id ).
  ENDMETHOD.


  METHOD user_valid.
    rv_valid = xsdbool( iv_user IS INITIAL OR zcl_ca_ops_factory=>get_auth( )->user_exists( iv_user ) = abap_true ).
  ENDMETHOD.


  METHOD team_valid.
    IF iv_team IS INITIAL.
      rv_valid = abap_true.
      RETURN.
    ENDIF.
    DATA(lv_teams) = zcl_ca_ops_factory=>get_params( )->get_param(
                       iv_name    = zif_ca_ops_ctl_types=>gc_param-teams
                       iv_default = CONV #( zif_ca_ops_ctl_types=>gc_param_default-teams ) ).
    DATA(lt_teams) = zcl_ca_ops_util=>split_list( to_upper( lv_teams ) ).
    DATA(lv_team) = to_upper( condense( CONV string( iv_team ) ) ).
    rv_valid = xsdbool( line_exists( lt_teams[ table_line = lv_team ] ) ).
  ENDMETHOD.


  METHOD url_valid.
    rv_valid = xsdbool( iv_url IS INITIAL
                        OR zcl_ca_ops_util=>pcre_match( iv_value   = iv_url
                                                        iv_pattern = zif_ca_ops_ctl_types=>gc_url_pattern ) = abap_true ).
  ENDMETHOD.


  METHOD link_valid.
    rv_valid = xsdbool( iv_url IS NOT INITIAL AND url_valid( iv_url ) = abap_true ).
  ENDMETHOD.


  METHOD approver_valid.
    IF iv_user IS INITIAL.
      rv_valid = abap_true.
      RETURN.
    ENDIF.
    rv_valid = xsdbool( iv_user <> sy-uname AND zcl_ca_ops_factory=>get_auth( )->user_exists( iv_user ) = abap_true ).
  ENDMETHOD.


  METHOD field_ref_valid.
    IF iv_ref IS INITIAL.
      rv_valid = abap_true.
      RETURN.
    ENDIF.
    DATA(ls_ref) = zcl_ca_ops_link_query=>split_ref( CONV #( iv_ref ) ).
    rv_valid = xsdbool( ls_ref-source IS NOT INITIAL
                        AND field_exists( iv_table = CONV #( ls_ref-source )
                                          iv_field = CONV #( ls_ref-field ) ) = abap_true ).
  ENDMETHOD.


  METHOD key_fields_valid.
    DATA(lt_fields) = zcl_ca_ops_util=>split_list( iv_fields ).
    rv_valid = xsdbool( lt_fields IS NOT INITIAL ).
    LOOP AT lt_fields ASSIGNING FIELD-SYMBOL(<lv_field>).
      IF zcl_ca_ops_correlator=>is_key_field( <lv_field> ) = abap_false.
        rv_valid = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD window_min_valid.
    rv_valid = xsdbool( iv_minutes >= 1 ).
  ENDMETHOD.


  METHOD param_exists.
    IF iv_name IS INITIAL.
      rv_exists = abap_true.
      RETURN.
    ENDIF.
    TRY.
        zcl_ca_param_factory=>get( )->get_definition( iv_area = iv_area
                                                      iv_name = iv_name ).
        rv_exists = abap_true.
      CATCH zcx_ca_param.
        rv_exists = abap_false.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
