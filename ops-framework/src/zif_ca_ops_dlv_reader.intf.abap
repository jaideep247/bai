*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_dlv_reader.intf.abap
*& Purpose:
*& Send status reader of the e-mail channel (docs/EVALUATION_AND_
*& COVERAGE.md section 4): the SAPconnect status (SOST) of one submitted
*& alert, by the send request reference the channel kept at submission.
*& Plugged by parameter EVAL_EMAIL_READER (interface checked by RTTI). No
*& reader is delivered: the BCS / SOST status read is not verified on a
*& reference system yet (VERIFY V271, V272), so without a reader the e-mail
*& channel answers "cannot confirm" - never "delivered". Read-only: no
*& resend, no change of the send request.
*& Modification log:
*& 2026-11-16 | Initial version (build O: alert delivery confirmation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - e-mail send status reader</p>
INTERFACE zif_ca_ops_dlv_reader
  PUBLIC.

  "! Delivery state of a submitted e-mail: D only when SAPconnect reports it delivered (or transmitted, as the
  "! site decides after V271), P while it waits, F on an error status, N when the status cannot be read
  METHODS read
    IMPORTING
      is_log             TYPE zif_ca_ops_types=>ty_alert_log
    RETURNING
      VALUE(rs_delivery) TYPE zif_ca_ops_eval_types=>ty_delivery.

ENDINTERFACE.
