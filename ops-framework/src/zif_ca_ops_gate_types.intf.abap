*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_gate_types.intf.abap
*& Purpose:
*& Types and constants of the configuration preview and rollback (build Q,
*& docs/EXTENSION_AND_GATE_PROOF.md section 4): kinds and types of a change
*& of the effective configuration, the rollback proposal of an activation
*& row of the process catalogue, the rule sets a preview compares and the
*& messages 640-649 of ZCA_OPS. No logic (ZCL_CA_OPS_CFG_PREVIEW, reports
*& ZCA_OPS_CFG_PREVIEW and ZCA_OPS_LINK_DRILL).
*& Modification log:
*& 2026-11-16 | Initial version (build Q: configuration preview and rollback).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - preview and rollback types</p>
INTERFACE zif_ca_ops_gate_types
  PUBLIC.

  TYPES ty_kind TYPE c LENGTH 10.
  TYPES ty_change_type TYPE c LENGTH 10.
  TYPES ty_object_id TYPE c LENGTH 40.

  "! What changed: a catalogue process, an effective link, a link ambiguous by design, a registry problem, a
  "! configuration line of a rule set, the configuration version of a rule set
  CONSTANTS:
    BEGIN OF gc_kind,
      catalogue TYPE ty_kind VALUE 'CATALOGUE',
      link      TYPE ty_kind VALUE 'LINK',
      ambiguous TYPE ty_kind VALUE 'AMBIGUOUS',
      problem   TYPE ty_kind VALUE 'PROBLEM',
      line      TYPE ty_kind VALUE 'LINE',
      version   TYPE ty_kind VALUE 'VERSION',
    END OF gc_kind.

  "! How it changed: switched on / off (active state), added / removed (a line, a note, a problem), changed
  CONSTANTS:
    BEGIN OF gc_change,
      switched_on  TYPE ty_change_type VALUE 'ON',
      switched_off TYPE ty_change_type VALUE 'OFF',
      added        TYPE ty_change_type VALUE 'ADDED',
      removed      TYPE ty_change_type VALUE 'REMOVED',
      changed      TYPE ty_change_type VALUE 'CHANGED',
    END OF gc_change.

  "! Rollback of an activation row: delete it (still planned), a new row (already effective), nothing to undo
  CONSTANTS:
    BEGIN OF gc_action,
      delete_planned TYPE ty_kind VALUE 'DELETE',
      new_row        TYPE ty_kind VALUE 'NEW_ROW',
      none           TYPE ty_kind VALUE 'NONE',
    END OF gc_action.

  "! Kinds of the rule sets a preview compares (the prefix of their configuration lines)
  CONSTANTS:
    BEGIN OF gc_rule_set,
      break TYPE ty_kind VALUE 'BRK_RULE',
      flow  TYPE ty_kind VALUE 'FLOW_RULE',
    END OF gc_rule_set.

  "! Messages of ZCA_OPS (640-649)
  CONSTANTS:
    BEGIN OF gc_msg,
      summary        TYPE zif_ca_ops_types=>ty_msgno VALUE '640',
      delete_planned TYPE zif_ca_ops_types=>ty_msgno VALUE '641',
      new_row        TYPE zif_ca_ops_types=>ty_msgno VALUE '642',
      reason         TYPE zif_ca_ops_types=>ty_msgno VALUE '643',
      nothing        TYPE zif_ca_ops_types=>ty_msgno VALUE '644',
      version        TYPE zif_ca_ops_types=>ty_msgno VALUE '646',
      link_detail    TYPE zif_ca_ops_types=>ty_msgno VALUE '647',
      process_detail TYPE zif_ca_ops_types=>ty_msgno VALUE '648',
    END OF gc_msg.

  "! One change of the effective configuration
  TYPES:
    BEGIN OF ty_change,
      kind      TYPE ty_kind,
      object_id TYPE ty_object_id,
      change    TYPE ty_change_type,
      before    TYPE string,
      after     TYPE string,
      "! Why or where: the deciding row, the link's objects and layer, the message of a problem
      detail    TYPE string,
    END OF ty_change.
  TYPES tt_change TYPE STANDARD TABLE OF ty_change WITH EMPTY KEY.

  "! The rollback of one activation row of the catalogue (a proposal: the user creates or deletes the row in the
  "! configuration app on a customizing request - approver required, history kept)
  TYPES:
    BEGIN OF ty_rollback,
      process_id  TYPE zif_ca_ops_cat_types=>ty_process_id,
      action      TYPE ty_kind,
      "! The activation row that is undone (its effective-from date)
      change_from TYPE d,
      "! NEW_ROW: the new row - effective from, active (the state before the change), reason
      valid_from  TYPE d,
      active      TYPE abap_bool,
      reason      TYPE zif_ca_ops_cat_types=>ty_reason,
      text        TYPE string,
    END OF ty_rollback.

ENDINTERFACE.
