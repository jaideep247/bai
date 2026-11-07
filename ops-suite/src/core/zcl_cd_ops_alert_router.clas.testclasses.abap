*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_alert_router.clas.testclasses.abap
*& Purpose:
*& Application tests of the alert router with LTD_* doubles for the alert DAO,
*& channel, clock and store (injected through ZCL_CD_OPS_INJECTOR).
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Claim, repeat, consecutive escalation, escalation override, send failures (audit A17, A45, A46).
*& 2026-11-06 | Delivered message carries the intent key and raise time (webhook de-duplication).
*& 2026-11-06 | Modern-syntax sweep: no trailing RETURN.
*& 2026-11-06 | Test invalid_rule_pattern_logged: a rule pattern that is not valid PCRE is logged F, nothing sent.
*& 2026-11-07 | Store double: get_param / get_range delegate to the shared fake ZCL_CD_OPS_PARAMS_MEM
*&            | (semantics of ZCL_CD_OPS_STORE: condensed, blank = default).
*& 2026-11-07 | Parameters over ZCA_PARAM (ZCL_CD_OPS_PARAM_SEED injected with INJECT_PARAMS); the store double
*&            | serves no parameters.
*&---------------------------------------------------------------------*
CLASS ltd_alert_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_alert_dao.
    DATA mt_rules    TYPE zif_cd_ops_types=>tt_alert_rule.
    DATA mt_channels TYPE zif_cd_ops_types=>tt_alert_channel.
    DATA mt_log      TYPE zif_cd_ops_types=>tt_alert_log.
    DATA mt_inserted TYPE zif_cd_ops_types=>tt_alert_log.
    "! Claims written before the send; final statuses arrive through complete( ) in mt_inserted
    DATA mt_claims   TYPE zif_cd_ops_types=>tt_alert_log.
    DATA mv_claimed_elsewhere TYPE abap_bool.
    DATA mt_repeat   TYPE zif_cd_ops_types=>tt_repeat_key.
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
  METHOD zif_cd_ops_alert_dao~claim.
    rv_claimed_elsewhere = mv_claimed_elsewhere.
    IF mv_claimed_elsewhere = abap_false.
      INSERT is_log INTO TABLE mt_claims.
    ENDIF.
  ENDMETHOD.
  METHOD zif_cd_ops_alert_dao~complete.
    INSERT is_log INTO TABLE mt_inserted.
  ENDMETHOD.
  METHOD zif_cd_ops_alert_dao~get_repeat_keys.
    rt_keys = mt_repeat.
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
    "! Parameters over ZCA_PARAM (delivered definitions, in memory)
    DATA mo_params TYPE REF TO zcl_cd_ops_param_seed.
    "! Run history for consecutive escalation (get_runs_since)
    DATA mt_runs   TYPE zif_cd_ops_types=>tt_run.
    METHODS constructor.
ENDCLASS.

