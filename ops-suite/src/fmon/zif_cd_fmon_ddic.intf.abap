*&---------------------------------------------------------------------*
*& Artifact: zif_cd_fmon_ddic.intf.abap
*& Purpose:
*& DDIC describer seam: returns the field list of a transparent table so
*& configured table and field names can be validated before any SQL.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Audit A51: MAY_READ (table display authorisation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - DDIC describer (seam)</p>
INTERFACE zif_cd_fmon_ddic
  PUBLIC.

  "! Fields of a DDIC table
  "! @raising zcx_ca_ops_error | table unknown or not a flat DDIC structure
  METHODS describe_table
    IMPORTING
      iv_table         TYPE zif_cd_fmon_types=>ty_tabname
    RETURNING
      VALUE(rt_fields) TYPE zif_cd_fmon_types=>tt_ddic_field
    RAISING
      zcx_ca_ops_error.

  "! Display authorisation for a table read by the dynamic reader (S_TABU_NAM 03,
  "! audit A51). DEFAULT IGNORE: a seam that does not implement it allows nothing.
  METHODS may_read DEFAULT IGNORE
    IMPORTING
      iv_table          TYPE zif_cd_fmon_types=>ty_tabname
    RETURNING
      VALUE(rv_allowed) TYPE abap_bool.

ENDINTERFACE.
