*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_pf_sched_src.intf.abap
*& Purpose:
*& Scheduler source of the payment file lifecycle (role SCHED): the state
*& of the job that generated a file - finished = milestone GENERATED,
*& cancelled = GENERATED failed. Delivered: ZCL_CA_OPS_PF_SRC_TBTCO (SAP
*& background jobs through the job monitor's data access); a site with
*& another scheduler plugs its own class. The methods are those of
*& ZIF_CA_OPS_PF_EVENT_SRC; the role is the interface.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - payment file scheduler source</p>
INTERFACE zif_ca_ops_pf_sched_src
  PUBLIC.

  INTERFACES zif_ca_ops_pf_event_src.

ENDINTERFACE.