CLASS ltd_store IMPLEMENTATION.
  METHOD constructor.
    mo_params = NEW #( ).
  ENDMETHOD.
  METHOD zif_cd_ops_store~start_run.
    rs_run-pe_area = iv_pe_area.
  ENDMETHOD.
  METHOD zif_cd_ops_store~save_findings.
    cs_run-finding_count = cs_run-finding_count + lines( it_findings ).
  ENDMETHOD.
  METHOD zif_cd_ops_store~finish_run.
  ENDMETHOD.
  METHOD zif_cd_ops_store~commit.
  ENDMETHOD.
  METHOD zif_cd_ops_store~get_last_run.
    CLEAR rs_run.
  ENDMETHOD.
  METHOD zif_cd_ops_store~get_runs_since.
    LOOP AT mt_runs INTO DATA(ls_run) WHERE pe_area = iv_pe_area AND started_at >= iv_since.
      INSERT ls_run INTO TABLE rt_runs.
    ENDLOOP.
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
        one_h_ago  TYPE timestampl VALUE '20261105070000.0000000',
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
        claimed_elsewhere TYPE abap_bool,
        carried          TYPE abap_bool,
        esc_override     TYPE abap_bool,
        healthy_between  TYPE abap_bool,
        channel_inactive TYPE abap_bool,
        bad_pattern      TYPE abap_bool,
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
    METHODS send_without_recipient_fails FOR TESTING.
    METHODS claim_precedes_delivery      FOR TESTING.
    METHODS claimed_elsewhere_not_sent   FOR TESTING.
    METHODS carried_exception_no_realert FOR TESTING.
    METHODS healthy_run_breaks_series    FOR TESTING.
    METHODS escalation_beats_throttle    FOR TESTING.
    METHODS send_inactive_channel_fails  FOR TESTING.
    METHODS invalid_rule_pattern_logged  FOR TESTING.
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
    zcl_cd_ops_injector=>inject_params( mo_store->mo_params->params( ) ).
    zcl_cd_ops_injector=>inject_plugin( iv_class_name = gc_test-channel_cl
                                        io_instance   = mo_channel ).
    CLEAR ms_run.
    ms_run-pe_area = zif_cd_ops_types=>gc_pe_area-ebs.
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
    ls_rule-pe_area          = zif_cd_ops_types=>gc_pe_area-ebs.
    ls_rule-min_severity    = zif_cd_ops_types=>gc_severity-error.
    ls_rule-channel         = zif_cd_ops_types=>gc_channel-email.
    ls_rule-destination     = gc_test-dest.
    ls_rule-digest          = abap_true.
    ls_rule-throttle_min    = is_flags-throttle_min.
    ls_rule-escalate_after  = is_flags-escalate_after.
    ls_rule-escalation_dest = gc_test-escalation.
    ls_rule-esc_override    = is_flags-esc_override.
    ls_rule-active          = is_flags-rule_active.
    IF is_flags-bad_pattern = abap_true.
      ls_rule-check_pattern = '(EBS'.
    ENDIF.
    IF is_flags-quiet_at_night = abap_true.
      ls_rule-quiet_from = '220000'.
      ls_rule-quiet_to   = '060000'.
    ENDIF.
    INSERT ls_rule INTO TABLE mo_dao->mt_rules.

    ls_channel-channel    = zif_cd_ops_types=>gc_channel-email.
    ls_channel-class_name = gc_test-channel_cl.
    ls_channel-active     = xsdbool( is_flags-channel_inactive = abap_false ).
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
      " A46: the alerting runs are part of the run history
      INSERT VALUE #( run_id = ls_log-run_id pe_area = zif_cd_ops_types=>gc_pe_area-ebs
                      started_at = gc_test-two_h_ago ) INTO TABLE mo_store->mt_runs.
    ENDDO.
    " A46: a healthy run (no alert of the rule) after the alerting ones breaks the series
    IF is_flags-healthy_between = abap_true.
      TRY.
          INSERT VALUE #( run_id = cl_system_uuid=>create_uuid_x16_static( ) pe_area = zif_cd_ops_types=>gc_pe_area-ebs
                          started_at = gc_test-one_h_ago ) INTO TABLE mo_store->mt_runs.
        CATCH cx_uuid_error.
          cl_abap_unit_assert=>fail( msg = 'UUID for healthy run could not be created' ).
      ENDTRY.
    ENDIF.
    mo_dao->mv_claimed_elsewhere = is_flags-claimed_elsewhere.
    IF is_flags-carried = abap_true.
      INSERT VALUE #( object_type = 'LINE' object_key = 'S0001/1' check_code = 'UNMAPPED_BTC' ) INTO TABLE mo_dao->mt_repeat.
    ENDIF.

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


  " A rule pattern that is not valid PCRE: the rule is logged as failed with the reason and
  " not applied - visible in the alert log, never a silent 'no match'
  METHOD invalid_rule_pattern_logged.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-bad_pattern = abap_true.
        configure_scenario( ls_flags ).

        run_dispatch( ).

        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_inserted ) exp = 1
                                            msg = 'One log row for the invalid rule' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-status
                                            exp = zif_cd_ops_types=>gc_alert_status-failed
                                            msg = 'The rule must be logged as failed' ).
        cl_abap_unit_assert=>assert_not_initial( act = mo_dao->mt_inserted[ 1 ]-error
                                                 msg = 'The log names the invalid pattern' ).
        cl_abap_unit_assert=>assert_initial( act = mo_channel->mt_delivered
                                             msg = 'Nothing is delivered for the invalid rule' ).
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
        mo_store->mo_params->set( iv_name = 'ALERT_MORNING' iv_value = gc_test-dest ).

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


  " Audit A45: send( ) without maintained recipients sends nothing and says so - a
  " failed log row and an exception, never a silent return (no hardcoded address)
  METHOD send_without_recipient_fails.
    configure_scenario( default_flags( ) ).
    TRY.
        zcl_cd_ops_factory=>get_alert( )->send( iv_route = 'MORNING' iv_subject = `Morning report`
                                               iv_html = `<p>ok</p>` ).
        cl_abap_unit_assert=>fail( msg = 'A report without recipients must raise' ).
      CATCH zcx_cd_ops_error.
        cl_abap_unit_assert=>assert_initial( act = mo_channel->mt_delivered
                                             msg = 'Without recipients nothing may be sent' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-status
                                            exp = zif_cd_ops_types=>gc_alert_status-failed
                                            msg = 'The missing recipient must be logged as F' ).
    ENDTRY.
  ENDMETHOD.


  " Audit A17: the alert is claimed (status C) before the channel delivers it, then completed
  METHOD claim_precedes_delivery.
    TRY.
        configure_scenario( default_flags( ) ).
        run_dispatch( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_claims ) exp = 1 msg = 'One claim before the send' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_claims[ 1 ]-alert_id
                                            exp = mo_channel->mt_delivered[ 1 ]-alert_id
                                            msg = 'The delivered alert is the claimed one' ).
        cl_abap_unit_assert=>assert_not_initial( act = mo_dao->mt_claims[ 1 ]-intent_key
                                                 msg = 'The claim carries the alert intent' ).
        " De-duplication: the channel receives the same intent key and raise time as the claim
        cl_abap_unit_assert=>assert_equals( act = mo_channel->mt_delivered[ 1 ]-intent_key
                                            exp = mo_dao->mt_claims[ 1 ]-intent_key
                                            msg = 'The delivered message carries the claimed intent key' ).
        cl_abap_unit_assert=>assert_equals( act = mo_channel->mt_delivered[ 1 ]-occurred_at
                                            exp = mo_dao->mt_claims[ 1 ]-sent_at
                                            msg = 'The delivered message carries the claim time' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A17: an intent claimed by another dispatcher is not sent a second time
  METHOD claimed_elsewhere_not_sent.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-claimed_elsewhere = abap_true.
        configure_scenario( ls_flags ).
        run_dispatch( ).
        cl_abap_unit_assert=>assert_initial( act = mo_channel->mt_delivered
                                             msg = 'A claimed intent must not be delivered again' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A17: an exception that was only carried forward is not alerted again (log R)
  METHOD carried_exception_no_realert.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-carried = abap_true.
        configure_scenario( ls_flags ).
        run_dispatch( ).
        cl_abap_unit_assert=>assert_initial( act = mo_channel->mt_delivered
                                             msg = 'A carried-forward exception must not be alerted again' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-status
                                            exp = zif_cd_ops_types=>gc_alert_status-repeat
                                            msg = 'The suppressed repeat must be logged as R' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A46: escalation counts consecutive runs - a healthy run in between resets it
  METHOD healthy_run_breaks_series.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-escalate_after  = 3.
        ls_flags-prior_runs_sent = 2.
        ls_flags-healthy_between = abap_true.
        configure_scenario( ls_flags ).
        run_dispatch( ).
        cl_abap_unit_assert=>assert_equals( act = mo_channel->mt_delivered[ 1 ]-destination
                                            exp = gc_test-dest
                                            msg = 'After a healthy run the series restarts - no escalation' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A46: with ESC_OVERRIDE a due escalation is delivered inside the throttle window
  METHOD escalation_beats_throttle.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-throttle_min     = 30.
        ls_flags-sent_minutes_ago = 10.
        ls_flags-escalate_after   = 2.
        ls_flags-prior_runs_sent  = 1.
        ls_flags-esc_override     = abap_true.
        configure_scenario( ls_flags ).
        run_dispatch( ).
        cl_abap_unit_assert=>assert_char_cp( act = mo_channel->mt_delivered[ 1 ]-destination
                                             exp = |*{ gc_test-escalation }*|
                                             msg = 'The escalation must be delivered despite the throttle' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A45: send( ) respects the channel's active flag
  METHOD send_inactive_channel_fails.
    DATA(ls_flags) = default_flags( ).
    ls_flags-channel_inactive = abap_true.
    configure_scenario( ls_flags ).
    mo_store->mo_params->set( iv_name = 'ALERT_MORNING' iv_value = gc_test-dest ).
    TRY.
        zcl_cd_ops_factory=>get_alert( )->send( iv_route = 'MORNING' iv_subject = `Morning report`
                                               iv_html = `<p>ok</p>` ).
        cl_abap_unit_assert=>fail( msg = 'An inactive channel must raise' ).
      CATCH zcx_cd_ops_error.
        cl_abap_unit_assert=>assert_initial( act = mo_channel->mt_delivered
                                             msg = 'An inactive channel must not deliver' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
