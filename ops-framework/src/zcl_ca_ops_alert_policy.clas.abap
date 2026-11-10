*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_alert_policy.clas.abap
*& Purpose:
*& Decides which alert rules fire for a run, whether quiet hours, throttling or
*& escalation apply, and builds the messages. Pure logic: no database, no
*& delivery. Severity B is never held back by quiet hours. The message
*& carries its business context (standard keys, table blocks) for the
*& e-mail template and the built-in layout of it (ZCL_CA_OPS_MAIL_TPL_BUILTIN).
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
*& 2026-11-10 | Alert e-mail templates (user decisions 2026-11-10): the message carries its business context
*&            | (standard keys of TY_MAIL_HEADER, table blocks TABLE_SECTION / TABLE_MAIN with their tokens)
*&            | and the template of the rule or section; HTML / text are the built-in layout
*&            | (ZCL_CA_OPS_MAIL_TPL_BUILTIN). Findings table: columns shown when known (business date,
*&            | company code, account, payment method, count, details); amounts only with SHOW_AMOUNTS (default
*&            | off). Digest subject impact first: [SYSID][AREA][sev] <check or rule>: <n> finding(s)[, amounts].
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - alert rule policy</p>
CLASS zcl_ca_ops_alert_policy DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS gc_default_max_items TYPE i VALUE 50.

    "! Settings of the alert e-mail read by the router (parameters, clock)
    TYPES:
      BEGIN OF ty_mail_settings,
        "! Time zone of the times shown (ALERT_TIME_ZONE; blank = UTC)
        time_zone TYPE tznzone,
        "! Exceptions app (ALERT_EXC_APP_LINK; blank = its name)
        exc_link  TYPE string,
        "! Today, for the overdue count
        today     TYPE d,
      END OF ty_mail_settings.

    "! @parameter io_section | a consumer's own section of the message (blank = general table only)
    "! @parameter is_mail    | settings of the alert e-mail (time zone, exceptions app link, today)
    METHODS constructor
      IMPORTING
        io_section TYPE REF TO zif_ca_ops_alert_section OPTIONAL
        is_mail    TYPE ty_mail_settings OPTIONAL.
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
        td_right     TYPE string VALUE `<td style="text-align:right">`,
        td_close     TYPE string VALUE `</td>`,
        line_break   TYPE string VALUE `<br>`,
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

    "! @parameter it_facts | stored exceptions of the run (new / repeated / overdue, due date, owner)
    METHODS build_messages
      IMPORTING
        is_selection       TYPE ty_selection
        is_run             TYPE zif_ca_ops_types=>ty_run
        iv_destination     TYPE zif_ca_ops_types=>ty_alert_dest
        it_facts           TYPE zif_ca_ops_types=>tt_exception_fact OPTIONAL
      RETURNING
        VALUE(rt_messages) TYPE zif_ca_ops_types=>tt_alert_message.

  PRIVATE SECTION.
    "! Between the parts of an amount list (currency totals)
    CONSTANTS gc_amount_separator TYPE string VALUE `; `.
    "! Between label and value in the text version of a finding
    CONSTANTS gc_label_separator TYPE string VALUE `: `.
    CONSTANTS gc_part_separator TYPE string VALUE ` | `.
    CONSTANTS gc_indent TYPE string VALUE `  `.
    "! The system / area / severity prefix of a subject ([SYSID][AREA][severity] )
    CONSTANTS gc_subject_prefix TYPE string VALUE `^(\[[^\]]*\])+\s*`.

    "! One column of the findings table: label, right-aligned, shown
    TYPES:
      BEGIN OF ty_column,
        label TYPE string,
        right TYPE abap_bool,
        shown TYPE abap_bool,
      END OF ty_column.
    TYPES tt_column TYPE STANDARD TABLE OF ty_column WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_amount_total,
        currency TYPE zif_ca_ops_types=>ty_currency,
        amount   TYPE decfloat34,
      END OF ty_amount_total.
    TYPES tt_amount_total TYPE SORTED TABLE OF ty_amount_total WITH UNIQUE KEY currency.

    DATA mo_section TYPE REF TO zif_ca_ops_alert_section.
    DATA ms_mail    TYPE ty_mail_settings.
    "! Exceptions of the run being built (BUILD_MESSAGES)
    DATA mt_facts   TYPE zif_ca_ops_types=>tt_exception_fact.

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

    "! Findings table (HTML): a column is shown when a finding has a value for it; amounts only
    "! when the rule shows them; the held-back count below
    METHODS findings_html
      IMPORTING
        it_findings     TYPE zif_ca_ops_types=>tt_finding
        iv_suppressed   TYPE i
        iv_show_amounts TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rv_html)  TYPE string.

    "! Findings as text lines (severity, rule, object, message, known context, details)
    METHODS findings_text
      IMPORTING
        it_findings     TYPE zif_ca_ops_types=>tt_finding
        iv_suppressed   TYPE i
        iv_show_amounts TYPE abap_bool
      RETURNING
        VALUE(rv_text)  TYPE string.

    "! Column labels of the findings table in cell order
    METHODS columns
      RETURNING
        VALUE(rt_columns) TYPE tt_column.

    "! Cell values of a finding in column order (plain text)
    METHODS cells
      IMPORTING
        is_finding      TYPE zif_ca_ops_types=>ty_finding
        iv_show_amounts TYPE abap_bool
      RETURNING
        VALUE(rt_cells) TYPE string_table.

    "! Standard business-context keys of the message
    METHODS header
      IMPORTING
        is_message       TYPE zif_ca_ops_types=>ty_alert_message
        is_selection     TYPE ty_selection
        is_run           TYPE zif_ca_ops_types=>ty_run
        it_findings      TYPE zif_ca_ops_types=>tt_finding
        iv_total         TYPE i
        iv_suppressed    TYPE i
        iv_amounts       TYPE string
      RETURNING
        VALUE(rs_header) TYPE zif_ca_ops_types=>ty_mail_header.

    "! Totals per currency of the findings with an amount (<CUR> <amount>; ...); blank = none
    METHODS amount_totals
      IMPORTING
        it_findings    TYPE zif_ca_ops_types=>tt_finding
      RETURNING
        VALUE(rv_text) TYPE string.

    "! What the message is about: the check code when all findings share it, else the rule
    METHODS what
      IMPORTING
        it_findings    TYPE zif_ca_ops_types=>tt_finding
        iv_rule_id     TYPE zif_ca_ops_types=>ty_rule_id
      RETURNING
        VALUE(rv_what) TYPE string.

    METHODS severity_text
      IMPORTING
        iv_severity    TYPE zif_ca_ops_types=>ty_severity
      RETURNING
        VALUE(rv_text) TYPE string.

    "! Time stamp in the e-mail's time zone (ISO date and time, zone); blank when initial
    METHODS time_text
      IMPORTING
        iv_timestamp   TYPE timestampl
      RETURNING
        VALUE(rv_text) TYPE string.

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
    ms_mail    = is_mail.
    IF ms_mail-time_zone IS INITIAL.
      ms_mail-time_zone = zif_ca_ops_types=>gc_time_zone_utc.
    ENDIF.
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
    mt_facts = it_facts.
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
    " amounts only where the rule shows them (SHOW_AMOUNTS, user decision 2026-11-10: default off)
    DATA(lv_amounts) = COND string( WHEN is_selection-rule-show_amounts = abap_true
                                    THEN amount_totals( it_findings ) ).
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
      WHEN lv_amounts IS NOT INITIAL
      THEN zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-alert_subject_amount
                                  iv_v1    = is_run-area
                                  iv_v2    = lv_worst
                                  iv_v3    = what( it_findings = it_findings iv_rule_id = is_selection-rule-rule_id )
                                  iv_v4    = iv_total
                                  iv_tail  = lv_amounts )
      ELSE zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-alert_subject_count
                                  iv_v1    = is_run-area
                                  iv_v2    = lv_worst
                                  iv_v3    = what( it_findings = it_findings iv_rule_id = is_selection-rule-rule_id )
                                  iv_v4    = iv_total ) ).
    " The system first: a QA1 alert is never mistaken for production
    rs_message-subject = |[{ COND sysysid( WHEN is_run-sysid IS NOT INITIAL THEN is_run-sysid ELSE sy-sysid ) }]|
                      && rs_message-subject.

    " Business context of the e-mail: standard keys and the table blocks (put in after rendering)
    DATA(lv_seed) = |{ is_run-run_id }|.
    rs_message-context-header = header( is_message    = rs_message
                                        is_selection  = is_selection
                                        is_run        = is_run
                                        it_findings   = it_findings
                                        iv_total      = iv_total
                                        iv_suppressed = iv_suppressed
                                        iv_amounts    = lv_amounts ).
    IF lt_owned IS NOT INITIAL.
      DATA(lv_section_token) = zcl_ca_ops_mail_composer=>token( iv_block = zif_ca_ops_types=>gc_mail_block-section
                                                                iv_seed  = lv_seed ).
      rs_message-context-header-table_section = lv_section_token.
      INSERT VALUE #( name  = zif_ca_ops_types=>gc_mail_block-section
                      token = lv_section_token
                      html  = mo_section->html( lt_owned )
                      text  = mo_section->text( lt_owned ) ) INTO TABLE rs_message-context-blocks.
    ENDIF.
    IF lt_other IS NOT INITIAL OR iv_suppressed > 0.
      DATA(lv_main_token) = zcl_ca_ops_mail_composer=>token( iv_block = zif_ca_ops_types=>gc_mail_block-main
                                                             iv_seed  = lv_seed ).
      rs_message-context-header-table_main = lv_main_token.
      INSERT VALUE #( name  = zif_ca_ops_types=>gc_mail_block-main
                      token = lv_main_token
                      html  = findings_html( it_findings     = lt_other
                                             iv_suppressed   = iv_suppressed
                                             iv_show_amounts = is_selection-rule-show_amounts )
                      text  = findings_text( it_findings     = lt_other
                                             iv_suppressed   = iv_suppressed
                                             iv_show_amounts = is_selection-rule-show_amounts ) )
             INTO TABLE rs_message-context-blocks.
    ENDIF.
    " Template: the rule's, else the section's for its findings (channel and generic: the router)
    rs_message-template_id = COND #( WHEN is_selection-rule-template_id IS NOT INITIAL
                                     THEN is_selection-rule-template_id
                                     WHEN lt_owned IS NOT INITIAL
                                     THEN mo_section->template_id( lt_owned ) ).
    " The built-in layout: the content of the message whatever renderer the router uses later
    zcl_ca_ops_mail_composer=>apply( EXPORTING io_template = NEW zcl_ca_ops_mail_tpl_builtin( )
                                               iv_renderer = zif_ca_ops_types=>gc_renderer-builtin
                                     CHANGING  cs_message  = rs_message ).
  ENDMETHOD.


  METHOD header.
    rs_header-subject   = is_message-subject.
    rs_header-headline  = condense( replace( val  = CONV string( is_message-subject )
                                             pcre = gc_subject_prefix
                                             with = `` ) ).
    rs_header-system_id = COND #( WHEN is_run-sysid IS NOT INITIAL THEN is_run-sysid ELSE sy-sysid ).
    rs_header-client    = sy-mandt.
    rs_header-area      = is_run-area.
    rs_header-rule_id   = is_selection-rule-rule_id.
    rs_header-severity  = is_message-severity.
    rs_header-severity_text = severity_text( is_message-severity ).
    rs_header-check_code = COND #( WHEN it_findings IS NOT INITIAL
                                        AND what( it_findings = it_findings iv_rule_id = space ) IS NOT INITIAL
                                   THEN it_findings[ 1 ]-check_code ).
    rs_header-check_text = COND #( WHEN it_findings IS NOT INITIAL THEN it_findings[ 1 ]-message ).
    rs_header-run_id      = |{ is_run-run_id }|.
    rs_header-run_variant = is_run-variant.
    rs_header-run_status  = is_run-status.
    rs_header-run_rag     = is_run-rag.
    DATA(lv_line_1) = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-alert_run_line_1
                                             iv_v1    = is_run-variant
                                             iv_v2    = is_run-status
                                             iv_v3    = is_run-rag
                                             iv_v4    = is_run-total_items ).
    DATA(lv_line_2) = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-alert_run_line_2
                                             iv_v1    = is_run-failed_items
                                             iv_v2    = is_run-blocked_items ).
    rs_header-run_line    = |{ lv_line_1 } { lv_line_2 }|.
    rs_header-job_name    = is_run-jobname.
    rs_header-job_count   = is_run-jobcount.
    rs_header-started_at  = time_text( is_run-started_at ).
    rs_header-ended_at    = time_text( is_run-ended_at ).
    rs_header-time_zone   = ms_mail-time_zone.
    rs_header-findings_total = |{ iv_total }|.
    IF iv_suppressed > 0.
      rs_header-findings_held_back = |{ iv_suppressed }|.
    ENDIF.
    " new / repeated / overdue, earliest due date and its owner: from the stored exceptions of the run
    IF mt_facts IS NOT INITIAL.
      DATA(lv_new) = 0.
      DATA(lv_repeated) = 0.
      DATA(lv_overdue) = 0.
      DATA(lv_due) = VALUE d( ).
      DATA(lv_owner) = VALUE syuname( ).
      LOOP AT it_findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
        READ TABLE mt_facts ASSIGNING FIELD-SYMBOL(<ls_fact>)
             WITH TABLE KEY object_type = <ls_finding>-object_type
                            object_key  = <ls_finding>-object_key
                            check_code  = <ls_finding>-check_code.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        IF <ls_fact>-occurrences > 1.
          lv_repeated += 1.
        ELSE.
          lv_new += 1.
        ENDIF.
        IF <ls_fact>-due_date IS NOT INITIAL AND ms_mail-today IS NOT INITIAL AND <ls_fact>-due_date < ms_mail-today.
          lv_overdue += 1.
        ENDIF.
        IF <ls_fact>-due_date IS NOT INITIAL AND ( lv_due IS INITIAL OR <ls_fact>-due_date < lv_due ).
          lv_due   = <ls_fact>-due_date.
          lv_owner = <ls_fact>-owner.
        ENDIF.
      ENDLOOP.
      rs_header-findings_new      = |{ lv_new }|.
      rs_header-findings_repeated = |{ lv_repeated }|.
      IF lv_overdue > 0.
        rs_header-findings_overdue = |{ lv_overdue }|.
      ENDIF.
      IF lv_due IS NOT INITIAL.
        rs_header-due_date = |{ lv_due DATE = ISO }|.
        rs_header-owner    = lv_owner.
      ENDIF.
    ENDIF.
    rs_header-exceptions_link = COND #( WHEN ms_mail-exc_link IS NOT INITIAL THEN ms_mail-exc_link
                                        ELSE zif_ca_ops_types=>gc_exc_app ).
    rs_header-reference_line = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-alert_run_reference
                                                      iv_v1    = is_run-run_id
                                                      iv_v2    = is_run-jobname
                                                      iv_v3    = is_run-jobcount ).
    rs_header-amount_total = iv_amounts.
  ENDMETHOD.


  METHOD findings_html.
    IF it_findings IS INITIAL AND iv_suppressed <= 0.
      RETURN.
    ENDIF.
    IF it_findings IS NOT INITIAL.
      " a column is shown when one finding has a value for it (the first five always)
      DATA(lt_columns) = columns( ).
      DATA lt_rows TYPE STANDARD TABLE OF string_table WITH EMPTY KEY.
      LOOP AT it_findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
        DATA(lt_cells) = cells( is_finding = <ls_finding> iv_show_amounts = iv_show_amounts ).
        LOOP AT lt_cells TRANSPORTING NO FIELDS WHERE table_line IS NOT INITIAL.
          lt_columns[ sy-tabix ]-shown = abap_true.
        ENDLOOP.
        INSERT lt_cells INTO TABLE lt_rows.
      ENDLOOP.
      rv_html = gc_html-table_open && gc_html-tr_open.
      LOOP AT lt_columns ASSIGNING FIELD-SYMBOL(<ls_column>) WHERE shown = abap_true.
        rv_html = rv_html && gc_html-th_open && zcl_ca_ops_util=>html_escape( <ls_column>-label ) && gc_html-th_close.
      ENDLOOP.
      rv_html = rv_html && gc_html-tr_close.
      LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<lt_row>).
        rv_html = rv_html && gc_html-tr_open.
        LOOP AT <lt_row> ASSIGNING FIELD-SYMBOL(<lv_value>).
          DATA(ls_column) = lt_columns[ sy-tabix ].
          IF ls_column-shown = abap_false.
            CONTINUE.
          ENDIF.
          rv_html = rv_html && COND string( WHEN ls_column-right = abap_true THEN gc_html-td_right ELSE gc_html-td_open )
                 && replace( val  = zcl_ca_ops_util=>html_escape( <lv_value> )
                             sub  = cl_abap_char_utilities=>newline
                             with = gc_html-line_break
                             occ  = 0 )
                 && gc_html-td_close.
        ENDLOOP.
        rv_html = rv_html && gc_html-tr_close.
      ENDLOOP.
      rv_html = rv_html && gc_html-table_close.
    ENDIF.
    IF iv_suppressed > 0.
      rv_html = rv_html && gc_html-p_open
             && zcl_ca_ops_util=>html_escape( zcl_ca_ops_util=>text(
                                                iv_msgno = zif_ca_ops_types=>gc_msg-alert_more_findings
                                                iv_v1    = iv_suppressed ) )
             && gc_html-p_close.
    ENDIF.
  ENDMETHOD.


  METHOD findings_text.
    DATA(lv_newline) = cl_abap_char_utilities=>newline.
    DATA(lt_columns) = columns( ).
    DATA lt_lines TYPE string_table.
    LOOP AT it_findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
      DATA(lv_line) = |{ <ls_finding>-severity } { <ls_finding>-rule_id } { <ls_finding>-object_key } { <ls_finding>-message }|.
      DATA(lt_cells) = cells( is_finding = <ls_finding> iv_show_amounts = iv_show_amounts ).
      " the known context after the line: columns 5 (reference) to the amount, labelled
      LOOP AT lt_cells ASSIGNING FIELD-SYMBOL(<lv_cell>) FROM 5 TO lines( lt_cells ) - 2
           WHERE table_line IS NOT INITIAL.
        lv_line = |{ lv_line }{ gc_part_separator }{ lt_columns[ sy-tabix ]-label }{ gc_label_separator }{ <lv_cell> }|.
      ENDLOOP.
      INSERT lv_line INTO TABLE lt_lines.
      " the labelled detail lines of the finding, indented
      IF <ls_finding>-details IS NOT INITIAL.
        SPLIT <ls_finding>-details AT lv_newline INTO TABLE DATA(lt_details).
        LOOP AT lt_details ASSIGNING FIELD-SYMBOL(<lv_detail>) WHERE table_line IS NOT INITIAL.
          INSERT |{ gc_indent }{ <lv_detail> }| INTO TABLE lt_lines.
        ENDLOOP.
      ENDIF.
    ENDLOOP.
    IF iv_suppressed > 0.
      INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-alert_more_findings
                                    iv_v1    = iv_suppressed ) INTO TABLE lt_lines.
    ENDIF.
    rv_text = concat_lines_of( table = lt_lines sep = lv_newline ).
  ENDMETHOD.


  METHOD columns.
    " order = CELLS: severity, rule, check, object, reference, business date, company code, account,
    " payment method, count, amount, message, details
    rt_columns = VALUE #( ( label = TEXT-c01 shown = abap_true )
                          ( label = TEXT-c02 shown = abap_true )
                          ( label = TEXT-c03 shown = abap_true )
                          ( label = TEXT-c04 shown = abap_true )
                          ( label = TEXT-c05 )
                          ( label = TEXT-c08 )
                          ( label = TEXT-c09 )
                          ( label = TEXT-c10 )
                          ( label = TEXT-c11 )
                          ( label = TEXT-c12 right = abap_true )
                          ( label = TEXT-c06 right = abap_true )
                          ( label = TEXT-c07 shown = abap_true )
                          ( label = TEXT-c13 ) ).
  ENDMETHOD.


  METHOD cells.
    DATA(lv_amount) = COND string(
      WHEN iv_show_amounts = abap_true AND is_finding-amount <> 0
      THEN condense( |{ is_finding-currency } { zcl_ca_ops_util=>format_amount( CONV #( is_finding-amount ) ) }| ) ).
    rt_cells = VALUE #( ( CONV #( is_finding-severity ) )
                        ( CONV #( is_finding-rule_id ) )
                        ( CONV #( is_finding-check_code ) )
                        ( condense( |{ is_finding-object_type } { is_finding-object_key }| ) )
                        ( CONV #( is_finding-reference ) )
                        ( COND #( WHEN is_finding-business_date IS NOT INITIAL
                                  THEN |{ is_finding-business_date DATE = ISO }| ) )
                        ( CONV #( is_finding-company_code ) )
                        ( CONV #( is_finding-account ) )
                        ( CONV #( is_finding-pay_method ) )
                        ( COND #( WHEN is_finding-item_count > 0 THEN |{ is_finding-item_count }| ) )
                        ( lv_amount )
                        ( CONV #( is_finding-message ) )
                        ( is_finding-details ) ).
  ENDMETHOD.


  METHOD amount_totals.
    DATA lt_totals TYPE tt_amount_total.
    DATA lt_parts  TYPE string_table.
    LOOP AT it_findings ASSIGNING FIELD-SYMBOL(<ls_finding>) WHERE amount <> 0.
      READ TABLE lt_totals ASSIGNING FIELD-SYMBOL(<ls_total>) WITH TABLE KEY currency = <ls_finding>-currency.
      IF sy-subrc <> 0.
        INSERT VALUE #( currency = <ls_finding>-currency ) INTO TABLE lt_totals ASSIGNING <ls_total>.
      ENDIF.
      <ls_total>-amount += <ls_finding>-amount.
    ENDLOOP.
    LOOP AT lt_totals ASSIGNING <ls_total>.
      INSERT condense( |{ <ls_total>-currency } { zcl_ca_ops_util=>format_amount( <ls_total>-amount ) }| )
        INTO TABLE lt_parts.
    ENDLOOP.
    rv_text = concat_lines_of( table = lt_parts sep = gc_amount_separator ).
  ENDMETHOD.


  METHOD what.
    rv_what = iv_rule_id.
    IF it_findings IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_check) = it_findings[ 1 ]-check_code.
    LOOP AT it_findings TRANSPORTING NO FIELDS WHERE check_code <> lv_check.
      RETURN.
    ENDLOOP.
    rv_what = lv_check.
  ENDMETHOD.


  METHOD severity_text.
    rv_text = SWITCH #( iv_severity
                        WHEN zif_ca_ops_types=>gc_severity-block   THEN TEXT-s01
                        WHEN zif_ca_ops_types=>gc_severity-error   THEN TEXT-s02
                        WHEN zif_ca_ops_types=>gc_severity-warning THEN TEXT-s03
                        WHEN zif_ca_ops_types=>gc_severity-info    THEN TEXT-s04 ).
  ENDMETHOD.


  METHOD time_text.
    IF iv_timestamp IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_timestamp) = CONV timestamp( iv_timestamp ).
    CONVERT TIME STAMP lv_timestamp TIME ZONE ms_mail-time_zone INTO DATE DATA(lv_date) TIME DATA(lv_time).
    rv_text = |{ lv_date DATE = ISO } { lv_time TIME = ISO } { ms_mail-time_zone }|.
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
