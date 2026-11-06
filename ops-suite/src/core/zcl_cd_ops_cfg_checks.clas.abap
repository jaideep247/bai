*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_cfg_checks.clas.abap
*& Purpose:
*& Field checks of the configuration apps, shared by all four behaviour
*& pools: DDIC name syntax, table / field existence (RTTI), plug-in class
*& implements its payment engine area interface, allowed values, time windows,
*& threshold order, rule groups without active rules. No SQL; RTTI reads
*& dictionary metadata only. Messages are chosen by the caller.
*& Modification log:
*& 2026-11-06 | Initial version (RAP configuration apps, design 5).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | PCRE instead of the obsolete POSIX regex in matches( ).
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

  PRIVATE SECTION.
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

ENDCLASS.
