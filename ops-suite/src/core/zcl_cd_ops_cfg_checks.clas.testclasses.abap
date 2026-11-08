*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_cfg_checks.clas.testclasses.abap
*& Purpose:
*& Domain tests of the field checks used by the configuration apps: DDIC
*& names, plug-in classes, allowed values, time windows, thresholds, rule
*& groups. RTTI reads dictionary metadata only (T000, existing suite
*& classes); does not prove live SAP runtime behavior.
*& ltc_destination: alert destinations are checked by the channel plug-in found
*& through the alert DAO (doubles injected by ZCL_CD_OPS_INJECTOR, no DB read).
*& Modification log:
*& 2026-11-06 | Initial version (written before the class, RAP config apps).
*& 2026-11-07 | ltc_destination: CHANNEL_CLASS / INVALID_DESTINATION (SO23 lists).
*& 2026-11-08 | ltc_posting_areas: configuration check of the customer posting areas (in-memory posting
*&            | areas ZCL_CD_OPS_POSTAREA_MEM, EBS rule groups from a configuration double) - every validation.
*&---------------------------------------------------------------------*
"! Alert configuration from memory: only the channels are read by the checks
CLASS ltd_alert_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_alert_dao.
    DATA mt_channels TYPE zif_cd_ops_types=>tt_alert_channel.
    DATA mt_inserted TYPE zif_cd_ops_types=>tt_alert_log.
ENDCLASS.

CLASS ltd_alert_dao IMPLEMENTATION.
  METHOD zif_cd_ops_alert_dao~get_rules.
    CLEAR rt_rules.
  ENDMETHOD.
  METHOD zif_cd_ops_alert_dao~get_channels.
    rt_channels = mt_channels.
  ENDMETHOD.
  METHOD zif_cd_ops_alert_dao~get_log.
    CLEAR rt_log.
  ENDMETHOD.
  METHOD zif_cd_ops_alert_dao~insert_log.
    INSERT LINES OF it_log INTO TABLE mt_inserted.
  ENDMETHOD.
ENDCLASS.

"! Channel that knows one list only: every other name is reported back
CLASS ltd_channel DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_alert_channel.
    CONSTANTS gc_known TYPE string VALUE `ZCD_RTBSUP`.
    DATA mv_delivered TYPE abap_bool.
ENDCLASS.

CLASS ltd_channel IMPLEMENTATION.
  METHOD zif_cd_ops_alert_channel~deliver.
    mv_delivered = abap_true.
  ENDMETHOD.
  METHOD zif_cd_ops_alert_channel~check_destination.
    DATA lt_invalid TYPE string_table.
    LOOP AT zcl_cd_ops_util=>split_list( iv_destination ) ASSIGNING FIELD-SYMBOL(<lv_name>).
      IF <lv_name> <> gc_known.
        INSERT <lv_name> INTO TABLE lt_invalid.
      ENDIF.
    ENDLOOP.
    rv_invalid = concat_lines_of( table = lt_invalid sep = `,` ).
  ENDMETHOD.
ENDCLASS.

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
        cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_cfg_checks=>is_valid_name( 'zcd_btc_rule' )
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


  " Rule: a plug-in class is accepted only if it implements the payment engine area interface
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


CLASS ltc_destination DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        channel   TYPE zif_cd_ops_types=>ty_channel VALUE 'EMAIL',
        class     TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_TEST_CHANNEL',
        no_class  TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_NOT_THERE',
        known     TYPE zif_cd_ops_types=>ty_alert_dest VALUE 'ZCD_RTBSUP',
        unknown   TYPE string VALUE `ZCD_NOLIST`,
      END OF gc_test.

    METHODS setup.
    METHODS teardown.
    METHODS channel_class_found          FOR TESTING.
    METHODS unknown_channel_blank        FOR TESTING.
    METHODS known_destination_accepted   FOR TESTING.
    METHODS unknown_destination_listed   FOR TESTING.
    METHODS no_channel_class_not_checked FOR TESTING.
ENDCLASS.


