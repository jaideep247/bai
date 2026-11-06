*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_query.clas.abap
*& Purpose:
*& Builds and validates reads of configured tables: every table and field
*& name must be a DDIC identifier and exist in the DDIC field list with a
*& fitting type before the DAO may execute it. Pure, no database.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A51: CHECK_APPROVED against ZCD_FMON_TABWL.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - DDIC validation of configured reads</p>
CLASS zcl_cd_fmon_query DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    "! Upper-case DDIC identifier, optionally with namespace (/ABC/NAME)
    CLASS-METHODS is_valid_name
      IMPORTING
        iv_name         TYPE clike
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    "! Append a role/field pair; blank fields are skipped, names upper-cased
    CLASS-METHODS add_field
      IMPORTING
        iv_role  TYPE zif_cd_fmon_types=>ty_role
        iv_field TYPE zif_cd_fmon_types=>ty_fieldname
      CHANGING
        cs_query TYPE zif_cd_fmon_types=>ty_query.

    "! @raising zcx_cd_ops_error | 201 unknown field, 202 invalid name,
    "! 203 wrong type of date field, 209 no restricting condition
    CLASS-METHODS validate
      IMPORTING
        is_query  TYPE zif_cd_fmon_types=>ty_query
        it_fields TYPE zif_cd_fmon_types=>tt_ddic_field
      RAISING
        zcx_cd_ops_error.

    "! Audit A51: the table and every queried field (and the date / IN field) must be
    "! approved in ZCD_FMON_TABWL (field '*' = all fields of the table)
    CLASS-METHODS check_approved
      IMPORTING
        is_query TYPE zif_cd_fmon_types=>ty_query
        it_allow TYPE zif_cd_fmon_types=>tt_tab_allow
      RAISING
        zcx_cd_ops_error.

  PRIVATE SECTION.
    "! DDIC name, optionally with namespace (/ABC/NAME); length checked separately
    CONSTANTS gc_ddic_name_pattern TYPE string VALUE `^/?[A-Z][A-Z0-9_]*(/[A-Z0-9_]+)?$`.

    CLASS-METHODS check_field
      IMPORTING
        iv_table  TYPE zif_cd_fmon_types=>ty_tabname
        iv_field  TYPE zif_cd_fmon_types=>ty_fieldname
        it_fields TYPE zif_cd_fmon_types=>tt_ddic_field
      RETURNING
        VALUE(rs_field) TYPE zif_cd_fmon_types=>ty_ddic_field
      RAISING
        zcx_cd_ops_error.

ENDCLASS.



CLASS zcl_cd_fmon_query IMPLEMENTATION.

  METHOD is_valid_name.
    DATA(lv_name) = CONV string( iv_name ).
    rv_valid = xsdbool( matches( val = lv_name pcre = gc_ddic_name_pattern )
                        AND strlen( lv_name ) <= 30 ).
  ENDMETHOD.


  METHOD add_field.
    DATA ls_field TYPE zif_cd_fmon_types=>ty_qfield.
    IF iv_field IS INITIAL.
      RETURN.
    ENDIF.
    ls_field-role  = iv_role.
    ls_field-field = to_upper( condense( iv_field ) ).
    INSERT ls_field INTO TABLE cs_query-fields.
  ENDMETHOD.


  METHOD validate.
    IF is_valid_name( is_query-table_name ) = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e202(zcd_ops) WITH is_query-table_name.
    ENDIF.

    LOOP AT is_query-fields INTO DATA(ls_qfield).
      check_field( iv_table  = is_query-table_name
                   iv_field  = ls_qfield-field
                   it_fields = it_fields ).
    ENDLOOP.

    IF is_query-date_field IS INITIAL AND is_query-in_field IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e209(zcd_ops) WITH is_query-table_name.
    ENDIF.

    IF is_query-date_field IS NOT INITIAL.
      DATA(ls_date) = check_field( iv_table  = is_query-table_name
                                   iv_field  = is_query-date_field
                                   it_fields = it_fields ).
      DATA(lv_expected) = COND string( WHEN is_query-date_kind = zif_cd_fmon_types=>gc_date_kind-date THEN `D`
                                       ELSE `P` ).
      IF ls_date-inttype <> lv_expected.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e203(zcd_ops) WITH ls_date-fieldname is_query-table_name ls_date-inttype lv_expected.
      ENDIF.
    ENDIF.

    IF is_query-in_field IS NOT INITIAL.
      check_field( iv_table  = is_query-table_name
                   iv_field  = is_query-in_field
                   it_fields = it_fields ).
    ENDIF.
  ENDMETHOD.


  METHOD check_field.
    IF is_valid_name( iv_field ) = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e202(zcd_ops) WITH iv_field.
    ENDIF.
    READ TABLE it_fields INTO rs_field WITH TABLE KEY fieldname = iv_field.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e201(zcd_ops) WITH iv_field iv_table.
    ENDIF.
  ENDMETHOD.

  METHOD check_approved.
    DATA lt_used TYPE SORTED TABLE OF zif_cd_fmon_types=>ty_fieldname WITH UNIQUE KEY table_line.
    DATA(lv_table) = to_upper( condense( CONV string( is_query-table_name ) ) ).
    DATA(lt_table_rows) = VALUE zif_cd_fmon_types=>tt_tab_allow(
      FOR ls_allow IN it_allow WHERE ( table_name = lv_table ) ( ls_allow ) ).
    IF lt_table_rows IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e244(zcd_ops) WITH lv_table.
    ENDIF.
    IF line_exists( lt_table_rows[ field_name = zif_cd_fmon_types=>gc_wildcard ] ).
      RETURN.
    ENDIF.
    LOOP AT is_query-fields INTO DATA(ls_field).
      INSERT to_upper( condense( ls_field-field ) ) INTO TABLE lt_used.
    ENDLOOP.
    IF is_query-date_field IS NOT INITIAL.
      INSERT to_upper( condense( is_query-date_field ) ) INTO TABLE lt_used.
    ENDIF.
    IF is_query-in_field IS NOT INITIAL.
      INSERT to_upper( condense( is_query-in_field ) ) INTO TABLE lt_used.
    ENDIF.
    LOOP AT lt_used INTO DATA(lv_field).
      IF NOT line_exists( lt_table_rows[ field_name = lv_field ] ).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e249(zcd_ops) WITH lv_field lv_table.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
