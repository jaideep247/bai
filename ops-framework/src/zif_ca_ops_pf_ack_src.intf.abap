*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_pf_ack_src.intf.abap
*& Purpose:
*& Acknowledgement source of the payment file lifecycle (role ACK): the
*& bank's answers - receipt (the bank has the file) and acceptance
*& (accepted, rejected, partly accepted) per file, per batch or per
*& payment, and acknowledgements that cover several files. Delivered:
*& none (bank formats are site-specific). The methods are those of
*& ZIF_CA_OPS_PF_EVENT_SRC; the role is the interface.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - payment file acknowledgement source</p>
INTERFACE zif_ca_ops_pf_ack_src
  PUBLIC.

  INTERFACES zif_ca_ops_pf_event_src.

ENDINTERFACE.
