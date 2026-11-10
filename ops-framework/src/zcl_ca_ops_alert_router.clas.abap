*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_alert_router.clas.abap
*& Purpose:
*& Configurable alert router for every area. Reads ZCA_OPS_ALRULE and
*& ZCA_OPS_ALCHN through the alert DAO, lets ZCL_CA_OPS_ALERT_POLICY decide
*& (severity, patterns, quiet hours, throttling, escalation) and delivers via
*& channel plug-ins. Every decision is logged in ZCA_OPS_ALLOG. A failing
*& channel is logged and never aborts the calling run. Test-mode runs never alert.
*& E-mail messages are rendered from their template (rule, consumer section,
*& channel, generic ALERT_TEMPLATE_DEFAULT) by the SAP e-mail template adapter
*& when ALERT_MAIL_RENDERER = SMTG; when it cannot be used the built-in layout
*& of the policy is sent and the reason is kept on the alert log row.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCA_OPS messages (phase 5).
*& 2026-11-06 | Durable claim before send, carried-forward exceptions not re-alerted, escalation over run
*&              history, escalation override, direct send failures surfaced (audit A17, A45, A46).
*& 2026-11-06 | Channel interface checked before the channel class is created (audit A62).
*& 2026-11-06 | Message handed to the channel carries intent key and raise time (webhook de-duplication).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Modern-syntax sweep: inline CAST, alert tables ZCA_OPS_ALCHN / ALLOG / ALRULE.
*& 2026-11-06 | A rule with a pattern that is not valid PCRE is logged FAILED (message 742) and not applied -
*&              visible in the alert log and a consumer's alert health check, never a silent no-match.
*& 2026-11-07 | Parameter names / default from zif_ca_ops_types; parameters through GET_PARAMS;
*&            | escalation window with zcl_ca_ops_util=>PARAM_INT.
*& 2026-11-07 | Intent key and claim time stay on the claim only (webhook de-duplication fields removed).
*& 2026-11-10 | An alert ID that cannot be generated raises 802 (was: initial ID, the second one a duplicate
*&            | key); the caller records ALERT_FAILED. Test seam ALERT_ID. Decisions logged before the error
*&            | are still written. A failed delivery keeps the exception trace in ZCA_OPS_ALLOG-ERROR.
*& 2026-11-10 | Moved from ZCL_CD_OPS_ALERT_ROUTER to the reusable framework ZCA_OPS.
*& 2026-11-10 | Alert e-mail templates (user decisions 2026-11-10): settings of the e-mail (ALERT_TIME_ZONE,
*&            | ALERT_EXC_APP_LINK) and the stored exceptions of the run (GET_EXCEPTION_FACTS) for the
*&            | context; template of the message, else the channel's, else ALERT_TEMPLATE_DEFAULT; rendered
*&            | after the claim by the SMTG adapter (ALERT_MAIL_RENDERER), built-in layout as fallback; the
*&            | template, renderer and fallback note on the alert log row. SEND: optional template.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - configurable alert router</p>
CLASS zcl_ca_ops_alert_router DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_alert.

    CONSTANTS gc_email_class TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_CA_OPS_CHN_EMAIL'.

  PRIVATE SECTION.
    CONSTANTS gc_intent_algorithm TYPE string VALUE `SHA1`.
    CONSTANTS gc_seconds_per_hour TYPE i VALUE 3600.
    DATA mo_policy TYPE REF TO zcl_ca_ops_alert_policy.
    DATA mt_log    TYPE zif_ca_ops_types=>tt_alert_log.
    "! Findings of the run raised again only by carry-forward (not re-alerted, A17)
    DATA mt_repeat TYPE zif_ca_ops_types=>tt_repeat_key.
    "! Stored exceptions of the run (e-mail context: new / repeated / overdue, due date, owner)
    DATA mt_facts TYPE zif_ca_ops_types=>tt_exception_fact.
    "! Renderer of SAP e-mail templates, created once per router (ZCL_CA_OPS_FACTORY=>GET_MAIL_TEMPLATE)
    DATA mo_template TYPE REF TO zif_ca_ops_mail_template.

    METHODS route_selection
      IMPORTING
        is_selection TYPE zcl_ca_ops_alert_policy=>ty_selection
        is_run       TYPE zif_ca_ops_types=>ty_run
        it_channels  TYPE zif_ca_ops_types=>tt_alert_channel
        io_dao       TYPE REF TO zif_ca_ops_alert_dao
      RAISING
        zcx_ca_ops_error.

    METHODS deliver_messages
      IMPORTING
        it_messages TYPE zif_ca_ops_types=>tt_alert_message
        is_channel  TYPE zif_ca_ops_types=>ty_alert_channel
        is_run      TYPE zif_ca_ops_types=>ty_run
        io_dao      TYPE REF TO zif_ca_ops_alert_dao
      RAISING
        zcx_ca_ops_error.
    "! Consecutive runs of the area (newest first, current included) in
    "! which the rule fired; a run without an alert of the rule ends the series (A46)
    METHODS count_consecutive
      IMPORTING
        it_log          TYPE zif_ca_ops_types=>tt_alert_log
        is_run          TYPE zif_ca_ops_types=>ty_run
        iv_since        TYPE timestampl
      RETURNING
        VALUE(rv_count) TYPE i.
    "! Alert intent: SHA-1 over rule, run, channel, destination and subject (A17)
    METHODS intent_key
      IMPORTING
        is_message    TYPE zif_ca_ops_types=>ty_alert_message
      RETURNING
        VALUE(rv_key) TYPE zif_ca_ops_types=>ty_intent_key.

    METHODS add_log
      IMPORTING
        iv_rule_id     TYPE zif_ca_ops_types=>ty_rule_id
        iv_channel     TYPE zif_ca_ops_types=>ty_channel
        is_run         TYPE zif_ca_ops_types=>ty_run
        iv_status      TYPE char1
        iv_destination TYPE zif_ca_ops_types=>ty_alert_dest OPTIONAL
        iv_subject     TYPE clike OPTIONAL
        iv_error       TYPE clike OPTIONAL
        iv_alert_id    TYPE zif_ca_ops_types=>ty_run_id OPTIONAL
        is_render      TYPE zif_ca_ops_types=>ty_alert_message OPTIONAL
      RAISING
        zcx_ca_ops_error.

    "! Settings of the alert e-mail: time zone, exceptions app link, today
    METHODS mail_settings
      RETURNING
        VALUE(rs_settings) TYPE zcl_ca_ops_alert_policy=>ty_mail_settings.

    "! E-mail message: its template (message, channel, generic) rendered by the SAP e-mail template
    "! adapter (ALERT_MAIL_RENDERER = SMTG); else, or when it cannot be used, the built-in layout
    "! stays and RENDER_INFO names why. Other channels (application log): the built-in text.
    METHODS render
      CHANGING
        cs_message TYPE zif_ca_ops_types=>ty_alert_message.

    "! The consumer section of the message (parameter ALERT_SECTION_CLASS; blank = none). A class
    "! that cannot be created is logged as a failed alert decision and the message goes without it
    METHODS section
      IMPORTING
        is_run            TYPE zif_ca_ops_types=>ty_run
      RETURNING
        VALUE(ro_section) TYPE REF TO zif_ca_ops_alert_section.

    "! Key of an alert log row; raises 802 when no UUID can be generated (an initial key would
    "! collide with the next one)
    METHODS new_id
      RETURNING
        VALUE(rv_id) TYPE zif_ca_ops_types=>ty_run_id
      RAISING
        zcx_ca_ops_error.

