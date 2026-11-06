*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_alert_policy.clas.testclasses.abap
*& Purpose:
*& Domain tests of the alert rules: severity floor, patterns, run-level RAG,
*& quiet hours, throttling, escalation and message building. No doubles.
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
CLASS ltc_alert_policy DEFINITION FINAL FOR TESTING
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
        hour_ago   TYPE timestampl VALUE '20261105070000.0000000',
        night      TYPE t VALUE '230000',
        day        TYPE t VALUE '100000',
      END OF gc_test.

    DATA mo_cut  TYPE REF TO zcl_cd_ops_alert_policy.
    DATA ms_rule TYPE zif_cd_ops_types=>ty_alert_rule.
    DATA ms_run  TYPE zif_cd_ops_types=>ty_run.

    METHODS setup.
    METHODS finding
      IMPORTING
        iv_severity       TYPE zif_cd_ops_types=>ty_severity
        iv_rule_id        TYPE zif_cd_ops_types=>ty_rule_id DEFAULT 'R14'
        iv_message        TYPE zif_cd_ops_types=>ty_message DEFAULT 'test finding'
      RETURNING
        VALUE(rs_finding) TYPE zif_cd_ops_types=>ty_finding.

    METHODS error_meets_error_floor      FOR TESTING.
    METHODS warning_below_error_floor    FOR TESTING.
    METHODS rule_pattern_filters_finding FOR TESTING.
    METHODS inactive_rule_never_selected FOR TESTING.
    METHODS red_run_triggers_rag_rule    FOR TESTING.
    METHODS aborted_run_triggers_abort   FOR TESTING.
    METHODS quiet_hours_wrap_midnight    FOR TESTING.
    METHODS block_overrides_quiet_hours  FOR TESTING.
    METHODS throttle_window_suppresses   FOR TESTING.
    METHODS throttle_expires             FOR TESTING.
    METHODS escalates_after_n_runs       FOR TESTING.
    METHODS digest_is_one_message        FOR TESTING.
    METHODS per_finding_caps_at_max      FOR TESTING.
    METHODS html_values_are_escaped      FOR TESTING.
ENDCLASS.


