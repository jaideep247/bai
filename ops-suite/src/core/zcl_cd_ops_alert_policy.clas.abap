*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_alert_policy.clas.abap
*& Purpose:
*& Decides which alert rules fire for a run, whether quiet hours, throttling or
*& escalation apply, and builds the messages. Pure logic: no database, no
*& delivery. Severity B is never held back by quiet hours.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - alert rule policy</p>
CLASS zcl_cd_ops_alert_policy DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS gc_default_max_items TYPE i VALUE 50.

    TYPES:
      BEGIN OF ty_selection,
        rule      TYPE zif_cd_ops_types=>ty_alert_rule,
        findings  TYPE zif_cd_ops_types=>tt_finding,
        "! Selected because of the run outcome (RAG / abort), not a finding
        run_level TYPE abap_bool,
      END OF ty_selection.
    TYPES tt_selection TYPE STANDARD TABLE OF ty_selection WITH EMPTY KEY.

    METHODS matches
      IMPORTING
        is_rule        TYPE zif_cd_ops_types=>ty_alert_rule
        is_finding     TYPE zif_cd_ops_types=>ty_finding
      RETURNING
        VALUE(rv_hit) TYPE abap_bool.

    METHODS select
      IMPORTING
        it_rules            TYPE zif_cd_ops_types=>tt_alert_rule
        is_run              TYPE zif_cd_ops_types=>ty_run
        it_findings         TYPE zif_cd_ops_types=>tt_finding
      RETURNING
        VALUE(rt_selection) TYPE tt_selection.

    METHODS is_quiet
      IMPORTING
        is_rule           TYPE zif_cd_ops_types=>ty_alert_rule
        iv_time           TYPE t
        iv_worst_severity TYPE zif_cd_ops_types=>ty_severity
      RETURNING
        VALUE(rv_quiet)   TYPE abap_bool.

    METHODS is_throttled
      IMPORTING
        is_rule             TYPE zif_cd_ops_types=>ty_alert_rule
        iv_last_sent        TYPE timestampl
        iv_now              TYPE timestampl
      RETURNING
        VALUE(rv_throttled) TYPE abap_bool.

    METHODS needs_escalation
      IMPORTING
        is_rule           TYPE zif_cd_ops_types=>ty_alert_rule
        iv_consecutive    TYPE i
      RETURNING
        VALUE(rv_escalate) TYPE abap_bool.

    METHODS build_messages
      IMPORTING
        is_selection       TYPE ty_selection
        is_run             TYPE zif_cd_ops_types=>ty_run
        iv_destination     TYPE zif_cd_ops_types=>ty_alert_dest
      RETURNING
        VALUE(rt_messages) TYPE zif_cd_ops_types=>tt_alert_message.

  PRIVATE SECTION.
    METHODS pattern_hit
      IMPORTING
        iv_pattern    TYPE zif_cd_ops_types=>ty_pattern
        iv_value      TYPE clike
      RETURNING
        VALUE(rv_hit) TYPE abap_bool.

    METHODS rag_rank
      IMPORTING
        iv_rag         TYPE zif_cd_ops_types=>ty_rag
      RETURNING
        VALUE(rv_rank) TYPE i.

    METHODS run_triggers
      IMPORTING
        is_rule       TYPE zif_cd_ops_types=>ty_alert_rule
        is_run        TYPE zif_cd_ops_types=>ty_run
      RETURNING
        VALUE(rv_hit) TYPE abap_bool.

    METHODS new_message
      IMPORTING
        is_selection      TYPE ty_selection
        is_run            TYPE zif_cd_ops_types=>ty_run
        iv_destination    TYPE zif_cd_ops_types=>ty_alert_dest
        it_findings       TYPE zif_cd_ops_types=>tt_finding
        iv_total          TYPE i
      RETURNING
        VALUE(rs_message) TYPE zif_cd_ops_types=>ty_alert_message.

    METHODS findings_html
      IMPORTING
        it_findings    TYPE zif_cd_ops_types=>tt_finding
        iv_total       TYPE i
      RETURNING
        VALUE(rv_html) TYPE string.

ENDCLASS.



