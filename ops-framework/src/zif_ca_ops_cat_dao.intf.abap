*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_cat_dao.intf.abap
*& Purpose:
*& Data access of the process catalogue: packages, processes, steps,
*& tables, dependencies and activation rows (small customizing tables, read
*& whole) and the business processes of ZCA_OPS_PROC with their catalogue
*& process (active or not). Read only.
*& Modification log:
*& 2026-11-11 | Initial version (process catalogue with activation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - process catalogue data access</p>
INTERFACE zif_ca_ops_cat_dao
  PUBLIC.

  METHODS get_packages
    RETURNING
      VALUE(rt_packages) TYPE zif_ca_ops_cat_types=>tt_package.

  METHODS get_processes
    RETURNING
      VALUE(rt_processes) TYPE zif_ca_ops_cat_types=>tt_process.

  METHODS get_steps
    RETURNING
      VALUE(rt_steps) TYPE zif_ca_ops_cat_types=>tt_step.

  METHODS get_tables
    RETURNING
      VALUE(rt_tables) TYPE zif_ca_ops_cat_types=>tt_table.

  METHODS get_dependencies
    RETURNING
      VALUE(rt_dependencies) TYPE zif_ca_ops_cat_types=>tt_dependency.

  METHODS get_activations
    RETURNING
      VALUE(rt_activations) TYPE zif_ca_ops_cat_types=>tt_activation.

  "! Business processes of ZCA_OPS_PROC (active or not) of an area; blank area = every area
  METHODS get_onboarded
    IMPORTING
      iv_area             TYPE zif_ca_ops_types=>ty_area OPTIONAL
    RETURNING
      VALUE(rt_onboarded) TYPE zif_ca_ops_cat_types=>tt_onboarded.

ENDINTERFACE.
