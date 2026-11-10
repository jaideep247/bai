*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_alert_policy.clas.testclasses.abap
*& Purpose:
*& Domain tests of the alert rules: severity floor, patterns, run-level RAG,
*& quiet hours, throttling, escalation and message building. No doubles.
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Severity-ordered cap, full-selection severity, held-back count (audit A63).
*& 2026-11-06 | PCRE rule patterns: whole value, case ignored, invalid pattern named.
*& 2026-11-10 | mail_names_system_and_job: system ID in the subject, run and job in the body (message 803).
*& 2026-11-10 | ack_mail_subject_and_table: missing bank ACK subject and own table; other findings stay in
*&            | the general table.
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
        iv_object_key     TYPE zif_cd_ops_types=>ty_finding-object_key DEFAULT 'S0001/1'
      RETURNING
        VALUE(rs_finding) TYPE zif_cd_ops_types=>ty_finding.

    METHODS error_meets_error_floor      FOR TESTING.
    METHODS warning_below_error_floor    FOR TESTING.
    METHODS rule_pattern_filters_finding FOR TESTING.
    METHODS rule_pattern_is_whole_value  FOR TESTING.
    METHODS rule_pattern_ignores_case    FOR TESTING.
    METHODS invalid_pattern_is_named     FOR TESTING.
    METHODS inactive_rule_never_selected FOR TESTING.
    METHODS red_run_triggers_rag_rule    FOR TESTING.
    METHODS aborted_run_triggers_abort   FOR TESTING.
    METHODS quiet_hours_wrap_midnight    FOR TESTING.
    METHODS block_overrides_quiet_hours  FOR TESTING.
    METHODS throttle_window_suppresses   FOR TESTING.
    METHODS throttle_expires             FOR TESTING.
    METHODS escalates_after_n_runs       FOR TESTING.
    METHODS digest_is_one_message        FOR TESTING.
    METHODS mail_names_system_and_job    FOR TESTING.
    METHODS ack_mail_subject_and_table   FOR TESTING.
    METHODS per_finding_caps_at_max      FOR TESTING.
    METHODS html_values_are_escaped      FOR TESTING.
    METHODS blocker_after_cap_is_kept    FOR TESTING.
    METHODS per_finding_blocker_first    FOR TESTING.
    METHODS cap_order_is_stable          FOR TESTING.
ENDCLASS.


