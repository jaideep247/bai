*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_params.intf.abap
*& Purpose:
*& Runtime parameters of the operations framework and its consumers.
*& Callers read parameters through ZCL_CA_OPS_FACTORY=>GET_PARAMS only (a
*& consumer through its own factory, which adds its name prefixes); the one
*& implementation is the adapter ZCL_CA_OPS_PARAMS over the global parameter
*& framework ZCA_PARAM. Definitions (value type, limits, default) live in
*& ZCA_PARAM; the framework's own are in area CA_OPS
*& (config/param_definitions.csv). Errors are never silent: get_errors( ).
*& Modification log:
*& 2026-11-07 | Initial version (split from the store interface; get_range added).
*& 2026-11-07 | Served by ZCA_PARAM; get_errors added; the definition default wins over the caller's
*&            | default; BOOL blank = off.
*& 2026-11-10 | Moved from ZIF_CD_OPS_PARAMS to the reusable framework ZCA_OPS: optional IV_AREA on every
*&            | read (else the area of the name prefix), ADD_PREFIXES (a consumer's prefixes), AREA_OF,
*&            | CHECK_AREA (the area of a run is a registered parameter area).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - runtime parameters</p>
"! Runtime parameters in the framework ZCA_PARAM: get_param (one value), get_range
"! (select-option style), refresh_params (snapshot per run) and get_errors (parameters
"! that could not be read). Semantics: the value the framework resolves wins, including
"! a definition default and a BOOL row with blank value (off); the caller's iv_default
"! applies only when the framework resolves nothing (no row, no definition default) or
"! the parameter cannot be read (unknown name, invalid value - then also logged).
INTERFACE zif_ca_ops_params
  PUBLIC.

  "! Drop the parameter snapshot: the next read sees the current values.
  "! start_run of the store calls it, so every run sees the parameters valid at its
  "! start (audit A64). Entry points that validate without a run call it themselves.
  "! It also clears the error list of the previous snapshot.
  METHODS refresh_params.

  "! Value of a parameter, condensed. BOOL: X (on) or blank (off), never iv_default.
  "! Other types: the maintained value or the definition default; iv_default when both
  "! are blank or the parameter cannot be read (error logged, see get_errors).
  "! @parameter iv_area | Area of the parameter; blank = the area of the name prefix (AREA_OF)
  METHODS get_param
    IMPORTING
      iv_name         TYPE zif_ca_ops_types=>ty_param_name
      iv_default      TYPE string OPTIONAL
      iv_area         TYPE zif_ca_ops_types=>ty_area OPTIONAL
    RETURNING
      VALUE(rv_value) TYPE string.

  "! Select-option style view of a parameter: the rows of a kind S parameter, or one row
  "! I / EQ per element of a LIST parameter (blank elements dropped); an empty table when
  "! nothing is maintained or the parameter cannot be read. Callers must treat an empty
  "! range as "not configured", never as "all values".
  "! @parameter iv_area | Area of the parameter; blank = the area of the name prefix (AREA_OF)
  METHODS get_range
    IMPORTING
      iv_name         TYPE zif_ca_ops_types=>ty_param_name
      iv_area         TYPE zif_ca_ops_types=>ty_area OPTIONAL
    RETURNING
      VALUE(rt_range) TYPE zif_ca_ops_types=>tt_param_range.

  "! Parameters of the current snapshot that could not be read (one row per area / name,
  "! message of ZCX_CA_PARAM)
  METHODS get_errors
    RETURNING
      VALUE(rt_errors) TYPE zif_ca_ops_types=>tt_param_error.

  "! Add name prefixes of a consumer's areas (a prefix already known keeps its area). The
  "! longest prefix that starts the name decides; the framework's own prefixes (ALERT_ SLA_
  "! RETENTION_ PURGE_) read area CA_OPS
  METHODS add_prefixes
    IMPORTING
      it_prefixes TYPE zif_ca_ops_types=>tt_param_prefix.

  "! Area of a parameter from its name prefix; CA_OPS when no prefix fits (ZCA_PARAM then
  "! reports the name as not defined)
  METHODS area_of
    IMPORTING
      iv_name        TYPE zif_ca_ops_types=>ty_param_name
    RETURNING
      VALUE(rv_area) TYPE zif_ca_ops_types=>ty_area.

  "! The area is a registered, active parameter area of ZCA_PARAM (ZCA_PARAM_AREA): the one
  "! area register of every run, finding, alert rule and lock (message 043 otherwise)
  "! @raising zcx_ca_ops_error | area unknown or inactive
  METHODS check_area
    IMPORTING
      iv_area TYPE zif_ca_ops_types=>ty_area
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
