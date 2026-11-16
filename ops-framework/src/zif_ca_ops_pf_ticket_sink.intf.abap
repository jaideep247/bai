*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_pf_ticket_sink.intf.abap
*& Purpose:
*& Ticket sink of the payment file lifecycle (role TICKET, optional): a
*& file that newly became overdue at its stop milestone is handed to the
*& site's ticketing once. Delivered: ZCL_CA_OPS_PF_TICKET_LOG (log only:
*& no outbound call, no incident in SAP). A site's sink that calls its
*& ticketing system is a customer class with its own outbound connection
*& and its own approval.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - payment file ticket sink</p>
INTERFACE zif_ca_ops_pf_ticket_sink
  PUBLIC.

  INTERFACES zif_ca_ops_pf_adapter.

  "! Raise a ticket for an overdue file
  "! @parameter is_ticket | File, milestone, minutes overdue and the finding text
  "! @parameter rs_result | L logged only, C created (with the ticket reference), F failed (with the text)
  METHODS raise_ticket
    IMPORTING
      is_ticket        TYPE zif_ca_ops_pf_types=>ty_ticket
    RETURNING
      VALUE(rs_result) TYPE zif_ca_ops_pf_types=>ty_ticket_result.

ENDINTERFACE.
