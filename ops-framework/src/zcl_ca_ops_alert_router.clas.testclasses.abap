*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_alert_router.clas.testclasses.abap
*& Purpose:
*& Application tests of the alert router with LTD_* doubles for the alert DAO,
*& channel, clock and store (injected through zcl_ca_ops_injector).
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Claim, repeat, consecutive escalation, escalation override, send failures (audit A17, A45, A46).
*& 2026-11-06 | Delivered message carries the intent key and raise time (webhook de-duplication).
*& 2026-11-06 | Modern-syntax sweep: no trailing RETURN.
*& 2026-11-06 | Test invalid_rule_pattern_logged: a rule pattern that is not valid PCRE is logged F, nothing sent.
*& 2026-11-07 | Store double: get_param / get_range delegate to the shared fake the former in-memory parameter fake
*&            | (semantics of ZCL_CA_OPS_STORE: condensed, blank = default).
*& 2026-11-07 | Delivered message no longer carries intent key / raise time (webhook fields removed).
*& 2026-11-07 | Parameters over ZCA_PARAM (zcl_ca_ops_param_seed injected with INJECT_PARAMS); the store double
*&            | serves no parameters.
*& 2026-11-10 | alert_id_failure_raises: no UUID for the alert log raises 802 (test seam ALERT_ID), nothing sent.
*& 2026-11-10 | Moved from ZCL_CD_OPS_ALERT_ROUTER to the reusable framework ZCA_OPS (test include).
*& 2026-11-10 | Alert e-mail templates: renderer double LTD_MAIL_TEMPLATE injected (no SMTG call); template
*&            | rendered after the claim and logged, fallback to the built-in layout logged, rule before
*&            | channel before generic template, a prepared report in a template (SEND).
*& 2026-11-11 | LTC_RESPONSE (operations response features): planned downtime suppresses and logs D (findings and
*&            | an area-wide window for run-level alerts), correlated children logged K and counted in the
*&            | parent's message, runbook in the message, escalation until acknowledged (due step sent once,
*&            | not again, children / downtime skipped, authorisation 16). Doubles LTD_DOWNTIME, LTD_AUTH.
*&---------------------------------------------------------------------*
CLASS ltd_alert_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_alert_dao.
    DATA mt_rules    TYPE zif_ca_ops_types=>tt_alert_rule.
    DATA mt_channels TYPE zif_ca_ops_types=>tt_alert_channel.
    DATA mt_log      TYPE zif_ca_ops_types=>tt_alert_log.
    DATA mt_inserted TYPE zif_ca_ops_types=>tt_alert_log.
    "! Claims written before the send; final statuses arrive through complete( ) in mt_inserted
    DATA mt_claims   TYPE zif_ca_ops_types=>tt_alert_log.
    DATA mv_claimed_elsewhere TYPE abap_bool.
    DATA mt_repeat   TYPE zif_ca_ops_types=>tt_repeat_key.
    "! Operations response features (2026-11-11): marks of the run's findings, open children, runbooks,
    "! escalation candidates and the log of escalation intents
    DATA mt_marks      TYPE zif_ca_ops_resp_types=>tt_finding_mark.
    DATA mt_children   TYPE zif_ca_ops_resp_types=>tt_corr_count.
    DATA mt_runbooks   TYPE zif_ca_ops_resp_types=>tt_runbook.
    DATA mt_candidates TYPE zif_ca_ops_resp_types=>tt_esc_candidate.
    DATA mt_intent_log TYPE zif_ca_ops_types=>tt_alert_log.
ENDCLASS.

CLASS ltd_alert_dao IMPLEMENTATION.
  METHOD zif_ca_ops_alert_dao~get_rules.
    rt_rules = mt_rules.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_dao~get_channels.
    rt_channels = mt_channels.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_dao~get_log.
    LOOP AT mt_log INTO DATA(ls_log) WHERE rule_id = iv_rule_id AND sent_at >= iv_since.
      INSERT ls_log INTO TABLE rt_log.
    ENDLOOP.
    SORT rt_log BY sent_at DESCENDING.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_dao~insert_log.
    INSERT LINES OF it_log INTO TABLE mt_inserted.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_dao~claim.
    rv_claimed_elsewhere = mv_claimed_elsewhere.
    IF mv_claimed_elsewhere = abap_false.
      INSERT is_log INTO TABLE mt_claims.
    ENDIF.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_dao~complete.
    INSERT is_log INTO TABLE mt_inserted.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_dao~get_repeat_keys.
    rt_keys = mt_repeat.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_dao~get_marks.
    rt_marks = mt_marks.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_dao~get_child_counts.
    LOOP AT mt_children INTO DATA(ls_count).
      IF line_exists( it_corr_ids[ table_line = ls_count-corr_id ] ).
        INSERT ls_count INTO TABLE rt_counts.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_dao~get_runbooks.
    rt_runbooks = mt_runbooks.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_dao~get_escalation_candidates.
    LOOP AT mt_candidates INTO DATA(ls_candidate) WHERE first_seen_at <= iv_seen_before.
      INSERT ls_candidate INTO TABLE rt_candidates.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_dao~get_intent_log.
    LOOP AT mt_intent_log INTO DATA(ls_log).
      IF line_exists( it_intent_keys[ table_line = ls_log-intent_key ] ).
        INSERT ls_log INTO TABLE rt_log.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

