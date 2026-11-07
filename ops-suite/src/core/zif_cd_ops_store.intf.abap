*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_store.intf.abap
*& Purpose:
*& One auditable store for all payment engine areas: run headers (ZCD_OPS_RUN)
*& and findings (ZCD_OPS_FINDING). Runtime parameters are not served here:
*& ZCL_CD_OPS_FACTORY=>GET_PARAMS (ZCA_PARAM).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | rollback( ) added (DEFAULT IGNORE).
*& 2026-11-06 | Exception carry-forward: reconcile( ) (DEFAULT IGNORE).
*& 2026-11-06 | get_stale_runs( ) for hung / dumped runs (audit A06, DEFAULT IGNORE).
*& 2026-11-06 | refresh_params: parameter snapshot per run (audit A64).
*& 2026-11-07 | Parameters split into ZIF_CD_OPS_PARAMS (INTERFACES + ALIASES, no caller changes).
*& 2026-11-07 | ZIF_CD_OPS_PARAMS no longer included: parameters come from ZCA_PARAM via the factory.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - shared result store</p>
"! One auditable store for all payment engine areas: run headers (ZCD_OPS_RUN) and
"! findings (ZCD_OPS_FINDING). start_run renews the parameter snapshot (A64).
INTERFACE zif_cd_ops_store
  PUBLIC.

  "! Create a run header in status RUNNING (persisted unless test mode)
  METHODS start_run
    IMPORTING
      iv_pe_area     TYPE zif_cd_ops_types=>ty_pe_area
      iv_variant    TYPE zif_cd_ops_types=>ty_variant OPTIONAL
      iv_test_mode  TYPE abap_bool DEFAULT abap_false
    RETURNING
      VALUE(rs_run) TYPE zif_cd_ops_types=>ty_run
    RAISING
      zcx_cd_ops_error.

  "! Append findings to a run; cs_run-finding_count is advanced. An exception (B/E/W)
  "! raised again for the same payment engine area, object and check code inherits disposition,
  "! owner, due date and first-seen time of the open one, which becomes superseded (S).
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

  "! Auto-resolve open exceptions (O, A) of earlier runs of the payment engine area whose object
  "! key (it_object_keys) or GROUP2 (it_groups) this run evaluated without raising
  "! them again. Exceptions raised again were already carried forward by
  "! save_findings; waived exceptions (W) are never touched.
  METHODS reconcile DEFAULT IGNORE
    IMPORTING
      is_run         TYPE zif_cd_ops_types=>ty_run
      it_object_keys TYPE zif_cd_ops_types=>tt_object_key OPTIONAL
      it_groups      TYPE zif_cd_ops_types=>tt_group OPTIONAL
    RAISING
      zcx_cd_ops_error.

  "! Undo this LUW's uncommitted changes (e.g. a registry saved only in part).
  "! Callers commit the run header first, so the run itself survives.
  METHODS rollback DEFAULT IGNORE.

  "! Most recent completed run of a payment engine area (and variant, when given)
  METHODS get_last_run
    IMPORTING
      iv_pe_area     TYPE zif_cd_ops_types=>ty_pe_area
      iv_variant    TYPE zif_cd_ops_types=>ty_variant OPTIONAL
    RETURNING
      VALUE(rs_run) TYPE zif_cd_ops_types=>ty_run.

  METHODS get_runs_since
    IMPORTING
      iv_pe_area      TYPE zif_cd_ops_types=>ty_pe_area
      iv_since       TYPE timestampl
    RETURNING
      VALUE(rt_runs) TYPE zif_cd_ops_types=>tt_run.

  "! Runs still in status R (running) that started before iv_started_before: a run
  "! that dumped or hangs (audit A06). iv_exclude_run = the caller's own run.
  METHODS get_stale_runs DEFAULT IGNORE
    IMPORTING
      iv_pe_area         TYPE zif_cd_ops_types=>ty_pe_area
      iv_started_before  TYPE timestampl
      iv_exclude_run     TYPE zif_cd_ops_types=>ty_run_id OPTIONAL
    RETURNING
      VALUE(rt_runs)     TYPE zif_cd_ops_types=>tt_run.

  METHODS get_findings
    IMPORTING
      iv_run_id          TYPE zif_cd_ops_types=>ty_run_id
    RETURNING
      VALUE(rt_findings) TYPE zif_cd_ops_types=>tt_finding.

ENDINTERFACE.