CLASS ltc_destination IMPLEMENTATION.

  METHOD setup.
    DATA(lo_dao) = NEW ltd_alert_dao( ).
    lo_dao->mt_channels = VALUE #( ( channel = gc_test-channel class_name = gc_test-class active = abap_true ) ).
    zcl_cd_ops_injector=>inject_alert_dao( lo_dao ).
    zcl_cd_ops_injector=>inject_plugin( iv_class_name = gc_test-class
                                        io_instance   = NEW ltd_channel( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  " Rule: an alert rule's channel ID leads to the plug-in class configured for it (any case)
  METHOD channel_class_found.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_cfg_checks=>channel_class( to_lower( gc_test-channel ) )
                                        exp = gc_test-class
                                        msg = 'Class of the configured channel' ).
  ENDMETHOD.


  " Rule: an unknown channel has no class - nothing to check the destination with
  METHOD unknown_channel_blank.
    cl_abap_unit_assert=>assert_initial( act = zcl_cd_ops_cfg_checks=>channel_class( 'NONE' )
                                         msg = 'Unknown channel gives no class' ).
  ENDMETHOD.


  " Rule: a destination the channel can deliver to passes
  METHOD known_destination_accepted.
    cl_abap_unit_assert=>assert_initial(
      act = zcl_cd_ops_cfg_checks=>invalid_destination( iv_class       = gc_test-class
                                                        iv_destination = gc_test-known )
      msg = 'Known SO23 list accepted' ).
  ENDMETHOD.


  " Rule: names the channel cannot deliver to are returned for message 419
  METHOD unknown_destination_listed.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cd_ops_cfg_checks=>invalid_destination(
              iv_class       = gc_test-class
              iv_destination = CONV #( |{ gc_test-known },{ gc_test-unknown }| ) )
      exp = gc_test-unknown
      msg = 'Unknown list reported' ).
  ENDMETHOD.


  " Rule: a missing or wrong class is the class check's finding, not a destination finding
  METHOD no_channel_class_not_checked.
    cl_abap_unit_assert=>assert_initial(
      act = zcl_cd_ops_cfg_checks=>invalid_destination( iv_class       = gc_test-no_class
                                                        iv_destination = CONV #( gc_test-unknown ) )
      msg = 'No class, no destination finding' ).
  ENDMETHOD.

ENDCLASS.


"! EBS rule assignments: only the rule groups are read by the posting area check
CLASS ltd_ebs_cfg DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_cfg_dao PARTIALLY IMPLEMENTED.
    DATA mt_rules TYPE zif_cd_ebs_types=>tt_rule_cfg.
ENDCLASS.

CLASS ltd_ebs_cfg IMPLEMENTATION.
  METHOD zif_cd_ebs_cfg_dao~get_rules.
    rt_rules = mt_rules.
  ENDMETHOD.
ENDCLASS.


"! Configuration check of the customer posting areas ZRSN / ZPMC / ZBTM / ZBTR: a valid set of
"! entries (in memory, ZCL_CD_OPS_POSTAREA_MEM) plus one invalid entry per scenario
CLASS ltc_posting_areas DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_area,
        rsn TYPE zif_cd_ops_postarea_types=>ty_area VALUE 'ZRSN',
        pmc TYPE zif_cd_ops_postarea_types=>ty_area VALUE 'ZPMC',
        btm TYPE zif_cd_ops_postarea_types=>ty_area VALUE 'ZBTM',
        btr TYPE zif_cd_ops_postarea_types=>ty_area VALUE 'ZBTR',
      END OF gc_area.
    CONSTANTS gc_group TYPE zif_cd_ebs_types=>ty_rule_group VALUE 'W01'.

    TYPES:
      BEGIN OF ty_flags,
        no_reasons      TYPE abap_bool,
        generic_keys    TYPE abap_bool,
        too_long        TYPE abap_bool,
        blank_bank      TYPE abap_bool,
        noc_flag        TYPE abap_bool,
        two_classes     TYPE abap_bool,
        bank_calendar   TYPE abap_bool,
        no_class_entry  TYPE abap_bool,
        class_differs   TYPE abap_bool,
        unknown_class   TYPE abap_bool,
        roles_per_usage TYPE abap_bool,
        scope_form      TYPE abap_bool,
        recon_scheme    TYPE abap_bool,
        rule_group      TYPE abap_bool,
        iso_parts       TYPE abap_bool,
      END OF ty_flags.

    DATA mo_mem TYPE REF TO zcl_cd_ops_postarea_mem.

    METHODS setup.
    METHODS teardown.

    METHODS valid_entries_no_finding     FOR TESTING.
    METHODS empty_area_is_warning        FOR TESTING.
    METHODS generic_key_where_not_read   FOR TESTING.
    METHODS value_longer_than_reader     FOR TESTING.
    METHODS blank_key_needs_value_or_any FOR TESTING.
    METHODS noc_flag_x_or_blank          FOR TESTING.
    METHODS one_class_per_pay_method     FOR TESTING.
    METHODS house_bank_needs_calendar    FOR TESTING.
    METHODS house_bank_needs_class_entry FOR TESTING.
    METHODS one_calendar_per_class       FOR TESTING.
    METHODS lifecycle_class_must_exist   FOR TESTING.
    METHODS role_values_per_usage        FOR TESTING.
    METHODS lifecycle_scope_form         FOR TESTING.
    METHODS recon_scheme_bai2_no_compare FOR TESTING.
    METHODS rule_group_needs_active_rule FOR TESTING.
    METHODS iso_code_needs_its_parts     FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS check
      RETURNING
        VALUE(rt_messages) TYPE zif_cd_ops_postarea_types=>tt_check_message.
    "! The message of an entry (area, key text, message number) is in the result
    METHODS assert_message
      IMPORTING
        it_messages TYPE zif_cd_ops_postarea_types=>tt_check_message
        iv_area     TYPE zif_cd_ops_postarea_types=>ty_area
        iv_entry    TYPE string
        iv_number   TYPE zif_cd_ops_cfg_types=>ty_msg_number
        iv_msg      TYPE string.
ENDCLASS.


CLASS ltc_posting_areas IMPLEMENTATION.

  METHOD setup.
    DATA(lo_ebs) = NEW ltd_ebs_cfg( ).
    INSERT VALUE #( rule_group = gc_group active = abap_true ) INTO TABLE lo_ebs->mt_rules.
    zcl_cd_ebs_injector=>inject_cfg_dao( lo_ebs ).
    zcl_cd_ops_injector=>inject_params( NEW zcl_cd_ops_param_seed( )->params( ) ).
    mo_mem = NEW #( ).
    zcl_cd_ops_postarea_injector=>inject_dao( mo_mem ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_postarea_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    zcl_cd_ebs_injector=>reset( ).
    CLEAR mo_mem.
  ENDMETHOD.


  METHOD configure_scenario.
    " Valid set (seed rows of config/postarea_*.csv and config/hck_seed.md 8a / 8e / 10b)
    IF is_flags-no_reasons = abap_false.
      mo_mem->add( iv_area = gc_area-rsn iv_keys = `R01` iv_results = `R1/` ).
      mo_mem->add( iv_area = gc_area-rsn iv_keys = `C01` iv_results = `/X` ).
      mo_mem->add( iv_area = gc_area-rsn iv_keys = `*` iv_results = `RZ/` ).
    ENDIF.
    mo_mem->add( iv_area = gc_area-pmc iv_keys = `D/E/*` iv_results = `WIR/VALUE_DATE/` ).
    mo_mem->add( iv_area = gc_area-pmc iv_keys = `D/A/*` iv_results = `ACH/VALUE_DATE/` ).
    mo_mem->add( iv_area = gc_area-pmc iv_keys = `D/G/*` iv_results = `ACH/VALUE_DATE/` ).
    mo_mem->add( iv_area = gc_area-pmc iv_keys = `D/X/*` iv_results = `ACI/VALUE_DATE/` ).
    mo_mem->add( iv_area = gc_area-pmc iv_keys = `D/X/BARC1` iv_results = `ACI//GB` ).
    mo_mem->add( iv_area = gc_area-btm iv_keys = `BAI2/495///*/*` iv_results = `W01//D/WIRE//AUTO_POST/` ).
    mo_mem->add( iv_area = gc_area-btm iv_keys = `ISO/PMNT/ICDT/*/JPMC/D` iv_results = `W02/W01/D/WIRE//AUTO_POST/` ).
    mo_mem->add( iv_area = gc_area-btm iv_keys = `PRTRY/NOC///*/*` iv_results = `N01//*/ACH//BLOCK/` ).
    mo_mem->add( iv_area = gc_area-btr iv_keys = `LIFECYCLE/DWIR/BAI2/495` iv_results = `ORIGINAL/` ).
    mo_mem->add( iv_area = gc_area-btr iv_keys = `LIFECYCLE/DACH/BAI2/168` iv_results = `RETURNED/X` ).
    mo_mem->add( iv_area = gc_area-btr iv_keys = `LIFECYCLE/DACI/ISO/PMNT/ICDT/ARET` iv_results = `RETURNED/X` ).
    mo_mem->add( iv_area = gc_area-btr iv_keys = `RECON/DISB_WIRE/BAI2/495` iv_results = `LEG` ).
    " One invalid entry per scenario
    IF is_flags-generic_keys = abap_true.
      mo_mem->add( iv_area = gc_area-btm iv_keys = `*/196///*/*` iv_results = `W01//D/WIRE//AUTO_POST/` ).
      mo_mem->add( iv_area = gc_area-pmc iv_keys = `*/E/*` iv_results = `WIR/VALUE_DATE/` ).
      mo_mem->add( iv_area = gc_area-btr iv_keys = `LIFECYCLE/DWIR/BAI2/*` iv_results = `ORIGINAL/` ).
    ENDIF.
    IF is_flags-too_long = abap_true.
      mo_mem->add( iv_area = gc_area-rsn iv_keys = `R02` iv_results = `ABCD/` ).
    ENDIF.
    IF is_flags-blank_bank = abap_true.
      mo_mem->add( iv_area = gc_area-btm iv_keys = `BAI2/466///` iv_results = `W01//D/ACH//AUTO_POST/` ).
    ENDIF.
    IF is_flags-noc_flag = abap_true.
      mo_mem->add( iv_area = gc_area-rsn iv_keys = `C02` iv_results = `/Y` ).
    ENDIF.
    IF is_flags-two_classes = abap_true.
      mo_mem->add( iv_area = gc_area-pmc iv_keys = `D/E/BARC1` iv_results = `ACI//GB` ).
    ENDIF.
    IF is_flags-bank_calendar = abap_true.
      mo_mem->add( iv_area = gc_area-pmc iv_keys = `D/X/COMM1` iv_results = `ACI/VALUE_DATE/` ).
    ENDIF.
    IF is_flags-no_class_entry = abap_true.
      mo_mem->add( iv_area = gc_area-pmc iv_keys = `D/Q/BARC1` iv_results = `ACI//GB` ).
    ENDIF.
    IF is_flags-class_differs = abap_true.
      mo_mem->add( iv_area = gc_area-pmc iv_keys = `D/H/*` iv_results = `ACH/ISSUE_DATE/` ).
    ENDIF.
    IF is_flags-unknown_class = abap_true.
      mo_mem->add( iv_area = gc_area-btr iv_keys = `LIFECYCLE/DCHQ/BAI2/581` iv_results = `CASHED/R` ).
    ENDIF.
    IF is_flags-roles_per_usage = abap_true.
      mo_mem->add( iv_area = gc_area-btr iv_keys = `LIFECYCLE/DACH/BAI2/466` iv_results = `LEG/` ).
      mo_mem->add( iv_area = gc_area-btr iv_keys = `LIFECYCLE/DACH/BAI2/166` iv_results = `/` ).
      mo_mem->add( iv_area = gc_area-btr iv_keys = `RECON/DISB_ACH/BAI2/466` iv_results = `ORIGINAL` ).
    ENDIF.
    IF is_flags-scope_form = abap_true.
      mo_mem->add( iv_area = gc_area-btr iv_keys = `LIFECYCLE/XACH/BAI2/466` iv_results = `ORIGINAL/` ).
    ENDIF.
    IF is_flags-recon_scheme = abap_true.
      mo_mem->add( iv_area = gc_area-btr iv_keys = `RECON/DISB_ACH/PRTRY/X1` iv_results = `LEG/X` ).
    ENDIF.
    IF is_flags-rule_group = abap_true.
      mo_mem->add( iv_area = gc_area-btm iv_keys = `BAI2/475///*/*` iv_results = `K01/G99/D/CHECK//AUTO_POST/` ).
    ENDIF.
    IF is_flags-iso_parts = abap_true.
      mo_mem->add( iv_area = gc_area-btm iv_keys = `ISO/PMNT///*/C` iv_results = `W01//C/WIRE//AUTO_POST/` ).
      mo_mem->add( iv_area = gc_area-btm iv_keys = `BAI2/142/RCDT//*/*` iv_results = `W01//C/ACH//AUTO_POST/` ).
    ENDIF.
  ENDMETHOD.


  METHOD check.
    rt_messages = zcl_cd_ops_cfg_checks=>check_posting_areas( ).
  ENDMETHOD.


  METHOD assert_message.
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( line_exists( it_messages[ area = iv_area entry = iv_entry number = iv_number ] ) )
      msg = iv_msg ).
  ENDMETHOD.


  " Rule: the delivered set (incl. ZRSN '*', ZPMC house-bank calendar, ZBTM bank and family rows)
  " gives no finding
  METHOD valid_entries_no_finding.
    TRY.
        configure_scenario( VALUE #( ) ).
        cl_abap_unit_assert=>assert_initial( act = check( ) msg = 'A valid configuration has no finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Boundary: a posting area without entries maps nothing - one warning, no entry key
  METHOD empty_area_is_warning.
    TRY.
        configure_scenario( VALUE #( no_reasons = abap_true ) ).
        DATA(lt_messages) = check( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_messages ) exp = 1 msg = 'One message' ).
        cl_abap_unit_assert=>assert_equals( act = lt_messages[ 1 ]-number exp = zif_cd_ops_cfg_types=>gc_msg-area_empty
                                            msg = 'Message 432' ).
        cl_abap_unit_assert=>assert_equals( act = lt_messages[ 1 ]-severity exp = zif_cd_ops_types=>gc_severity-warning
                                            msg = 'A warning' ).
        cl_abap_unit_assert=>assert_equals( act = lt_messages[ 1 ]-area exp = gc_area-rsn msg = 'Of ZRSN' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: '*' only where the reader applies it (ZBTM scheme, ZPMC flow, ZBTR code: refused)
  METHOD generic_key_where_not_read.
    TRY.
        configure_scenario( VALUE #( generic_keys = abap_true ) ).
        DATA(lt_messages) = check( ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btm iv_entry = `*/196///*/*`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-generic_key iv_msg = 'Scheme * refused' ).
        assert_message( it_messages = lt_messages iv_area = gc_area-pmc iv_entry = `*/E/*`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-generic_key iv_msg = 'Flow * refused' ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btr iv_entry = `LIFECYCLE/DWIR/BAI2/*`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-generic_key iv_msg = 'Code * refused' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_messages ) exp = 3 msg = 'Nothing else (ZRSN * is fine)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a value longer than its reader takes is a finding, never truncated
  METHOD value_longer_than_reader.
    TRY.
        configure_scenario( VALUE #( too_long = abap_true ) ).
        DATA(lt_messages) = check( ).
        assert_message( it_messages = lt_messages iv_area = gc_area-rsn iv_entry = `R02`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-value_too_long iv_msg = 'FICA_REASON has 3 characters' ).
        cl_abap_unit_assert=>assert_equals( act = lt_messages[ 1 ]-v2 exp = zif_cd_ops_postarea_types=>gc_field-fica_reason
                                            msg = 'Names the field' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: bank key and flow of ZBTM are a value or '*' (blank no longer means 'every bank')
  METHOD blank_key_needs_value_or_any.
    TRY.
        configure_scenario( VALUE #( blank_bank = abap_true ) ).
        DATA(lt_messages) = check( ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btm iv_entry = `BAI2/466`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-key_blank iv_msg = 'Blank bank key / flow' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_messages ) exp = 2 msg = 'Bank key and flow' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the NOC flag of ZRSN is X or blank
  METHOD noc_flag_x_or_blank.
    TRY.
        configure_scenario( VALUE #( noc_flag = abap_true ) ).
        assert_message( it_messages = check( ) iv_area = gc_area-rsn iv_entry = `C02`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-value_invalid iv_msg = 'NOC flag Y refused' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a payment method maps to exactly one class - a house bank may not name another class
  METHOD one_class_per_pay_method.
    TRY.
        configure_scenario( VALUE #( two_classes = abap_true ) ).
        assert_message( it_messages = check( ) iv_area = gc_area-pmc iv_entry = `D/E/BARC1`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-method_two_classes iv_msg = 'E in WIR and ACI' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a house-bank entry overrides the calendar only - calendar present, no ageing basis
  METHOD house_bank_needs_calendar.
    TRY.
        configure_scenario( VALUE #( bank_calendar = abap_true ) ).
        DATA(lt_messages) = check( ).
        assert_message( it_messages = lt_messages iv_area = gc_area-pmc iv_entry = `D/X/COMM1`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-required iv_msg = 'Calendar required' ).
        assert_message( it_messages = lt_messages iv_area = gc_area-pmc iv_entry = `D/X/COMM1`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-must_be_blank iv_msg = 'No ageing basis' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a house-bank entry needs the class entry ('*') of its payment method
  METHOD house_bank_needs_class_entry.
    TRY.
        configure_scenario( VALUE #( no_class_entry = abap_true ) ).
        assert_message( it_messages = check( ) iv_area = gc_area-pmc iv_entry = `D/Q/BARC1`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-class_entry_none iv_msg = 'No D/Q/* entry' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the payment methods of one class share ageing basis and calendar
  METHOD one_calendar_per_class.
    TRY.
        configure_scenario( VALUE #( class_differs = abap_true ) ).
        assert_message( it_messages = check( ) iv_area = gc_area-pmc iv_entry = `D/H/*`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-entries_differ iv_msg = 'ACH ageing basis differs' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the method class of a LIFECYCLE scope exists in ZPMC for the flow
  METHOD lifecycle_class_must_exist.
    TRY.
        configure_scenario( VALUE #( unknown_class = abap_true ) ).
        assert_message( it_messages = check( ) iv_area = gc_area-btr iv_entry = `LIFECYCLE/DCHQ/BAI2/581`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-class_unknown iv_msg = 'CHQ is no class of D' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: LIFECYCLE needs a role and never a reconciliation role; RECON only the seven roles
  METHOD role_values_per_usage.
    TRY.
        configure_scenario( VALUE #( roles_per_usage = abap_true ) ).
        DATA(lt_messages) = check( ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btr iv_entry = `LIFECYCLE/DACH/BAI2/466`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-value_reserved iv_msg = 'LEG is a RECON role' ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btr iv_entry = `LIFECYCLE/DACH/BAI2/166`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-required iv_msg = 'Lifecycle role required' ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btr iv_entry = `RECON/DISB_ACH/BAI2/466`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-value_invalid iv_msg = 'ORIGINAL is no RECON role' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a LIFECYCLE scope is flow D / C + method class
  METHOD lifecycle_scope_form.
    TRY.
        configure_scenario( VALUE #( scope_form = abap_true ) ).
        assert_message( it_messages = check( ) iv_area = gc_area-btr iv_entry = `LIFECYCLE/XACH/BAI2/466`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-form_invalid iv_msg = 'XACH has no flow' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: RECON entries are BAI2 type codes and compare no amount
  METHOD recon_scheme_bai2_no_compare.
    TRY.
        configure_scenario( VALUE #( recon_scheme = abap_true ) ).
        DATA(lt_messages) = check( ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btr iv_entry = `RECON/DISB_ACH/PRTRY/X1`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-value_invalid iv_msg = 'RECON scheme BAI2 only' ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btr iv_entry = `RECON/DISB_ACH/PRTRY/X1`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-must_be_blank iv_msg = 'RECON compares nothing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a ZBTM entry that is not BLOCK needs a rule group (blank = category) in ZCD_BTC_RULE
  METHOD rule_group_needs_active_rule.
    TRY.
        configure_scenario( VALUE #( rule_group = abap_true ) ).
        DATA(lt_messages) = check( ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btm iv_entry = `BAI2/475///*/*`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-rule_group_empty iv_msg = 'G99 has no rule' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_messages ) exp = 1
                                            msg = 'W02 uses group W01; BLOCK (NOC) needs none' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an ISO code needs family and sub-family; other schemes leave both blank
  METHOD iso_code_needs_its_parts.
    TRY.
        configure_scenario( VALUE #( iso_parts = abap_true ) ).
        DATA(lt_messages) = check( ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btm iv_entry = `ISO/PMNT///*/C`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-required iv_msg = 'ISO family required' ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btm iv_entry = `BAI2/142/RCDT//*/*`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-must_be_blank iv_msg = 'BAI2 has no family' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
