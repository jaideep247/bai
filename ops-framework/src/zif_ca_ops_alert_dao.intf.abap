*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_alert_dao.intf.abap
*& Purpose:
*& Repository for alert configuration (ZCA_OPS_ALRULE, ZCA_OPS_ALCHN)
*& and the delivery log ZCA_OPS_ALLOG (throttling, escalation, audit).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | claim, complete, get_repeat_keys (audit A17, DEFAULT IGNORE).
*& 2026-11-06 | Modern-syntax sweep: alert tables ZCA_OPS_ALCHN / ALLOG / ALRULE.
*& 2026-11-10 | Moved from ZIF_CD_OPS_ALERT_DAO to the reusable framework ZCA_OPS.
*& 2026-11-10 | GET_EXCEPTION_FACTS (business context of the alert e-mail); template fields of rules,
*&            | channels and log rows.
*& 2026-11-11 | Operations response features (DEFAULT IGNORE, existing doubles unchanged): GET_MARKS (planned
*&            | downtime and correlation of the stored findings of a run), GET_CHILD_COUNTS, GET_RUNBOOKS,
*&            | GET_ESCALATION_CANDIDATES (open, unassigned exceptions), GET_INTENT_LOG (escalation steps).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - alert configuration and log</p>
INTERFACE zif_ca_ops_alert_dao
  PUBLIC.

  "! Active rules of a area plus rules for area '*'
  METHODS get_rules
    IMPORTING
      iv_area       TYPE zif_ca_ops_types=>ty_area
    RETURNING
      VALUE(rt_rules) TYPE zif_ca_ops_types=>tt_alert_rule.

  METHODS get_channels
    RETURNING
      VALUE(rt_channels) TYPE zif_ca_ops_types=>tt_alert_channel.

  "! Log rows of a rule since a point in time, newest first
  METHODS get_log
    IMPORTING
      iv_rule_id    TYPE zif_ca_ops_types=>ty_rule_id
      iv_since      TYPE timestampl
    RETURNING
      VALUE(rt_log) TYPE zif_ca_ops_types=>tt_alert_log.

  "! Audit rows of routing decisions (throttled, quiet hours, repeat, failed, sent by SEND). A row
  "! without an alert intent gets its alert ID (hex) as INTENT_KEY and attempt 0, so the unique
  "! index INT (MANDT, INTENT_KEY, ATTEMPT) never makes two decisions collide; a row the database
  "! still does not take is an error (message 081), never a silent loss
  METHODS insert_log
    IMPORTING
      it_log TYPE zif_ca_ops_types=>tt_alert_log
    RAISING
      zcx_ca_ops_error.

  "! Durable claim of an alert intent before the external send (audit A17): inserts
  "! is_log (status C) with the next attempt number unless the intent is already
  "! claimed or sent; returns abap_true when another dispatcher holds it
  METHODS claim DEFAULT IGNORE
    IMPORTING
      is_log                     TYPE zif_ca_ops_types=>ty_alert_log
    RETURNING
      VALUE(rv_claimed_elsewhere) TYPE abap_bool.

  "! Final status of a claimed alert (S, F or P) with error and time
  METHODS complete DEFAULT IGNORE
    IMPORTING
      is_log TYPE zif_ca_ops_types=>ty_alert_log
    RAISING
      zcx_ca_ops_error.

  "! Findings of a run that were raised again only because an open exception was
  "! carried forward (OCCURRENCES > 1) - not alerted again (audit A17)
  METHODS get_repeat_keys DEFAULT IGNORE
    IMPORTING
      iv_run_id      TYPE zif_ca_ops_types=>ty_run_id
    RETURNING
      VALUE(rt_keys) TYPE zif_ca_ops_types=>tt_repeat_key.

  "! Stored exceptions of a run (open or assigned): occurrences, SLA due date and owner - the
  "! business context of the alert e-mail (new / repeated / overdue, due date, owner)
  METHODS get_exception_facts DEFAULT IGNORE
    IMPORTING
      iv_run_id       TYPE zif_ca_ops_types=>ty_run_id
    RETURNING
      VALUE(rt_facts) TYPE zif_ca_ops_types=>tt_exception_fact.

  "! Planned downtime and correlation marks of the stored findings of a run (2026-11-11)
  METHODS get_marks DEFAULT IGNORE
    IMPORTING
      iv_run_id       TYPE zif_ca_ops_types=>ty_run_id
    RETURNING
      VALUE(rt_marks) TYPE zif_ca_ops_resp_types=>tt_finding_mark.

  "! Open (O / A) children of correlation groups - the number the parent's alert names
  METHODS get_child_counts DEFAULT IGNORE
    IMPORTING
      it_corr_ids      TYPE zif_ca_ops_resp_types=>tt_uuid
    RETURNING
      VALUE(rt_counts) TYPE zif_ca_ops_resp_types=>tt_corr_count.

  "! Active runbook rows of an area (ZCA_OPS_RUNBOOK)
  METHODS get_runbooks DEFAULT IGNORE
    IMPORTING
      iv_area            TYPE zif_ca_ops_types=>ty_area
    RETURNING
      VALUE(rt_runbooks) TYPE zif_ca_ops_resp_types=>tt_runbook.

  "! Open, unassigned exceptions (disposition O, severity B / E / W) of an area first seen at or before
  "! iv_seen_before - the candidates of the escalation until acknowledged
  METHODS get_escalation_candidates DEFAULT IGNORE
    IMPORTING
      iv_area              TYPE zif_ca_ops_types=>ty_area
      iv_seen_before       TYPE timestampl
    RETURNING
      VALUE(rt_candidates) TYPE zif_ca_ops_resp_types=>tt_esc_candidate.

  "! Log rows of these alert intents (the escalation steps claimed, sent or failed so far)
  METHODS get_intent_log DEFAULT IGNORE
    IMPORTING
      it_intent_keys TYPE zif_ca_ops_resp_types=>tt_intent_key
    RETURNING
      VALUE(rt_log)  TYPE zif_ca_ops_types=>tt_alert_log.

ENDINTERFACE.
