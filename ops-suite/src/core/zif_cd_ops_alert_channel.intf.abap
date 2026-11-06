*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_alert_channel.intf.abap
*& Purpose:
*& One delivery channel (e-mail, application log, HTTP webhook). Channels are
*& plug-ins configured in ZCD_OPS_ALCHN; they deliver and nothing else.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Modern-syntax sweep: alert tables ZCD_OPS_ALCHN / ALLOG / ALRULE.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - alert delivery channel</p>
INTERFACE zif_cd_ops_alert_channel
  PUBLIC.

  "! @raising zcx_cd_ops_error | delivery failed (router logs it as F)
  METHODS deliver
    IMPORTING
      is_message TYPE zif_cd_ops_types=>ty_alert_message
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
