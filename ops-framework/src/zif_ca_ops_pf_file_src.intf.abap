*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_pf_file_src.intf.abap
*& Purpose:
*& File source of the payment file lifecycle (role FILE): which payment
*& files the payment runs produced in a window and the payments and
*& amounts each holds. Delivered: ZCL_CA_OPS_PF_SRC_DPAYH (SAP FI-CA
*& payment runs, DPAYH); a site plugs its own (a file register of its
*& middleware, a folder log). A failure raises - the engine records the
*& source as not evaluated, never as "no files".
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - payment file source</p>
INTERFACE zif_ca_ops_pf_file_src
  PUBLIC.

  INTERFACES zif_ca_ops_pf_adapter.

  "! The files of the window with their payments
  "! @parameter is_request | Area, file type, adapter row, window (UTC, overlap applied), limit, known files
  "! @parameter rs_batch   | Files, as-of of the source, partial flag and reason
  "! @raising zcx_ca_ops_error | the source could not be read
  METHODS read_files
    IMPORTING
      is_request      TYPE zif_ca_ops_pf_types=>ty_request
    RETURNING
      VALUE(rs_batch) TYPE zif_ca_ops_pf_types=>ty_file_batch
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
