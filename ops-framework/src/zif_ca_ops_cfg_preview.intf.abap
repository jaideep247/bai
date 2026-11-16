*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_cfg_preview.intf.abap
*& Purpose:
*& Preview and rollback of configuration changes (build Q, docs/
*& EXTENSION_AND_GATE_PROOF.md section 4): what a pending change will
*& alter before it takes effect, and how an effective-dated change is
*& undone. Process catalogue activation (effective-dated): the processes
*& whose state changes between two dates, and the rollback of one
*& activation row (delete a planned row; a new row from a date with the
*& state before the change - history kept, four-eyes in the app). Link
*& registry: the effective links, the links ambiguous by design and the
*& problems that change between the current rows and a proposed set (an
*& override row, a layer switched, rows of a pending transport). Rule sets
*& (break buckets, flow stages): the lines added or removed and the
*& configuration version before and after (the version a finding records,
*& ZCL_CA_OPS_CFG_VERSION). Read only: nothing is written. Types and
*& messages: ZIF_CA_OPS_GATE_TYPES.
*& Modification log:
*& 2026-11-16 | Initial version (build Q: configuration preview and rollback).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - configuration preview and rollback</p>
INTERFACE zif_ca_ops_cfg_preview
  PUBLIC.

  "! Processes whose effective activation differs between two dates (planned rows taking effect, ends)
  METHODS catalogue
    IMPORTING
      iv_from           TYPE d
      iv_to             TYPE d
    RETURNING
      VALUE(rt_changes) TYPE zif_ca_ops_gate_types=>tt_change.

  "! Rollback of the activation row of a process effective from IV_CHANGE_FROM
  "! @parameter iv_today        | Today: a row effective later is still planned (delete it)
  "! @parameter iv_restore_from | Effective-from date of the new row (never before today)
  METHODS catalogue_rollback
    IMPORTING
      iv_process_id      TYPE zif_ca_ops_cat_types=>ty_process_id
      iv_change_from     TYPE d
      iv_today           TYPE d
      iv_restore_from    TYPE d OPTIONAL
    RETURNING
      VALUE(rs_rollback) TYPE zif_ca_ops_gate_types=>ty_rollback.

  "! Effective links, links ambiguous by design and problems that differ between two sets of registry rows
  METHODS links
    IMPORTING
      is_current        TYPE zif_ca_ops_link_types=>ty_registry
      is_proposed       TYPE zif_ca_ops_link_types=>ty_registry
    RETURNING
      VALUE(rt_changes) TYPE zif_ca_ops_gate_types=>tt_change.

  "! Lines added and removed between two sets of configuration lines of a rule set, and the configuration
  "! version of each set (ZCL_CA_OPS_CFG_VERSION=>OF_LINES)
  METHODS rule_set
    IMPORTING
      iv_kind           TYPE zif_ca_ops_gate_types=>ty_kind
      it_before         TYPE string_table
      it_after          TYPE string_table
    RETURNING
      VALUE(rt_changes) TYPE zif_ca_ops_gate_types=>tt_change.

ENDINTERFACE.