CLASS ltc_alert_policy IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( ).
    CLEAR: ms_rule, ms_run.
    ms_rule-rule_id      = gc_test-rule_id.
    ms_rule-module       = zif_cd_ops_types=>gc_module-ebs.
    ms_rule-min_severity = zif_cd_ops_types=>gc_severity-error.
    ms_rule-channel      = zif_cd_ops_types=>gc_channel-email.
    ms_rule-destination  = gc_test-dest.
    ms_rule-digest       = abap_true.
    ms_rule-max_items    = 2.
    ms_rule-active       = abap_true.
    ms_run-module        = zif_cd_ops_types=>gc_module-ebs.
    ms_run-status        = zif_cd_ops_types=>gc_run_status-success.
    ms_run-rag           = zif_cd_ops_types=>gc_rag-green.
  ENDMETHOD.


  METHOD finding.
    rs_finding-object_type = 'LINE'.
    rs_finding-object_key  = 'S0001/1'.
    rs_finding-rule_id     = iv_rule_id.
    rs_finding-check_code  = 'UNMAPPED_BTC'.
    rs_finding-severity    = iv_severity.
    rs_finding-message     = iv_message.
  ENDMETHOD.


  " Severity floor: an E finding meets a rule with minimum severity E
  METHOD error_meets_error_floor.
    TRY.
        cl_abap_unit_assert=>assert_true(
          act = mo_cut->matches( is_rule    = ms_rule
                                 is_finding = finding( zif_cd_ops_types=>gc_severity-error ) )
          msg = 'E finding must match a rule with floor E' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Severity floor: a W finding does not reach a rule with minimum severity E
  METHOD warning_below_error_floor.
    TRY.
        cl_abap_unit_assert=>assert_false(
          act = mo_cut->matches( is_rule    = ms_rule
                                 is_finding = finding( zif_cd_ops_types=>gc_severity-warning ) )
          msg = 'W finding must not match a rule with floor E' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule pattern: only findings whose rule id matches the CP pattern are routed
  METHOD rule_pattern_filters_finding.
    TRY.
        ms_rule-rule_pattern = 'S*'.
        DATA(lt_findings) = VALUE zif_cd_ops_types=>tt_finding(
          ( finding( iv_severity = zif_cd_ops_types=>gc_severity-error iv_rule_id = 'S02' ) )
          ( finding( iv_severity = zif_cd_ops_types=>gc_severity-error iv_rule_id = 'R14' ) ) ).

        DATA(lt_selection) = mo_cut->select( it_rules    = VALUE #( ( ms_rule ) )
                                             is_run      = ms_run
                                             it_findings = lt_findings ).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_selection ) exp = 1
                                            msg = 'One rule must be selected' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_selection[ 1 ]-findings ) exp = 1
                                            msg = 'Only the S* finding must be routed' ).
        cl_abap_unit_assert=>assert_equals( act = lt_selection[ 1 ]-findings[ 1 ]-rule_id
                                            exp = CONV zif_cd_ops_types=>ty_rule_id( 'S02' )
                                            msg = 'The routed finding must be S02' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " An inactive rule is never selected, whatever the findings
  METHOD inactive_rule_never_selected.
    TRY.
        ms_rule-active = abap_false.
        DATA(lt_selection) = mo_cut->select(
          it_rules    = VALUE #( ( ms_rule ) )
          is_run      = ms_run
          it_findings = VALUE #( ( finding( zif_cd_ops_types=>gc_severity-block ) ) ) ).
        cl_abap_unit_assert=>assert_initial( act = lt_selection
                                             msg = 'Inactive rule must not be selected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Run-level rule: a red run triggers a rule with minimum RAG amber even without findings
  METHOD red_run_triggers_rag_rule.
    TRY.
        ms_rule-min_rag = zif_cd_ops_types=>gc_rag-amber.
        ms_run-rag      = zif_cd_ops_types=>gc_rag-red.
        DATA(lt_selection) = mo_cut->select( it_rules    = VALUE #( ( ms_rule ) )
                                             is_run      = ms_run
                                             it_findings = VALUE #( ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_selection ) exp = 1
                                            msg = 'Red run must trigger an amber run-level rule' ).
        cl_abap_unit_assert=>assert_true( act = lt_selection[ 1 ]-run_level
                                          msg = 'Selection must be flagged run-level' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A run aborted by the circuit breaker alerts every rule with on_abort set
  METHOD aborted_run_triggers_abort.
    TRY.
        ms_rule-on_abort = abap_true.
        ms_run-status    = zif_cd_ops_types=>gc_run_status-aborted.
        DATA(lt_selection) = mo_cut->select( it_rules    = VALUE #( ( ms_rule ) )
                                             is_run      = ms_run
                                             it_findings = VALUE #( ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_selection ) exp = 1
                                            msg = 'Aborted run must trigger an on-abort rule' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Quiet hours 22:00-06:00 wrap midnight: 23:00 is quiet, 10:00 is not
  METHOD quiet_hours_wrap_midnight.
    TRY.
        ms_rule-quiet_from = '220000'.
        ms_rule-quiet_to   = '060000'.
        cl_abap_unit_assert=>assert_true(
          act = mo_cut->is_quiet( is_rule = ms_rule iv_time = gc_test-night
                                  iv_worst_severity = zif_cd_ops_types=>gc_severity-error )
          msg = '23:00 must be inside 22:00-06:00' ).
        cl_abap_unit_assert=>assert_false(
          act = mo_cut->is_quiet( is_rule = ms_rule iv_time = gc_test-day
                                  iv_worst_severity = zif_cd_ops_types=>gc_severity-error )
          msg = '10:00 must be outside 22:00-06:00' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A block (B) is never held back by quiet hours - money must not wait for the morning
  METHOD block_overrides_quiet_hours.
    TRY.
        ms_rule-quiet_from = '220000'.
        ms_rule-quiet_to   = '060000'.
        cl_abap_unit_assert=>assert_false(
          act = mo_cut->is_quiet( is_rule = ms_rule iv_time = gc_test-night
                                  iv_worst_severity = zif_cd_ops_types=>gc_severity-block )
          msg = 'Severity B must override quiet hours' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Throttle 30 minutes: a send 10 minutes ago suppresses the next alert
  METHOD throttle_window_suppresses.
    TRY.
        ms_rule-throttle_min = 30.
        cl_abap_unit_assert=>assert_true(
          act = mo_cut->is_throttled( is_rule = ms_rule iv_last_sent = gc_test-ten_ago
                                      iv_now = gc_test-now )
          msg = 'A send inside the throttle window must suppress' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Throttle 30 minutes: a send an hour ago no longer suppresses
  METHOD throttle_expires.
    TRY.
        ms_rule-throttle_min = 30.
        cl_abap_unit_assert=>assert_false(
          act = mo_cut->is_throttled( is_rule = ms_rule iv_last_sent = gc_test-hour_ago
                                      iv_now = gc_test-now )
          msg = 'A send outside the throttle window must not suppress' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Escalation after 3 consecutive alerting runs adds the escalation destination
  METHOD escalates_after_n_runs.
    TRY.
        ms_rule-escalate_after  = 3.
        ms_rule-escalation_dest = gc_test-escalation.
        cl_abap_unit_assert=>assert_false( act = mo_cut->needs_escalation( is_rule = ms_rule iv_consecutive = 2 )
                                           msg = 'Two runs must not escalate' ).
        cl_abap_unit_assert=>assert_true( act = mo_cut->needs_escalation( is_rule = ms_rule iv_consecutive = 3 )
                                          msg = 'Three runs must escalate' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Digest mode: all findings of a rule and run go out as one message
  METHOD digest_is_one_message.
    DATA ls_selection TYPE zcl_cd_ops_alert_policy=>ty_selection.
    TRY.
        ls_selection-rule     = ms_rule.
        ls_selection-findings = VALUE #( ( finding( zif_cd_ops_types=>gc_severity-error ) )
                                         ( finding( zif_cd_ops_types=>gc_severity-block ) ) ).
        DATA(lt_messages) = mo_cut->build_messages( is_selection   = ls_selection
                                                    is_run         = ms_run
                                                    iv_destination = gc_test-dest ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_messages ) exp = 1
                                            msg = 'Digest must produce one message' ).
        cl_abap_unit_assert=>assert_equals( act = lt_messages[ 1 ]-item_count exp = 2
                                            msg = 'Digest must carry both findings' ).
        cl_abap_unit_assert=>assert_equals( act = lt_messages[ 1 ]-severity
                                            exp = zif_cd_ops_types=>gc_severity-block
                                            msg = 'Digest severity is the worst finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Per-finding mode is capped at max_items messages (no alert storm)
  METHOD per_finding_caps_at_max.
    DATA ls_selection TYPE zcl_cd_ops_alert_policy=>ty_selection.
    TRY.
        ms_rule-digest = abap_false.
        ls_selection-rule     = ms_rule.
        ls_selection-findings = VALUE #( ( finding( zif_cd_ops_types=>gc_severity-error ) )
                                         ( finding( zif_cd_ops_types=>gc_severity-error ) )
                                         ( finding( zif_cd_ops_types=>gc_severity-error ) ) ).
        DATA(lt_messages) = mo_cut->build_messages( is_selection   = ls_selection
                                                    is_run         = ms_run
                                                    iv_destination = gc_test-dest ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_messages ) exp = ms_rule-max_items
                                            msg = 'Per-finding messages must stop at max_items' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Finding text is HTML-escaped in the message body
  METHOD html_values_are_escaped.
    DATA ls_selection TYPE zcl_cd_ops_alert_policy=>ty_selection.
    TRY.
        ls_selection-rule     = ms_rule.
        ls_selection-findings = VALUE #( ( finding( iv_severity = zif_cd_ops_types=>gc_severity-error
                                                    iv_message  = '<script>x</script>' ) ) ).
        DATA(lt_messages) = mo_cut->build_messages( is_selection   = ls_selection
                                                    is_run         = ms_run
                                                    iv_destination = gc_test-dest ).
        cl_abap_unit_assert=>assert_char_np( act = lt_messages[ 1 ]-html exp = '*<script>*'
                                             msg = 'Raw markup must not reach the HTML body' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