CLASS zcl_cd_ops_alert_policy IMPLEMENTATION.

  METHOD matches.
    DATA(lv_floor) = zcl_cd_ops_util=>severity_rank( is_rule-min_severity ).
    IF lv_floor = 0 OR zcl_cd_ops_util=>severity_rank( is_finding-severity ) < lv_floor.
      RETURN.
    ENDIF.
    rv_hit = xsdbool( pattern_hit( iv_pattern = is_rule-rule_pattern   iv_value = is_finding-rule_id )
                  AND pattern_hit( iv_pattern = is_rule-check_pattern  iv_value = is_finding-check_code )
                  AND pattern_hit( iv_pattern = is_rule-group1_pattern iv_value = is_finding-group1 )
                  AND pattern_hit( iv_pattern = is_rule-group2_pattern iv_value = is_finding-group2 ) ).
  ENDMETHOD.


  METHOD select.
    DATA ls_selection TYPE ty_selection.
    LOOP AT it_rules INTO DATA(ls_rule) WHERE active = abap_true.
      CLEAR ls_selection.
      ls_selection-rule = ls_rule.
      LOOP AT it_findings INTO DATA(ls_finding).
        IF matches( is_rule = ls_rule is_finding = ls_finding ) = abap_true.
          INSERT ls_finding INTO TABLE ls_selection-findings.
        ENDIF.
      ENDLOOP.
      IF ls_selection-findings IS INITIAL.
        ls_selection-run_level = run_triggers( is_rule = ls_rule is_run = is_run ).
      ENDIF.
      IF ls_selection-findings IS NOT INITIAL OR ls_selection-run_level = abap_true.
        INSERT ls_selection INTO TABLE rt_selection.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD is_quiet.
    IF iv_worst_severity = zif_cd_ops_types=>gc_severity-block
       OR ( is_rule-quiet_from IS INITIAL AND is_rule-quiet_to IS INITIAL ).
      RETURN.
    ENDIF.
    IF is_rule-quiet_from <= is_rule-quiet_to.
      rv_quiet = xsdbool( iv_time >= is_rule-quiet_from AND iv_time < is_rule-quiet_to ).
    ELSE.
      " Window wraps midnight, e.g. 22:00-06:00
      rv_quiet = xsdbool( iv_time >= is_rule-quiet_from OR iv_time < is_rule-quiet_to ).
    ENDIF.
  ENDMETHOD.


  METHOD is_throttled.
    IF is_rule-throttle_min <= 0 OR iv_last_sent IS INITIAL.
      RETURN.
    ENDIF.
    rv_throttled = xsdbool( zcl_cd_ops_util=>elapsed_ms( iv_from = iv_last_sent iv_to = iv_now )
                            < is_rule-throttle_min * 60000 ).
  ENDMETHOD.


  METHOD needs_escalation.
    rv_escalate = xsdbool( is_rule-escalate_after > 0
                       AND is_rule-escalation_dest IS NOT INITIAL
                       AND iv_consecutive >= is_rule-escalate_after ).
  ENDMETHOD.


  METHOD build_messages.
    DATA(lv_max) = COND i( WHEN is_selection-rule-max_items > 0 THEN is_selection-rule-max_items
                           ELSE gc_default_max_items ).
    DATA(lv_total) = lines( is_selection-findings ).

    IF is_selection-rule-digest = abap_true OR is_selection-findings IS INITIAL.
      DATA lt_shown TYPE zif_cd_ops_types=>tt_finding.
      LOOP AT is_selection-findings INTO DATA(ls_shown) TO lv_max.
        INSERT ls_shown INTO TABLE lt_shown.
      ENDLOOP.
      INSERT new_message( is_selection   = is_selection
                          is_run         = is_run
                          iv_destination = iv_destination
                          it_findings    = lt_shown
                          iv_total       = lv_total ) INTO TABLE rt_messages.
      RETURN.
    ENDIF.

    LOOP AT is_selection-findings INTO DATA(ls_finding) TO lv_max.
      INSERT new_message( is_selection   = is_selection
                          is_run         = is_run
                          iv_destination = iv_destination
                          it_findings    = VALUE #( ( ls_finding ) )
                          iv_total       = 1 ) INTO TABLE rt_messages.
    ENDLOOP.
  ENDMETHOD.


  METHOD pattern_hit.
    rv_hit = xsdbool( iv_pattern IS INITIAL OR iv_value CP iv_pattern ).
  ENDMETHOD.


  METHOD rag_rank.
    rv_rank = SWITCH #( iv_rag
                        WHEN zif_cd_ops_types=>gc_rag-red   THEN 3
                        WHEN zif_cd_ops_types=>gc_rag-amber THEN 2
                        WHEN zif_cd_ops_types=>gc_rag-green THEN 1
                        ELSE 0 ).
  ENDMETHOD.


  METHOD run_triggers.
    IF is_rule-on_abort = abap_true AND is_run-status = zif_cd_ops_types=>gc_run_status-aborted.
      rv_hit = abap_true.
      RETURN.
    ENDIF.
    IF is_rule-min_rag IS NOT INITIAL.
      rv_hit = xsdbool( rag_rank( is_run-rag ) >= rag_rank( is_rule-min_rag ) ).
    ENDIF.
  ENDMETHOD.


  METHOD new_message.
    DATA(lv_worst) = zcl_cd_ops_util=>worst_severity( it_findings ).
    IF lv_worst IS INITIAL.
      lv_worst = COND #( WHEN is_run-status = zif_cd_ops_types=>gc_run_status-aborted
                         THEN zif_cd_ops_types=>gc_severity-error
                         ELSE zif_cd_ops_types=>gc_severity-warning ).
    ENDIF.
    rs_message-rule_id     = is_selection-rule-rule_id.
    rs_message-channel     = is_selection-rule-channel.
    rs_message-destination = iv_destination.
    rs_message-module      = is_run-module.
    rs_message-run_id      = is_run-run_id.
    rs_message-severity    = lv_worst.
    rs_message-item_count  = iv_total.
    rs_message-subject     = COND #(
      WHEN is_selection-run_level = abap_true
      THEN |[{ is_run-module }] run { is_run-variant } ended { is_run-status } / RAG { is_run-rag }|
      WHEN iv_total = 1 AND lines( it_findings ) = 1
      THEN |[{ is_run-module }][{ lv_worst }] { it_findings[ 1 ]-rule_id } { it_findings[ 1 ]-message }|
      ELSE |[{ is_run-module }][{ lv_worst }] { iv_total } finding(s) - rule { is_selection-rule-rule_id }| ).
    rs_message-html = |<p><b>{ zcl_cd_ops_util=>html_escape( rs_message-subject ) }</b></p>|
                   && |<p>Run { is_run-variant } status { is_run-status }, RAG { is_run-rag }, |
                   && |items { is_run-total_items }, failed { is_run-failed_items }, |
                   && |blocked { is_run-blocked_items }.</p>|
                   && findings_html( it_findings = it_findings iv_total = iv_total ).
    rs_message-text = rs_message-subject.
    LOOP AT it_findings INTO DATA(ls_finding).
      rs_message-text = |{ rs_message-text }\n{ ls_finding-severity } { ls_finding-rule_id } |
                     && |{ ls_finding-object_key } { ls_finding-message }|.
    ENDLOOP.
  ENDMETHOD.


  METHOD findings_html.
    IF it_findings IS INITIAL.
      RETURN.
    ENDIF.
    rv_html = |<table border="1" cellpadding="4" style="border-collapse:collapse">|
           && |<tr><th>Severity</th><th>Rule</th><th>Check</th><th>Object</th>|
           && |<th>Reference</th><th>Amount</th><th>Message</th></tr>|.
    LOOP AT it_findings INTO DATA(ls_finding).
      rv_html = rv_html
             && |<tr><td>{ zcl_cd_ops_util=>html_escape( ls_finding-severity ) }</td>|
             && |<td>{ zcl_cd_ops_util=>html_escape( ls_finding-rule_id ) }</td>|
             && |<td>{ zcl_cd_ops_util=>html_escape( ls_finding-check_code ) }</td>|
             && |<td>{ zcl_cd_ops_util=>html_escape( ls_finding-object_key ) }</td>|
             && |<td>{ zcl_cd_ops_util=>html_escape( ls_finding-reference ) }</td>|
             && |<td>{ ls_finding-amount } { zcl_cd_ops_util=>html_escape( ls_finding-currency ) }</td>|
             && |<td>{ zcl_cd_ops_util=>html_escape( ls_finding-message ) }</td></tr>|.
    ENDLOOP.
    rv_html = rv_html && |</table>|.
    IF iv_total > lines( it_findings ).
      rv_html = rv_html && |<p>{ iv_total - lines( it_findings ) } more finding(s) in ZCD_OPS_FINDING.</p>|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
