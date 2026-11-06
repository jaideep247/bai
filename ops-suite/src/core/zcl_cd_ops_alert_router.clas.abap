*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_alert_router.clas.abap
*& Purpose:
*& Configurable alert router for every payment engine area. Reads ZCD_OPS_ALERT_RULE and
*& ZCD_OPS_ALERT_CHN through the alert DAO, lets ZCL_CD_OPS_ALERT_POLICY decide
*& (severity, patterns, quiet hours, throttling, escalation) and delivers via
*& channel plug-ins. Every decision is logged in ZCD_OPS_ALERT_LOG. A failing
*& channel is logged and never aborts the calling run. Test-mode runs never alert.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Durable claim before send, carried-forward exceptions not re-alerted, escalation over run
*&              history, escalation override, direct send failures surfaced (audit A17, A45, A46).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - configurable alert router</p>
CLASS zcl_cd_ops_alert_router DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_alert.

    CONSTANTS gc_default_window_hours TYPE i VALUE 24.
    CONSTANTS gc_email_class TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_OPS_CHN_EMAIL'.

  PRIVATE SECTION.
    CONSTANTS gc_intent_algorithm TYPE string VALUE `SHA1`.
    CONSTANTS gc_seconds_per_hour TYPE i VALUE 3600.
    DATA mo_policy TYPE REF TO zcl_cd_ops_alert_policy.
    DATA mt_log    TYPE zif_cd_ops_types=>tt_alert_log.
    "! Findings of the run raised again only by carry-forward (not re-alerted, A17)
    DATA mt_repeat TYPE zif_cd_ops_types=>tt_repeat_key.

    METHODS route_selection
      IMPORTING
        is_selection TYPE zcl_cd_ops_alert_policy=>ty_selection
        is_run       TYPE zif_cd_ops_types=>ty_run
        it_channels  TYPE zif_cd_ops_types=>tt_alert_channel
        io_dao       TYPE REF TO zif_cd_ops_alert_dao.

    METHODS deliver_messages
      IMPORTING
        it_messages TYPE zif_cd_ops_types=>tt_alert_message
        is_channel  TYPE zif_cd_ops_types=>ty_alert_channel
        is_run      TYPE zif_cd_ops_types=>ty_run
        io_dao      TYPE REF TO zif_cd_ops_alert_dao.
    "! Consecutive runs of the payment engine area (newest first, current included) in
    "! which the rule fired; a run without an alert of the rule ends the series (A46)
    METHODS count_consecutive
      IMPORTING
        it_log          TYPE zif_cd_ops_types=>tt_alert_log
        is_run          TYPE zif_cd_ops_types=>ty_run
        iv_since        TYPE timestampl
      RETURNING
        VALUE(rv_count) TYPE i.
    "! Alert intent: SHA-1 over rule, run, channel, destination and subject (A17)
    METHODS intent_key
      IMPORTING
        is_message    TYPE zif_cd_ops_types=>ty_alert_message
      RETURNING
        VALUE(rv_key) TYPE zif_cd_ops_types=>ty_intent_key.

    METHODS add_log
      IMPORTING
        iv_rule_id     TYPE zif_cd_ops_types=>ty_rule_id
        iv_channel     TYPE zif_cd_ops_types=>ty_channel
        is_run         TYPE zif_cd_ops_types=>ty_run
        iv_status      TYPE char1
        iv_destination TYPE zif_cd_ops_types=>ty_alert_dest OPTIONAL
        iv_subject     TYPE clike OPTIONAL
        iv_error       TYPE clike OPTIONAL
        iv_alert_id    TYPE zif_cd_ops_types=>ty_run_id OPTIONAL.

    METHODS new_id
      RETURNING
        VALUE(rv_id) TYPE zif_cd_ops_types=>ty_run_id.

ENDCLASS.



