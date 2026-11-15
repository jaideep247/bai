*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_flow_dao.intf.abap
*& Purpose:
*& Data access of the account flow reconciliation: its configuration
*& (flows, accounts, stages, stage controls, stage rules), the evaluation
*& it writes (header and items, retention) and the reads of the delivered
*& sources - the latest break analysis snapshots of a clearing account and
*& their explained groups, the open FI-CA items of a reconciliation
*& account, the open findings of the checks that control a stage. Every
*& read of business data is aggregated on the database and read-only.
*& Modification log:
*& 2026-11-15 | Initial version (build G: account flow reconciliation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - account flow data access</p>
INTERFACE zif_ca_ops_flow_dao
  PUBLIC.

  "! Active flows of an area (one flow when IV_FLOW_ID is given)
  METHODS get_flows
    IMPORTING
      iv_area         TYPE zif_ca_ops_types=>ty_area
      iv_flow_id      TYPE zif_ca_ops_flow_types=>ty_flow_id OPTIONAL
    RETURNING
      VALUE(rt_flows) TYPE zif_ca_ops_flow_types=>tt_flow.

  "! The active accounts, stages, stage controls and stage rules of a flow
  METHODS get_config
    IMPORTING
      is_flow          TYPE zif_ca_ops_flow_types=>ty_flow
    RETURNING
      VALUE(rs_config) TYPE zif_ca_ops_flow_types=>ty_config.

  "! Save an evaluation (header and items); the caller commits
  "! @raising zcx_ca_ops_error | 010 insert failed
  METHODS save_evaluation
    IMPORTING
      is_eval  TYPE zif_ca_ops_flow_types=>ty_eval
      it_items TYPE zif_ca_ops_flow_types=>tt_eval_item
    RAISING
      zcx_ca_ops_error.

  "! Remove the evaluations of a flow with a key date before IV_BEFORE (header and items)
  "! @parameter rv_count | Evaluations removed
  METHODS delete_evaluations
    IMPORTING
      iv_area         TYPE zif_ca_ops_types=>ty_area
      iv_flow_id      TYPE zif_ca_ops_flow_types=>ty_flow_id
      iv_before       TYPE d
    RETURNING
      VALUE(rv_count) TYPE i.

  METHODS commit.

  "! The latest break analysis snapshot of every break account of the company code whose G/L account is in the
  "! range, with a key date from IV_FROM to IV_KEY_DATE
  METHODS break_snapshots
    IMPORTING
      iv_bukrs        TYPE bukrs
      iv_hkont_from   TYPE saknr
      iv_hkont_to     TYPE saknr
      iv_from         TYPE d
      iv_key_date     TYPE d
    RETURNING
      VALUE(rt_snaps) TYPE zif_ca_ops_flow_types=>tt_break_snap.

  "! Open break groups in a named bucket (not OTHER) of the snapshots, summed per currency
  METHODS break_explained
    IMPORTING
      it_snap_ids    TYPE zif_ca_ops_flow_types=>tt_run_id
    RETURNING
      VALUE(rt_sums) TYPE zif_ca_ops_flow_types=>tt_currency_sum.

  "! Open FI-CA business partner items of a reconciliation account posted up to the key date, per currency
  "! (DFKKOP: company code, G/L account range, no clearing document; currency blank = every currency)
  METHODS fica_open_items
    IMPORTING
      iv_bukrs       TYPE bukrs
      iv_hkont_from  TYPE saknr
      iv_hkont_to    TYPE saknr
      iv_currency    TYPE zif_ca_ops_types=>ty_currency
      iv_key_date    TYPE d
    RETURNING
      VALUE(rt_sums) TYPE zif_ca_ops_flow_types=>tt_currency_sum.

  "! Open exceptions (open or assigned) of the checks for a company code, amounts summed per currency
  METHODS open_findings
    IMPORTING
      it_checks      TYPE zif_ca_ops_flow_types=>tt_check_ref
      iv_bukrs       TYPE bukrs
      iv_currency    TYPE zif_ca_ops_types=>ty_currency
    RETURNING
      VALUE(rt_sums) TYPE zif_ca_ops_flow_types=>tt_currency_sum.

ENDINTERFACE.
