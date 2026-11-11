*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_alert.intf.abap
*& Purpose:
*& Alert router port used by every area. dispatch( ) applies the alert
*& rules in ZCA_OPS_ALRULE; send( ) delivers a prepared report (e.g. the
*& daily report) by e-mail to the recipients of a route parameter.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-05 | dispatch( ) added: configurable rules, channels, throttling.
*& 2026-11-06 | Modern-syntax sweep: alert tables ZCA_OPS_ALCHN / ALLOG / ALRULE.
*& 2026-11-07 | Comment: recipients ALERT_<route> in ZCA_PARAM (the former parameter table retired).
*& 2026-11-10 | Moved from ZIF_CD_OPS_ALERT to the reusable framework ZCA_OPS.
*& 2026-11-10 | SEND: optional e-mail template around the prepared report (alert e-mail templates).
*& 2026-11-11 | ESCALATE (DEFAULT IGNORE): escalation until acknowledged - job ZCA_OPS_ESCALATE.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - alert router port</p>
INTERFACE zif_ca_ops_alert
  PUBLIC.

  "! Deliver a prepared HTML report by e-mail. Recipients: ZCA_PARAM
  "! ALERT_<route>, fallback ALERT_DEFAULT; none maintained = nothing sent.
  "! @parameter iv_template_id | e-mail template around the report (the report is its block
  "! TABLE_MAIN, the subject its key SUBJECT); blank = the report as it is
  METHODS send
    IMPORTING
      iv_route       TYPE zif_ca_ops_types=>ty_param_name
      iv_subject     TYPE string
      iv_html        TYPE string
      iv_template_id TYPE zif_ca_ops_types=>ty_template_id OPTIONAL
    RAISING
      zcx_ca_ops_error.

  "! Apply the configured alert rules of the run's area to its findings and
  "! deliver through the configured channels. Delivery failures are logged in
  "! ZCA_OPS_ALLOG and never raised; raises only when configuration cannot be read.
  METHODS dispatch
    IMPORTING
      is_run      TYPE zif_ca_ops_types=>ty_run
      it_findings TYPE zif_ca_ops_types=>tt_finding
    RAISING
      zcx_ca_ops_error.

  "! Escalation until acknowledged (2026-11-11): every open, unassigned exception of the area that an active
  "! rule with ESC_AFTER_MIN selects and whose next escalation step is due is sent to the rule's
  "! ESCALATION_DEST - one message per exception and step, logged in ZCA_OPS_ALLOG (ESC_STEP, one intent per
  "! exception and step: a step is never sent twice). Skipped: correlated children (their parent escalates),
  "! exceptions inside an approved planned downtime window, quiet hours of the rule (B excepted).
  "! Authorisation ZCA_OPS 16 for the area (041). Delivery failures are logged, never raised.
  METHODS escalate DEFAULT IGNORE
    IMPORTING
      iv_area          TYPE zif_ca_ops_types=>ty_area
    RETURNING
      VALUE(rs_result) TYPE zif_ca_ops_resp_types=>ty_escalation_result
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