"! Planned downtime API: the windows given by the test, decided by the real policy
CLASS ltd_downtime DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_downtime.
    DATA mt_windows TYPE zif_ca_ops_resp_types=>tt_window.
ENDCLASS.

CLASS ltd_downtime IMPLEMENTATION.
  METHOD zif_ca_ops_downtime~windows.
    rt_windows = mt_windows.
  ENDMETHOD.
  METHOD zif_ca_ops_downtime~planned.
    rv_window_id = zcl_ca_ops_downtime_policy=>covering( it_windows = mt_windows iv_area = iv_area
                                                         is_finding = is_finding iv_from = iv_from iv_to = iv_to ).
  ENDMETHOD.
  METHOD zif_ca_ops_downtime~area_planned.
    rv_window_id = zcl_ca_ops_downtime_policy=>area_wide( it_windows = mt_windows iv_area = iv_area iv_at = iv_at ).
  ENDMETHOD.
ENDCLASS.

"! Authorisation of the escalation job (ZCA_OPS 16 for the area): allowed unless the test refuses it
CLASS ltd_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_auth.
    DATA mv_refuse TYPE abap_bool.
ENDCLASS.

CLASS ltd_auth IMPLEMENTATION.
  METHOD zif_ca_ops_auth~is_allowed.
    rv_allowed = xsdbool( mv_refuse = abap_false ).
  ENDMETHOD.
  METHOD zif_ca_ops_auth~check.
    IF mv_refuse = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e041(zca_ops) WITH iv_area iv_activity.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_channel DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_alert_channel.
    DATA mt_delivered TYPE zif_ca_ops_types=>tt_alert_message.
    DATA mv_fail      TYPE abap_bool.
ENDCLASS.

CLASS ltd_channel IMPLEMENTATION.
  METHOD zif_ca_ops_alert_channel~deliver.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e020(zca_ops) WITH 'TEST'.
    ENDIF.
    INSERT is_message INTO TABLE mt_delivered.
  ENDMETHOD.
ENDCLASS.

"! Renderer of SAP e-mail templates (the SMTG adapter is never called by these tests)
CLASS ltd_mail_template DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_mail_template.
    DATA mv_available TYPE abap_bool.
    DATA mt_asked     TYPE STANDARD TABLE OF zif_ca_ops_types=>ty_template_id WITH EMPTY KEY.
ENDCLASS.

CLASS ltd_mail_template IMPLEMENTATION.
  METHOD zif_ca_ops_mail_template~is_available.
    rv_available = mv_available.
  ENDMETHOD.
  METHOD zif_ca_ops_mail_template~exists.
    rv_exists = abap_true.
  ENDMETHOD.
  METHOD zif_ca_ops_mail_template~render.
    INSERT iv_template_id INTO TABLE mt_asked.
    rs_rendered-subject = is_context-header-subject.
    rs_rendered-html    = |<h1>TEMPLATE</h1>{ is_context-header-table_main }|.
    rs_rendered-text    = |TEMPLATE { is_context-header-table_main }|.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock.
    DATA mv_now  TYPE timestampl.
    DATA mv_time TYPE t.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~now.
    rv_timestamp = mv_now.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~today.
    rv_date = '20261105'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~time.
    rv_time = mv_time.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_store.
    "! Parameters over ZCA_PARAM (delivered definitions, in memory)
    DATA mo_params TYPE REF TO zcl_ca_ops_param_seed.
    "! Run history for consecutive escalation (get_runs_since)
    DATA mt_runs   TYPE zif_ca_ops_types=>tt_run.
    METHODS constructor.
ENDCLASS.

