*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_pf_transfer_src.intf.abap
*& Purpose:
*& Transfer source of the payment file lifecycle (role TRANSFER): the
*& hand-offs of a file after SAP generated it - middleware pickup, onward
*& delivery, a direct transfer to the bank's server - and their failures.
*& Delivered: none (site-specific); a middleware's file register or the
*& log of a direct transfer are customer classes. The methods are those
*& of ZIF_CA_OPS_PF_EVENT_SRC; the role is the interface.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - payment file transfer source</p>
INTERFACE zif_ca_ops_pf_transfer_src
  PUBLIC.

  INTERFACES zif_ca_ops_pf_event_src.

ENDINTERFACE.
