*&---------------------------------------------------------------------*
*& Artifact: zif_cd_fmon_prism_queue.intf.abap
*& Purpose:
*& Seam for queueing the instant processing of one stored PRISM event (real
*& implementation: bgPF, ZCL_CD_FMON_PRISM_QUEUE). The unit starts with the
*& caller's COMMIT WORK, so event row and unit are committed together.
*& Modification log:
*& 2026-11-06 | Initial version (instant PRISM processing, user decision 2026-11-06).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FMON PRISM status API - queue the instant processing</p>
INTERFACE zif_cd_fmon_prism_queue
  PUBLIC.

  "! Register the background unit for the event in the current LUW (starts at COMMIT WORK)
  "! @raising zcx_cd_ops_error | the unit could not be registered (the 5-minute run applies the event)
  METHODS enqueue
    IMPORTING
      iv_event_id TYPE zif_cd_fmon_prism_types=>ty_event_id
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