CLASS ltd_store IMPLEMENTATION.
  METHOD constructor.
    mo_params = NEW #( ).
  ENDMETHOD.
  METHOD zif_ca_ops_store~start_run.
    rs_run-area = iv_area.
  ENDMETHOD.
  METHOD zif_ca_ops_store~save_findings.
    cs_run-finding_count = cs_run-finding_count + lines( it_findings ).
  ENDMETHOD.
  METHOD zif_ca_ops_store~finish_run.
  ENDMETHOD.
  METHOD zif_ca_ops_store~commit.
  ENDMETHOD.
  METHOD zif_ca_ops_store~get_last_run.
    CLEAR rs_run.
  ENDMETHOD.
  METHOD zif_ca_ops_store~get_runs_since.
    LOOP AT mt_runs INTO DATA(ls_run) WHERE area = iv_area AND started_at >= iv_since.
      INSERT ls_run INTO TABLE rt_runs.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_ca_ops_store~get_findings.
    CLEAR rt_findings.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_alert_router DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        rule_id    TYPE zif_ca_ops_types=>ty_rule_id VALUE 'ZT_BLOCK',
        dest       TYPE zif_ca_ops_types=>ty_alert_dest VALUE 'ops@example.com',
        escalation TYPE zif_ca_ops_types=>ty_alert_dest VALUE 'lead@example.com',
        now        TYPE timestampl VALUE '20261105080000.0000000',
        ten_ago    TYPE timestampl VALUE '20261105075000.0000000',
        two_h_ago  TYPE timestampl VALUE '20261105060000.0000000',
        one_h_ago  TYPE timestampl VALUE '20261105070000.0000000',
        day        TYPE t VALUE '080000',
        night      TYPE t VALUE '230000',
        channel_cl TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_CA_OPS_CHN_EMAIL',
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
        "! E-mail templates: available renderer, template of the rule / of the channel
        smtg_available   TYPE abap_bool,
        rule_template    TYPE zif_ca_ops_types=>ty_template_id,
        channel_template TYPE zif_ca_ops_types=>ty_template_id,
      END OF ty_flags.

    DATA mo_dao     TYPE REF TO ltd_alert_dao.
    DATA mo_channel TYPE REF TO ltd_channel.
    DATA mo_clock   TYPE REF TO ltd_clock.
    DATA mo_store   TYPE REF TO ltd_store.
    DATA mo_template TYPE REF TO ltd_mail_template.
    DATA ms_run     TYPE zif_ca_ops_types=>ty_run.

    METHODS setup.
    METHODS teardown.
    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS run_dispatch
      IMPORTING
        iv_severity TYPE zif_ca_ops_types=>ty_severity DEFAULT zif_ca_ops_types=>gc_severity-error.
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
    METHODS alert_id_failure_raises      FOR TESTING.
    METHODS template_rendered_and_logged FOR TESTING.
    METHODS template_fallback_is_logged  FOR TESTING.
    METHODS rule_template_beats_channel  FOR TESTING.
    METHODS channel_template_is_default  FOR TESTING.
    METHODS send_wraps_report_template   FOR TESTING.
ENDCLASS.