CLASS zcl_cd_ops_alert_router IMPLEMENTATION.

  METHOD zif_cd_ops_alert~dispatch.
    IF is_run-test_mode = abap_true.
      RETURN.
    ENDIF.
    CLEAR mt_log.
    mo_policy = NEW #( ).

    DATA(lo_dao) = zcl_cd_ops_factory=>get_alert_dao( ).
    DATA(lt_rules) = lo_dao->get_rules( is_run-pe_area ).
    IF lt_rules IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_channels) = lo_dao->get_channels( ).
    mt_repeat = lo_dao->get_repeat_keys( is_run-run_id ).
    DATA(lt_selection) = mo_policy->select( it_rules    = lt_rules
                                            is_run      = is_run
                                            it_findings = it_findings ).
    LOOP AT lt_selection INTO DATA(ls_selection).
      route_selection( is_selection = ls_selection
                       is_run       = is_run
                       it_channels  = lt_channels
                       io_dao       = lo_dao ).
    ENDLOOP.

    IF mt_log IS NOT INITIAL.
      lo_dao->insert_log( mt_log ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_alert~send.
    DATA ls_message TYPE zif_cd_ops_types=>ty_alert_message.
    DATA ls_run     TYPE zif_cd_ops_types=>ty_run.

    CLEAR mt_log.
    DATA(lo_store) = zcl_cd_ops_factory=>get_store( ).
    DATA(lv_recipients) = lo_store->get_param(
      iv_name    = CONV #( |ALERT_{ iv_route }| )
      iv_default = lo_store->get_param( 'ALERT_DEFAULT' ) ).
    DATA(lo_dao) = zcl_cd_ops_factory=>get_alert_dao( ).
    " A45: no recipient is a delivery failure the caller hears about, not a silent return
    IF zcl_cd_ops_util=>split_list( lv_recipients ) IS INITIAL.
      add_log( iv_rule_id = CONV #( iv_route ) iv_channel = zif_cd_ops_types=>gc_channel-email is_run = ls_run
               iv_status = zif_cd_ops_types=>gc_alert_status-failed iv_subject = iv_subject
               iv_error = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_types=>gc_msg-no_recipient iv_v1 = iv_route ) ).
      lo_dao->insert_log( mt_log ).
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e021(zcd_ops) WITH iv_route.
    ENDIF.
    DATA(lt_channels) = lo_dao->get_channels( ).
    DATA(ls_channel) = VALUE #( lt_channels[ channel = zif_cd_ops_types=>gc_channel-email ] OPTIONAL ).
    IF ls_channel-class_name IS INITIAL.
      ls_channel-channel    = zif_cd_ops_types=>gc_channel-email.
      ls_channel-class_name = gc_email_class.
      ls_channel-active     = abap_true.
    ENDIF.
    " A45: a maintained channel switched off is respected by the direct send as well
    IF ls_channel-active = abap_false.
      add_log( iv_rule_id = CONV #( iv_route ) iv_channel = ls_channel-channel is_run = ls_run
               iv_status = zif_cd_ops_types=>gc_alert_status-failed iv_subject = iv_subject
               iv_error = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_types=>gc_msg-channel_inactive
                                               iv_v1    = ls_channel-channel ) ).
      lo_dao->insert_log( mt_log ).
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e007(zcd_ops) WITH ls_channel-channel.
    ENDIF.

    ls_message-alert_id    = new_id( ).
    ls_message-rule_id     = iv_route.
    ls_message-channel     = zif_cd_ops_types=>gc_channel-email.
    ls_message-destination = lv_recipients.
    ls_message-subject     = iv_subject.
    ls_message-html        = iv_html.
    ls_message-text        = iv_subject.
    ls_message-severity    = zif_cd_ops_types=>gc_severity-info.
    ls_message-extnumber   = |{ iv_route }|.
    TRY.
        DATA(lo_channel) = CAST zif_cd_ops_alert_channel(
          zcl_cd_ops_factory=>get_plugin( ls_channel-class_name ) ).
        lo_channel->deliver( ls_message ).
        add_log( iv_rule_id = CONV #( iv_route ) iv_channel = ls_message-channel is_run = ls_run
                 iv_status = zif_cd_ops_types=>gc_alert_status-sent
                 iv_destination = ls_message-destination iv_subject = iv_subject
                 iv_alert_id = ls_message-alert_id ).
        lo_dao->insert_log( mt_log ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        add_log( iv_rule_id = CONV #( iv_route ) iv_channel = ls_message-channel is_run = ls_run
                 iv_status = zif_cd_ops_types=>gc_alert_status-failed
                 iv_destination = ls_message-destination iv_subject = iv_subject
                 iv_error = lx_error->get_text( ) iv_alert_id = ls_message-alert_id ).
        lo_dao->insert_log( mt_log ).
        RAISE EXCEPTION lx_error.
      CATCH cx_sy_move_cast_error INTO DATA(lx_cast).
        add_log( iv_rule_id = CONV #( iv_route ) iv_channel = ls_message-channel is_run = ls_run
                 iv_status = zif_cd_ops_types=>gc_alert_status-failed
                 iv_error = lx_cast->get_text( ) iv_alert_id = ls_message-alert_id ).
        lo_dao->insert_log( mt_log ).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e032(zcd_ops) WITH ls_channel-class_name 'ZIF_CD_OPS_ALERT_CHANNEL'.
    ENDTRY.
  ENDMETHOD.


  METHOD route_selection.
    DATA(lo_clock) = zcl_cd_ops_factory=>get_clock( ).
    DATA(lv_now) = lo_clock->now( ).
    DATA(ls_rule) = is_selection-rule.

    DATA(lv_worst) = zcl_cd_ops_util=>worst_severity( is_selection-findings ).
    IF lv_worst IS INITIAL.
      lv_worst = zif_cd_ops_types=>gc_severity-error.
    ENDIF.

    IF mo_policy->is_quiet( is_rule = ls_rule iv_time = lo_clock->time( ) iv_worst_severity = lv_worst ) = abap_true.
      add_log( iv_rule_id = ls_rule-rule_id iv_channel = ls_rule-channel is_run = is_run
               iv_status = zif_cd_ops_types=>gc_alert_status-quiet ).
      RETURN.
    ENDIF.

    DATA(lv_window_h) = CONV i( zcl_cd_ops_util=>to_decimal(
      iv_value   = zcl_cd_ops_factory=>get_store( )->get_param( iv_name = 'ALERT_ESCALATION_WINDOW_H'
                                                                iv_default = |{ gc_default_window_hours }| )
      iv_default = gc_default_window_hours ) ).
    DATA(lv_since) = lv_now.
    TRY.
        lv_since = cl_abap_tstmp=>add( tstmp = lv_now secs = - lv_window_h * gc_seconds_per_hour ).
      CATCH cx_parameter_invalid_range cx_parameter_invalid_type.
        CLEAR lv_since.
    ENDTRY.
    DATA(lt_log) = io_dao->get_log( iv_rule_id = ls_rule-rule_id iv_since = lv_since ).
    " A46: escalation is decided first - over the actual run history
    DATA(lv_escalate) = mo_policy->needs_escalation(
      is_rule        = ls_rule
      iv_consecutive = count_consecutive( it_log = lt_log is_run = is_run iv_since = lv_since ) ).
    DATA(lv_last_sent) = VALUE timestampl( ).
    " A17: a claim in delivery counts like a sent alert for throttling
    LOOP AT lt_log INTO DATA(ls_log) WHERE status = zif_cd_ops_types=>gc_alert_status-sent
                                        OR status = zif_cd_ops_types=>gc_alert_status-claimed
                                        OR status = zif_cd_ops_types=>gc_alert_status-partial.
      IF ls_log-sent_at > lv_last_sent.
        lv_last_sent = ls_log-sent_at.
      ENDIF.
    ENDLOOP.
    IF mo_policy->is_throttled( is_rule = ls_rule iv_last_sent = lv_last_sent iv_now = lv_now ) = abap_true
       AND NOT ( lv_escalate = abap_true AND ls_rule-esc_override = abap_true ).
      add_log( iv_rule_id = ls_rule-rule_id iv_channel = ls_rule-channel is_run = is_run
               iv_status = zif_cd_ops_types=>gc_alert_status-throttled ).
      RETURN.
    ENDIF.
    DATA(ls_channel) = VALUE #( it_channels[ channel = ls_rule-channel ] OPTIONAL ).
    IF ls_channel IS INITIAL OR ls_channel-active = abap_false.
      add_log( iv_rule_id = ls_rule-rule_id iv_channel = ls_rule-channel is_run = is_run
               iv_status = zif_cd_ops_types=>gc_alert_status-failed
               iv_error = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_types=>gc_msg-channel_inactive
                                               iv_v1    = ls_rule-channel ) ).
      RETURN.
    ENDIF.
    " A17: findings raised again only by carry-forward are not re-alerted (unless escalating)
    DATA(ls_selection) = is_selection.
    IF lv_escalate = abap_false AND mt_repeat IS NOT INITIAL AND ls_selection-findings IS NOT INITIAL.
      CLEAR ls_selection-findings.
      LOOP AT is_selection-findings INTO DATA(ls_finding).
        IF NOT line_exists( mt_repeat[ object_type = ls_finding-object_type
                                       object_key  = ls_finding-object_key
                                       check_code  = ls_finding-check_code ] ).
          INSERT ls_finding INTO TABLE ls_selection-findings.
        ENDIF.
      ENDLOOP.
      IF ls_selection-findings IS INITIAL.
        add_log( iv_rule_id = ls_rule-rule_id iv_channel = ls_rule-channel is_run = is_run
                 iv_status = zif_cd_ops_types=>gc_alert_status-repeat ).
        RETURN.
      ENDIF.
    ENDIF.
    DATA(lv_destination) = COND zif_cd_ops_types=>ty_alert_dest(
      WHEN ls_rule-destination IS NOT INITIAL THEN ls_rule-destination
      ELSE ls_channel-destination ).
    IF lv_escalate = abap_true.
      lv_destination = |{ lv_destination },{ ls_rule-escalation_dest }|.
    ENDIF.
    deliver_messages( it_messages = mo_policy->build_messages( is_selection   = ls_selection
                                                              is_run         = is_run
                                                              iv_destination = lv_destination )
                      is_channel  = ls_channel
                      is_run      = is_run
                      io_dao      = io_dao ).
  ENDMETHOD.


  METHOD deliver_messages.
    DATA lo_channel TYPE REF TO zif_cd_ops_alert_channel.
    TRY.
        lo_channel = CAST zif_cd_ops_alert_channel( zcl_cd_ops_factory=>get_plugin( is_channel-class_name ) ).
      CATCH zcx_cd_ops_error cx_sy_move_cast_error INTO DATA(lx_wiring).
        LOOP AT it_messages INTO DATA(ls_failed).
          add_log( iv_rule_id = ls_failed-rule_id iv_channel = ls_failed-channel is_run = is_run
                   iv_status = zif_cd_ops_types=>gc_alert_status-failed
                   iv_destination = ls_failed-destination iv_subject = ls_failed-subject
                   iv_error = lx_wiring->get_text( ) ).
        ENDLOOP.
        RETURN.
    ENDTRY.

    DATA(lo_store) = zcl_cd_ops_factory=>get_store( ).
    LOOP AT it_messages INTO DATA(ls_message).
      ls_message-alert_id  = new_id( ).
      ls_message-extnumber = |{ is_run-pe_area }/{ is_run-run_id }/{ ls_message-rule_id }|.
      " A17: durable claim first (status C, committed) - a second dispatcher sees it and a
      " failure after the external send still leaves evidence of the delivery attempt
      DATA(ls_claim) = VALUE zif_cd_ops_types=>ty_alert_log( alert_id    = ls_message-alert_id
                                                            rule_id     = ls_message-rule_id
                                                            channel     = ls_message-channel
                                                            run_id      = is_run-run_id
                                                            pe_area     = is_run-pe_area
                                                            sent_at     = zcl_cd_ops_factory=>get_clock( )->now( )
                                                            status      = zif_cd_ops_types=>gc_alert_status-claimed
                                                            destination = ls_message-destination
                                                            subject     = ls_message-subject
                                                            intent_key  = intent_key( ls_message ) ).
      IF io_dao->claim( ls_claim ) = abap_true.
        CONTINUE.
      ENDIF.
      lo_store->commit( ).
      DATA(ls_final) = ls_claim.
      TRY.
          lo_channel->deliver( ls_message ).
          ls_final-status = zif_cd_ops_types=>gc_alert_status-sent.
        CATCH zcx_cd_ops_error INTO DATA(lx_ops).
          " A45: a partly written application log is PARTIAL, not SENT
          ls_final-status = COND #( WHEN lx_ops->if_t100_message~t100key-msgno = zif_cd_ops_types=>gc_msg-applog_partial
                                    THEN zif_cd_ops_types=>gc_alert_status-partial
                                    ELSE zif_cd_ops_types=>gc_alert_status-failed ).
          ls_final-error = lx_ops->get_text( ).
        CATCH cx_root INTO DATA(lx_delivery).
          " Deliberately broad: a channel must never abort the run it reports on
          ls_final-status = zif_cd_ops_types=>gc_alert_status-failed.
          ls_final-error  = lx_delivery->get_text( ).
      ENDTRY.
      ls_final-sent_at = zcl_cd_ops_factory=>get_clock( )->now( ).
      io_dao->complete( ls_final ).
      lo_store->commit( ).
    ENDLOOP.
  ENDMETHOD.


  METHOD count_consecutive.
    DATA lt_fired TYPE SORTED TABLE OF zif_cd_ops_types=>ty_run_id WITH UNIQUE KEY table_line.
    " every logged decision (sent, throttled, quiet, repeat, failed, claimed) means the rule fired
    LOOP AT it_log INTO DATA(ls_log) WHERE run_id IS NOT INITIAL.
      INSERT ls_log-run_id INTO TABLE lt_fired.
    ENDLOOP.
    DATA(lt_runs) = zcl_cd_ops_factory=>get_store( )->get_runs_since( iv_pe_area = is_run-pe_area
                                                                      iv_since   = iv_since ).
    SORT lt_runs BY started_at DESCENDING run_id DESCENDING.
    " The current run is the newest of the series
    rv_count = 1.
    LOOP AT lt_runs INTO DATA(ls_run) WHERE run_id <> is_run-run_id.
      IF NOT line_exists( lt_fired[ table_line = ls_run-run_id ] ).
        " A46: a healthy run of the area ends the series
        EXIT.
      ENDIF.
      rv_count = rv_count + 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD intent_key.
    DATA lv_hash TYPE string.
    TRY.
        cl_abap_message_digest=>calculate_hash_for_char(
          EXPORTING
            if_algorithm  = gc_intent_algorithm
            if_data       = |{ is_message-rule_id }{ is_message-run_id }{ is_message-channel }|
                         && |{ is_message-destination }{ is_message-subject }|
          IMPORTING
            ef_hashstring = lv_hash ).
      CATCH cx_abap_message_digest.
        " without a key the claim still records the attempt; only the duplicate guard is lost
        CLEAR lv_hash.
    ENDTRY.
    rv_key = lv_hash.
  ENDMETHOD.


  METHOD add_log.
    DATA ls_log TYPE zif_cd_ops_types=>ty_alert_log.
    ls_log-alert_id    = COND #( WHEN iv_alert_id IS NOT INITIAL THEN iv_alert_id ELSE new_id( ) ).
    ls_log-rule_id     = iv_rule_id.
    ls_log-channel     = iv_channel.
    ls_log-run_id      = is_run-run_id.
    ls_log-pe_area      = is_run-pe_area.
    ls_log-sent_at     = zcl_cd_ops_factory=>get_clock( )->now( ).
    ls_log-status      = iv_status.
    ls_log-destination = iv_destination.
    ls_log-subject     = iv_subject.
    ls_log-error       = iv_error.
    INSERT ls_log INTO TABLE mt_log.
  ENDMETHOD.


  METHOD new_id.
    TRY.
        rv_id = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        " Log key falls back to an initial id; the row is still written for audit
        CLEAR rv_id.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
