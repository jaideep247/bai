*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_pay_request.intf.abap
*& Purpose:
*& The one rule of a payment request's due date and stage (requests not
*& paid on their requested payment date, user decision 2026-11-08): a
*& request is tracked when ANY attempt of FIN + source in the request log
*& ZCD_PAYM_REQ_LOG has the SUCCESS status (never the highest COUNTER); it
*& is due on its requested payment date, or the next business day when it
*& was received after the cut-off of its source on that day or the day is
*& no business day; it is processed when the payment engine item(s) of the
*& FIN are cleared by a payment run on or before the due date. Used by the
*& payment worklist (ZCL_CD_OPS_PAY_SNAPSHOT: source REQUESTS, NIGHTLY
*& re-check) and the payment trace - no second copy of the rule.
*& Read-only: never posts, clears or changes a status.
*& Modification log:
*& 2026-11-08 | Initial version (requests not paid on their requested payment date).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment request - due date and stage (one rule)</p>
"! Instance from ZCL_CD_OPS_FACTORY=>GET_PAY_REQUEST (test double by
"! ZCL_CD_OPS_INJECTOR=>INJECT_PAY_REQUEST).
INTERFACE zif_cd_ops_pay_request
  PUBLIC.

  "! New payment requests of the watermark source REQUESTS: request log rows received after the
  "! watermark (keyset received date, time, FIN of the configured TRACE_SRC_REQUEST), at most iv_max;
  "! the FIN + source of every SUCCESS row and the watermark of the last row read
  "! @parameter iv_to | SWEEP: last received date read (initial: no upper bound)
  "! @raising zcx_cd_ops_error | request source not configured (TABLE, KEY, KEY2, STATUS, DATE) or not readable
  METHODS changes
    IMPORTING
      is_watermark      TYPE zif_cd_ops_payout_types=>ty_watermark
      iv_max            TYPE i
      iv_to             TYPE d OPTIONAL
    RETURNING
      VALUE(rs_changes) TYPE zif_cd_ops_payout_types=>ty_changes
    RAISING
      zcx_cd_ops_error.

  "! Due date and stage of the requests at the instant iv_now (UTC): one read of the request log for
  "! all their FIN numbers and one read of the items; a key without SUCCESS attempt is finished (not
  "! tracked - failures are the morning report's C_PRQ_NO_SPE)
  "! @raising zcx_cd_ops_error | request source not configured or not readable, capped read (fail closed)
  METHODS evaluate
    IMPORTING
      it_keys            TYPE zif_cd_ops_payout_types=>tt_req_key
      iv_now             TYPE zif_cd_ops_payout_types=>ty_timestamp
    RETURNING
      VALUE(rt_requests) TYPE zif_cd_ops_payout_types=>tt_request
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
