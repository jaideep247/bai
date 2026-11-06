*&---------------------------------------------------------------------*
*& Artifact: zif_cd_fmon_ddic.intf.abap
*& Purpose:
*& DDIC describer seam: returns the field list of a transparent table so
*& configured table and field names can be validated before any SQL.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - DDIC describer (seam)</p>
INTERFACE zif_cd_fmon_ddic
  PUBLIC.

  "! Fields of a DDIC table
  "! @raising zcx_cd_ops_error | table unknown or not a flat DDIC structure
  METHODS describe_table
    IMPORTING
      iv_table         TYPE zif_cd_fmon_types=>ty_tabname
    RETURNING
      VALUE(rt_fields) TYPE zif_cd_fmon_types=>tt_ddic_field
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
