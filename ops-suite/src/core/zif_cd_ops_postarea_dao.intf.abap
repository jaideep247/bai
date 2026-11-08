*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_postarea_dao.intf.abap
*& Purpose:
*& SQL seam of the posting area reader: the stored FQC0 entries of one
*& posting area (TFK033D, set-based, read-only). Implementation
*& ZCL_CD_OPS_POSTAREA_DAO; in-memory double ZCL_CD_OPS_POSTAREA_MEM.
*& Modification log:
*& 2026-11-08 | Initial version (customer posting areas ZRSN, ZPMC, ZBTM, ZBTR).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - customer posting areas: repository</p>
INTERFACE zif_cd_ops_postarea_dao
  PUBLIC.

  "! Every entry of the posting area for the application area and chart of accounts,
  "! ordered by KEY01..KEY08 (values condensed; nothing truncated)
  METHODS read_entries
    IMPORTING
      iv_applk          TYPE zif_cd_ops_postarea_types=>ty_applk
      iv_area           TYPE zif_cd_ops_postarea_types=>ty_area
      iv_ktopl          TYPE zif_cd_ops_postarea_types=>ty_ktopl
    RETURNING
      VALUE(rt_entries) TYPE zif_cd_ops_postarea_types=>tt_entry.

ENDINTERFACE.
