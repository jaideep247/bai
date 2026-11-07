*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_params.intf.abap
*& Purpose:
*& Runtime parameters of the operations suite, split from ZIF_CD_OPS_STORE
*& (interface segregation): callers that only read parameters depend on this
*& interface (ZCL_CD_OPS_FACTORY=>GET_PARAMS), not on the run / finding store.
*& Today implemented by ZCL_CD_OPS_STORE over ZCD_OPS_PARAM and by the in-memory
*& ZCL_CD_OPS_PARAMS_MEM; designed so that an adapter over another parameter
*& framework can implement it later without touching a caller.
*& Modification log:
*& 2026-11-07 | Initial version (split from ZIF_CD_OPS_STORE; get_range added).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - runtime parameters</p>
"! Runtime parameters: get_param (one value), get_range (select-option style) and
"! refresh_params (snapshot per run). Semantics every implementation keeps:
"! the value is condensed; a missing or blank value returns iv_default.
INTERFACE zif_cd_ops_params
  PUBLIC.

  "! Drop the parameter snapshot: the next read sees the current values.
  "! start_run of the store calls it, so every run sees the parameters valid at its
  "! start (audit A64). Entry points that validate without a run call it themselves.
  METHODS refresh_params DEFAULT IGNORE.

  "! Value of a parameter, condensed; iv_default when not maintained or blank.
  "! Values are a snapshot per run (see refresh_params).
  METHODS get_param
    IMPORTING
      iv_name         TYPE zif_cd_ops_types=>ty_param_name
      iv_default      TYPE string OPTIONAL
    RETURNING
      VALUE(rv_value) TYPE string.

  "! Select-option style view of a parameter: one row I / EQ per entry of the
  "! comma or semicolon list (blank entries dropped); an empty table when the
  "! parameter is not maintained or blank. Callers must treat an empty range as
  "! "not configured", never as "all values".
  METHODS get_range
    IMPORTING
      iv_name         TYPE zif_cd_ops_types=>ty_param_name
    RETURNING
      VALUE(rt_range) TYPE zif_cd_ops_types=>tt_param_range.

ENDINTERFACE.
