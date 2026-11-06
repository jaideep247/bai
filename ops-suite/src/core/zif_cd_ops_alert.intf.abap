*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_alert.intf.abap
*& Purpose:
*& Alert router port used by every payment engine area. dispatch( ) applies the alert
*& rules in ZCD_OPS_ALRULE; send( ) delivers a prepared report (e.g. the
*& morning report) by e-mail to the recipients of a route parameter.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-05 | dispatch( ) added: configurable rules, channels, throttling.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - alert router port</p>
INTERFACE zif_cd_ops_alert
  PUBLIC.

  "! Deliver a prepared HTML report by e-mail. Recipients: ZCD_OPS_PARAM
  "! ALERT_<route>, fallback ALERT_DEFAULT; none maintained = nothing sent.
  METHODS send
    IMPORTING
      iv_route   TYPE zif_cd_ops_types=>ty_param_name
      iv_subject TYPE string
      iv_html    TYPE string
    RAISING
      zcx_cd_ops_error.

  "! Apply the configured alert rules of the run's payment engine area to its findings and
  "! deliver through the configured channels. Delivery failures are logged in
  "! ZCD_OPS_ALLOG and never raised; raises only when configuration cannot be read.
  METHODS dispatch
    IMPORTING
      is_run      TYPE zif_cd_ops_types=>ty_run
      it_findings TYPE zif_cd_ops_types=>tt_finding
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
