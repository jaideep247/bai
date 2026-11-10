*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_demo_dao.intf.abap
*& Purpose:
*& Data access of the demo consumer ZCA_OPS_DEMO: counts background jobs of
*& this client in TBTCO (SAP standard, read only) by status and time. The
*& unit tests of ZCL_CA_OPS_DEMO replace it with a double.
*& Modification log:
*& 2026-11-10 | Initial version (demo consumer of the operations framework).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework demo - job counts</p>
INTERFACE zif_ca_ops_demo_dao
  PUBLIC.

  "! Jobs of this client with status iv_status that ended between is_from and is_to (both included)
  METHODS count_ended
    IMPORTING
      iv_status       TYPE zif_ca_ops_demo_types=>ty_job_status
      is_from         TYPE zif_ca_ops_demo_types=>ty_moment
      is_to           TYPE zif_ca_ops_demo_types=>ty_moment
    RETURNING
      VALUE(rv_count) TYPE i.

  "! Jobs of this client with status iv_status planned to start between is_from and is_to
  METHODS count_planned
    IMPORTING
      iv_status       TYPE zif_ca_ops_demo_types=>ty_job_status
      is_from         TYPE zif_ca_ops_demo_types=>ty_moment
      is_to           TYPE zif_ca_ops_demo_types=>ty_moment
    RETURNING
      VALUE(rv_count) TYPE i.

ENDINTERFACE.
