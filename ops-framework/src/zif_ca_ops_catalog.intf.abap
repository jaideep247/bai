*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_catalog.intf.abap
*& Purpose:
*& Public API of the process catalogue: the effective state of a catalogue
*& process on a day (activation row, delivered default, package switch),
*& the definition of a process (package, steps, tables, dependencies and the
*& business processes of ZCA_OPS_PROC that monitor it), the active
*& processes, the business processes of an area that are not in effect
*& (the runner skips their checks) and the rule check of the catalogue
*& rows. Read by the runner, the onboarding check, a consumer's own engine
*& and a test tool's catalogue adapter. Obtained from
*& ZCL_CA_OPS_FACTORY=>GET_CATALOG.
*& Modification log:
*& 2026-11-11 | Initial version (process catalogue with activation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - process catalogue API</p>
INTERFACE zif_ca_ops_catalog
  PUBLIC.

  "! Effective state of a catalogue process on a day: the activation row with the latest VALID_FROM on or before
  "! iv_date decides, else the delivered default; a package switched off (or unknown) makes it inactive; an
  "! unknown process is inactive (source U)
  METHODS state
    IMPORTING
      iv_process_id   TYPE zif_ca_ops_cat_types=>ty_process_id
      iv_date         TYPE d
    RETURNING
      VALUE(rs_state) TYPE zif_ca_ops_cat_types=>ty_state.

  "! Effective state of every catalogue process on a day
  METHODS states
    IMPORTING
      iv_date          TYPE d
    RETURNING
      VALUE(rt_states) TYPE zif_ca_ops_cat_types=>tt_state.

  "! Everything the catalogue knows about a process (initial process ID when it is not defined)
  METHODS definition
    IMPORTING
      iv_process_id        TYPE zif_ca_ops_cat_types=>ty_process_id
      iv_date              TYPE d
    RETURNING
      VALUE(rs_definition) TYPE zif_ca_ops_cat_types=>ty_definition.

  "! The catalogue processes active on a day (in sequence of their package rank and SEQ)
  METHODS active_processes
    IMPORTING
      iv_date             TYPE d
    RETURNING
      VALUE(rt_processes) TYPE zif_ca_ops_cat_types=>tt_process.

  "! Business processes of the area (ZCA_OPS_PROC) that are not in effect on a day: the row is inactive, or its
  "! catalogue process is not active. A check of one of them does not run (runner). A catalogue process that is
  "! not defined does not stop monitoring (fail-open; the onboarding check reports CAT_REF_UNKNOWN)
  METHODS inactive_onboarded
    IMPORTING
      iv_area             TYPE zif_ca_ops_types=>ty_area
      iv_date             TYPE d
    RETURNING
      VALUE(rt_processes) TYPE zif_ca_ops_cat_types=>tt_process_ids.

  "! Business processes of every area with their catalogue process (active or not)
  METHODS onboarded
    RETURNING
      VALUE(rt_onboarded) TYPE zif_ca_ops_cat_types=>tt_onboarded.

  "! Rules the catalogue rows break: process ID prefix of its package, unknown package, dependency on an unknown
  "! process or one of a higher package, dependency cycle, activation of an unknown process or without reason
  "! or approver
  METHODS validate
    RETURNING
      VALUE(rt_problems) TYPE zif_ca_ops_cat_types=>tt_problem.

ENDINTERFACE.
