*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_params.intf.abap
*& Purpose:
*& Runtime parameters of the operations suite. Callers read parameters
*& through ZCL_CD_OPS_FACTORY=>GET_PARAMS only; the one implementation is
*& the adapter ZCL_CD_OPS_PARAMS_CA over the global parameter framework
*& ZCA_PARAM (areas CD_OPS, CD_EBS, CD_FMON, CD_HCK). Definitions (value
*& type, limits, default) live in the framework; config/param_definitions.csv
*& is the delivered set. Errors are never silent: get_errors( ).
*& Modification log:
*& 2026-11-07 | Initial version (split from ZIF_CD_OPS_STORE; get_range added).
*& 2026-11-07 | Served by ZCA_PARAM (adapter ZCL_CD_OPS_PARAMS_CA); get_errors added; the
*&            | definition default wins over the caller's default; BOOL blank = off.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - runtime parameters</p>
"! Runtime parameters in the framework ZCA_PARAM: get_param (one value), get_range
"! (select-option style), refresh_params (snapshot per run) and get_errors (parameters
"! that could not be read). Semantics: the value the framework resolves wins, including
"! a definition default and a BOOL row with blank value (off); the caller's iv_default
"! applies only when the framework resolves nothing (no row, no definition default) or
"! the parameter cannot be read (unknown name, invalid value - then also logged).
INTERFACE zif_cd_ops_params
  PUBLIC.

  "! Drop the parameter snapshot: the next read sees the current values.
  "! start_run of the store calls it, so every run sees the parameters valid at its
  "! start (audit A64). Entry points that validate without a run call it themselves.
  "! It also clears the error list of the previous snapshot.
  METHODS refresh_params.

  "! Value of a parameter, condensed. BOOL: X (on) or blank (off), never iv_default.
  "! Other types: the maintained value or the definition default; iv_default when both
  "! are blank or the parameter cannot be read (error logged, see get_errors).
  METHODS get_param
    IMPORTING
      iv_name         TYPE zif_cd_ops_types=>ty_param_name
      iv_default      TYPE string OPTIONAL
    RETURNING
      VALUE(rv_value) TYPE string.

  "! Select-option style view of a parameter: the rows of a kind S parameter, or one row
  "! I / EQ per element of a LIST parameter (blank elements dropped); an empty table when
  "! nothing is maintained or the parameter cannot be read. Callers must treat an empty
  "! range as "not configured", never as "all values".
  METHODS get_range
    IMPORTING
      iv_name         TYPE zif_cd_ops_types=>ty_param_name
    RETURNING
      VALUE(rt_range) TYPE zif_cd_ops_types=>tt_param_range.

  "! Parameters of the current snapshot that could not be read (one row per area / name,
  "! message of ZCX_CA_PARAM); each was also written to the application log once
  METHODS get_errors
    RETURNING
      VALUE(rt_errors) TYPE zif_cd_ops_types=>tt_param_error.

ENDINTERFACE.
