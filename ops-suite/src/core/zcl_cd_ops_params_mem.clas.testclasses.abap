*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_params_mem.clas.testclasses.abap
*& Purpose:
*& Domain tests of the shared parameter fake: the read semantics of
*& ZCL_CD_OPS_STORE (exact name, CHAR 255 value read condensed, blank or
*& missing = default, get_range I / EQ rows) - the store's OSQL tests assert the
*& same cases against ZCD_OPS_PARAM. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (shared parameter fake).
*&---------------------------------------------------------------------*
CLASS ltc_params_mem DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        name    TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_WATCH_PE_AREAS',
        lower   TYPE zif_cd_ops_types=>ty_param_name VALUE 'hck_watch_pe_areas',
        default TYPE string VALUE `DEFAULT`,
        value   TYPE string VALUE `EBS`,
      END OF gc.
    DATA mo_cut TYPE REF TO zcl_cd_ops_params_mem.
    DATA mo_params TYPE REF TO zif_cd_ops_params.

    METHODS setup.
    METHODS missing_param_gives_default  FOR TESTING.
    METHODS blank_param_gives_default    FOR TESTING.
    METHODS param_value_is_condensed     FOR TESTING.
    METHODS name_is_exact_key            FOR TESTING.
    METHODS value_cut_at_table_width     FOR TESTING.
    METHODS set_overwrites_value         FOR TESTING.
    METHODS removed_param_gives_default  FOR TESTING.
    METHODS set_all_maintains_rows       FOR TESTING.
    METHODS param_range_from_list        FOR TESTING.
    METHODS blank_param_empty_range      FOR TESTING.
    METHODS refresh_is_counted           FOR TESTING.
ENDCLASS.


CLASS ltc_params_mem IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( ).
    mo_params = mo_cut.
  ENDMETHOD.


  " Rule: a parameter that is not maintained returns the caller's default
  METHOD missing_param_gives_default.
    cl_abap_unit_assert=>assert_equals( act = mo_params->get_param( iv_name = gc-name iv_default = gc-default )
                                        exp = gc-default
                                        msg = 'Missing parameter must return the default' ).
  ENDMETHOD.


  " Rule: a blank value is the default (as ZCL_CD_OPS_STORE)
  METHOD blank_param_gives_default.
    mo_cut->set( iv_name = gc-name iv_value = `   ` ).
    cl_abap_unit_assert=>assert_equals( act = mo_params->get_param( iv_name = gc-name iv_default = gc-default )
                                        exp = gc-default
                                        msg = 'A blank parameter must return the default' ).
  ENDMETHOD.


  " Rule: the value is read condensed (leading blanks removed, inner blanks collapsed)
  METHOD param_value_is_condensed.
    mo_cut->set( iv_name = gc-name iv_value = `  EBS,   FMON ` ).
    cl_abap_unit_assert=>assert_equals( act = mo_params->get_param( iv_name = gc-name iv_default = gc-default )
                                        exp = `EBS, FMON`
                                        msg = 'The value must be condensed' ).
  ENDMETHOD.


  " Rule: the name is the exact key (PARAM_NAME is stored upper case; no case folding)
  METHOD name_is_exact_key.
    mo_cut->set( iv_name = gc-name iv_value = gc-value ).
    cl_abap_unit_assert=>assert_equals( act = mo_params->get_param( iv_name = gc-lower iv_default = gc-default )
                                        exp = gc-default
                                        msg = 'A name in other case is another parameter' ).
  ENDMETHOD.


  " Rule: the value is kept as the table keeps it (CHAR 255)
  METHOD value_cut_at_table_width.
    CONSTANTS lc_width TYPE i VALUE 255.
    DATA(lv_long) = repeat( val = `A` occ = lc_width + 5 ).
    mo_cut->set( iv_name = gc-name iv_value = lv_long ).
    cl_abap_unit_assert=>assert_equals( act = strlen( mo_params->get_param( gc-name ) )
                                        exp = lc_width
                                        msg = 'The value must be cut at 255 characters' ).
  ENDMETHOD.


  METHOD set_overwrites_value.
    mo_cut->set( iv_name = gc-name iv_value = gc-default )->set( iv_name = gc-name iv_value = gc-value ).
    cl_abap_unit_assert=>assert_equals( act = mo_params->get_param( gc-name )
                                        exp = gc-value
                                        msg = 'The last value set must win' ).
  ENDMETHOD.


  METHOD removed_param_gives_default.
    mo_cut->set( iv_name = gc-name iv_value = gc-value ).
    mo_cut->remove( gc-name ).
    cl_abap_unit_assert=>assert_equals( act = mo_params->get_param( iv_name = gc-name iv_default = gc-default )
                                        exp = gc-default
                                        msg = 'A removed parameter must return the default' ).
  ENDMETHOD.


  METHOD set_all_maintains_rows.
    DATA lt_params TYPE zif_cd_ops_types=>tt_kv.
    INSERT VALUE #( name = gc-name value = gc-value ) INTO TABLE lt_params.
    mo_cut->set_all( lt_params ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_all( )
                                        exp = lt_params
                                        msg = 'Every row set must be maintained' ).
  ENDMETHOD.


  " Rule: get_range gives one I / EQ row per list entry, blank entries dropped
  METHOD param_range_from_list.
    DATA lt_exp TYPE zif_cd_ops_types=>tt_param_range.
    mo_cut->set( iv_name = gc-name iv_value = `EBS;;FMON` ).
    INSERT VALUE #( sign = zif_cd_ops_types=>gc_range-sign_include option = zif_cd_ops_types=>gc_range-option_equal
                    low = zif_cd_ops_types=>gc_pe_area-ebs ) INTO TABLE lt_exp.
    INSERT VALUE #( sign = zif_cd_ops_types=>gc_range-sign_include option = zif_cd_ops_types=>gc_range-option_equal
                    low = zif_cd_ops_types=>gc_pe_area-file_monitor ) INTO TABLE lt_exp.
    cl_abap_unit_assert=>assert_equals( act = mo_params->get_range( gc-name )
                                        exp = lt_exp
                                        msg = 'One I / EQ row per entry' ).
  ENDMETHOD.


  " Rule: an unmaintained or blank parameter is an empty range ("not configured")
  METHOD blank_param_empty_range.
    mo_cut->set( iv_name = gc-name iv_value = ` ` ).
    cl_abap_unit_assert=>assert_initial( act = mo_params->get_range( gc-name )
                                         msg = 'A blank parameter must give no range row' ).
  ENDMETHOD.


  METHOD refresh_is_counted.
    mo_params->refresh_params( ).
    mo_params->refresh_params( ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->refresh_count( )
                                        exp = 2
                                        msg = 'Every refresh_params call must be counted' ).
  ENDMETHOD.

ENDCLASS.
