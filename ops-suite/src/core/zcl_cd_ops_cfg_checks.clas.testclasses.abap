*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_cfg_checks.clas.testclasses.abap
*& Purpose:
*& Domain tests of the field checks used by the configuration apps: DDIC
*& names, plug-in classes, allowed values, time windows, thresholds, rule
*& groups. RTTI reads dictionary metadata only (T000, existing suite
*& classes); does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (written before the class, RAP config apps).
*&---------------------------------------------------------------------*
CLASS ltc_checks DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        table      TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'T000',
        field      TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'MANDT',
        no_table   TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'ZZZ_CD_NOT_THERE',
        no_field   TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'ZZ_NOT_A_FIELD',
        injected   TYPE zif_cd_ops_cfg_types=>ty_name VALUE `T000 WHERE 1 = 1`,
        channel    TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'ZCL_CD_OPS_CHN_EMAIL',
        util       TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'ZCL_CD_OPS_UTIL',
        no_class   TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'ZCL_CD_NOT_THERE',
        channel_if TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'ZIF_CD_OPS_ALERT_CHANNEL',
        severities TYPE zif_cd_ops_cfg_types=>ty_value_list VALUE `B,E,W,I`,
        group1     TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'BAI166D',
        group2     TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'BAI168D',
      END OF gc_test.

    METHODS ddic_name_accepts_lower_case  FOR TESTING.
    METHODS ddic_name_rejects_injection   FOR TESTING.
    METHODS existing_table_found          FOR TESTING.
    METHODS unknown_table_rejected        FOR TESTING.
    METHODS existing_field_found          FOR TESTING.
    METHODS unknown_field_rejected        FOR TESTING.
    METHODS class_with_interface_accepted FOR TESTING.
    METHODS class_without_iface_rejected  FOR TESTING.
    METHODS unknown_class_rejected        FOR TESTING.
    METHODS value_in_list_accepted        FOR TESTING.
    METHODS value_outside_list_rejected   FOR TESTING.
    METHODS blank_needs_blank_entry       FOR TESTING.
    METHODS half_window_rejected          FOR TESTING.
    METHODS empty_window_accepted         FOR TESTING.
    METHODS amber_below_red_when_higher   FOR TESTING.
    METHODS amber_above_red_when_lower    FOR TESTING.
    METHODS missing_rule_group_listed     FOR TESTING.
ENDCLASS.


CLASS ltc_checks IMPLEMENTATION.

  " Rule: names are compared in upper case, as the dictionary stores them
  METHOD ddic_name_accepts_lower_case.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_cfg_checks=>is_valid_name( 'zcd_btc_map' )
                                          msg = 'A lower-case DDIC name is valid' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: anything but letters, digits, _ and / is refused before the dictionary is asked
  METHOD ddic_name_rejects_injection.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_cd_ops_cfg_checks=>is_valid_name( gc_test-injected )
                                           msg = 'Blanks and operators are not part of a DDIC name' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD existing_table_found.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_cfg_checks=>table_exists( gc_test-table )
                                          msg = 'T000 exists' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD unknown_table_rejected.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_cd_ops_cfg_checks=>table_exists( gc_test-no_table )
                                           msg = 'An unknown table must be rejected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD existing_field_found.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_cfg_checks=>field_exists( iv_table = gc_test-table
                                                                                      iv_field = gc_test-field )
                                          msg = 'T000-MANDT exists' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD unknown_field_rejected.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_cd_ops_cfg_checks=>field_exists( iv_table = gc_test-table
                                                                                       iv_field = gc_test-no_field )
                                           msg = 'An unknown field must be rejected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a plug-in class is accepted only if it implements the module interface
  METHOD class_with_interface_accepted.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_cfg_checks=>implements( iv_class     = gc_test-channel
                                                                                    iv_interface = gc_test-channel_if )
                                          msg = 'The e-mail channel implements the channel interface' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD class_without_iface_rejected.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_cd_ops_cfg_checks=>implements( iv_class     = gc_test-util
                                                                                     iv_interface = gc_test-channel_if )
                                           msg = 'A class without the interface must be rejected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD unknown_class_rejected.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_cd_ops_cfg_checks=>implements( iv_class     = gc_test-no_class
                                                                                     iv_interface = gc_test-channel_if )
                                           msg = 'An unknown class must be rejected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD value_in_list_accepted.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_cfg_checks=>in_list( iv_value = 'W'
                                                                                 iv_list  = gc_test-severities )
                                          msg = 'W is an allowed severity' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD value_outside_list_rejected.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_cd_ops_cfg_checks=>in_list( iv_value = 'X'
                                                                                  iv_list  = gc_test-severities )
                                           msg = 'X is not an allowed severity' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: blank is allowed only where the list has an empty entry (leading comma)
  METHOD blank_needs_blank_entry.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_cd_ops_cfg_checks=>in_list( iv_value = space
                                                                                  iv_list  = gc_test-severities )
                                           msg = 'Blank is not allowed without an empty entry' ).
        cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_cfg_checks=>in_list( iv_value = space
                                                                                 iv_list  = `,` && gc_test-severities )
                                          msg = 'Blank is allowed with an empty entry' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a time window is either complete or empty (crossing midnight is allowed)
  METHOD half_window_rejected.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_cd_ops_cfg_checks=>window_complete( iv_from = '220000'
                                                                                          iv_to   = '000000' )
                                           msg = 'Only a start time is incomplete' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD empty_window_accepted.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_cfg_checks=>window_complete( iv_from = '000000'
                                                                                         iv_to   = '000000' )
                                          msg = 'No window at all is valid' ).
        cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_cfg_checks=>window_complete( iv_from = '220000'
                                                                                         iv_to   = '060000' )
                                          msg = 'A window across midnight is valid' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: higher is worse -> amber below red; lower is worse -> amber above red
  METHOD amber_below_red_when_higher.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_cfg_checks=>thresholds_ordered( iv_amber           = 5
                                                                                            iv_red             = 10
                                                                                            iv_higher_is_worse = abap_true )
                                          msg = 'Amber 5 / red 10 is ordered when higher is worse' ).
        cl_abap_unit_assert=>assert_false( act = zcl_cd_ops_cfg_checks=>thresholds_ordered( iv_amber           = 10
                                                                                             iv_red             = 5
                                                                                             iv_higher_is_worse = abap_true )
                                           msg = 'Amber 10 / red 5 is reversed when higher is worse' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD amber_above_red_when_lower.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_cfg_checks=>thresholds_ordered( iv_amber           = 10
                                                                                            iv_red             = 5
                                                                                            iv_higher_is_worse = abap_false )
                                          msg = 'Amber 10 / red 5 is ordered when lower is worse' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an active BTC map row needs a rule group with at least one active rule
  METHOD missing_rule_group_listed.
    DATA lt_needed    TYPE zif_cd_ops_cfg_types=>ty_names.
    DATA lt_available TYPE zif_cd_ops_cfg_types=>ty_names.
    DATA lt_expected  TYPE zif_cd_ops_cfg_types=>ty_names.
    INSERT gc_test-group1 INTO TABLE lt_needed.
    INSERT gc_test-group2 INTO TABLE lt_needed.
    INSERT gc_test-group1 INTO TABLE lt_available.
    INSERT gc_test-group2 INTO TABLE lt_expected.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_cfg_checks=>missing_names( it_needed    = lt_needed
                                                                                         it_available = lt_available )
                                            exp = lt_expected
                                            msg = 'Only the group without an active rule is listed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
