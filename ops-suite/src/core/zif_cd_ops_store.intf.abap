*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_store.intf.abap
*& Purpose:
*& One auditable store for all modules: run headers (ZCD_OPS_RUN),
*& findings (ZCD_OPS_FINDING) and runtime parameters (ZCD_OPS_PARAM).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - shared result store and parameters</p>
"! One auditable store for all modules: run headers (ZCD_OPS_RUN),
"! findings (ZCD_OPS_FINDING) and runtime parameters (ZCD_OPS_PARAM).
INTERFACE zif_cd_ops_store
  PUBLIC.

  "! Create a run header in status RUNNING (persisted unless test mode)
  METHODS start_run
    IMPORTING
      iv_module     TYPE zif_cd_ops_types=>ty_module
      iv_variant    TYPE zif_cd_ops_types=>ty_variant OPTIONAL
      iv_test_mode  TYPE abap_bool DEFAULT abap_false
    RETURNING
      VALUE(rs_run) TYPE zif_cd_ops_types=>ty_run
    RAISING
      zcx_cd_ops_error.

  "! Append findings to a run; cs_run-finding_count is advanced
  METHODS save_findings
    IMPORTING
      it_findings TYPE zif_cd_ops_types=>tt_finding
    CHANGING
      cs_run      TYPE zif_cd_ops_types=>ty_run
    RAISING
      zcx_cd_ops_error.

  "! Close a run: counts, status, RAG, runtime
  METHODS finish_run
    IMPORTING
      is_run TYPE zif_cd_ops_types=>ty_run
    RAISING
      zcx_cd_ops_error.

  METHODS commit.

  "! Read a parameter from ZCD_OPS_PARAM; returns iv_default when not maintained
  METHODS get_param
    IMPORTING
      iv_name         TYPE zif_cd_ops_types=>ty_param_name
      iv_default      TYPE string OPTIONAL
    RETURNING
      VALUE(rv_value) TYPE string.

  "! Most recent completed run of a module (and variant, when given)
  METHODS get_last_run
    IMPORTING
      iv_module     TYPE zif_cd_ops_types=>ty_module
      iv_variant    TYPE zif_cd_ops_types=>ty_variant OPTIONAL
    RETURNING
      VALUE(rs_run) TYPE zif_cd_ops_types=>ty_run.

  METHODS get_runs_since
    IMPORTING
      iv_module      TYPE zif_cd_ops_types=>ty_module
      iv_since       TYPE timestampl
    RETURNING
      VALUE(rt_runs) TYPE zif_cd_ops_types=>tt_run.

  METHODS get_findings
    IMPORTING
      iv_run_id          TYPE zif_cd_ops_types=>ty_run_id
    RETURNING
      VALUE(rt_findings) TYPE zif_cd_ops_types=>tt_finding.

ENDINTERFACE.
