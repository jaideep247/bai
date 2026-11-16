*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_pf_stmt_src.intf.abap
*& Purpose:
*& Statement source of the payment file lifecycle (role STMT, optional):
*& bank statement evidence that the payments of a file were posted or
*& settled (milestone SETTLED), e.g. a statement line that carries the
*& file's reference. Delivered: none (statement references are
*& site-specific). The methods are those of ZIF_CA_OPS_PF_EVENT_SRC; the
*& role is the interface.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - payment file statement source</p>
INTERFACE zif_ca_ops_pf_stmt_src
  PUBLIC.

  INTERFACES zif_ca_ops_pf_event_src.

ENDINTERFACE.
