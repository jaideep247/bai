*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_value_query.clas.testclasses.abap
*& Purpose:
*& Pure tests of the value-query builder: NAME=VALUE parameters, names
*& checked against the DDIC field list and the whitelist, character-like
*& result fields only, mandatory date restriction, quoted literals.
*& Static ABAP Unit only; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*&---------------------------------------------------------------------*
CLASS ltc_value_query DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_table TYPE zif_cd_hck_types=>ty_tabname VALUE 'ZCD_PAYM_REQ_LOG'.

    METHODS fields
      RETURNING
        VALUE(rt_fields) TYPE zif_cd_hck_types=>tt_field.
    METHODS build
      IMPORTING
        it_return       TYPE string_table
        iv_date_field   TYPE zif_cd_hck_types=>ty_fieldname DEFAULT 'ERDAT'
        iv_whitelisted  TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rs_query) TYPE zif_cd_hck_value_types=>ty_value_query
      RAISING
        zcx_cd_ops_error.

    METHODS parameter_pairs_are_parsed   FOR TESTING.
    METHODS query_has_conditions_and_day FOR TESTING.
    METHODS unknown_field_is_rejected    FOR TESTING.
    METHODS numeric_result_is_rejected   FOR TESTING.
    METHODS date_restriction_is_required FOR TESTING.
    METHODS table_must_be_whitelisted    FOR TESTING.
ENDCLASS.


CLASS ltc_value_query IMPLEMENTATION.

  METHOD fields.
    rt_fields = VALUE #( ( fieldname = 'REQ_ID'    type_kind = 'C' keyflag = abap_true )
                         ( fieldname = 'ZZ_STATUS' type_kind = 'C' )
                         ( fieldname = 'ERDAT'     type_kind = 'D' )
                         ( fieldname = 'AMOUNT'    type_kind = 'P' ) ).
  ENDMETHOD.


  METHOD build.
    rs_query = zcl_cd_hck_value_query=>build(
                 iv_tabname     = gc_table
                 it_return      = it_return
                 it_conditions  = VALUE #( ( field = 'ZZ_STATUS' operator = 'EQ' value = 'SUCCESS' ) )
                 iv_date_field  = iv_date_field
                 iv_date_from   = '20261103'
                 it_fields      = fields( )
                 iv_whitelisted = iv_whitelisted ).
  ENDMETHOD.


  " Rule: PARAM1-4 hold NAME=VALUE pairs separated by semicolons (names in upper case)
  METHOD parameter_pairs_are_parsed.
    TRY.
        DATA(lt_spec) = zcl_cd_hck_value_query=>parse( 'table=ZCD_PAYM_REQ_LOG; KEY=REQ_ID ;STATUS=ZZ_STATUS' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_value_query=>value( it_spec = lt_spec iv_name = 'TABLE' )
                                            exp = `ZCD_PAYM_REQ_LOG` msg = 'TABLE must be read case-insensitive' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_value_query=>value( it_spec = lt_spec iv_name = 'KEY' )
                                            exp = `REQ_ID` msg = 'Values must be trimmed' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_value_query=>value( it_spec    = lt_spec
                                                                                  iv_name    = 'DAYS'
                                                                                  iv_default = `3` )
                                            exp = `3` msg = 'A missing name must give the default' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the query returns the requested fields as V1..V3, filters by the conditions and the day
  METHOD query_has_conditions_and_day.
    TRY.
        DATA(ls_query) = build( VALUE #( ( `REQ_ID` ) ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_query-field_list exp = `REQ_ID AS v1`
                                            msg = 'The key must be returned as V1' ).
        cl_abap_unit_assert=>assert_char_cp( act = ls_query-where_clause exp = '*ZZ_STATUS*SUCCESS*'
                                             msg = 'The status condition must be part of the WHERE clause' ).
        cl_abap_unit_assert=>assert_char_cp( act = ls_query-where_clause exp = '*ERDAT >=*20261103*'
                                             msg = 'The date restriction must be part of the WHERE clause' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a configured name that is not in the DDIC never reaches the database (304)
  METHOD unknown_field_is_rejected.
    TRY.
        build( VALUE #( ( `NO_SUCH_FIELD` ) ) ).
        cl_abap_unit_assert=>fail( msg = 'An unknown field must be rejected' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '304'
                                            msg = 'Unknown field must raise 304' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: only character-like fields are returned (keys, statuses, dates) (203)
  METHOD numeric_result_is_rejected.
    TRY.
        build( VALUE #( ( `AMOUNT` ) ) ).
        cl_abap_unit_assert=>fail( msg = 'A numeric result field must be rejected' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '203'
                                            msg = 'A numeric result field must raise 203' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: every value query is limited by a date field - no full-table reads (323)
  METHOD date_restriction_is_required.
    TRY.
        build( it_return = VALUE #( ( `REQ_ID` ) ) iv_date_field = space ).
        cl_abap_unit_assert=>fail( msg = 'A query without date restriction must be rejected' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '323'
                                            msg = 'A missing date restriction must raise 323' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: only tables on the whitelist ZCD_HCK_TABWL are read (302)
  METHOD table_must_be_whitelisted.
    TRY.
        build( it_return = VALUE #( ( `REQ_ID` ) ) iv_whitelisted = abap_false ).
        cl_abap_unit_assert=>fail( msg = 'A table off the whitelist must be rejected' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '302'
                                            msg = 'A table off the whitelist must raise 302' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
