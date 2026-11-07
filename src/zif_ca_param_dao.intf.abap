*&---------------------------------------------------------------------*
*& Artifact: zif_ca_param_dao.intf.abap
*& Purpose:
*& Data access of the parameter framework: one call reads everything of one
*& area (master row, definitions, values), with deterministic order. The
*& implementations are ZCL_CA_PARAM_DAO (database) and ZCL_CA_PARAM_DAO_MEM
*& (in memory, for tests). No logic: semantics live in ZCL_CA_PARAM only.
*& Modification log:
*& 2026-11-07 | Initial version.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Parameter framework - data access</p>
INTERFACE zif_ca_param_dao
  PUBLIC.

  "! Area row, its definitions (by name) and values (by name, NUMB).
  "! rs_data-found = abap_false when the area does not exist.
  "! @parameter iv_area | Parameter area (upper case)
  "! @parameter rs_data | Snapshot of the area
  METHODS read_area
    IMPORTING
      iv_area        TYPE zif_ca_param_types=>ty_area
    RETURNING
      VALUE(rs_data) TYPE zif_ca_param_types=>ty_area_data.

ENDINTERFACE.
