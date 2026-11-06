*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_alert_router.clas.testclasses.abap
*& Purpose:
*& Application tests of the alert router with LTD_* doubles for the alert DAO,
*& channel, clock and store (injected through ZCL_CD_OPS_INJECTOR).
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
CLASS ltd_alert_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_alert_dao.
    DATA mt_rules    TYPE zif_cd_ops_types=>tt_alert_rule.
    DATA mt_channels TYPE zif_cd_ops_types=>tt_alert_channel.
    DATA mt_log      TYPE zif_cd_ops_types=>tt_alert_log.
    DATA mt_inserted TYPE zif_cd_ops_types=>tt_alert_log.
ENDCLASS.

CLASS ltd_alert_dao IMPLEMENTATION.
  METHOD zif_cd_ops_alert_dao~get_rules.
    rt_rules = mt_rules.
  ENDMETHOD.
  METHOD zif_cd_ops_alert_dao~get_channels.
    rt_channels = mt_channels.
  ENDMETHOD.
  METHOD zif_cd_ops_alert_dao~get_log.
    LOOP AT mt_log INTO DATA(ls_log) WHERE rule_id = iv_rule_id AND sent_at >= iv_since.
      INSERT ls_log INTO TABLE rt_log.
    ENDLOOP.
    SORT rt_log BY sent_at DESCENDING.
  ENDMETHOD.
  METHOD zif_cd_ops_alert_dao~insert_log.
    INSERT LINES OF it_log INTO TABLE mt_inserted.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_channel DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_alert_channel.
    DATA mt_delivered TYPE zif_cd_ops_types=>tt_alert_message.
    DATA mv_fail      TYPE abap_bool.
ENDCLASS.

CLASS ltd_channel IMPLEMENTATION.
  METHOD zif_cd_ops_alert_channel~deliver.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e020(zcd_ops) WITH 'TEST'.
    ENDIF.
    INSERT is_message INTO TABLE mt_delivered.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock.
    DATA mv_now  TYPE timestampl.
    DATA mv_time TYPE t.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~now.
    rv_timestamp = mv_now.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~today.
    rv_date = '20261105'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~time.
    rv_time = mv_time.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_store.
    DATA mt_params TYPE zif_cd_ops_types=>tt_kv.
ENDCLASS.

CLASS ltd_store IMPLEMENTATION.
  METHOD zif_cd_ops_store~start_run.
    rs_run-module = iv_module.
  ENDMETHOD.
  METHOD zif_cd_ops_store~save_findings.
    cs_run-finding_count = cs_run-finding_count + lines( it_findings ).
  ENDMETHOD.
  METHOD zif_cd_ops_store~finish_run.
    RETURN.
  ENDMETHOD.
  METHOD zif_cd_ops_store~commit.
    RETURN.
  ENDMETHOD.
  METHOD zif_cd_ops_store~get_param.
    rv_value = VALUE #( mt_params[ name = iv_name ]-value DEFAULT iv_default ).
  ENDMETHOD.
  METHOD zif_cd_ops_store~get_last_run.
    CLEAR rs_run.
  ENDMETHOD.
  METHOD zif_cd_ops_store~get_runs_since.
    CLEAR rt_runs.
  ENDMETHOD.
  METHOD zif_cd_ops_store~get_findings.
    CLEAR rt_findings.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_alert_router DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        rule_id    TYPE zif_cd_ops_types=>ty_rule_id VALUE 'EBS_BLOCK',
        dest       TYPE zif_cd_ops_types=>ty_alert_dest VALUE 'ops@example.com',
        escalation TYPE zif_cd_ops_types=>ty_alert_dest VALUE 'lead@example.com',
        now        TYPE timestampl VALUE '20261105080000.0000000',
        ten_ago    TYPE timestampl VALUE '20261105075000.0000000',
        two_h_ago  TYPE timestampl VALUE '20261105060000.0000000',
        day        TYPE t VALUE '080000',
        night      TYPE t VALUE '230000',
        channel_cl TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_OPS_CHN_EMAIL',
      END OF gc_test.

    TYPES:
      BEGIN OF ty_flags,
        rule_active      TYPE abap_bool,
        throttle_min     TYPE i,
        sent_minutes_ago TYPE i,
        quiet_at_night   TYPE abap_bool,
        night            TYPE abap_bool,
        channel_fails    TYPE abap_bool,
        escalate_after   TYPE i,
        prior_runs_sent  TYPE i,
      END OF ty_flags.

    DATA mo_dao     TYPE REF TO ltd_alert_dao.
    DATA mo_channel TYPE REF TO ltd_channel.
    DATA mo_clock   TYPE REF TO ltd_clock.
    DATA mo_store   TYPE REF TO ltd_store.
    DATA ms_run     TYPE zif_cd_ops_types=>ty_run.

    METHODS setup.
    METHODS teardown.
    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS run_dispatch
      IMPORTING
        iv_severity TYPE zif_cd_ops_types=>ty_severity DEFAULT zif_cd_ops_types=>gc_severity-error.
    METHODS default_flags
      RETURNING
        VALUE(rs_flags) TYPE ty_flags.

    METHODS matching_rule_delivers_once  FOR TESTING.
    METHODS throttled_rule_logs_t_only   FOR TESTING.
    METHODS quiet_hours_log_q_only       FOR TESTING.
    METHODS channel_failure_not_raised   FOR TESTING.
    METHODS no_active_rule_no_delivery   FOR TESTING.
    METHODS escalation_adds_destination  FOR TESTING.
    METHODS send_uses_route_parameter    FOR TESTING.
    METHODS send_without_recipient_skips FOR TESTING.