CLASS ltc_alert_policy IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( ).
    CLEAR: ms_rule, ms_run.
    ms_rule-rule_id      = gc_test-rule_id.
    ms_rule-pe_area       = zif_cd_ops_types=>gc_pe_area-ebs.
    ms_rule-min_severity = zif_cd_ops_types=>gc_severity-error.
    ms_rule-channel      = zif_cd_ops_types=>gc_channel-email.
    ms_rule-destination  = gc_test-dest.
    ms_rule-digest       = abap_true.
    ms_rule-max_items    = 2.
    ms_rule-active       = abap_true.
    ms_run-pe_area        = zif_cd_ops_types=>gc_pe_area-ebs.
    ms_run-status        = zif_cd_ops_types=>gc_run_status-success.
    ms_run-rag           = zif_cd_ops_types=>gc_rag-green.
  ENDMETHOD.


  METHOD finding.
    rs_finding-object_type = 'LINE'.
    rs_finding-object_key  = iv_object_key.
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


  " Rule pattern: only findings whose rule id matches the PCRE pattern are routed
  " The pattern describes the complete value: S0 does not cover S02
  METHOD rule_pattern_is_whole_value.
    TRY.
        ms_rule-rule_pattern = 'S0'.
        cl_abap_unit_assert=>assert_false(
          act = mo_cut->matches( is_rule    = ms_rule
                                 is_finding = finding( iv_severity = zif_cd_ops_types=>gc_severity-error
                                                       iv_rule_id  = 'S02' ) )
          msg = 'A pattern for part of the rule id must not match' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Case is ignored, as with the CP wildcards before
  METHOD rule_pattern_ignores_case.
    TRY.
        ms_rule-check_pattern = 'unmapped_.*'.
        DATA(ls_finding) = finding( iv_severity = zif_cd_ops_types=>gc_severity-error iv_rule_id = 'R14' ).
        ls_finding-check_code = 'UNMAPPED_BTC'.
        cl_abap_unit_assert=>assert_true(
          act = mo_cut->matches( is_rule = ms_rule is_finding = ls_finding )
          msg = 'Lower-case pattern must match the upper-case check code' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A pattern that does not compile is named (the router logs the rule as failed)
  METHOD invalid_pattern_is_named.
    TRY.
        ms_rule-group1_pattern = 'IFACE_(1'.
        cl_abap_unit_assert=>assert_equals( act = mo_cut->invalid_pattern( ms_rule )
                                            exp = CONV zif_cd_ops_types=>ty_pattern( 'IFACE_(1' )
                                            msg = 'The invalid group pattern must be named' ).
        ms_rule-group1_pattern = 'IFACE_.*'.
        cl_abap_unit_assert=>assert_initial( act = mo_cut->invalid_pattern( ms_rule )
                                             msg = 'Valid patterns name nothing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD rule_pattern_filters_finding.
    TRY.
        ms_rule-rule_pattern = 'S.*'.
        DATA(lt_findings) = VALUE zif_cd_ops_types=>tt_finding(
          ( finding( iv_severity = zif_cd_ops_types=>gc_severity-error iv_rule_id = 'S02' ) )
          ( finding( iv_severity = zif_cd_ops_types=>gc_severity-error iv_rule_id = 'R14' ) ) ).

        DATA(lt_selection) = mo_cut->select( it_rules    = VALUE #( ( ms_rule ) )
                                             is_run      = ms_run
                                             it_findings = lt_findings ).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_selection ) exp = 1
                                            msg = 'One rule must be selected' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_selection[ 1 ]-findings ) exp = 1
                                            msg = 'Only the S.* finding must be routed' ).
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


  " B12: the receiver sees the system in the subject and the run / job link in the body
  METHOD mail_names_system_and_job.
    DATA ls_selection TYPE zcl_cd_ops_alert_policy=>ty_selection.
    CONSTANTS lc_jobname TYPE btcjob VALUE 'ZCD_EBS_VALIDATE_JPMC'.
    CONSTANTS lc_jobcount TYPE btcjobcnt VALUE '11223344'.
    TRY.
        ms_run-jobname  = lc_jobname.
        ms_run-jobcount = lc_jobcount.
        ls_selection-rule     = ms_rule.
        ls_selection-findings = VALUE #( ( finding( zif_cd_ops_types=>gc_severity-error ) ) ).
        DATA(lt_messages) = mo_cut->build_messages( is_selection   = ls_selection
                                                    is_run         = ms_run
                                                    iv_destination = gc_test-dest ).
        DATA(ls_message) = lt_messages[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_message-subject(5)
                                            exp = |[{ sy-sysid }]|
                                            msg = 'The subject starts with the system ID' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( ls_message-text CS lc_jobname AND ls_message-text CS lc_jobcount )
                                          msg = 'The text names job name and count' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( ls_message-html CS lc_jobcount )
                                          msg = 'The HTML body names the job count' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " User request 2026-11-10: the missing bank ACK mail leads with the impact and shows the ACK
  " files in their own table; a finding without ACK evidence stays in the general table
  METHOD ack_mail_subject_and_table.
    DATA ls_selection TYPE zcl_cd_ops_alert_policy=>ty_selection.
    CONSTANTS lc_file TYPE string VALUE `ACH_JPMC_20261110_01.txt`.
    TRY.
        DATA(ls_ack) = finding( iv_severity = zif_cd_ops_types=>gc_severity-error ).
        ls_ack-details = zcl_cd_ops_ack_mail=>marker( ) && cl_abap_char_utilities=>newline
                      && zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-file_name iv_value = lc_file )
                      && cl_abap_char_utilities=>newline
                      && zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-payments iv_value = `120` ).
        DATA(ls_other) = finding( iv_severity = zif_cd_ops_types=>gc_severity-error
                                  iv_object_key = 'OTHER_FILE' ).
        ms_run-pe_area        = zif_cd_ops_types=>gc_pe_area-file_monitor.
        ls_selection-rule     = ms_rule.
        ls_selection-findings = VALUE #( ( ls_ack ) ( ls_other ) ).
        DATA(lt_messages) = mo_cut->build_messages( is_selection   = ls_selection
                                                    is_run         = ms_run
                                                    iv_destination = gc_test-dest ).
        DATA(ls_message) = lt_messages[ 1 ].
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( find( val = ls_message-subject sub = |[{ sy-sysid }][FMON][E] | ) = 0 )
          msg = 'Subject: [system][area][severity] first' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( ls_message-subject CS zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_types=>gc_ack_msg-subject
                                                                      iv_v1    = 1
                                                                      iv_v2    = 120
                                                                      iv_v3    = zcl_cd_ops_util=>text(
                                                                                   zif_cd_ops_types=>gc_ack_msg-unknown ) ) )
          msg = 'Missing bank ACK: 1 file, 120 payments, amount unknown' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( ls_message-html CS lc_file )
                                          msg = 'The ACK file is in the ACK table' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( ls_message-html CS 'OTHER_FILE' )
                                          msg = 'The other finding stays in the general table' ).
        cl_abap_unit_assert=>assert_equals( act = lines( zcl_cd_ops_ack_mail=>rows( ls_selection-findings ) ) exp = 1
                                            msg = 'The other finding is no row of the ACK table' ).
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


  " Audit A63: a blocker placed after the cap is still shown; the digest severity and the
  " subject come from the complete selection and the held-back count is in the message
  METHOD blocker_after_cap_is_kept.
    DATA ls_selection TYPE zcl_cd_ops_alert_policy=>ty_selection.
    TRY.
        ls_selection-rule     = ms_rule.
        ls_selection-findings = VALUE #( ( finding( iv_severity = zif_cd_ops_types=>gc_severity-warning
                                                    iv_message  = 'first warning' ) )
                                         ( finding( iv_severity = zif_cd_ops_types=>gc_severity-error
                                                    iv_message  = 'an error' ) )
                                         ( finding( iv_severity = zif_cd_ops_types=>gc_severity-warning
                                                    iv_message  = 'second warning' ) )
                                         ( finding( iv_severity = zif_cd_ops_types=>gc_severity-block
                                                    iv_message  = 'the blocker' ) ) ).
        DATA(lt_messages) = mo_cut->build_messages( is_selection   = ls_selection
                                                    is_run         = ms_run
                                                    iv_destination = gc_test-dest ).
        DATA(ls_message) = lt_messages[ 1 ].
        cl_abap_unit_assert=>assert_char_cp( act = ls_message-text exp = '*the blocker*'
                                             msg = 'The blocker behind the cap must be shown' ).
        cl_abap_unit_assert=>assert_char_cp( act = ls_message-text exp = '*an error*'
                                             msg = 'The error ranks before the warnings' ).
        cl_abap_unit_assert=>assert_char_np( act = ls_message-text exp = '*first warning*'
                                             msg = 'Warnings are the ones held back' ).
        cl_abap_unit_assert=>assert_equals( act = ls_message-severity
                                            exp = zif_cd_ops_types=>gc_severity-block
                                            msg = 'Digest severity is the worst of the selection' ).
        cl_abap_unit_assert=>assert_equals( act = ls_message-item_count exp = 4
                                            msg = 'The digest counts the complete selection' ).
        DATA(lv_more) = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_types=>gc_msg-alert_more_findings
                                               iv_v1    = 2 ).
        cl_abap_unit_assert=>assert_char_cp( act = ls_message-text exp = |*{ lv_more }*|
                                             msg = 'The held-back count must be in the text' ).
        cl_abap_unit_assert=>assert_char_cp( act = ls_message-html exp = |*{ lv_more }*|
                                             msg = 'The held-back count must be in the HTML' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A63: per-finding mode sends the blocker first; the last message names the rest
  METHOD per_finding_blocker_first.
    DATA ls_selection TYPE zcl_cd_ops_alert_policy=>ty_selection.
    TRY.
        ms_rule-digest = abap_false.
        ls_selection-rule     = ms_rule.
        ls_selection-findings = VALUE #( ( finding( zif_cd_ops_types=>gc_severity-error ) )
                                         ( finding( zif_cd_ops_types=>gc_severity-error ) )
                                         ( finding( zif_cd_ops_types=>gc_severity-block ) ) ).
        DATA(lt_messages) = mo_cut->build_messages( is_selection   = ls_selection
                                                    is_run         = ms_run
                                                    iv_destination = gc_test-dest ).
        cl_abap_unit_assert=>assert_equals( act = lt_messages[ 1 ]-severity
                                            exp = zif_cd_ops_types=>gc_severity-block
                                            msg = 'The blocker must be sent first' ).
        DATA(lv_more) = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_types=>gc_msg-alert_more_findings
                                               iv_v1    = 1 ).
        cl_abap_unit_assert=>assert_char_cp( act = lt_messages[ lines( lt_messages ) ]-text
                                             exp = |*{ lv_more }*|
                                             msg = 'The last message must name the held-back finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A63: equal severities are capped in a stable order, whatever the input order
  METHOD cap_order_is_stable.
    DATA ls_selection TYPE zcl_cd_ops_alert_policy=>ty_selection.
    TRY.
        ms_rule-max_items = 1.
        ls_selection-rule     = ms_rule.
        ls_selection-findings = VALUE #( ( finding( iv_severity   = zif_cd_ops_types=>gc_severity-error
                                                    iv_message    = 'line two'
                                                    iv_object_key = 'S0001/2' ) )
                                         ( finding( iv_severity   = zif_cd_ops_types=>gc_severity-error
                                                    iv_message    = 'line one'
                                                    iv_object_key = 'S0001/1' ) ) ).
        DATA(lt_messages) = mo_cut->build_messages( is_selection   = ls_selection
                                                    is_run         = ms_run
                                                    iv_destination = gc_test-dest ).
        cl_abap_unit_assert=>assert_char_cp( act = lt_messages[ 1 ]-text exp = '*line one*'
                                             msg = 'Ties are broken by object key, not input order' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