ENDCLASS.



CLASS zcl_ca_ops_alert_router IMPLEMENTATION.

  METHOD zif_ca_ops_alert~dispatch.
    IF is_run-test_mode = abap_true.
      RETURN.
    ENDIF.
    CLEAR: mt_log, mt_facts.
    mo_policy = NEW #( io_section = section( is_run )
                       is_mail    = mail_settings( ) ).

    DATA(lo_dao) = zcl_ca_ops_factory=>get_alert_dao( ).
    DATA(lt_rules) = lo_dao->get_rules( is_run-area ).
    IF lt_rules IS INITIAL.
      RETURN.
    ENDIF.
    " PCRE patterns: a rule whose pattern does not compile is a configuration error -
    " logged as a failed alert of the rule and not applied
    TRY.
        LOOP AT lt_rules ASSIGNING FIELD-SYMBOL(<ls_rule>).
          DATA(lv_invalid) = mo_policy->invalid_pattern( <ls_rule> ).
          IF lv_invalid IS NOT INITIAL.
            add_log( iv_rule_id = <ls_rule>-rule_id iv_channel = <ls_rule>-channel is_run = is_run
                     iv_status  = zif_ca_ops_types=>gc_alert_status-failed
                     iv_error   = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-alert_pattern_invalid
                                                         iv_v1    = <ls_rule>-rule_id
                                                         iv_v2    = lv_invalid ) ).
            DELETE lt_rules.
          ENDIF.
        ENDLOOP.
        DATA(lt_channels) = lo_dao->get_channels( ).
        mt_repeat = lo_dao->get_repeat_keys( is_run-run_id ).
        DATA(lt_selection) = mo_policy->select( it_rules    = lt_rules
                                                is_run      = is_run
                                                it_findings = it_findings ).
        IF lt_selection IS NOT INITIAL.
          " one read by the run key: the business context of the e-mail (new / repeated / overdue)
          mt_facts = lo_dao->get_exception_facts( is_run-run_id ).
        ENDIF.
        LOOP AT lt_selection ASSIGNING FIELD-SYMBOL(<ls_selection>).
          route_selection( is_selection = <ls_selection>
                           is_run       = is_run
                           it_channels  = lt_channels
                           io_dao       = lo_dao ).
        ENDLOOP.
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        " the decisions taken so far stay auditable; the caller records ALERT_FAILED
        IF mt_log IS NOT INITIAL.
          lo_dao->insert_log( mt_log ).
        ENDIF.
        RAISE EXCEPTION lx_error.
    ENDTRY.

    IF mt_log IS NOT INITIAL.
      lo_dao->insert_log( mt_log ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_alert~send.
    DATA ls_message TYPE zif_ca_ops_types=>ty_alert_message.
    DATA ls_run     TYPE zif_ca_ops_types=>ty_run.

    CLEAR mt_log.
    DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
    DATA(lv_recipients) = lo_params->get_param(
      iv_name    = CONV #( |{ zif_ca_ops_types=>gc_param_prefix-alert }{ iv_route }| )
      iv_default = lo_params->get_param( zif_ca_ops_types=>gc_param-alert_default ) ).
    DATA(lo_dao) = zcl_ca_ops_factory=>get_alert_dao( ).
    " A45: no recipient is a delivery failure the caller hears about, not a silent return
    IF zcl_ca_ops_util=>split_list( lv_recipients ) IS INITIAL.
      add_log( iv_rule_id = CONV #( iv_route ) iv_channel = zif_ca_ops_types=>gc_channel-email is_run = ls_run
               iv_status = zif_ca_ops_types=>gc_alert_status-failed iv_subject = iv_subject
               iv_error = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-no_recipient iv_v1 = iv_route ) ).
      lo_dao->insert_log( mt_log ).
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e021(zca_ops) WITH iv_route.
    ENDIF.
    DATA(lt_channels) = lo_dao->get_channels( ).
    DATA(ls_channel) = VALUE #( lt_channels[ channel = zif_ca_ops_types=>gc_channel-email ] OPTIONAL ).
    IF ls_channel-class_name IS INITIAL.
      ls_channel-channel    = zif_ca_ops_types=>gc_channel-email.
      ls_channel-class_name = gc_email_class.
      ls_channel-active     = abap_true.
    ENDIF.
    " A45: a maintained channel switched off is respected by the direct send as well
    IF ls_channel-active = abap_false.
      add_log( iv_rule_id = CONV #( iv_route ) iv_channel = ls_channel-channel is_run = ls_run
               iv_status = zif_ca_ops_types=>gc_alert_status-failed iv_subject = iv_subject
               iv_error = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-channel_inactive
                                               iv_v1    = ls_channel-channel ) ).
      lo_dao->insert_log( mt_log ).
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e007(zca_ops) WITH ls_channel-channel.
    ENDIF.

    ls_message-alert_id    = new_id( ).
    ls_message-rule_id     = iv_route.
    ls_message-channel     = zif_ca_ops_types=>gc_channel-email.
    ls_message-destination = lv_recipients.
    ls_message-subject     = iv_subject.
    ls_message-html        = iv_html.
    ls_message-text        = iv_subject.
    ls_message-severity    = zif_ca_ops_types=>gc_severity-info.
    ls_message-extnumber   = |{ iv_route }|.
    " A prepared report in a template (iv_template_id): the report is the block TABLE_MAIN
    IF iv_template_id IS NOT INITIAL.
      DATA(lv_token) = zcl_ca_ops_mail_composer=>token( iv_block = zif_ca_ops_types=>gc_mail_block-main
                                                        iv_seed  = |{ ls_message-alert_id }| ).
      ls_message-template_id                       = iv_template_id.
      ls_message-renderer                          = zif_ca_ops_types=>gc_renderer-builtin.
      ls_message-context-header-subject            = iv_subject.
      ls_message-context-header-headline           = iv_subject.
      ls_message-context-header-system_id          = sy-sysid.
      ls_message-context-header-client             = sy-mandt.
      ls_message-context-header-rule_id            = iv_route.
      ls_message-context-header-time_zone          = mail_settings( )-time_zone.
      ls_message-context-header-exceptions_link    = mail_settings( )-exc_link.
      ls_message-context-header-table_main         = lv_token.
      ls_message-context-blocks = VALUE #( ( name  = zif_ca_ops_types=>gc_mail_block-main
                                             token = lv_token
                                             html  = iv_html
                                             text  = iv_subject ) ).
      render( CHANGING cs_message = ls_message ).
    ENDIF.
    TRY.
        CAST zif_ca_ops_alert_channel(
          zcl_ca_ops_factory=>get_plugin( iv_class_name = ls_channel-class_name
                                          iv_interface  = zif_ca_ops_types=>gc_plugin_intf-alert_channel )
        )->deliver( ls_message ).
        add_log( iv_rule_id = CONV #( iv_route ) iv_channel = ls_message-channel is_run = ls_run
                 iv_status = zif_ca_ops_types=>gc_alert_status-sent
                 iv_destination = ls_message-destination iv_subject = ls_message-subject
                 iv_alert_id = ls_message-alert_id is_render = ls_message ).
        lo_dao->insert_log( mt_log ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        add_log( iv_rule_id = CONV #( iv_route ) iv_channel = ls_message-channel is_run = ls_run
                 iv_status = zif_ca_ops_types=>gc_alert_status-failed
                 iv_destination = ls_message-destination iv_subject = ls_message-subject
                 iv_error = lx_error->get_text( ) iv_alert_id = ls_message-alert_id is_render = ls_message ).
        lo_dao->insert_log( mt_log ).
        RAISE EXCEPTION lx_error.
      CATCH cx_sy_move_cast_error INTO DATA(lx_cast).
        add_log( iv_rule_id = CONV #( iv_route ) iv_channel = ls_message-channel is_run = ls_run
                 iv_status = zif_ca_ops_types=>gc_alert_status-failed
                 iv_error = lx_cast->get_text( ) iv_alert_id = ls_message-alert_id ).
        lo_dao->insert_log( mt_log ).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e032(zca_ops) WITH ls_channel-class_name zif_ca_ops_types=>gc_plugin_intf-alert_channel
          EXPORTING
            previous = lx_cast.
    ENDTRY.
  ENDMETHOD.


  METHOD route_selection.
    DATA(lo_clock) = zcl_ca_ops_factory=>get_clock( ).
    DATA(lv_now) = lo_clock->now( ).
    DATA(ls_rule) = is_selection-rule.

    DATA(lv_worst) = zcl_ca_ops_util=>worst_severity( is_selection-findings ).
    IF lv_worst IS INITIAL.
      lv_worst = zif_ca_ops_types=>gc_severity-error.
    ENDIF.

    IF mo_policy->is_quiet( is_rule = ls_rule iv_time = lo_clock->time( ) iv_worst_severity = lv_worst ) = abap_true.
      add_log( iv_rule_id = ls_rule-rule_id iv_channel = ls_rule-channel is_run = is_run
               iv_status = zif_ca_ops_types=>gc_alert_status-quiet ).
      RETURN.
    ENDIF.

    DATA(lv_window_h) = zcl_ca_ops_util=>param_int( io_params  = zcl_ca_ops_factory=>get_params( )
                                                    iv_name    = zif_ca_ops_types=>gc_param-alert_window_h
                                                    iv_default = zif_ca_ops_types=>gc_param_default-alert_window_h ).
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
    LOOP AT lt_log ASSIGNING FIELD-SYMBOL(<ls_log>) WHERE status = zif_ca_ops_types=>gc_alert_status-sent
                                        OR status = zif_ca_ops_types=>gc_alert_status-claimed
                                        OR status = zif_ca_ops_types=>gc_alert_status-partial.
      IF <ls_log>-sent_at > lv_last_sent.
        lv_last_sent = <ls_log>-sent_at.
      ENDIF.
    ENDLOOP.
    IF mo_policy->is_throttled( is_rule = ls_rule iv_last_sent = lv_last_sent iv_now = lv_now ) = abap_true
       AND NOT ( lv_escalate = abap_true AND ls_rule-esc_override = abap_true ).
      add_log( iv_rule_id = ls_rule-rule_id iv_channel = ls_rule-channel is_run = is_run
               iv_status = zif_ca_ops_types=>gc_alert_status-throttled ).
      RETURN.
    ENDIF.
    DATA(ls_channel) = VALUE #( it_channels[ channel = ls_rule-channel ] OPTIONAL ).
    IF ls_channel IS INITIAL OR ls_channel-active = abap_false.
      add_log( iv_rule_id = ls_rule-rule_id iv_channel = ls_rule-channel is_run = is_run
               iv_status = zif_ca_ops_types=>gc_alert_status-failed
               iv_error = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-channel_inactive
                                               iv_v1    = ls_rule-channel ) ).
      RETURN.
    ENDIF.
    " A17: findings raised again only by carry-forward are not re-alerted (unless escalating)
    DATA(ls_selection) = is_selection.
    IF lv_escalate = abap_false AND mt_repeat IS NOT INITIAL AND ls_selection-findings IS NOT INITIAL.
      CLEAR ls_selection-findings.
      LOOP AT is_selection-findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
        IF NOT line_exists( mt_repeat[ object_type = <ls_finding>-object_type
                                       object_key  = <ls_finding>-object_key
                                       check_code  = <ls_finding>-check_code ] ).
          INSERT <ls_finding> INTO TABLE ls_selection-findings.
        ENDIF.
      ENDLOOP.
      IF ls_selection-findings IS INITIAL.
        add_log( iv_rule_id = ls_rule-rule_id iv_channel = ls_rule-channel is_run = is_run
                 iv_status = zif_ca_ops_types=>gc_alert_status-repeat ).
        RETURN.
      ENDIF.
    ENDIF.
    DATA(lv_destination) = COND zif_ca_ops_types=>ty_alert_dest(
      WHEN ls_rule-destination IS NOT INITIAL THEN ls_rule-destination
      ELSE ls_channel-destination ).
    IF lv_escalate = abap_true.
      lv_destination = |{ lv_destination },{ ls_rule-escalation_dest }|.
    ENDIF.
    deliver_messages( it_messages = mo_policy->build_messages( is_selection   = ls_selection
                                                              is_run         = is_run
                                                              iv_destination = lv_destination
                                                              it_facts       = mt_facts )
                      is_channel  = ls_channel
                      is_run      = is_run
                      io_dao      = io_dao ).
  ENDMETHOD.


  METHOD deliver_messages.
    DATA lo_channel TYPE REF TO zif_ca_ops_alert_channel.
    TRY.
        lo_channel = CAST zif_ca_ops_alert_channel( zcl_ca_ops_factory=>get_plugin(
          iv_class_name = is_channel-class_name
          iv_interface  = zif_ca_ops_types=>gc_plugin_intf-alert_channel ) ).
      CATCH zcx_ca_ops_error cx_sy_move_cast_error INTO DATA(lx_wiring).
        LOOP AT it_messages ASSIGNING FIELD-SYMBOL(<ls_failed>).
          add_log( iv_rule_id = <ls_failed>-rule_id iv_channel = <ls_failed>-channel is_run = is_run
                   iv_status = zif_ca_ops_types=>gc_alert_status-failed
                   iv_destination = <ls_failed>-destination iv_subject = <ls_failed>-subject
                   iv_error = lx_wiring->get_text( ) ).
        ENDLOOP.
        RETURN.
    ENDTRY.

    DATA(lo_store) = zcl_ca_ops_factory=>get_store( ).
    " the generic template when neither the rule, the consumer section nor the channel names one
    DATA(lv_default_template) = CONV zif_ca_ops_types=>ty_template_id(
      zcl_ca_ops_factory=>get_params( )->get_param( iv_name    = zif_ca_ops_types=>gc_param-template_default
                                                    iv_default = CONV #( zif_ca_ops_types=>gc_param_default-template_default ) ) ).
    LOOP AT it_messages INTO DATA(ls_message).
      ls_message-alert_id  = new_id( ).
      ls_message-extnumber = |{ is_run-area }/{ is_run-run_id }/{ ls_message-rule_id }|.
      ls_message-template_id = zcl_ca_ops_mail_composer=>template_for( iv_rule    = ls_message-template_id
                                                                       iv_channel = is_channel-template_id
                                                                       iv_default = lv_default_template ).
      " the intent key and the claim carry the code's subject: a template change is no new alert
      " A17: durable claim first (status C, committed) - a second dispatcher sees it and a
      " failure after the external send still leaves evidence of the delivery attempt
      DATA(ls_claim) = VALUE zif_ca_ops_types=>ty_alert_log( alert_id    = ls_message-alert_id
                                                            rule_id     = ls_message-rule_id
                                                            channel     = ls_message-channel
                                                            run_id      = is_run-run_id
                                                            area     = is_run-area
                                                            sent_at     = zcl_ca_ops_factory=>get_clock( )->now( )
                                                            status      = zif_ca_ops_types=>gc_alert_status-claimed
                                                            destination = ls_message-destination
                                                            subject     = ls_message-subject
                                                            intent_key  = intent_key( ls_message )
                                                            template_id = ls_message-template_id ).
      IF io_dao->claim( ls_claim ) = abap_true.
        CONTINUE.
      ENDIF.
      lo_store->commit( ).
      " rendered after the claim: a data source by key finds the alert log row
      render( CHANGING cs_message = ls_message ).
      DATA(ls_final) = ls_claim.
      ls_final-subject     = ls_message-subject.
      ls_final-renderer    = ls_message-renderer.
      ls_final-render_info = ls_message-render_info.
      TRY.
          lo_channel->deliver( ls_message ).
          ls_final-status = zif_ca_ops_types=>gc_alert_status-sent.
        CATCH zcx_ca_ops_error INTO DATA(lx_ops).
          " A45: a partly written application log is PARTIAL, not SENT
          ls_final-status = COND #( WHEN lx_ops->if_t100_message~t100key-msgno = zif_ca_ops_types=>gc_msg-applog_partial
                                    THEN zif_ca_ops_types=>gc_alert_status-partial
                                    ELSE zif_ca_ops_types=>gc_alert_status-failed ).
          " B10: the chain (class, message, position of each link), cut to the log field
          ls_final-error = zcl_ca_ops_util=>exception_trace( lx_ops ).
        CATCH cx_root INTO DATA(lx_delivery).
          " Deliberately broad: a channel must never abort the run it reports on
          ls_final-status = zif_ca_ops_types=>gc_alert_status-failed.
          ls_final-error  = zcl_ca_ops_util=>exception_trace( lx_delivery ).
      ENDTRY.
      ls_final-sent_at = zcl_ca_ops_factory=>get_clock( )->now( ).
      io_dao->complete( ls_final ).
      lo_store->commit( ).
    ENDLOOP.
  ENDMETHOD.


  METHOD count_consecutive.
    DATA lt_fired TYPE SORTED TABLE OF zif_ca_ops_types=>ty_run_id WITH UNIQUE KEY table_line.
    " every logged decision (sent, throttled, quiet, repeat, failed, claimed) means the rule fired
    LOOP AT it_log ASSIGNING FIELD-SYMBOL(<ls_log>) WHERE run_id IS NOT INITIAL.
      INSERT <ls_log>-run_id INTO TABLE lt_fired.
    ENDLOOP.
    DATA(lt_runs) = zcl_ca_ops_factory=>get_store( )->get_runs_since( iv_area = is_run-area
                                                                      iv_since   = iv_since ).
    SORT lt_runs BY started_at DESCENDING run_id DESCENDING.
    " The current run is the newest of the series
    rv_count = 1.
    LOOP AT lt_runs ASSIGNING FIELD-SYMBOL(<ls_run>) WHERE run_id <> is_run-run_id.
      IF NOT line_exists( lt_fired[ table_line = <ls_run>-run_id ] ).
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
    DATA ls_log TYPE zif_ca_ops_types=>ty_alert_log.
    ls_log-alert_id    = COND #( WHEN iv_alert_id IS NOT INITIAL THEN iv_alert_id ELSE new_id( ) ).
    ls_log-rule_id     = iv_rule_id.
    ls_log-channel     = iv_channel.
    ls_log-run_id      = is_run-run_id.
    ls_log-area      = is_run-area.
    ls_log-sent_at     = zcl_ca_ops_factory=>get_clock( )->now( ).
    ls_log-status      = iv_status.
    ls_log-destination = iv_destination.
    ls_log-subject     = iv_subject.
    ls_log-error       = iv_error.
    ls_log-template_id = is_render-template_id.
    ls_log-renderer    = is_render-renderer.
    ls_log-render_info = is_render-render_info.
    INSERT ls_log INTO TABLE mt_log.
  ENDMETHOD.


  METHOD mail_settings.
    DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
    rs_settings-time_zone = to_upper( lo_params->get_param( iv_name    = zif_ca_ops_types=>gc_param-mail_time_zone
                                                            iv_default = CONV #( zif_ca_ops_types=>gc_param_default-mail_time_zone ) ) ).
    rs_settings-exc_link  = lo_params->get_param( zif_ca_ops_types=>gc_param-exc_app_link ).
    rs_settings-today     = zcl_ca_ops_factory=>get_clock( )->today( ).
  ENDMETHOD.


  METHOD render.
    IF cs_message-channel <> zif_ca_ops_types=>gc_channel-email.
      RETURN.
    ENDIF.
    DATA(lv_renderer) = to_upper( zcl_ca_ops_factory=>get_params( )->get_param(
                                    iv_name    = zif_ca_ops_types=>gc_param-mail_renderer
                                    iv_default = CONV #( zif_ca_ops_types=>gc_param_default-mail_renderer ) ) ).
    IF lv_renderer = zif_ca_ops_types=>gc_renderer-builtin.
      " switched off: the built-in layout is sent, the log names the template that was not used
      cs_message-render_info = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-tpl_renderer_off
                                                      iv_v1    = cs_message-template_id ).
      RETURN.
    ENDIF.
    IF mo_template IS NOT BOUND.
      mo_template = zcl_ca_ops_factory=>get_mail_template( ).
    ENDIF.
    " never silent, never blocking: a template that cannot be used leaves the built-in layout
    zcl_ca_ops_mail_composer=>apply( EXPORTING io_template = mo_template
                                               iv_renderer = zif_ca_ops_types=>gc_renderer-smtg
                                               iv_alert_id = cs_message-alert_id
                                     CHANGING  cs_message  = cs_message ).
  ENDMETHOD.


  METHOD section.
    DATA(lv_class) = zcl_ca_ops_factory=>get_params( )->get_param( zif_ca_ops_types=>gc_param-alert_section ).
    IF lv_class IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        ro_section = CAST zif_ca_ops_alert_section(
          zcl_ca_ops_factory=>get_plugin( iv_class_name = CONV #( lv_class )
                                          iv_interface  = zif_ca_ops_types=>gc_plugin_intf-alert_section ) ).
      CATCH zcx_ca_ops_error cx_sy_move_cast_error INTO DATA(lx_error).
        " never silent, never blocking: the decision log names the class, the message goes without it
        TRY.
            add_log( iv_rule_id = space iv_channel = space is_run = is_run
                     iv_status  = zif_ca_ops_types=>gc_alert_status-failed
                     iv_error   = lx_error->get_text( ) ).
          CATCH zcx_ca_ops_error.
            " no log ID: the run's own alert decisions still follow
            CLEAR ro_section.
        ENDTRY.
    ENDTRY.
  ENDMETHOD.


  METHOD new_id.
    DATA lx_error TYPE REF TO cx_uuid_error.
    TEST-SEAM alert_id.
      TRY.
          rv_id = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error INTO lx_error.
          " raised below: an initial key would collide with the next alert of this kind
      ENDTRY.
    END-TEST-SEAM.
    IF lx_error IS BOUND OR rv_id IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e802(zca_ops)
        EXPORTING
          previous = lx_error.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
