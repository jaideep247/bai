*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_postarea_layout.clas.testclasses.abap
*& Purpose:
*& Domain tests of the mapping layouts: the fit of each purpose to TFK033D
*& of the reference system (8 keys, 6 results, CHAR 12) - ZRSN and ZPMC fit,
*& ZBTM (keys of 35 / 15, 7 results) and ZBTR (keys of 35, role of 15) do
*& not, with the fields and counts named; the typed table and its entity per
*& purpose. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (written before the class; source per purpose).
*&---------------------------------------------------------------------*
CLASS ltc_layout DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_unknown TYPE zif_cd_ops_postarea_types=>ty_purpose VALUE 'XXX'.

    METHODS reason_and_classes_fit    FOR TESTING.
    METHODS btc_map_needs_typed_table FOR TESTING.
    METHODS btc_roles_too_long        FOR TESTING.
    METHODS table_and_entity_per_use  FOR TESTING.
    METHODS unknown_purpose_empty     FOR TESTING.
ENDCLASS.


CLASS ltc_layout IMPLEMENTATION.

  " Rule: ZRSN (up to 4 characters, 2 results) and ZPMC (up to 10, 3 results) fit TFK033D
  METHOD reason_and_classes_fit.
    TRY.
        cl_abap_unit_assert=>assert_initial(
          act = zcl_cd_ops_postarea_layout=>misfits( zif_cd_ops_postarea_types=>gc_purpose-reason ) msg = 'ZRSN fits' ).
        cl_abap_unit_assert=>assert_initial(
          act = zcl_cd_ops_postarea_layout=>misfits( zif_cd_ops_postarea_types=>gc_purpose-pm_class ) msg = 'ZPMC fits' ).
        DATA(ls_layout) = zcl_cd_ops_postarea_layout=>layout( zif_cd_ops_postarea_types=>gc_purpose-pm_class ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_layout-keys ) exp = 3 msg = 'ZPMC: 3 keys' ).
        cl_abap_unit_assert=>assert_true( act = ls_layout-keys[ 3 ]-generic msg = 'House bank: * allowed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: ZBTM does not fit - CODE / FAMILY / SUB_FAMILY 35, BANK_KEY 15 (440) and 7 results (441)
  METHOD btc_map_needs_typed_table.
    TRY.
        DATA(lt_misfits) = zcl_cd_ops_postarea_layout=>misfits( zif_cd_ops_postarea_types=>gc_purpose-btc_map ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_misfits ) exp = 5 msg = 'Four fields and the results' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( lt_misfits[ number = zif_cd_ops_cfg_types=>gc_msg-postarea_too_short
                                                  v1     = zif_cd_ops_postarea_types=>gc_field-code
                                                  v2     = '35'
                                                  v3     = '12' ] ) )
          msg = 'CODE needs 35, TFK033D holds 12' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( lt_misfits[ number = zif_cd_ops_cfg_types=>gc_msg-postarea_too_few
                                                  v1     = '6/7'
                                                  v2     = '8/6' ] ) )
          msg = '7 results, TFK033D has 6' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: ZBTR fits by count (6 keys, 2 results) but not by length - CODE / FAMILY / SUB_FAMILY 35, ROLE 15
  METHOD btc_roles_too_long.
    TRY.
        DATA(lt_misfits) = zcl_cd_ops_postarea_layout=>misfits( zif_cd_ops_postarea_types=>gc_purpose-btc_role ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_misfits ) exp = 4 msg = 'Three code parts and the role' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( lt_misfits[ v1 = zif_cd_ops_postarea_types=>gc_field-role v2 = '15' ] ) )
          msg = 'ROLE needs 15' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( lt_misfits[ number = zif_cd_ops_cfg_types=>gc_msg-postarea_too_few ] ) )
          msg = 'Counts fit' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: each purpose has its typed table and app entity (transport recording of the migration)
  METHOD table_and_entity_per_use.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_postarea_layout=>table_of( zif_cd_ops_postarea_types=>gc_purpose-btc_map )
                                            exp = zif_cd_ops_postarea_types=>gc_table-btc_map msg = 'ZCD_OPS_MAPBTM' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_postarea_layout=>table_of( zif_cd_ops_postarea_types=>gc_purpose-reason )
                                            exp = zif_cd_ops_postarea_types=>gc_table-reason msg = 'ZCD_OPS_MAPRSN' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_postarea_layout=>table_of( zif_cd_ops_postarea_types=>gc_purpose-pm_class )
                                            exp = zif_cd_ops_postarea_types=>gc_table-pm_class msg = 'ZCD_OPS_MAPPMC' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_postarea_layout=>table_of( zif_cd_ops_postarea_types=>gc_purpose-btc_role )
                                            exp = zif_cd_ops_postarea_types=>gc_table-btc_role msg = 'ZCD_OPS_MAPBTR' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_postarea_layout=>entity_of( zif_cd_ops_postarea_types=>gc_purpose-btc_role )
                                            exp = zif_cd_ops_postarea_types=>gc_entity-btc_role msg = 'MapBtcRole' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_postarea_layout=>entity_of( zif_cd_ops_postarea_types=>gc_purpose-reason )
                                            exp = zif_cd_ops_postarea_types=>gc_entity-reason msg = 'MapReason' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_postarea_layout=>entity_of( zif_cd_ops_postarea_types=>gc_purpose-pm_class )
                                            exp = zif_cd_ops_postarea_types=>gc_entity-pm_class msg = 'MapMethodClass' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_postarea_layout=>entity_of( zif_cd_ops_postarea_types=>gc_purpose-btc_map )
                                            exp = zif_cd_ops_postarea_types=>gc_entity-btc_map msg = 'MapBtcCode' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Boundary: an unknown purpose has no layout, no table and nothing to report
  METHOD unknown_purpose_empty.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = zcl_cd_ops_postarea_layout=>layout( gc_unknown )-keys msg = 'No keys' ).
        cl_abap_unit_assert=>assert_initial( act = zcl_cd_ops_postarea_layout=>table_of( gc_unknown ) msg = 'No table' ).
        cl_abap_unit_assert=>assert_initial( act = zcl_cd_ops_postarea_layout=>misfits( gc_unknown ) msg = 'No misfit' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
