*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cfg_checks.clas.testclasses.abap
*& Purpose:
*& Domain tests of the generic field checks of the configuration apps: DDIC
*& names, plug-in classes, allowed values, time windows, missing names.
*& RTTI reads dictionary metadata only (T000, existing framework classes);
*& does not prove live SAP runtime behavior.
*& ltc_destination: alert destinations are checked by the channel plug-in found
*& through the alert DAO (doubles injected by ZCL_CA_OPS_INJECTOR, no DB read).
*& Modification log:
*& 2026-11-06 | Initial version (written before the class, RAP config apps).
*& 2026-11-07 | ltc_destination: CHANNEL_CLASS / INVALID_DESTINATION (SO23 lists).
*& 2026-11-10 | Moved from ZCL_CD_OPS_CFG_CHECKS to the reusable framework ZCA_OPS (test include; generic
*&            | checks; threshold order and posting areas stay with the consumer's checks).
*& 2026-11-10 | LTC_TEMPLATE_CHECK: e-mail template ID of a rule / channel (syntax, existence through the
*&            | injected renderer double LTD_MAIL_TEMPLATE).
*& 2026-11-10 | LTC_CONTROL_CHECK: owner / backup user (double LTD_USERS), team (parameter CONTROL_TEAMS of the
*&            | in-memory parameter store), runbook link (control register of the daily review).
*& 2026-11-11 | LTC_RESPONSE_CHECK: runbook link of an active row, correlation key fields and window.
*& 2026-11-11 | LTC_LINK_REF: TABLE-FIELD references of the link registry conditions (T000 metadata).
*&---------------------------------------------------------------------*
"! Alert configuration from memory: only the channels are read by the checks
CLASS ltd_alert_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_alert_dao.
    DATA mt_channels TYPE zif_ca_ops_types=>tt_alert_channel.
    DATA mt_inserted TYPE zif_ca_ops_types=>tt_alert_log.
ENDCLASS.

CLASS ltd_alert_dao IMPLEMENTATION.
  METHOD zif_ca_ops_alert_dao~get_rules.
    CLEAR rt_rules.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_dao~get_channels.
    rt_channels = mt_channels.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_dao~get_log.
    CLEAR rt_log.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_dao~insert_log.
    INSERT LINES OF it_log INTO TABLE mt_inserted.
  ENDMETHOD.
ENDCLASS.

"! Channel that knows one list only: every other name is reported back
CLASS ltd_channel DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_alert_channel.
    CONSTANTS gc_known TYPE string VALUE `ZT_LIST`.
    DATA mv_delivered TYPE abap_bool.
ENDCLASS.

CLASS ltd_channel IMPLEMENTATION.
  METHOD zif_ca_ops_alert_channel~deliver.
    mv_delivered = abap_true.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_channel~check_destination.
    DATA lt_invalid TYPE string_table.
    LOOP AT zcl_ca_ops_util=>split_list( iv_destination ) ASSIGNING FIELD-SYMBOL(<lv_name>).
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
        table      TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'T000',
        field      TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'MANDT',
        no_table   TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'ZZZ_CA_NOT_THERE',
        no_field   TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'ZZ_NOT_A_FIELD',
        injected   TYPE zif_ca_ops_cfg_types=>ty_name VALUE `T000 WHERE 1 = 1`,
        channel    TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'ZCL_CA_OPS_CHN_EMAIL',
        util       TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'ZCL_CA_OPS_UTIL',
        no_class   TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'ZCL_CA_NOT_THERE',
        channel_if TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'ZIF_CA_OPS_ALERT_CHANNEL',
        severities TYPE zif_ca_ops_cfg_types=>ty_value_list VALUE `B,E,W,I`,
        group1     TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'GROUP_A',
        group2     TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'GROUP_B',
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
    METHODS missing_rule_group_listed     FOR TESTING.
ENDCLASS.


CLASS ltc_checks IMPLEMENTATION.

  " Rule: names are compared in upper case, as the dictionary stores them
  METHOD ddic_name_accepts_lower_case.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>is_valid_name( 'zt_config' )
                                          msg = 'A lower-case DDIC name is valid' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: anything but letters, digits, _ and / is refused before the dictionary is asked
  METHOD ddic_name_rejects_injection.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>is_valid_name( gc_test-injected )
                                           msg = 'Blanks and operators are not part of a DDIC name' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD existing_table_found.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>table_exists( gc_test-table )
                                          msg = 'T000 exists' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD unknown_table_rejected.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>table_exists( gc_test-no_table )
                                           msg = 'An unknown table must be rejected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD existing_field_found.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>field_exists( iv_table = gc_test-table
                                                                                      iv_field = gc_test-field )
                                          msg = 'T000-MANDT exists' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD unknown_field_rejected.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>field_exists( iv_table = gc_test-table
                                                                                       iv_field = gc_test-no_field )
                                           msg = 'An unknown field must be rejected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a plug-in class is accepted only if it implements the area interface
  METHOD class_with_interface_accepted.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>implements( iv_class     = gc_test-channel
                                                                                    iv_interface = gc_test-channel_if )
                                          msg = 'The e-mail channel implements the channel interface' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD class_without_iface_rejected.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>implements( iv_class     = gc_test-util
                                                                                     iv_interface = gc_test-channel_if )
                                           msg = 'A class without the interface must be rejected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD unknown_class_rejected.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>implements( iv_class     = gc_test-no_class
                                                                                     iv_interface = gc_test-channel_if )
                                           msg = 'An unknown class must be rejected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD value_in_list_accepted.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>in_list( iv_value = 'W'
                                                                                 iv_list  = gc_test-severities )
                                          msg = 'W is an allowed severity' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD value_outside_list_rejected.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>in_list( iv_value = 'X'
                                                                                  iv_list  = gc_test-severities )
                                           msg = 'X is not an allowed severity' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: blank is allowed only where the list has an empty entry (leading comma)
  METHOD blank_needs_blank_entry.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>in_list( iv_value = space
                                                                                  iv_list  = gc_test-severities )
                                           msg = 'Blank is not allowed without an empty entry' ).
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>in_list( iv_value = space
                                                                                 iv_list  = `,` && gc_test-severities )
                                          msg = 'Blank is allowed with an empty entry' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a time window is either complete or empty (crossing midnight is allowed)
  METHOD half_window_rejected.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>window_complete( iv_from = '220000'
                                                                                          iv_to   = '000000' )
                                           msg = 'Only a start time is incomplete' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD empty_window_accepted.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>window_complete( iv_from = '000000'
                                                                                         iv_to   = '000000' )
                                          msg = 'No window at all is valid' ).
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>window_complete( iv_from = '220000'
                                                                                         iv_to   = '060000' )
                                          msg = 'A window across midnight is valid' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: names needed but not available are listed once
  METHOD missing_rule_group_listed.
    DATA lt_needed    TYPE zif_ca_ops_cfg_types=>ty_names.
    DATA lt_available TYPE zif_ca_ops_cfg_types=>ty_names.
    DATA lt_expected  TYPE zif_ca_ops_cfg_types=>ty_names.
    INSERT gc_test-group1 INTO TABLE lt_needed.
    INSERT gc_test-group2 INTO TABLE lt_needed.
    INSERT gc_test-group1 INTO TABLE lt_available.
    INSERT gc_test-group2 INTO TABLE lt_expected.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_cfg_checks=>missing_names( it_needed    = lt_needed
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
        channel   TYPE zif_ca_ops_types=>ty_channel VALUE 'EMAIL',
        class     TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_CA_TEST_CHANNEL',
        no_class  TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_CA_NOT_THERE',
        known     TYPE zif_ca_ops_types=>ty_alert_dest VALUE 'ZT_LIST_KNOWN',
        unknown   TYPE string VALUE `ZT_LIST_UNKNOWN`,
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
    zcl_ca_ops_injector=>inject_alert_dao( lo_dao ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = gc_test-class
                                        io_instance   = NEW ltd_channel( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  " Rule: an alert rule's channel ID leads to the plug-in class configured for it (any case)
  METHOD channel_class_found.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_cfg_checks=>channel_class( to_lower( gc_test-channel ) )
                                        exp = gc_test-class
                                        msg = 'Class of the configured channel' ).
  ENDMETHOD.


  " Rule: an unknown channel has no class - nothing to check the destination with
  METHOD unknown_channel_blank.
    cl_abap_unit_assert=>assert_initial( act = zcl_ca_ops_cfg_checks=>channel_class( 'NONE' )
                                         msg = 'Unknown channel gives no class' ).
  ENDMETHOD.


  " Rule: a destination the channel can deliver to passes
  METHOD known_destination_accepted.
    cl_abap_unit_assert=>assert_initial(
      act = zcl_ca_ops_cfg_checks=>invalid_destination( iv_class       = gc_test-class
                                                        iv_destination = gc_test-known )
      msg = 'Known SO23 list accepted' ).
  ENDMETHOD.


  " Rule: names the channel cannot deliver to are returned for message 419
  METHOD unknown_destination_listed.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ca_ops_cfg_checks=>invalid_destination(
              iv_class       = gc_test-class
              iv_destination = CONV #( |{ gc_test-known },{ gc_test-unknown }| ) )
      exp = gc_test-unknown
      msg = 'Unknown list reported' ).
  ENDMETHOD.


  " Rule: a missing or wrong class is the class check's finding, not a destination finding
  METHOD no_channel_class_not_checked.
    cl_abap_unit_assert=>assert_initial(
      act = zcl_ca_ops_cfg_checks=>invalid_destination( iv_class       = gc_test-no_class
                                                        iv_destination = CONV #( gc_test-unknown ) )
      msg = 'No class, no destination finding' ).
  ENDMETHOD.

ENDCLASS.


"! Template renderer that knows one template only (existence check of the configuration app)
CLASS ltd_mail_template DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_mail_template.
    CONSTANTS gc_known TYPE zif_ca_ops_types=>ty_template_id VALUE 'ZT_KNOWN_TPL'.
ENDCLASS.

CLASS ltd_mail_template IMPLEMENTATION.
  METHOD zif_ca_ops_mail_template~is_available.
    rv_available = abap_true.
  ENDMETHOD.
  METHOD zif_ca_ops_mail_template~exists.
    rv_exists = xsdbool( iv_template_id = gc_known ).
  ENDMETHOD.
  METHOD zif_ca_ops_mail_template~render.
    CLEAR rs_rendered.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_template_check DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS setup.
    METHODS teardown.
    METHODS blank_template_is_valid      FOR TESTING.
    METHODS known_template_is_valid      FOR TESTING.
    METHODS unknown_template_is_refused  FOR TESTING.
    METHODS bad_syntax_is_refused        FOR TESTING.
ENDCLASS.


CLASS ltc_template_check IMPLEMENTATION.

  METHOD setup.
    zcl_ca_ops_injector=>inject_mail_template( NEW ltd_mail_template( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD blank_template_is_valid.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>template_valid( space )
                                          msg = 'Blank = channel default / generic template' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD known_template_is_valid.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>template_valid( ltd_mail_template=>gc_known )
                                          msg = 'An existing template is accepted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD unknown_template_is_refused.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>template_valid( 'ZT_UNKNOWN_TPL' )
                                           msg = 'A template that does not exist is refused (436)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD bad_syntax_is_refused.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>template_valid( 'zt_known_tpl' )
                                           msg = 'Lower case is refused' ).
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>template_valid( 'ZT KNOWN' )
                                           msg = 'A blank inside the ID is refused' ).
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>template_valid( '1ZT' )
                                           msg = 'An ID starts with a letter or a namespace' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! Users of the client as the authorisation seam sees them: only ZT_OWNER exists
CLASS ltd_users DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_auth PARTIALLY IMPLEMENTED.
    CONSTANTS gc_known TYPE syuname VALUE 'ZT_OWNER'.
ENDCLASS.


CLASS ltd_users IMPLEMENTATION.

  METHOD zif_ca_ops_auth~user_exists.
    rv_exists = xsdbool( iv_user = gc_known ).
  ENDMETHOD.

ENDCLASS.


"! Control register: owner / backup, team and runbook link checked on save (messages 437-439)
CLASS ltc_control_check DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS setup.
    METHODS teardown.
    METHODS known_user_is_valid          FOR TESTING.
    METHODS unknown_user_is_refused      FOR TESTING.
    METHODS approver_four_eyes           FOR TESTING.
    METHODS team_from_parameter          FOR TESTING.
    METHODS maintained_teams_replace     FOR TESTING.
    METHODS http_link_is_valid           FOR TESTING.
    METHODS link_without_scheme_refused  FOR TESTING.
ENDCLASS.


CLASS ltc_control_check IMPLEMENTATION.

  METHOD setup.
    zcl_ca_ops_injector=>inject_auth( NEW ltd_users( ) ).
    zcl_ca_ops_injector=>inject_params( NEW zcl_ca_ops_param_seed( )->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD known_user_is_valid.
    cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>user_valid( ltd_users=>gc_known )
                                      msg = 'An existing user is accepted' ).
    cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>user_valid( space )
                                      msg = 'No backup yet is accepted (blank)' ).
  ENDMETHOD.


  METHOD unknown_user_is_refused.
    cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>user_valid( 'ZT_NOBODY' )
                                       msg = 'A user that does not exist is refused (437)' ).
  ENDMETHOD.


  METHOD approver_four_eyes.
    cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>approver_valid( ltd_users=>gc_known )
                                      msg = 'Another existing user approves the activation' ).
    cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>approver_valid( space )
                                      msg = 'Blank is left to the required check (235)' ).
    cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>approver_valid( sy-uname )
                                       msg = 'Nobody approves their own activation change (240)' ).
    cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>approver_valid( 'ZT_NOBODY' )
                                       msg = 'A user that does not exist is refused (240)' ).
  ENDMETHOD.


  METHOD team_from_parameter.
    cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>team_valid( 'offshore' )
                                      msg = 'A delivered team, any case' ).
    cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>team_valid( 'NIGHT' )
                                       msg = 'A team that is not configured is refused (438)' ).
  ENDMETHOD.


  METHOD maintained_teams_replace.
    zcl_ca_ops_injector=>inject_params(
      NEW zcl_ca_ops_param_seed( )->set( iv_name  = zif_ca_ops_ctl_types=>gc_param-teams
                                         iv_value = `ONSITE,NIGHT` )->params( ) ).
    cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>team_valid( 'NIGHT' )
                                      msg = 'A maintained team list is used' ).
    cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>team_valid( 'OFFSHORE' )
                                       msg = 'The maintained list replaces the delivered one' ).
  ENDMETHOD.


  METHOD http_link_is_valid.
    cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>url_valid( 'https://wiki.example.com/runbook/ctl-01' )
                                      msg = 'An https link is accepted' ).
    cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>url_valid( space )
                                      msg = 'The runbook link is optional' ).
  ENDMETHOD.


  METHOD link_without_scheme_refused.
    cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>url_valid( 'wiki.example.com/runbook' )
                                       msg = 'A link without http(s):// is refused (439)' ).
    cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>url_valid( 'https://wiki.example.com/run book' )
                                       msg = 'A link with a blank is refused' ).
  ENDMETHOD.

