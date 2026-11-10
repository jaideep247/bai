*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_alert_policy.clas.abap
*& Purpose:
*& Decides which alert rules fire for a run, whether quiet hours, throttling or
*& escalation apply, and builds the messages. Pure logic: no database, no
*& delivery. Severity B is never held back by quiet hours.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCA_OPS messages (phase 5).
*& 2026-11-06 | Cap keeps the most severe findings (B > E > W > I, stable order); digest severity from the full
*& 2026-11-06 |               selection; held-back count in text and HTML (audit A63).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Rule patterns are PCRE matched to the complete value (case ignored; blank = any);
*&              invalid_pattern( ) names a pattern that does not compile (the router logs and skips the rule).
*& 2026-11-10 | Subject starts with the system ID; text and HTML carry run ID, job name / count and the
*&              exceptions app (message 803) - the receiver finds the run without searching.
*& 2026-11-10 | Missing bank ACK (user request 2026-11-10): findings with ACK evidence get their own table
*&              (house bank, bank, file, method, payments, amount, payment run, times, overdue; totals per
*&              currency; most overdue first) and the impact-first subject (a consumer's class); other
*&              findings stay in the general table. Text version with the same content.
*& 2026-11-10 | Moved from ZCL_CD_OPS_ALERT_POLICY to the reusable framework ZCA_OPS.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - alert rule policy</p>
CLASS zcl_ca_ops_alert_policy DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS gc_default_max_items TYPE i VALUE 50.

    "! @parameter io_section | a consumer's own section of the message (blank = general table only)
    METHODS constructor
      IMPORTING
        io_section TYPE REF TO zif_ca_ops_alert_section OPTIONAL.
    "! Markup of the alert e-mail - not text; words are text symbols / ZCA_OPS messages
    CONSTANTS:
      BEGIN OF gc_html,
        p_open       TYPE string VALUE `<p>`,
        p_close      TYPE string VALUE `</p>`,
        p_bold_open  TYPE string VALUE `<p><b>`,
        p_bold_close TYPE string VALUE `</b></p>`,
        table_open   TYPE string VALUE `<table border="1" cellpadding="4" style="border-collapse:collapse">`,
        table_close  TYPE string VALUE `</table>`,
        tr_open      TYPE string VALUE `<tr>`,
        tr_close     TYPE string VALUE `</tr>`,
        th_open      TYPE string VALUE `<th>`,
        th_close     TYPE string VALUE `</th>`,
        td_open      TYPE string VALUE `<td>`,
        td_close     TYPE string VALUE `</td>`,
      END OF gc_html.

    TYPES:
      BEGIN OF ty_selection,
        rule      TYPE zif_ca_ops_types=>ty_alert_rule,
        findings  TYPE zif_ca_ops_types=>tt_finding,
        "! Selected because of the run outcome (RAG / abort), not a finding
        run_level TYPE abap_bool,
      END OF ty_selection.
    TYPES tt_selection TYPE STANDARD TABLE OF ty_selection WITH EMPTY KEY.

    "! Severity floor and the four patterns (PCRE, complete value, case ignored; blank = any)
    METHODS matches
      IMPORTING
        is_rule        TYPE zif_ca_ops_types=>ty_alert_rule
        is_finding     TYPE zif_ca_ops_types=>ty_finding
      RETURNING
        VALUE(rv_hit) TYPE abap_bool.

    "! First pattern of the rule that is not valid PCRE (blank = all valid)
    METHODS invalid_pattern
      IMPORTING
        is_rule           TYPE zif_ca_ops_types=>ty_alert_rule
      RETURNING
        VALUE(rv_pattern) TYPE zif_ca_ops_types=>ty_pattern.

    METHODS select
      IMPORTING
        it_rules            TYPE zif_ca_ops_types=>tt_alert_rule
        is_run              TYPE zif_ca_ops_types=>ty_run
        it_findings         TYPE zif_ca_ops_types=>tt_finding
      RETURNING
        VALUE(rt_selection) TYPE tt_selection.

    METHODS is_quiet
      IMPORTING
        is_rule           TYPE zif_ca_ops_types=>ty_alert_rule
        iv_time           TYPE t
        iv_worst_severity TYPE zif_ca_ops_types=>ty_severity
      RETURNING
        VALUE(rv_quiet)   TYPE abap_bool.

    METHODS is_throttled
      IMPORTING
        is_rule             TYPE zif_ca_ops_types=>ty_alert_rule
        iv_last_sent        TYPE timestampl
        iv_now              TYPE timestampl
      RETURNING
        VALUE(rv_throttled) TYPE abap_bool.

    METHODS needs_escalation
      IMPORTING
        is_rule           TYPE zif_ca_ops_types=>ty_alert_rule
        iv_consecutive    TYPE i
      RETURNING
        VALUE(rv_escalate) TYPE abap_bool.

    METHODS build_messages
      IMPORTING
        is_selection       TYPE ty_selection
        is_run             TYPE zif_ca_ops_types=>ty_run
        iv_destination     TYPE zif_ca_ops_types=>ty_alert_dest
      RETURNING
        VALUE(rt_messages) TYPE zif_ca_ops_types=>tt_alert_message.

  PRIVATE SECTION.
    DATA mo_section TYPE REF TO zif_ca_ops_alert_section.

    METHODS pattern_hit
      IMPORTING
        iv_pattern    TYPE zif_ca_ops_types=>ty_pattern
        iv_value      TYPE clike
      RETURNING
        VALUE(rv_hit) TYPE abap_bool.

    METHODS rag_rank
      IMPORTING
        iv_rag         TYPE zif_ca_ops_types=>ty_rag
      RETURNING
        VALUE(rv_rank) TYPE i.

    METHODS run_triggers
      IMPORTING
        is_rule       TYPE zif_ca_ops_types=>ty_alert_rule
        is_run        TYPE zif_ca_ops_types=>ty_run
      RETURNING
        VALUE(rv_hit) TYPE abap_bool.

    "! @parameter iv_worst      | severity of the complete selection (digest); blank = worst shown
    "! @parameter iv_suppressed | findings of the selection beyond the cap (shown as a count)
    METHODS new_message
      IMPORTING
        is_selection      TYPE ty_selection
        is_run            TYPE zif_ca_ops_types=>ty_run
        iv_destination    TYPE zif_ca_ops_types=>ty_alert_dest
        it_findings       TYPE zif_ca_ops_types=>tt_finding
        iv_total          TYPE i
        iv_worst          TYPE zif_ca_ops_types=>ty_severity OPTIONAL
        iv_suppressed     TYPE i DEFAULT 0
      RETURNING
        VALUE(rs_message) TYPE zif_ca_ops_types=>ty_alert_message.

    METHODS findings_html
      IMPORTING
        it_findings    TYPE zif_ca_ops_types=>tt_finding
        iv_suppressed  TYPE i
      RETURNING
        VALUE(rv_html) TYPE string.

    "! Findings ordered B > E > W > I; ties by rule, check, object and input position
    "! so the same selection always yields the same capped list (audit A63)
    METHODS ranked
      IMPORTING
        it_findings        TYPE zif_ca_ops_types=>tt_finding
      RETURNING
        VALUE(rt_findings) TYPE zif_ca_ops_types=>tt_finding.

ENDCLASS.



CLASS zcl_ca_ops_alert_policy IMPLEMENTATION.

  METHOD constructor.
    mo_section = io_section.
  ENDMETHOD.


  METHOD matches.
    DATA(lv_floor) = zcl_ca_ops_util=>severity_rank( is_rule-min_severity ).
    IF lv_floor = 0 OR zcl_ca_ops_util=>severity_rank( is_finding-severity ) < lv_floor.
      RETURN.
    ENDIF.
    rv_hit = xsdbool( pattern_hit( iv_pattern = is_rule-rule_pattern   iv_value = is_finding-rule_id )
                  AND pattern_hit( iv_pattern = is_rule-check_pattern  iv_value = is_finding-check_code )
                  AND pattern_hit( iv_pattern = is_rule-group1_pattern iv_value = is_finding-group1 )
                  AND pattern_hit( iv_pattern = is_rule-group2_pattern iv_value = is_finding-group2 ) ).
  ENDMETHOD.


  METHOD invalid_pattern.
    DATA(lt_patterns) = VALUE string_table( ( CONV #( is_rule-rule_pattern ) )
                                            ( CONV #( is_rule-check_pattern ) )
                                            ( CONV #( is_rule-group1_pattern ) )
                                            ( CONV #( is_rule-group2_pattern ) ) ).
    LOOP AT lt_patterns ASSIGNING FIELD-SYMBOL(<lv_pattern>).
      IF zcl_ca_ops_util=>pcre_valid( <lv_pattern> ) = abap_false.
        rv_pattern = <lv_pattern>.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD select.
    DATA ls_selection TYPE ty_selection.
    LOOP AT it_rules ASSIGNING FIELD-SYMBOL(<ls_rule>) WHERE active = abap_true.
      CLEAR ls_selection.
      ls_selection-rule = <ls_rule>.
      LOOP AT it_findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
        IF matches( is_rule = <ls_rule> is_finding = <ls_finding> ) = abap_true.
          INSERT <ls_finding> INTO TABLE ls_selection-findings.
        ENDIF.
      ENDLOOP.
      IF ls_selection-findings IS INITIAL.
        ls_selection-run_level = run_triggers( is_rule = <ls_rule> is_run = is_run ).
      ENDIF.
      IF ls_selection-findings IS NOT INITIAL OR ls_selection-run_level = abap_true.
        INSERT ls_selection INTO TABLE rt_selection.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD is_quiet.
    IF iv_worst_severity = zif_ca_ops_types=>gc_severity-block
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
    rv_throttled = xsdbool( zcl_ca_ops_util=>elapsed_ms( iv_from = iv_last_sent iv_to = iv_now )
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
    " A63: the cap keeps the most severe findings - a blocker behind the cap is never lost
    DATA(lt_ranked) = ranked( is_selection-findings ).
    DATA(lv_suppressed) = nmax( val1 = lv_total - lv_max val2 = 0 ).

    IF is_selection-rule-digest = abap_true OR is_selection-findings IS INITIAL.
      DATA lt_shown TYPE zif_ca_ops_types=>tt_finding.
      LOOP AT lt_ranked ASSIGNING FIELD-SYMBOL(<ls_shown>) TO lv_max.
        INSERT <ls_shown> INTO TABLE lt_shown.
      ENDLOOP.
      " subject and severity describe the complete selection, not only the shown part
      INSERT new_message( is_selection   = is_selection
                          is_run         = is_run
                          iv_destination = iv_destination
                          it_findings    = lt_shown
                          iv_total       = lv_total
                          iv_worst       = zcl_ca_ops_util=>worst_severity( is_selection-findings )
                          iv_suppressed  = lv_suppressed ) INTO TABLE rt_messages.
      RETURN.
    ENDIF.

    LOOP AT lt_ranked ASSIGNING FIELD-SYMBOL(<ls_finding>) TO lv_max.
      DATA(lv_last) = xsdbool( sy-tabix = nmin( val1 = lv_max val2 = lv_total ) ).
      " the last message of the capped series names how many were held back
      INSERT new_message( is_selection   = is_selection
                          is_run         = is_run
                          iv_destination = iv_destination
                          it_findings    = VALUE #( ( <ls_finding> ) )
                          iv_total       = 1
                          iv_suppressed  = COND #( WHEN lv_last = abap_true THEN lv_suppressed ) )
             INTO TABLE rt_messages.
    ENDLOOP.
  ENDMETHOD.


  METHOD pattern_hit.
    rv_hit = xsdbool( iv_pattern IS INITIAL
                      OR zcl_ca_ops_util=>pcre_match( iv_value = iv_value iv_pattern = iv_pattern ) = abap_true ).
  ENDMETHOD.


  METHOD rag_rank.
    rv_rank = SWITCH #( iv_rag
                        WHEN zif_ca_ops_types=>gc_rag-red   THEN 3
                        WHEN zif_ca_ops_types=>gc_rag-amber THEN 2
                        WHEN zif_ca_ops_types=>gc_rag-green THEN 1
                        ELSE 0 ).
  ENDMETHOD.


  METHOD run_triggers.
    IF is_rule-on_abort = abap_true AND is_run-status = zif_ca_ops_types=>gc_run_status-aborted.
      rv_hit = abap_true.
      RETURN.
    ENDIF.
    IF is_rule-min_rag IS NOT INITIAL.
      rv_hit = xsdbool( rag_rank( is_run-rag ) >= rag_rank( is_rule-min_rag ) ).
    ENDIF.
  ENDMETHOD.


  METHOD new_message.
    DATA(lv_worst) = COND zif_ca_ops_types=>ty_severity(
      WHEN iv_worst IS NOT INITIAL THEN iv_worst
      ELSE zcl_ca_ops_util=>worst_severity( it_findings ) ).
    IF lv_worst IS INITIAL.
      lv_worst = COND #( WHEN is_run-status = zif_ca_ops_types=>gc_run_status-aborted
                         THEN zif_ca_ops_types=>gc_severity-error
                         ELSE zif_ca_ops_types=>gc_severity-warning ).
    ENDIF.
    rs_message-rule_id     = is_selection-rule-rule_id.
    rs_message-channel     = is_selection-rule-channel.
    rs_message-destination = iv_destination.
    rs_message-area      = is_run-area.
    rs_message-run_id      = is_run-run_id.
    rs_message-severity    = lv_worst.
    rs_message-item_count  = iv_total.
    " A consumer's own section (plug-in): its findings get its table and may name the subject
    DATA(lt_owned) = VALUE zif_ca_ops_types=>tt_finding( ).
    DATA(lt_other) = it_findings.
    IF mo_section IS BOUND.
      LOOP AT lt_other ASSIGNING FIELD-SYMBOL(<ls_other>).
        IF mo_section->owns( <ls_other> ) = abap_true.
          INSERT <ls_other> INTO TABLE lt_owned.
          DELETE lt_other.
        ENDIF.
      ENDLOOP.
    ENDIF.
    DATA(lv_section_subject) = COND zif_ca_ops_types=>ty_message(
      WHEN lt_owned IS NOT INITIAL AND is_selection-run_level = abap_false
      THEN mo_section->subject( it_findings = lt_owned
                                iv_area     = is_run-area
                                iv_severity = lv_worst ) ).
    rs_message-subject     = COND #(
      WHEN lv_section_subject IS NOT INITIAL
      THEN lv_section_subject
      WHEN is_selection-run_level = abap_true
      THEN zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-alert_subject_run
                                  iv_v1    = is_run-area
                                  iv_v2    = is_run-variant
                                  iv_v3    = is_run-status
                                  iv_v4    = is_run-rag )
      WHEN iv_total = 1 AND lines( it_findings ) = 1
      THEN |[{ is_run-area }][{ lv_worst }] { it_findings[ 1 ]-rule_id } { it_findings[ 1 ]-message }|
      ELSE zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-alert_subject_count
                                  iv_v1    = is_run-area
                                  iv_v2    = lv_worst
                                  iv_v3    = iv_total
                                  iv_v4    = is_selection-rule-rule_id ) ).
    " The system first: a QA1 alert is never mistaken for production
    rs_message-subject = |[{ COND sysysid( WHEN is_run-sysid IS NOT INITIAL THEN is_run-sysid ELSE sy-sysid ) }]|
                      && rs_message-subject.
    DATA(lv_reference) = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-alert_run_reference
                                                iv_v1    = is_run-run_id
                                                iv_v2    = is_run-jobname
                                                iv_v3    = is_run-jobcount ).
    rs_message-html = gc_html-p_bold_open && zcl_ca_ops_util=>html_escape( rs_message-subject ) && gc_html-p_bold_close
                   && gc_html-p_open
                   && zcl_ca_ops_util=>html_escape(
                        zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-alert_run_line_1
                                               iv_v1    = is_run-variant
                                               iv_v2    = is_run-status
                                               iv_v3    = is_run-rag
                                               iv_v4    = is_run-total_items )
                        && ` ` &&
                        zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-alert_run_line_2
                                               iv_v1    = is_run-failed_items
                                               iv_v2    = is_run-blocked_items ) )
                   && gc_html-p_close
                   && gc_html-p_open && zcl_ca_ops_util=>html_escape( lv_reference ) && gc_html-p_close
                   && COND string( WHEN lt_owned IS NOT INITIAL THEN mo_section->html( lt_owned ) )
                   && findings_html( it_findings = lt_other iv_suppressed = iv_suppressed ).
    rs_message-text = |{ rs_message-subject }\n{ lv_reference }|.
    IF lt_owned IS NOT INITIAL.
      rs_message-text = |{ rs_message-text }\n{ mo_section->text( lt_owned ) }|.
    ENDIF.
    LOOP AT lt_other ASSIGNING FIELD-SYMBOL(<ls_finding>).
      rs_message-text = |{ rs_message-text }\n{ <ls_finding>-severity } { <ls_finding>-rule_id } |
                     && |{ <ls_finding>-object_key } { <ls_finding>-message }|.
    ENDLOOP.
    IF iv_suppressed > 0.
      rs_message-text = |{ rs_message-text }\n|
                     && zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-alert_more_findings
                                               iv_v1    = iv_suppressed ).
    ENDIF.
  ENDMETHOD.


  METHOD findings_html.
    IF it_findings IS INITIAL.
      RETURN.
    ENDIF.
    rv_html = gc_html-table_open && gc_html-tr_open.
    LOOP AT VALUE string_table( ( CONV #( TEXT-c01 ) ) ( CONV #( TEXT-c02 ) ) ( CONV #( TEXT-c03 ) )
                                ( CONV #( TEXT-c04 ) ) ( CONV #( TEXT-c05 ) ) ( CONV #( TEXT-c06 ) )
                                ( CONV #( TEXT-c07 ) ) ) ASSIGNING FIELD-SYMBOL(<lv_title>).
      rv_html = rv_html && gc_html-th_open && zcl_ca_ops_util=>html_escape( <lv_title> ) && gc_html-th_close.
    ENDLOOP.
    rv_html = rv_html && gc_html-tr_close.
    LOOP AT it_findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
      rv_html = rv_html && gc_html-tr_open
             && gc_html-td_open && zcl_ca_ops_util=>html_escape( <ls_finding>-severity ) && gc_html-td_close
             && gc_html-td_open && zcl_ca_ops_util=>html_escape( <ls_finding>-rule_id ) && gc_html-td_close
             && gc_html-td_open && zcl_ca_ops_util=>html_escape( <ls_finding>-check_code ) && gc_html-td_close
             && gc_html-td_open && zcl_ca_ops_util=>html_escape( <ls_finding>-object_key ) && gc_html-td_close
             && gc_html-td_open && zcl_ca_ops_util=>html_escape( <ls_finding>-reference ) && gc_html-td_close
             && gc_html-td_open && |{ <ls_finding>-amount } | && zcl_ca_ops_util=>html_escape( <ls_finding>-currency )
             && gc_html-td_close
             && gc_html-td_open && zcl_ca_ops_util=>html_escape( <ls_finding>-message ) && gc_html-td_close
             && gc_html-tr_close.
    ENDLOOP.
    rv_html = rv_html && gc_html-table_close.
    IF iv_suppressed > 0.
      rv_html = rv_html && gc_html-p_open
             && zcl_ca_ops_util=>html_escape( zcl_ca_ops_util=>text(
                                                iv_msgno = zif_ca_ops_types=>gc_msg-alert_more_findings
                                                iv_v1    = iv_suppressed ) )
             && gc_html-p_close.
    ENDIF.
  ENDMETHOD.


  METHOD ranked.
    TYPES:
      BEGIN OF ty_ranked,
        rank    TYPE i,
        pos     TYPE i,
        finding TYPE zif_ca_ops_types=>ty_finding,
      END OF ty_ranked.
    DATA lt_ranked TYPE STANDARD TABLE OF ty_ranked WITH EMPTY KEY.
    DATA lv_pos    TYPE i.
    LOOP AT it_findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
      lv_pos = lv_pos + 1.
      INSERT VALUE #( rank    = zcl_ca_ops_util=>severity_rank( <ls_finding>-severity )
                      pos     = lv_pos
                      finding = <ls_finding> ) INTO TABLE lt_ranked.
    ENDLOOP.
    SORT lt_ranked BY rank DESCENDING
                      finding-rule_id finding-check_code finding-object_type finding-object_key
                      pos.
    rt_findings = VALUE #( FOR ls_ranked IN lt_ranked ( ls_ranked-finding ) ).
  ENDMETHOD.

ENDCLASS.