ENDCLASS.


CLASS ltc_alert_router IMPLEMENTATION.

  METHOD setup.
    mo_dao     = NEW #( ).
    mo_channel = NEW #( ).
    mo_clock   = NEW #( ).
    mo_store   = NEW #( ).
    zcl_cd_ops_injector=>inject_alert_dao( mo_dao ).
    zcl_cd_ops_injector=>inject_clock( mo_clock ).
    zcl_cd_ops_injector=>inject_store( mo_store ).
    zcl_cd_ops_injector=>inject_plugin( iv_class_name = gc_test-channel_cl
                                        io_instance   = mo_channel ).
    CLEAR ms_run.
    ms_run-module = zif_cd_ops_types=>gc_module-ebs.
    ms_run-status = zif_cd_ops_types=>gc_run_status-error.
    ms_run-rag    = zif_cd_ops_types=>gc_rag-red.
    TRY.
        ms_run-run_id = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        cl_abap_unit_assert=>fail( msg = 'UUID for test run could not be created' ).
    ENDTRY.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    CLEAR: mo_dao, mo_channel, mo_clock, mo_store.
  ENDMETHOD.


  METHOD default_flags.
    rs_flags-rule_active = abap_true.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_rule    TYPE zif_cd_ops_types=>ty_alert_rule.
    DATA ls_channel TYPE zif_cd_ops_types=>ty_alert_channel.
    DATA ls_log     TYPE zif_cd_ops_types=>ty_alert_log.

    ls_rule-rule_id         = gc_test-rule_id.
    ls_rule-module          = zif_cd_ops_types=>gc_module-ebs.
    ls_rule-min_severity    = zif_cd_ops_types=>gc_severity-error.
    ls_rule-channel         = zif_cd_ops_types=>gc_channel-email.
    ls_rule-destination     = gc_test-dest.
    ls_rule-digest          = abap_true.
    ls_rule-throttle_min    = is_flags-throttle_min.
    ls_rule-escalate_after  = is_flags-escalate_after.
    ls_rule-escalation_dest = gc_test-escalation.
    ls_rule-active          = is_flags-rule_active.
    IF is_flags-quiet_at_night = abap_true.
      ls_rule-quiet_from = '220000'.
      ls_rule-quiet_to   = '060000'.
    ENDIF.
    INSERT ls_rule INTO TABLE mo_dao->mt_rules.

    ls_channel-channel    = zif_cd_ops_types=>gc_channel-email.
    ls_channel-class_name = gc_test-channel_cl.
    ls_channel-active     = abap_true.
    INSERT ls_channel INTO TABLE mo_dao->mt_channels.

    IF is_flags-sent_minutes_ago > 0.
      ls_log-rule_id = gc_test-rule_id.
      ls_log-status  = zif_cd_ops_types=>gc_alert_status-sent.
      ls_log-sent_at = gc_test-ten_ago.
      INSERT ls_log INTO TABLE mo_dao->mt_log.
    ENDIF.

    DO is_flags-prior_runs_sent TIMES.
      CLEAR ls_log.
      ls_log-rule_id = gc_test-rule_id.
      ls_log-status  = zif_cd_ops_types=>gc_alert_status-sent.
      ls_log-sent_at = gc_test-two_h_ago.
      TRY.
          ls_log-run_id = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error.
          cl_abap_unit_assert=>fail( msg = 'UUID for prior run could not be created' ).
      ENDTRY.
      INSERT ls_log INTO TABLE mo_dao->mt_log.
    ENDDO.

    mo_channel->mv_fail = is_flags-channel_fails.
    mo_clock->mv_now    = gc_test-now.
    mo_clock->mv_time   = COND #( WHEN is_flags-night = abap_true THEN gc_test-night ELSE gc_test-day ).
  ENDMETHOD.


  METHOD run_dispatch.
    DATA ls_finding TYPE zif_cd_ops_types=>ty_finding.
    ls_finding-object_type = 'LINE'.
    ls_finding-object_key  = 'S0001/1'.
    ls_finding-rule_id     = 'R14'.
    ls_finding-check_code  = 'UNMAPPED_BTC'.
    ls_finding-severity    = iv_severity.
    ls_finding-message     = 'Unmapped code'.
    TRY.
        zcl_cd_ops_factory=>get_alert( )->dispatch( is_run      = ms_run
                                                   it_findings = VALUE #( ( ls_finding ) ) ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |dispatch must not raise: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " A matching active rule delivers exactly one digest and logs it as sent
  METHOD matching_rule_delivers_once.
    TRY.
        configure_scenario( default_flags( ) ).

        run_dispatch( ).

        cl_abap_unit_assert=>assert_equals( act = lines( mo_channel->mt_delivered ) exp = 1
                                            msg = 'Exactly one message must be delivered' ).
        cl_abap_unit_assert=>assert_equals( act = mo_channel->mt_delivered[ 1 ]-destination
                                            exp = gc_test-dest
                                            msg = 'Message must go to the rule destination' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_inserted ) exp = 1
                                            msg = 'One log row must be written' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-status
                                            exp = zif_cd_ops_types=>gc_alert_status-sent
                                            msg = 'Log status must be S' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Throttle: a send inside the window is logged as T and nothing is delivered
  METHOD throttled_rule_logs_t_only.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-throttle_min     = 30.
        ls_flags-sent_minutes_ago = 10.
        configure_scenario( ls_flags ).

        run_dispatch( ).

        cl_abap_unit_assert=>assert_initial( act = mo_channel->mt_delivered
                                             msg = 'Throttled alert must not be delivered' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-status
                                            exp = zif_cd_ops_types=>gc_alert_status-throttled
                                            msg = 'Throttled alert must be logged as T' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Quiet hours: an E alert at night is logged as Q and not delivered
  METHOD quiet_hours_log_q_only.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-quiet_at_night = abap_true.
        ls_flags-night          = abap_true.
        configure_scenario( ls_flags ).

        run_dispatch( ).

        cl_abap_unit_assert=>assert_initial( act = mo_channel->mt_delivered
                                             msg = 'Quiet-hour alert must not be delivered' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-status
                                            exp = zif_cd_ops_types=>gc_alert_status-quiet
                                            msg = 'Quiet-hour alert must be logged as Q' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A failing channel is logged as F and never aborts the calling run
  METHOD channel_failure_not_raised.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-channel_fails = abap_true.
        configure_scenario( ls_flags ).

        run_dispatch( ).

        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-status
                                            exp = zif_cd_ops_types=>gc_alert_status-failed
                                            msg = 'Failed delivery must be logged as F' ).
        cl_abap_unit_assert=>assert_not_initial( act = mo_dao->mt_inserted[ 1 ]-error
                                                 msg = 'Failed delivery must log the error text' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " No active rule: nothing delivered, nothing logged
  METHOD no_active_rule_no_delivery.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-rule_active = abap_false.
        configure_scenario( ls_flags ).

        run_dispatch( ).

        cl_abap_unit_assert=>assert_initial( act = mo_channel->mt_delivered
                                             msg = 'Inactive rule must not deliver' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted
                                             msg = 'Inactive rule must not log' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Escalation: the third consecutive alerting run also goes to the escalation destination
  METHOD escalation_adds_destination.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-escalate_after  = 3.
        ls_flags-prior_runs_sent = 2.
        configure_scenario( ls_flags ).

        run_dispatch( ).

        cl_abap_unit_assert=>assert_char_cp( act = mo_channel->mt_delivered[ 1 ]-destination
                                             exp = |*{ gc_test-escalation }*|
                                             msg = 'Escalation destination must be added' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " send( ) delivers a prepared report to the recipients of ALERT_<route>
  METHOD send_uses_route_parameter.
    TRY.
        configure_scenario( default_flags( ) ).
        INSERT VALUE #( name = 'ALERT_MORNING' value = gc_test-dest ) INTO TABLE mo_store->mt_params.

        zcl_cd_ops_factory=>get_alert( )->send( iv_route = 'MORNING' iv_subject = `Morning report`
                                               iv_html = `<p>ok</p>` ).

        cl_abap_unit_assert=>assert_equals( act = lines( mo_channel->mt_delivered ) exp = 1
                                            msg = 'Report must be delivered once' ).
        cl_abap_unit_assert=>assert_equals( act = mo_channel->mt_delivered[ 1 ]-destination
                                            exp = gc_test-dest
                                            msg = 'Report must go to the route recipients' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " send( ) without maintained recipients sends nothing (no hardcoded address)
  METHOD send_without_recipient_skips.
    TRY.
        configure_scenario( default_flags( ) ).

        zcl_cd_ops_factory=>get_alert( )->send( iv_route = 'MORNING' iv_subject = `Morning report`
                                               iv_html = `<p>ok</p>` ).

        cl_abap_unit_assert=>assert_initial( act = mo_channel->mt_delivered
                                             msg = 'Without recipients nothing may be sent' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
