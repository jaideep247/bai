*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_value_query.clas.abap
*& Purpose:
*& Value queries for the known-table checks, pure: parses NAME=VALUE check
*& parameters and builds a query whose table is whitelisted, whose names
*& exist in the DDIC, whose result fields are character-like and which is
*& always limited by a date field. Conditions and literals come from
*& ZCL_CD_HCK_AGG_QUERY (quoted). The DAO runs the query.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - value queries for known tables</p>
CLASS zcl_cd_hck_value_query DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! 'TABLE=X;KEY=Y' -> pairs; names upper case, values trimmed
    CLASS-METHODS parse
      IMPORTING
        iv_param       TYPE clike
      RETURNING
        VALUE(rt_spec) TYPE zif_cd_hck_value_types=>tt_spec.

    CLASS-METHODS value
      IMPORTING
        it_spec         TYPE zif_cd_hck_value_types=>tt_spec
        iv_name         TYPE clike
        iv_default      TYPE string OPTIONAL
      RETURNING
        VALUE(rv_value) TYPE string.

    "! @raising zcx_cd_ops_error | 302 not whitelisted, 303 no fields, 304 unknown field,
    "! 203 result field not character-like, 323 no date restriction, 305/306 conditions
    CLASS-METHODS build
      IMPORTING
        iv_tabname      TYPE zif_cd_hck_types=>ty_tabname
        it_return       TYPE string_table
        it_conditions   TYPE zif_cd_hck_value_types=>tt_condition OPTIONAL
        iv_date_field   TYPE zif_cd_hck_types=>ty_fieldname
        iv_date_from    TYPE d
        it_fields       TYPE zif_cd_hck_types=>tt_field
        iv_whitelisted  TYPE abap_bool
      RETURNING
        VALUE(rs_query) TYPE zif_cd_hck_value_types=>ty_value_query
      RAISING
        zcx_cd_ops_error.

    "! Validate (whitelist + DDIC through the DAO), build and run a value query
    CLASS-METHODS read
      IMPORTING
        io_dao         TYPE REF TO zif_cd_hck_dao
        iv_tabname     TYPE clike
        it_return      TYPE string_table
        it_conditions  TYPE zif_cd_hck_value_types=>tt_condition OPTIONAL
        iv_date_field  TYPE clike
        iv_date_from   TYPE d
        iv_max_rows    TYPE i
      RETURNING
        VALUE(rt_rows) TYPE zif_cd_hck_value_types=>tt_value_row
      RAISING
        zcx_cd_ops_error.

    "! First value of each row as a key set
    CLASS-METHODS keys
      IMPORTING
        it_rows        TYPE zif_cd_hck_value_types=>tt_value_row
      RETURNING
        VALUE(rt_keys) TYPE zif_cd_hck_value_types=>tt_key.

  PRIVATE SECTION.
    CONSTANTS gc_char_kinds TYPE string VALUE `CNDT`.
ENDCLASS.



CLASS zcl_cd_hck_value_query IMPLEMENTATION.

  METHOD parse.
    SPLIT iv_param AT ';' INTO TABLE DATA(lt_pairs).
    LOOP AT lt_pairs INTO DATA(lv_pair).
      SPLIT lv_pair AT '=' INTO DATA(lv_name) DATA(lv_value).
      lv_name = to_upper( condense( lv_name ) ).
      IF lv_name IS INITIAL.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( name = lv_name value = condense( lv_value ) ) INTO TABLE rt_spec.
    ENDLOOP.
  ENDMETHOD.


  METHOD value.
    rv_value = VALUE #( it_spec[ name = to_upper( iv_name ) ]-value DEFAULT iv_default ).
  ENDMETHOD.


  METHOD build.
    DATA lt_where TYPE string_table.
    DATA lt_select TYPE string_table.
    DATA lt_order TYPE string_table.

    IF iv_whitelisted = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e302(zcd_ops) WITH iv_tabname.
    ENDIF.
    IF it_fields IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e303(zcd_ops) WITH iv_tabname.
    ENDIF.
    IF iv_date_field IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e323(zcd_ops) WITH iv_tabname.
    ENDIF.

    LOOP AT it_return INTO DATA(lv_return) FROM 1 TO 3.
      DATA(lv_field) = CONV zif_cd_hck_types=>ty_fieldname( to_upper( condense( lv_return ) ) ).
      DATA(ls_field) = VALUE #( it_fields[ fieldname = lv_field ] OPTIONAL ).
      IF ls_field IS INITIAL.
        RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e304(zcd_ops) WITH lv_field iv_tabname.
      ENDIF.
      IF ls_field-type_kind IS INITIAL OR gc_char_kinds NS ls_field-type_kind.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e203(zcd_ops) WITH lv_field iv_tabname ls_field-type_kind 'CHAR'.
      ENDIF.
      INSERT |{ lv_field } AS v{ sy-tabix }| INTO TABLE lt_select.
      INSERT CONV string( lv_field ) INTO TABLE lt_order.
    ENDLOOP.

    LOOP AT it_conditions INTO DATA(ls_condition).
      INSERT zcl_cd_hck_agg_query=>condition( iv_field    = ls_condition-field
                                              iv_operator = ls_condition-operator
                                              iv_value    = ls_condition-value
                                              iv_tabname  = iv_tabname
                                              it_fields   = it_fields ) INTO TABLE lt_where.
    ENDLOOP.
    INSERT zcl_cd_hck_agg_query=>condition( iv_field    = iv_date_field
                                            iv_operator = zif_cd_hck_types=>gc_operator-ge
                                            iv_value    = CONV #( iv_date_from )
                                            iv_tabname  = iv_tabname
                                            it_fields   = it_fields ) INTO TABLE lt_where.

    rs_query-tabname      = iv_tabname.
    rs_query-field_list   = concat_lines_of( table = lt_select sep = `, ` ).
    rs_query-where_clause = concat_lines_of( table = lt_where sep = ` AND ` ).
    rs_query-order_by     = concat_lines_of( table = lt_order sep = `, ` ).
  ENDMETHOD.

  METHOD read.
    DATA(lv_tabname) = CONV zif_cd_hck_types=>ty_tabname( to_upper( condense( iv_tabname ) ) ).
    DATA(ls_query) = build( iv_tabname     = lv_tabname
                            it_return      = it_return
                            it_conditions  = it_conditions
                            iv_date_field  = CONV #( to_upper( condense( iv_date_field ) ) )
                            iv_date_from   = iv_date_from
                            it_fields      = io_dao->get_table_fields( lv_tabname )
                            iv_whitelisted = io_dao->is_table_whitelisted( lv_tabname ) ).
    rt_rows = io_dao->select_values( is_query = ls_query iv_max_rows = iv_max_rows ).
  ENDMETHOD.


  METHOD keys.
    LOOP AT it_rows INTO DATA(ls_row).
      INSERT ls_row-v1 INTO TABLE rt_keys.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
