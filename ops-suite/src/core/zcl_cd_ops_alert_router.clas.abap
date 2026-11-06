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
    DATA mo_policy TYPE REF TO zcl_cd_ops_alert_policy.
    DATA mt_log    TYPE zif_cd_ops_types=>tt_alert_log.

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
        is_run      TYPE zif_cd_ops_types=>ty_run.

    METHODS count_consecutive
      IMPORTING
        it_log          TYPE zif_cd_ops_types=>tt_alert_log
        iv_run_id       TYPE zif_cd_ops_types=>ty_run_id
      RETURNING
        VALUE(rv_count) TYPE i.

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
    IF zcl_cd_ops_util=>split_list( lv_recipients ) IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lo_dao) = zcl_cd_ops_factory=>get_alert_dao( ).
    DATA(lt_channels) = lo_dao->get_channels( ).
    DATA(ls_channel) = VALUE #( lt_channels[ channel = zif_cd_ops_types=>gc_channel-email ] OPTIONAL ).
    IF ls_channel-class_name IS INITIAL.
      ls_channel-channel    = zif_cd_ops_types=>gc_channel-email.
      ls_channel-class_name = gc_email_class.
    ENDIF.

    ls_message-alert_id    = new_id( ).
    ls_message-rule_id     = iv_route.
    ls_message-channel     = zif_cd_ops_types=>gc_channel-email.
    ls_message-destination = lv_recipients.
    ls_message-subject     = iv_subject.
    ls_message-html        = iv_html.
    ls_message-text        = iv_subject.
    ls_message-severity    = zif_cd_ops_types=>gc_severity-info.

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
        lv_since = cl_abap_tstmp=>add( tstmp = lv_now secs = - lv_window_h * 3600 ).
      CATCH cx_parameter_invalid_range cx_parameter_invalid_type.
        CLEAR lv_since.
    ENDTRY.
    DATA(lt_log) = io_dao->get_log( iv_rule_id = ls_rule-rule_id iv_since = lv_since ).

    DATA(lv_last_sent) = VALUE timestampl( ).
    LOOP AT lt_log INTO DATA(ls_log) WHERE status = zif_cd_ops_types=>gc_alert_status-sent.
      IF ls_log-sent_at > lv_last_sent.
        lv_last_sent = ls_log-sent_at.
      ENDIF.
    ENDLOOP.
    IF mo_policy->is_throttled( is_rule = ls_rule iv_last_sent = lv_last_sent iv_now = lv_now ) = abap_true.
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

    DATA(lv_destination) = COND zif_cd_ops_types=>ty_alert_dest(
      WHEN ls_rule-destination IS NOT INITIAL THEN ls_rule-destination
      ELSE ls_channel-destination ).
    IF mo_policy->needs_escalation( is_rule = ls_rule
                                    iv_consecutive = count_consecutive( it_log = lt_log
                                                                        iv_run_id = is_run-run_id ) ) = abap_true.
      lv_destination = |{ lv_destination },{ ls_rule-escalation_dest }|.
    ENDIF.

    deliver_messages( it_messages = mo_policy->build_messages( is_selection   = is_selection
                                                              is_run         = is_run
                                                              iv_destination = lv_destination )
                      is_channel  = ls_channel
                      is_run      = is_run ).
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

    LOOP AT it_messages INTO DATA(ls_message).
      ls_message-alert_id = new_id( ).
      TRY.
          lo_channel->deliver( ls_message ).
          add_log( iv_rule_id = ls_message-rule_id iv_channel = ls_message-channel is_run = is_run
                   iv_status = zif_cd_ops_types=>gc_alert_status-sent
                   iv_destination = ls_message-destination iv_subject = ls_message-subject
                   iv_alert_id = ls_message-alert_id ).
        CATCH cx_root INTO DATA(lx_delivery).
          " Deliberately broad: a channel must never abort the run it reports on
          add_log( iv_rule_id = ls_message-rule_id iv_channel = ls_message-channel is_run = is_run
                   iv_status = zif_cd_ops_types=>gc_alert_status-failed
                   iv_destination = ls_message-destination iv_subject = ls_message-subject
                   iv_error = lx_delivery->get_text( ) iv_alert_id = ls_message-alert_id ).
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD count_consecutive.
    DATA lt_runs TYPE SORTED TABLE OF zif_cd_ops_types=>ty_run_id WITH UNIQUE KEY table_line.
    LOOP AT it_log INTO DATA(ls_log) WHERE status = zif_cd_ops_types=>gc_alert_status-sent
                                       AND run_id <> iv_run_id.
      INSERT ls_log-run_id INTO TABLE lt_runs.
    ENDLOOP.
    " The current run is the next one in the series
    rv_count = lines( lt_runs ) + 1.
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
