*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cfg_version.clas.testclasses.abap
*& Purpose:
*& Pure tests of the configuration version: a line holds the kind and the
*& values of a row in order, the version is the same for the same rows in
*& any order, differs when one value differs, ignores the description and
*& sequence of the registry row and is a 40 character SHA-1. No doubles;
*& does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (explainable, versioned results).
*&---------------------------------------------------------------------*
CLASS ltc_cfg_version DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area  TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        check TYPE zif_ca_ops_chk_types=>ty_check_id VALUE 'ZT_CHECK',
        class TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_ZT_CHECK',
      END OF gc.

    METHODS check_row
      RETURNING
        VALUE(rs_check) TYPE zif_ca_ops_chk_types=>ty_check.

    METHODS line_lists_row_values      FOR TESTING.
    METHODS order_does_not_matter      FOR TESTING.
    METHODS changed_value_new_version  FOR TESTING.
    METHODS cosmetic_fields_ignored    FOR TESTING.
ENDCLASS.


CLASS ltc_cfg_version IMPLEMENTATION.

  METHOD check_row.
    rs_check-area        = gc-area.
    rs_check-check_id    = gc-check.
    rs_check-class_name  = gc-class.
    rs_check-sched_group = 'DAILY'.
    rs_check-active      = abap_true.
  ENDMETHOD.


  " Rule: kind first, then every elementary value of the row, separated
  METHOD line_lists_row_values.
    DATA ls_agg TYPE zif_ca_ops_chk_types=>ty_agg.
    TRY.
        ls_agg-agg_id = 'A1'.
        ls_agg-amber  = 1.
        ls_agg-red    = 3.
        DATA(lv_line) = zcl_ca_ops_cfg_version=>line( iv_kind = 'AGG' is_row = ls_agg ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( lv_line CS 'AGG|' ) msg = 'Kind first' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( lv_line CS '|A1|' ) msg = 'Aggregate ID' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_cfg_version=>line( iv_kind = 'P' is_row = 'X' )
                                            exp = `P|X` msg = 'Elementary value' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the lines are sorted before hashing - the order a check lists them in changes nothing
  METHOD order_does_not_matter.
    TRY.
        DATA(lv_one) = zcl_ca_ops_cfg_version=>of_lines( VALUE #( ( `A|1` ) ( `B|2` ) ) ).
        DATA(lv_two) = zcl_ca_ops_cfg_version=>of_lines( VALUE #( ( `B|2` ) ( `A|1` ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lv_two exp = lv_one msg = 'Same rows, same version' ).
        cl_abap_unit_assert=>assert_equals( act = strlen( lv_one ) exp = 40 msg = 'SHA-1 in hex' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: one changed value (a threshold, a rule, an account) is another version
  METHOD changed_value_new_version.
    TRY.
        DATA(ls_check) = check_row( ).
        DATA(lv_base) = zcl_ca_ops_cfg_version=>of_check( is_check = ls_check it_lines = VALUE #( ( `AGG|A1|1|3` ) ) ).
        cl_abap_unit_assert=>assert_differs(
          act = zcl_ca_ops_cfg_version=>of_check( is_check = ls_check it_lines = VALUE #( ( `AGG|A1|1|4` ) ) )
          exp = lv_base msg = 'Threshold changed' ).
        ls_check-bukrs_aware = abap_true.
        cl_abap_unit_assert=>assert_differs(
          act = zcl_ca_ops_cfg_version=>of_check( is_check = ls_check it_lines = VALUE #( ( `AGG|A1|1|3` ) ) )
          exp = lv_base msg = 'Registry row changed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: description and sequence of the registry row change no result - and no version
  METHOD cosmetic_fields_ignored.
    TRY.
        DATA(ls_check) = check_row( ).
        DATA(lv_base) = zcl_ca_ops_cfg_version=>of_check( ls_check ).
        ls_check-description = 'Renamed'.
        ls_check-seq         = 90.
        cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_cfg_version=>of_check( ls_check ) exp = lv_base
                                            msg = 'Same version' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
