*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_check_dao.intf.abap
*& Purpose:
*& Data access of the process onboarding framework: registered checks and
*& processes, aggregate rows, the approved-table list and the runtime DDIC
*& of an approved table, the aggregate itself (built and run on the
*& database), and the facts the onboarding check compares (controls that
*& cover a check, areas with an active alert rule, active areas). Read only.
*& Modification log:
*& 2026-11-10 | Initial version (process onboarding framework).
*& 2026-11-11 | AGGREGATE: optional date / time window (outage check of the process catalogue).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - check registry data access</p>
INTERFACE zif_ca_ops_check_dao
  PUBLIC.

  "! Active checks of an area and schedule group, in sequence
  METHODS get_checks
    IMPORTING
      iv_area          TYPE zif_ca_ops_types=>ty_area
      iv_sched_group   TYPE zif_ca_ops_chk_types=>ty_sched_group
    RETURNING
      VALUE(rt_checks) TYPE zif_ca_ops_chk_types=>tt_check.

  "! Active checks of every area (onboarding check)
  METHODS get_all_checks
    RETURNING
      VALUE(rt_checks) TYPE zif_ca_ops_chk_types=>tt_check.

  "! Active business processes of every area
  METHODS get_processes
    RETURNING
      VALUE(rt_processes) TYPE zif_ca_ops_chk_types=>tt_process.

  "! Active aggregate rows of a check
  METHODS get_aggregates
    IMPORTING
      iv_area        TYPE zif_ca_ops_types=>ty_area
      iv_check_id    TYPE zif_ca_ops_chk_types=>ty_check_id
    RETURNING
      VALUE(rt_aggs) TYPE zif_ca_ops_chk_types=>tt_agg.

  "! The table is approved (active row of ZCA_OPS_TABWL) for aggregate checks of the area
  METHODS is_table_approved
    IMPORTING
      iv_area            TYPE zif_ca_ops_types=>ty_area
      iv_tabname         TYPE zif_ca_ops_chk_types=>ty_tabname
    RETURNING
      VALUE(rv_approved) TYPE abap_bool.

  "! Fields of the runtime DDIC of a table the user may display (S_TABU_NAM 03)
  "! @raising zcx_ca_ops_error | 087 no display authorisation, 082 not a DDIC table
  METHODS get_table_fields
    IMPORTING
      iv_tabname       TYPE zif_ca_ops_chk_types=>ty_tabname
    RETURNING
      VALUE(rt_fields) TYPE zif_ca_ops_chk_types=>tt_field
    RAISING
      zcx_ca_ops_error.

  "! Validate one aggregate row (approval, DDIC, operators, literals) and run it on the database:
  "! one row, or one row per company code (at most ZIF_CA_OPS_CHK_TYPES=>GC_MAX_GROUPS)
  "! @parameter is_window | measured in this date / time window instead of the row's age limits (outage check)
  "! @raising zcx_ca_ops_error | 082-093 / 103 / 255 the row cannot be measured
  METHODS aggregate
    IMPORTING
      is_agg         TYPE zif_ca_ops_chk_types=>ty_agg
      iv_bukrs_aware TYPE abap_bool
      iv_today       TYPE d
      is_window      TYPE zif_ca_ops_chk_types=>ty_window OPTIONAL
    RETURNING
      VALUE(rt_rows) TYPE zif_ca_ops_chk_types=>tt_agg_row
    RAISING
      zcx_ca_ops_error.

  "! Checks covered by an active control (ZCA_OPS_CTLCHK with finding field GROUP2)
  METHODS get_covered_checks
    RETURNING
      VALUE(rt_covered) TYPE zif_ca_ops_chk_types=>tt_covered.

  "! Areas with an active alert rule (ZCA_OPS_ALRULE; * = every area is not the area of a process)
  METHODS get_alert_areas
    RETURNING
      VALUE(rt_areas) TYPE zif_ca_ops_chk_types=>tt_area.

  "! The area is an active parameter area of ZCA_PARAM (the authorisation field ZCA_PARAR takes it)
  METHODS is_area_active
    IMPORTING
      iv_area          TYPE zif_ca_ops_types=>ty_area
    RETURNING
      VALUE(rv_active) TYPE abap_bool.

ENDINTERFACE.
