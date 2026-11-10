*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_alert_channel.intf.abap
*& Purpose:
*& One delivery channel (e-mail, application log). Channels are
*& plug-ins configured in ZCA_OPS_ALCHN; they deliver and nothing else.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Modern-syntax sweep: alert tables ZCA_OPS_ALCHN / ALLOG / ALRULE.
*& 2026-11-07 | HTTP webhook channel removed (read-only scope).
*& 2026-11-07 | CHECK_DESTINATION: the channel validates its own destination (e-mail: SO23 lists).
*& 2026-11-10 | Moved from ZIF_CD_OPS_ALERT_CHANNEL to the reusable framework ZCA_OPS.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - alert delivery channel</p>
INTERFACE zif_ca_ops_alert_channel
  PUBLIC.

  "! @raising zcx_ca_ops_error | delivery failed (router logs it as F)
  METHODS deliver
    IMPORTING
      is_message TYPE zif_ca_ops_types=>ty_alert_message
    RAISING
      zcx_ca_ops_error.

  "! Entries of iv_destination this channel cannot deliver to, comma-separated;
  "! blank = deliverable (or the channel does not check). Used by the configuration
  "! app before a rule is saved and by DELIVER before anything is sent.
  METHODS check_destination DEFAULT IGNORE
    IMPORTING
      iv_destination    TYPE zif_ca_ops_types=>ty_alert_dest
    RETURNING
      VALUE(rv_invalid) TYPE string.

ENDINTERFACE.
