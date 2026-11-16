*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_pf_adapter.intf.abap
*& Purpose:
*& Common contract of every adapter of the payment file lifecycle
*& (docs/PAYMENT_FILE_LIFECYCLE.md section 8): a class named in
*& ZCA_OPS_PFADP-CLASS_NAME implements it and the interface of its role
*& (file source, transfer, acknowledgement, scheduler, statement source,
*& ticket sink, business calendar). The engine creates it by name through
*& ZCL_CA_OPS_FACTORY=>GET_PLUGIN (interface checked by RTTI) and hands
*& it its configuration row once. An adapter only reads: no posting, no
*& restart or retransmission of a file, no IDoc, no outbound call unless
*& it is a ticket sink a site configured.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - payment file adapter</p>
INTERFACE zif_ca_ops_pf_adapter
  PUBLIC.

  "! The adapter's configuration row (source ID, setting, source type) - called once after creation
  "! @raising zcx_ca_ops_error | the setting is not valid for the adapter (the file type is not evaluated)
  METHODS configure
    IMPORTING
      is_adapter TYPE zif_ca_ops_pf_types=>ty_adapter
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