ENDCLASS.


"! Operations response features: runbook link of an active row, correlation key fields and window (153 / 154)
CLASS ltc_response_check DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS active_runbook_needs_link    FOR TESTING.
    METHODS key_fields_of_the_finding    FOR TESTING.
    METHODS window_at_least_one_minute   FOR TESTING.
ENDCLASS.


CLASS ltc_response_check IMPLEMENTATION.

  " Rule: an active runbook row needs an http(s) link - the placeholder of a seed row is refused
  METHOD active_runbook_needs_link.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>link_valid( 'https://wiki.example.com/runbook/no-ack' )
                                          msg = 'An https link is accepted' ).
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>link_valid( space )
                                           msg = 'An active row without link is refused (439)' ).
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>link_valid( '<Site runbook URL>' )
                                           msg = 'The placeholder of a seed row is refused while active' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the key is built from finding fields only, in any case, comma separated
  METHOD key_fields_of_the_finding.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>key_fields_valid( 'GROUP1, object_key' )
                                          msg = 'Finding fields, any case, blanks ignored' ).
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>key_fields_valid( 'GROUP1,AMOUNT' )
                                           msg = 'A field that is not a key field is refused (153)' ).
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>key_fields_valid( space )
                                           msg = 'An empty list is refused (153)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the correlation window is at least one minute
  METHOD window_at_least_one_minute.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>window_min_valid( 1 ) msg = 'One minute is accepted' ).
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>window_min_valid( 0 ) msg = 'Zero is refused (154)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_link_ref DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_ref,
        valid         TYPE string VALUE `T000-MANDT`,
        lower_case    TYPE string VALUE `t000-mtext`,
        unknown_field TYPE string VALUE `T000-ZZ_NOT_THERE`,
        no_table      TYPE string VALUE `MANDT`,
      END OF gc_ref.

    METHODS existing_ref_accepted   FOR TESTING.
    METHODS lower_case_ref_accepted FOR TESTING.
    METHODS unknown_field_rejected  FOR TESTING.
    METHODS ref_without_table_fails FOR TESTING.
    METHODS blank_ref_accepted      FOR TESTING.
ENDCLASS.


CLASS ltc_link_ref IMPLEMENTATION.

  " Rule: a reference names a table of the dictionary and one of its fields
  METHOD existing_ref_accepted.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>field_ref_valid( gc_ref-valid )
                                          msg = 'T000-MANDT is a field of the dictionary' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD lower_case_ref_accepted.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>field_ref_valid( gc_ref-lower_case )
                                          msg = 'Names are compared in upper case' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD unknown_field_rejected.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>field_ref_valid( gc_ref-unknown_field )
                                           msg = 'A field the table does not have is refused' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD ref_without_table_fails.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_cfg_checks=>field_ref_valid( gc_ref-no_table )
                                           msg = 'A field without its table is refused' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a condition kind without that side leaves it blank
  METHOD blank_ref_accepted.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_cfg_checks=>field_ref_valid( space )
                                          msg = 'Blank is valid' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
