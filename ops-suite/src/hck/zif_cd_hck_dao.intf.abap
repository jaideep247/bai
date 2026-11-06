*&---------------------------------------------------------------------*
*& Artifact: zif_cd_hck_dao.intf.abap
*& Purpose:
*& Data access of the health check module: customizing, metric history,
*& configuration baselines and the technical reads used by the checks.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | get_suppressions (design 6.3), DEFAULT IGNORE for existing doubles.
*& 2026-11-06 | select_values for the known-table checks (DEFAULT IGNORE).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - data access (all SQL of HCK)</p>
"! The only place in the HCK module that issues SQL, calls DDIC runtime
"! descriptions or reads system tables. Checks and the engine stay SQL-free.
INTERFACE zif_cd_hck_dao
  PUBLIC.

  "! Active checks (ZCD_HCK_DEF) matching the selection, ordered by SEQ
  METHODS get_check_defs
    IMPORTING
      it_categories  TYPE zif_cd_hck_types=>tt_category_range OPTIONAL
      it_priorities  TYPE zif_cd_hck_types=>tt_priority_range OPTIONAL
      it_check_ids   TYPE zif_cd_hck_types=>tt_check_range OPTIONAL
    RETURNING
      VALUE(rt_defs) TYPE zif_cd_hck_types=>tt_check_def.

  "! All threshold rows of a check (every company code incl. '*')
  METHODS get_thresholds
    IMPORTING
      iv_check_id          TYPE zif_cd_hck_types=>ty_check_id
    RETURNING
      VALUE(rt_thresholds) TYPE zif_cd_hck_types=>tt_threshold.

  "! Generic aggregate definitions (ZCD_HCK_AGG) of a check
  METHODS get_agg_defs
    IMPORTING
      iv_check_id    TYPE zif_cd_hck_types=>ty_check_id
    RETURNING
      VALUE(rt_defs) TYPE zif_cd_hck_types=>tt_agg_def.

  "! Table is on the whitelist ZCD_HCK_TABWL and active
  METHODS is_table_whitelisted
    IMPORTING
      iv_tabname        TYPE zif_cd_hck_types=>ty_tabname
    RETURNING
      VALUE(rv_allowed) TYPE abap_bool.

  "! Fields of a DDIC table from the runtime DDIC
  "! @raising zcx_cd_ops_error | table unknown (303)
  METHODS get_table_fields
    IMPORTING
      iv_tabname       TYPE zif_cd_hck_types=>ty_tabname
    RETURNING
      VALUE(rt_fields) TYPE zif_cd_hck_types=>tt_field
    RAISING
      zcx_cd_ops_error.

  "! Run a validated aggregate (COUNT/SUM, optional GROUP BY)
  "! @raising zcx_cd_ops_error | dynamic SQL error (308)
  METHODS aggregate
    IMPORTING
      is_query       TYPE zif_cd_hck_types=>ty_agg_query
    RETURNING
      VALUE(rt_rows) TYPE zif_cd_hck_types=>tt_agg_row
    RAISING
      zcx_cd_ops_error.

  "! Last iv_max_rows values of a metric (newest first), current run excluded
  METHODS get_metric_history
    IMPORTING
      iv_check_id      TYPE zif_cd_hck_types=>ty_check_id
      iv_metric        TYPE zif_cd_hck_types=>ty_metric_name
      iv_dim1          TYPE zif_cd_hck_types=>ty_dim
      iv_max_rows      TYPE i
    RETURNING
      VALUE(rt_values) TYPE zif_cd_hck_types=>tt_value.

  "! Append metric history (duplicates of the same key in one run are ignored)
  METHODS save_metrics
    IMPORTING
      it_metrics TYPE zif_cd_hck_types=>tt_metric_hist
    RAISING
      zcx_cd_ops_error.

  "! Tables under configuration-drift control (ZCD_HCK_DRIFT)
  METHODS get_drift_tables
    RETURNING
      VALUE(rt_tables) TYPE zif_cd_hck_types=>tt_drift_def.

  "! Stored golden baselines (ZCD_HCK_BASELINE)
  METHODS get_baselines
    RETURNING
      VALUE(rt_baselines) TYPE zif_cd_hck_types=>tt_baseline.

  "! SHA-256 over the full content of a table, ordered by primary key
  "! @raising zcx_cd_ops_error | table unknown (303) or hash error (311)
  METHODS compute_table_hash
    IMPORTING
      iv_tabname     TYPE zif_cd_hck_types=>ty_tabname
    RETURNING
      VALUE(rs_hash) TYPE zif_cd_hck_types=>ty_baseline
    RAISING
      zcx_cd_ops_error.

  "! Replace the stored baselines of the given tables
  METHODS save_baselines
    IMPORTING
      it_baselines TYPE zif_cd_hck_types=>tt_baseline
    RAISING
      zcx_cd_ops_error.

  "! Steps of active job cycles (ZCD_JOB_CYCLE + ZCD_JOB_STEP), by cycle and step
  METHODS get_cycle_steps
    IMPORTING
      it_cycle_ids    TYPE zif_cd_hck_types=>tt_cycle_range OPTIONAL
    RETURNING
      VALUE(rt_steps) TYPE zif_cd_hck_types=>tt_cycle_step.

  "! Date is a working day of the factory calendar (blank calendar = always)
  METHODS is_working_day
    IMPORTING
      iv_calendar       TYPE zif_cd_hck_types=>ty_calendar
      iv_date           TYPE d
    RETURNING
      VALUE(rv_working) TYPE abap_bool.

  "! Background job instances (TBTCO) planned or started in a date window
  METHODS get_job_runs
    IMPORTING
      it_jobnames    TYPE zif_cd_hck_types=>tt_jobname_range
      iv_from        TYPE d
      iv_to          TYPE d
    RETURNING
      VALUE(rt_runs) TYPE zif_cd_hck_types=>tt_job_run.

  "! Application-log message counters (BALHDR) per object / subobject for a day
  METHODS get_applog_stats
    IMPORTING
      it_objects     TYPE zif_cd_hck_types=>tt_object_range
      it_subobjects  TYPE zif_cd_hck_types=>tt_subobj_range OPTIONAL
      iv_date        TYPE d
    RETURNING
      VALUE(rt_stat) TYPE zif_cd_hck_types=>tt_applog_stat.

  "! Owned exceptions past their due date, per module (ZCD_OPS_FINDING)
  METHODS get_overdue_exceptions
    IMPORTING
      iv_today          TYPE d
    RETURNING
      VALUE(rt_overdue) TYPE zif_cd_hck_types=>tt_overdue.

  "! Oldest-due open owned exceptions (all modules), at most iv_max_rows
  METHODS get_open_exceptions
    IMPORTING
      iv_max_rows          TYPE i
    RETURNING
      VALUE(rt_exceptions) TYPE zif_cd_hck_types=>tt_open_exception.

  "! Reconciliation keys with totals records but no GL document
  "! (DFKKSUMC-FIKEY = DFKKKO-FIKEY = AWKEY), posting date in window
  METHODS get_fikeys_without_gl
    IMPORTING
      iv_from        TYPE d
      iv_to          TYPE d
      iv_max_rows    TYPE i
    RETURNING
      VALUE(rt_gaps) TYPE zif_cd_hck_types=>tt_fikey_gap.

  "! Number of short dumps on a date
  METHODS count_short_dumps
    IMPORTING
      iv_date         TYPE d
    RETURNING
      VALUE(rv_count) TYPE i.

  "! Number of update requests in error status (SM13)
  METHODS count_update_errors
    RETURNING
      VALUE(rv_count) TYPE i.

  "! Lock entries of this client and age of the oldest one
  "! @raising zcx_cd_ops_error | lock table could not be read (313)
  METHODS read_lock_stats
    IMPORTING
      iv_now_date    TYPE d
      iv_now_time    TYPE t
    RETURNING
      VALUE(rs_stat) TYPE zif_cd_hck_types=>ty_tech_stat
    RAISING
      zcx_cd_ops_error.

  "! Alert deliveries (ZCD_OPS_ALERT_LOG) per channel and status in a window
  METHODS get_alert_stats
    IMPORTING
      iv_from        TYPE timestampl
      iv_to          TYPE timestampl
    RETURNING
      VALUE(rt_stat) TYPE zif_cd_hck_types=>tt_alert_stat.

  "! Run a validated value query (ZCL_CD_HCK_VALUE_QUERY): rows of up to three
  "! character-like fields, ordered, at most iv_max_rows
  METHODS select_values DEFAULT IGNORE
    IMPORTING
      is_query       TYPE zif_cd_hck_value_types=>ty_value_query
      iv_max_rows    TYPE i
    RETURNING
      VALUE(rt_rows) TYPE zif_cd_hck_value_types=>tt_value_row
    RAISING
      zcx_cd_ops_error.

  "! Active suppressions (status A, today within the period) - design 6.3
  METHODS get_suppressions DEFAULT IGNORE
    IMPORTING
      iv_today               TYPE d
    RETURNING
      VALUE(rt_suppressions) TYPE zif_cd_hck_suppress_types=>tt_suppression.

ENDINTERFACE.
