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

  METHODS insert_log
    IMPORTING
      it_log TYPE zif_ca_ops_types=>tt_alert_log.

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
      is_log TYPE zif_ca_ops_types=>ty_alert_log.

  "! Findings of a run that were raised again only because an open exception was
  "! carried forward (OCCURRENCES > 1) - not alerted again (audit A17)
  METHODS get_repeat_keys DEFAULT IGNORE
    IMPORTING
      iv_run_id      TYPE zif_ca_ops_types=>ty_run_id
    RETURNING
      VALUE(rt_keys) TYPE zif_ca_ops_types=>tt_repeat_key.

ENDINTERFACE.
