*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_pf_event_src.intf.abap
*& Purpose:
*& Event source of the payment file lifecycle: the records of one source
*& in a window - each with its own ID and version, its native status (the
*& status mapping ZCA_OPS_PFMAP says which milestone and outcome it
*& evidences), the file it is about (native key, the files it covers, the
*& run, the payment or the batch), when it happened and its amount.
*& Included by the role interfaces ZIF_CA_OPS_PF_TRANSFER_SRC,
*& _ACK_SRC, _SCHED_SRC and _STMT_SRC. Out-of-order and repeated records
*& are expected: the engine stores each observation once.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - payment file event source</p>
INTERFACE zif_ca_ops_pf_event_src
  PUBLIC.

  INTERFACES zif_ca_ops_pf_adapter.

  "! The records of the window
  "! @parameter is_request | Area, file type, adapter row, window (UTC, overlap applied), limit, open files
  "! @parameter rs_batch   | Events, as-of of the source, partial flag and reason
  "! @raising zcx_ca_ops_error | the source could not be read (not evaluated - never "no events")
  METHODS read_events
    IMPORTING
      is_request      TYPE zif_ca_ops_pf_types=>ty_request
    RETURNING
      VALUE(rs_batch) TYPE zif_ca_ops_pf_types=>ty_event_batch
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
