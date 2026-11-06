*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_alert_dao.intf.abap
*& Purpose:
*& Repository for alert configuration (ZCD_OPS_ALERT_RULE, ZCD_OPS_ALERT_CHN)
*& and the delivery log ZCD_OPS_ALERT_LOG (throttling, escalation, audit).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - alert configuration and log</p>
INTERFACE zif_cd_ops_alert_dao
  PUBLIC.

  "! Active rules of a payment engine area plus rules for payment engine area '*'
  METHODS get_rules
    IMPORTING
      iv_pe_area       TYPE zif_cd_ops_types=>ty_pe_area
    RETURNING
      VALUE(rt_rules) TYPE zif_cd_ops_types=>tt_alert_rule.

  METHODS get_channels
    RETURNING
      VALUE(rt_channels) TYPE zif_cd_ops_types=>tt_alert_channel.

  "! Log rows of a rule since a point in time, newest first
  METHODS get_log
    IMPORTING
      iv_rule_id    TYPE zif_cd_ops_types=>ty_rule_id
      iv_since      TYPE timestampl
    RETURNING
      VALUE(rt_log) TYPE zif_cd_ops_types=>tt_alert_log.

  METHODS insert_log
    IMPORTING
      it_log TYPE zif_cd_ops_types=>tt_alert_log.

ENDINTERFACE.