CLASS ltc_alert_router IMPLEMENTATION.

  METHOD setup.
    mo_dao     = NEW #( ).
    mo_channel = NEW #( ).
    mo_clock   = NEW #( ).
    mo_store   = NEW #( ).
    mo_template = NEW #( ).
    zcl_ca_ops_injector=>inject_mail_template( mo_template ).
    zcl_ca_ops_injector=>inject_alert_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_clock( mo_clock ).
    zcl_ca_ops_injector=>inject_store( mo_store ).
    zcl_ca_ops_injector=>inject_params( mo_store->mo_params->params( ) ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = gc_test-channel_cl
                                        io_instance   = mo_channel ).
    CLEAR ms_run.
    ms_run-area = zcl_ca_ops_param_seed=>gc_test_area-first.
    ms_run-status = zif_ca_ops_types=>gc_run_status-error.
    ms_run-rag    = zif_ca_ops_types=>gc_rag-red.
    TRY.
        ms_run-run_id = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        cl_abap_unit_assert=>fail( msg = 'UUID for test run could not be created' ).
    ENDTRY.
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
    CLEAR: mo_dao, mo_channel, mo_clock, mo_store, mo_template.
  ENDMETHOD.


  METHOD default_flags.
    rs_flags-rule_active = abap_true.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_rule    TYPE zif_ca_ops_types=>ty_alert_rule.
    DATA ls_channel TYPE zif_ca_ops_types=>ty_alert_channel.
    DATA ls_log     TYPE zif_ca_ops_types=>ty_alert_log.

    ls_rule-rule_id         = gc_test-rule_id.
    ls_rule-area          = zcl_ca_ops_param_seed=>gc_test_area-first.
    ls_rule-min_severity    = zif_ca_ops_types=>gc_severity-error.
    ls_rule-channel         = zif_ca_ops_types=>gc_channel-email.
    ls_rule-destination     = gc_test-dest.
    ls_rule-digest          = abap_true.
    ls_rule-throttle_min    = is_flags-throttle_min.
    ls_rule-escalate_after  = is_flags-escalate_after.
    ls_rule-escalation_dest = gc_test-escalation.
    ls_rule-esc_override    = is_flags-esc_override.
    ls_rule-active          = is_flags-rule_active.
    ls_rule-template_id     = is_flags-rule_template.
    IF is_flags-bad_pattern = abap_true.
      ls_rule-check_pattern = '(ZT'.
    ENDIF.
    IF is_flags-quiet_at_night = abap_true.
      ls_rule-quiet_from = '220000'.
      ls_rule-quiet_to   = '060000'.
    ENDIF.
    INSERT ls_rule INTO TABLE mo_dao->mt_rules.

    ls_channel-channel    = zif_ca_ops_types=>gc_channel-email.
    ls_channel-class_name = gc_test-channel_cl.
    ls_channel-active     = xsdbool( is_flags-channel_inactive = abap_false ).
    ls_channel-template_id = is_flags-channel_template.
    INSERT ls_channel INTO TABLE mo_dao->mt_channels.

    IF is_flags-sent_minutes_ago > 0.
      ls_log-rule_id = gc_test-rule_id.
      ls_log-status  = zif_ca_ops_types=>gc_alert_status-sent.
      ls_log-sent_at = gc_test-ten_ago.
      INSERT ls_log INTO TABLE mo_dao->mt_log.
    ENDIF.

    DO is_flags-prior_runs_sent TIMES.
      CLEAR ls_log.
      ls_log-rule_id = gc_test-rule_id.
      ls_log-status  = zif_ca_ops_types=>gc_alert_status-sent.
      ls_log-sent_at = gc_test-two_h_ago.
      TRY.
          ls_log-run_id = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error.
          cl_abap_unit_assert=>fail( msg = 'UUID for prior run could not be created' ).
      ENDTRY.
      INSERT ls_log INTO TABLE mo_dao->mt_log.
      " A46: the alerting runs are part of the run history
      INSERT VALUE #( run_id = ls_log-run_id area = zcl_ca_ops_param_seed=>gc_test_area-first
                      started_at = gc_test-two_h_ago ) INTO TABLE mo_store->mt_runs.
    ENDDO.
    " A46: a healthy run (no alert of the rule) after the alerting ones breaks the series
    IF is_flags-healthy_between = abap_true.
      TRY.
          INSERT VALUE #( run_id = cl_system_uuid=>create_uuid_x16_static( ) area = zcl_ca_ops_param_seed=>gc_test_area-first
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
    mo_template->mv_available = is_flags-smtg_available.
    mo_clock->mv_now    = gc_test-now.
    mo_clock->mv_time   = COND #( WHEN is_flags-night = abap_true THEN gc_test-night ELSE gc_test-day ).
  ENDMETHOD.


  METHOD run_dispatch.
    DATA ls_finding TYPE zif_ca_ops_types=>ty_finding.
    ls_finding-object_type = 'LINE'.
    ls_finding-object_key  = 'S0001/1'.
    ls_finding-rule_id     = 'R14'.
    ls_finding-check_code  = 'UNMAPPED_BTC'.
    ls_finding-severity    = iv_severity.
    ls_finding-message     = 'Unmapped code'.
    TRY.
        zcl_ca_ops_factory=>get_alert( )->dispatch( is_run      = ms_run
                                                   it_findings = VALUE #( ( ls_finding ) ) ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
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
                                            exp = zif_ca_ops_types=>gc_alert_status-sent
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
                                            exp = zif_ca_ops_types=>gc_alert_status-throttled
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
                                            exp = zif_ca_ops_types=>gc_alert_status-quiet
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
                                            exp = zif_ca_ops_types=>gc_alert_status-failed
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
                                            exp = zif_ca_ops_types=>gc_alert_status-failed
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

        zcl_ca_ops_factory=>get_alert( )->send( iv_route = 'MORNING' iv_subject = `Daily report`
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
        zcl_ca_ops_factory=>get_alert( )->send( iv_route = 'MORNING' iv_subject = `Daily report`
                                               iv_html = `<p>ok</p>` ).
        cl_abap_unit_assert=>fail( msg = 'A report without recipients must raise' ).
      CATCH zcx_ca_ops_error.
        cl_abap_unit_assert=>assert_initial( act = mo_channel->mt_delivered
                                             msg = 'Without recipients nothing may be sent' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-status
                                            exp = zif_ca_ops_types=>gc_alert_status-failed
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
        cl_abap_unit_assert=>assert_not_initial( act = mo_dao->mt_claims[ 1 ]-sent_at
                                                 msg = 'The claim carries the claim time' ).
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
                                            exp = zif_ca_ops_types=>gc_alert_status-repeat
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
        zcl_ca_ops_factory=>get_alert( )->send( iv_route = 'MORNING' iv_subject = `Daily report`
                                               iv_html = `<p>ok</p>` ).
        cl_abap_unit_assert=>fail( msg = 'An inactive channel must raise' ).
      CATCH zcx_ca_ops_error.
        cl_abap_unit_assert=>assert_initial( act = mo_channel->mt_delivered
                                             msg = 'An inactive channel must not deliver' ).
    ENDTRY.
  ENDMETHOD.


  " B17: an alert log ID that cannot be generated is an error the caller records (ALERT_FAILED),
  " never an initial key that collides with the next alert
  METHOD alert_id_failure_raises.
    DATA ls_finding TYPE zif_ca_ops_types=>ty_finding.
    configure_scenario( default_flags( ) ).
    ls_finding-check_code = 'UNMAPPED_BTC'.
    ls_finding-severity   = zif_ca_ops_types=>gc_severity-error.
    TEST-INJECTION alert_id.
      lx_error = NEW cx_uuid_error( ).
    END-TEST-INJECTION.
    TRY.
        zcl_ca_ops_factory=>get_alert( )->dispatch( is_run      = ms_run
                                                    it_findings = VALUE #( ( ls_finding ) ) ).
        cl_abap_unit_assert=>fail( msg = 'A missing alert ID must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno
                                            exp = zif_ca_ops_types=>gc_msg-alert_id_failed
                                            msg = 'Message 802' ).
        cl_abap_unit_assert=>assert_initial( act = mo_channel->mt_delivered
                                             msg = 'Nothing is delivered without a log key' ).
    ENDTRY.
  ENDMETHOD.


  " SMTG available: the generic template is rendered after the claim, the table is put in, the log
  " row names template and renderer
  METHOD template_rendered_and_logged.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-smtg_available = abap_true.
        configure_scenario( ls_flags ).

        run_dispatch( ).

        cl_abap_unit_assert=>assert_equals( act = lines( mo_channel->mt_delivered ) exp = 1
                                            msg = 'The alert is delivered once' ).
        DATA(ls_delivered) = mo_channel->mt_delivered[ 1 ].
        cl_abap_unit_assert=>assert_char_cp( act = ls_delivered-html exp = '<h1>TEMPLATE</h1>*S0001/1*'
                                             msg = 'Template HTML with the findings table in place' ).
        cl_abap_unit_assert=>assert_equals( act = mo_template->mt_asked[ 1 ]
                                            exp = CONV zif_ca_ops_types=>ty_template_id(
                                                    zif_ca_ops_types=>gc_param_default-template_default )
                                            msg = 'Without rule and channel template the generic one' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_claims[ 1 ]-template_id
                                            exp = mo_template->mt_asked[ 1 ]
                                            msg = 'The claim names the template' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-renderer
                                            exp = zif_ca_ops_types=>gc_renderer-smtg
                                            msg = 'The log names the renderer' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted[ 1 ]-render_info
                                             msg = 'Nothing to note' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " SMTG not usable: the built-in layout is delivered all the same, the fallback is on the log row
  METHOD template_fallback_is_logged.
    TRY.
        configure_scenario( default_flags( ) ).

        run_dispatch( ).

        cl_abap_unit_assert=>assert_equals( act = lines( mo_channel->mt_delivered ) exp = 1
                                            msg = 'A fallback still delivers the e-mail' ).
        cl_abap_unit_assert=>assert_char_cp( act = mo_channel->mt_delivered[ 1 ]-html exp = '*Unmapped code*'
                                             msg = 'The built-in layout names the finding' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-status
                                            exp = zif_ca_ops_types=>gc_alert_status-sent
                                            msg = 'Sent' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-renderer
                                            exp = zif_ca_ops_types=>gc_renderer-builtin
                                            msg = 'The log names the built-in renderer' ).
        cl_abap_unit_assert=>assert_not_initial( act = mo_dao->mt_inserted[ 1 ]-render_info
                                                 msg = 'The fallback is never silent' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD rule_template_beats_channel.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-smtg_available   = abap_true.
        ls_flags-rule_template    = 'ZT_RULE_TPL'.
        ls_flags-channel_template = 'ZT_CHANNEL_TPL'.
        configure_scenario( ls_flags ).

        run_dispatch( ).

        cl_abap_unit_assert=>assert_equals( act = mo_template->mt_asked[ 1 ] exp = 'ZT_RULE_TPL'
                                            msg = 'The rule template wins over the channel default' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD channel_template_is_default.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-smtg_available   = abap_true.
        ls_flags-channel_template = 'ZT_CHANNEL_TPL'.
        configure_scenario( ls_flags ).

        run_dispatch( ).

        cl_abap_unit_assert=>assert_equals( act = mo_template->mt_asked[ 1 ] exp = 'ZT_CHANNEL_TPL'
                                            msg = 'Without a rule template the channel default applies' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A prepared report (send) in a template: the report is the block TABLE_MAIN
  METHOD send_wraps_report_template.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-smtg_available = abap_true.
        configure_scenario( ls_flags ).
        mo_store->mo_params->set( iv_name = 'ALERT_MORNING' iv_value = gc_test-dest ).

        zcl_ca_ops_factory=>get_alert( )->send( iv_route       = 'MORNING'
                                                iv_subject     = `Daily report`
                                                iv_html        = `<p>report</p>`
                                                iv_template_id = 'ZT_REPORT_TPL' ).

        cl_abap_unit_assert=>assert_equals( act = mo_channel->mt_delivered[ 1 ]-html
                                            exp = `<h1>TEMPLATE</h1><p>report</p>`
                                            msg = 'The report stands where the template has TABLE_MAIN' ).
        cl_abap_unit_assert=>assert_equals( act = mo_template->mt_asked[ 1 ] exp = 'ZT_REPORT_TPL'
                                            msg = 'The template of the caller' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-template_id exp = 'ZT_REPORT_TPL'
                                            msg = 'The log names the template' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! Operations response features (2026-11-11): planned downtime, correlation, runbook, escalation until
"! acknowledged - router decisions with the doubles above (no database, no SMTG, no delivery)
CLASS ltc_response DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        rule_id    TYPE zif_ca_ops_types=>ty_rule_id VALUE 'ZT_RESP',
        dest       TYPE zif_ca_ops_types=>ty_alert_dest VALUE 'ZT_OPS',
        escalation TYPE zif_ca_ops_types=>ty_alert_dest VALUE 'ZT_LEAD',
        channel_cl TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_CA_OPS_CHN_EMAIL',
        now        TYPE timestampl VALUE '20261111100000.0000000',
        hour_ago   TYPE timestampl VALUE '20261111090000.0000000',
        win_from   TYPE timestampl VALUE '20261111090000.0000000',
        win_to     TYPE timestampl VALUE '20261111110000.0000000',
        window_id  TYPE zif_ca_ops_resp_types=>ty_uuid VALUE '000000000000000000000000000000A9',
        parent_id  TYPE zif_ca_ops_resp_types=>ty_uuid VALUE '000000000000000000000000000000B9',
        approver   TYPE syuname VALUE 'ZT_APPROVER',
        url        TYPE zif_ca_ops_resp_types=>ty_runbook_url VALUE 'https://wiki.example.com/unmapped-btc',
        check      TYPE zif_ca_ops_types=>ty_check_code VALUE 'UNMAPPED_BTC',
        day        TYPE t VALUE '100000',
        finding_no TYPE i VALUE 7,
      END OF gc.

    DATA mo_dao      TYPE REF TO ltd_alert_dao.
    DATA mo_channel  TYPE REF TO ltd_channel.
    DATA mo_clock    TYPE REF TO ltd_clock.
    DATA mo_store    TYPE REF TO ltd_store.
    DATA mo_downtime TYPE REF TO ltd_downtime.
    DATA mo_auth     TYPE REF TO ltd_auth.
    DATA ms_run      TYPE zif_ca_ops_types=>ty_run.

    METHODS setup.
    METHODS teardown.
    "! Active e-mail rule of the test area (E or worse), digest, escalation destination
    METHODS given_rule
      IMPORTING
        iv_esc_after_min TYPE i DEFAULT 0
        iv_min_rag       TYPE zif_ca_ops_types=>ty_rag OPTIONAL.
    METHODS finding
      IMPORTING
        iv_object_key     TYPE zif_ca_ops_types=>ty_object_key
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.
    METHODS mark
      IMPORTING
        iv_object_key  TYPE zif_ca_ops_types=>ty_object_key
        iv_downtime    TYPE zif_ca_ops_resp_types=>ty_uuid OPTIONAL
        iv_role        TYPE zif_ca_ops_resp_types=>ty_corr_role OPTIONAL.
    METHODS dispatch
      IMPORTING
        it_findings TYPE zif_ca_ops_types=>tt_finding.
    METHODS escalate
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_resp_types=>ty_escalation_result.
    METHODS candidate
      IMPORTING
        iv_role             TYPE zif_ca_ops_resp_types=>ty_corr_role OPTIONAL
      RETURNING
        VALUE(rs_candidate) TYPE zif_ca_ops_resp_types=>ty_esc_candidate.
    METHODS logged
      IMPORTING
        iv_status       TYPE char1
      RETURNING
        VALUE(rv_count) TYPE i.

    METHODS downtime_finding_not_alerted FOR TESTING.
    METHODS area_window_holds_run_alert  FOR TESTING.
    METHODS child_held_back_parent_count FOR TESTING.
    METHODS runbook_link_in_the_message  FOR TESTING.
    METHODS due_escalation_sent_once     FOR TESTING.
    METHODS escalated_step_not_resent    FOR TESTING.
    METHODS child_and_downtime_skipped   FOR TESTING.
    METHODS not_yet_due_not_escalated    FOR TESTING.
    METHODS escalation_needs_execute     FOR TESTING.
ENDCLASS.


CLASS ltc_response IMPLEMENTATION.

  METHOD setup.
    mo_dao      = NEW #( ).
    mo_channel  = NEW #( ).
    mo_clock    = NEW #( ).
    mo_store    = NEW #( ).
    mo_downtime = NEW #( ).
    mo_auth     = NEW #( ).
    zcl_ca_ops_injector=>inject_mail_template( NEW ltd_mail_template( ) ).
    zcl_ca_ops_injector=>inject_alert_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_clock( mo_clock ).
    zcl_ca_ops_injector=>inject_store( mo_store ).
    zcl_ca_ops_injector=>inject_params( mo_store->mo_params->params( ) ).
    zcl_ca_ops_injector=>inject_downtime( mo_downtime ).
    zcl_ca_ops_injector=>inject_auth( mo_auth ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = gc-channel_cl
                                        io_instance   = mo_channel ).
    mo_clock->mv_now  = gc-now.
    mo_clock->mv_time = gc-day.
    INSERT VALUE #( channel = zif_ca_ops_types=>gc_channel-email class_name = gc-channel_cl active = abap_true )
      INTO TABLE mo_dao->mt_channels.
    CLEAR ms_run.
    ms_run-area   = zcl_ca_ops_param_seed=>gc_test_area-first.
    ms_run-status = zif_ca_ops_types=>gc_run_status-error.
    ms_run-rag    = zif_ca_ops_types=>gc_rag-red.
    TRY.
        ms_run-run_id = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        cl_abap_unit_assert=>fail( msg = 'UUID for test run could not be created' ).
    ENDTRY.
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD given_rule.
    DATA ls_rule TYPE zif_ca_ops_types=>ty_alert_rule.
    ls_rule-rule_id         = gc-rule_id.
    ls_rule-area            = zcl_ca_ops_param_seed=>gc_test_area-first.
    ls_rule-min_severity    = zif_ca_ops_types=>gc_severity-error.
    ls_rule-min_rag         = iv_min_rag.
    ls_rule-channel         = zif_ca_ops_types=>gc_channel-email.
    ls_rule-destination     = gc-dest.
    ls_rule-escalation_dest = gc-escalation.
    ls_rule-esc_after_min   = iv_esc_after_min.
    ls_rule-esc_repeat_min  = 60.
    ls_rule-digest          = abap_true.
    ls_rule-active          = abap_true.
    INSERT ls_rule INTO TABLE mo_dao->mt_rules.
  ENDMETHOD.


  METHOD finding.
    rs_finding-object_type = 'LINE'.
    rs_finding-object_key  = iv_object_key.
    rs_finding-rule_id     = 'R14'.
    rs_finding-check_code  = gc-check.
    rs_finding-severity    = zif_ca_ops_types=>gc_severity-error.
    rs_finding-message     = 'Unmapped code'.
  ENDMETHOD.


  METHOD mark.
    INSERT VALUE #( object_type = 'LINE'
                    object_key  = iv_object_key
                    check_code  = gc-check
                    downtime_id = iv_downtime
                    corr_id     = COND #( WHEN iv_role IS NOT INITIAL THEN gc-parent_id )
                    corr_role   = iv_role ) INTO TABLE mo_dao->mt_marks.
  ENDMETHOD.


  METHOD dispatch.
    TRY.
        zcl_ca_ops_factory=>get_alert( )->dispatch( is_run = ms_run it_findings = it_findings ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |dispatch must not raise: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD escalate.
    TRY.
        rs_result = zcl_ca_ops_factory=>get_alert( )->escalate( zcl_ca_ops_param_seed=>gc_test_area-first ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |escalate must not raise: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD candidate.
    rs_candidate-run_id        = ms_run-run_id.
    rs_candidate-finding_no    = gc-finding_no.
    rs_candidate-first_seen_at = gc-hour_ago.
    rs_candidate-corr_role     = iv_role.
    rs_candidate-finding       = finding( 'S0001/1' ).
  ENDMETHOD.


  METHOD logged.
    LOOP AT mo_dao->mt_inserted TRANSPORTING NO FIELDS WHERE status = iv_status.
      rv_count += 1.
    ENDLOOP.
  ENDMETHOD.


  " Rule: a finding recorded in an approved planned downtime window is not alerted; the decision is logged D
  METHOD downtime_finding_not_alerted.
    given_rule( ).
    mark( iv_object_key = 'S0001/1' iv_downtime = gc-window_id ).
    dispatch( VALUE #( ( finding( 'S0001/1' ) ) ) ).
    cl_abap_unit_assert=>assert_initial( act = mo_channel->mt_delivered msg = 'Nothing is delivered' ).
    cl_abap_unit_assert=>assert_equals( act = logged( zif_ca_ops_types=>gc_alert_status-downtime ) exp = 1
                                        msg = 'One decision D in the alert log' ).
  ENDMETHOD.


  " Rule: a run-level alert (RAG) inside an approved area-wide window is held back and logged D
  METHOD area_window_holds_run_alert.
    given_rule( iv_min_rag = zif_ca_ops_types=>gc_rag-red ).
    INSERT VALUE #( window_id = gc-window_id area = zcl_ca_ops_param_seed=>gc_test_area-first
                    from_utc = gc-win_from to_utc = gc-win_to approved_by = gc-approver ) INTO TABLE mo_downtime->mt_windows.
    dispatch( VALUE #( ) ).
    cl_abap_unit_assert=>assert_initial( act = mo_channel->mt_delivered msg = 'The red run is not alerted' ).
    cl_abap_unit_assert=>assert_equals( act = logged( zif_ca_ops_types=>gc_alert_status-downtime ) exp = 1
                                        msg = 'Logged D' ).
  ENDMETHOD.


  " Rule: a correlated child is not alerted on its own (logged K); the parent's message names its open children
  METHOD child_held_back_parent_count.
    given_rule( ).
    mark( iv_object_key = 'S0001/1' iv_role = zif_ca_ops_resp_types=>gc_corr_role-parent ).
    mark( iv_object_key = 'S0001/2' iv_role = zif_ca_ops_resp_types=>gc_corr_role-child ).
    INSERT VALUE #( corr_id = gc-parent_id children = 1 ) INTO TABLE mo_dao->mt_children.
    dispatch( VALUE #( ( finding( 'S0001/1' ) ) ( finding( 'S0001/2' ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_channel->mt_delivered ) exp = 1 msg = 'One message' ).
    DATA(ls_message) = mo_channel->mt_delivered[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_message-item_count exp = 1 msg = 'Only the parent is listed' ).
    cl_abap_unit_assert=>assert_equals( act = ls_message-context-header-correlated_count exp = '1'
                                        msg = 'The parent names its child' ).
    cl_abap_unit_assert=>assert_equals( act = logged( zif_ca_ops_types=>gc_alert_status-correlated ) exp = 1
                                        msg = 'The held-back child is logged K' ).
  ENDMETHOD.


  " Rule: the alert e-mail carries the runbook link of its check
  METHOD runbook_link_in_the_message.
    given_rule( ).
    INSERT VALUE #( area = zcl_ca_ops_param_seed=>gc_test_area-first match_field = zif_ca_ops_ctl_types=>gc_match_field-check_code
                    match_value = gc-check runbook_url = gc-url first_action = 'Map the code' ) INTO TABLE mo_dao->mt_runbooks.
    dispatch( VALUE #( ( finding( 'S0001/1' ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_channel->mt_delivered[ 1 ]-context-header-runbook_url exp = gc-url
                                        msg = 'Runbook link of the check' ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( find( val = mo_channel->mt_delivered[ 1 ]-html sub = gc-url ) >= 0 )
                                      msg = 'The built-in layout shows the link' ).
  ENDMETHOD.


  " Rule: an open, unassigned exception past ESC_AFTER_MIN is escalated once to the escalation destination,
  " the step and the exception on the claim
  METHOD due_escalation_sent_once.
    given_rule( iv_esc_after_min = 30 ).
    INSERT candidate( ) INTO TABLE mo_dao->mt_candidates.
    DATA(ls_result) = escalate( ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-escalated exp = 1 msg = 'One escalation' ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_channel->mt_delivered ) exp = 1 msg = 'One message' ).
    cl_abap_unit_assert=>assert_equals( act = mo_channel->mt_delivered[ 1 ]-destination exp = gc-escalation
                                        msg = 'To the escalation destination' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_claims[ 1 ]-esc_step exp = 1 msg = 'Step 1 on the claim' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_claims[ 1 ]-finding_no exp = gc-finding_no
                                        msg = 'The exception on the claim' ).
  ENDMETHOD.


  " Rule: a step already sent is not sent again (the next job sends the next step when it is due)
  METHOD escalated_step_not_resent.
    given_rule( iv_esc_after_min = 30 ).
    INSERT candidate( ) INTO TABLE mo_dao->mt_candidates.
    escalate( ).
    DATA(ls_sent) = mo_dao->mt_claims[ 1 ].
    ls_sent-status = zif_ca_ops_types=>gc_alert_status-sent.
    INSERT ls_sent INTO TABLE mo_dao->mt_intent_log.
    CLEAR mo_channel->mt_delivered.
    DATA(ls_result) = escalate( ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-escalated exp = 0 msg = 'Nothing more' ).
    cl_abap_unit_assert=>assert_initial( act = mo_channel->mt_delivered msg = 'No second message' ).
  ENDMETHOD.


  " Rule: a correlated child escalates with its parent; an exception in planned downtime is held back
  METHOD child_and_downtime_skipped.
    given_rule( iv_esc_after_min = 30 ).
    INSERT candidate( zif_ca_ops_resp_types=>gc_corr_role-child ) INTO TABLE mo_dao->mt_candidates.
    DATA(ls_result) = escalate( ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-skipped exp = 1 msg = 'The child is skipped' ).
    CLEAR mo_dao->mt_candidates.
    INSERT candidate( ) INTO TABLE mo_dao->mt_candidates.
    INSERT VALUE #( window_id = gc-window_id area = zcl_ca_ops_param_seed=>gc_test_area-first
                    from_utc = gc-win_from to_utc = gc-win_to approved_by = gc-approver ) INTO TABLE mo_downtime->mt_windows.
    ls_result = escalate( ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-skipped exp = 1 msg = 'Planned downtime holds it back' ).
    cl_abap_unit_assert=>assert_initial( act = mo_channel->mt_delivered msg = 'Nothing is escalated' ).
  ENDMETHOD.


  " Rule: before ESC_AFTER_MIN nothing is escalated; a rule without time-based escalation never escalates
  METHOD not_yet_due_not_escalated.
    given_rule( iv_esc_after_min = 90 ).
    INSERT candidate( ) INTO TABLE mo_dao->mt_candidates.
    cl_abap_unit_assert=>assert_equals( act = escalate( )-escalated exp = 0 msg = '60 of 90 minutes' ).
    CLEAR mo_dao->mt_rules.
    given_rule( ).
    cl_abap_unit_assert=>assert_equals( act = escalate( )-escalated exp = 0 msg = 'Run-based rule' ).
    cl_abap_unit_assert=>assert_initial( act = mo_channel->mt_delivered msg = 'Nothing delivered' ).
  ENDMETHOD.


  " Rule: the escalation job needs ZCA_OPS 16 for the area (041)
  METHOD escalation_needs_execute.
    given_rule( iv_esc_after_min = 30 ).
    mo_auth->mv_refuse = abap_true.
    TRY.
        zcl_ca_ops_factory=>get_alert( )->escalate( zcl_ca_ops_param_seed=>gc_test_area-first ).
        cl_abap_unit_assert=>fail( msg = 'Without authorisation the job must stop' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '041'
                                            msg = 'Message 041' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
