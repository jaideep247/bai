*&---------------------------------------------------------------------*
*& Artifact: zif_cd_hck_dao.intf.abap
*& Purpose:
*& Data access of the health check payment engine area: customizing, metric history,
*& configuration baselines and the technical reads used by the checks.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | get_suppressions (design 6.3), DEFAULT IGNORE for existing doubles.
*& 2026-11-06 | select_values for the known-table checks (DEFAULT IGNORE).
*& 2026-11-06 | get_metric_history by distinct completed runs with as-of bound (audit A58).
*& 2026-11-06 | get_unresolved_jobs; job runs carry program/variant (audit A42, A44).
*& 2026-11-06 | G/L transfer gaps per company code and reference type; total count (audit A43).
*& 2026-11-06 | get_metric_history at the persisted grain incl. DIM2 (audit A101).
*& 2026-11-06 | get_agg_groups (expected groups); row cap public (audit A103).
*& 2026-11-06 | Modern-syntax sweep: alert tables ZCD_OPS_ALCHN / ALLOG / ALRULE.
*& 2026-11-06 | PCRE patterns: job names, application-log objects / subobjects and cycle ids are lists of
*&              PCRE patterns (complete value, case ignored); job reads raise message 747 at the name cap.
*& 2026-11-07 | GC_MAX_AGG_ROWS is the hard ceiling (50,000) of parameter HCK_MAX_AGG_ROWS (default 5,000).
*& 2026-11-07 | get_monitor_cfg (ZCD_OPS_MONCFG, DEFAULT IGNORE for existing doubles).
*& 2026-11-08 | Table consolidation: approved tables (HCK / READ) and drift tables (HCK / DRIFT) read from
*&            | ZCD_OPS_TABWL (was ZCD_HCK_TABWL, ZCD_HCK_DRIFT).
*& 2026-11-08 | Table consolidation: get_monitor_cfg (ZCD_OPS_MONCFG) removed - the stale threshold per area
*&            | is the core parameter MON_STALE_AFTER_MIN_<area>.
*& 2026-11-08 | Table consolidation: expected groups are the field EXPECTED_GROUPS of ZCD_HCK_AGG (read with
*&            | the definitions); get_agg_groups (ZCD_HCK_AGGGRP) removed.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - data access (all SQL of HCK)</p>
"! The only place in the HCK payment engine area that issues SQL, calls DDIC runtime
"! descriptions or reads system tables. Checks and the engine stay SQL-free.
INTERFACE zif_cd_hck_dao
  PUBLIC.

  "! Groups returned by one grouped aggregate at most; a result of this size may be cut
  "! off, so missing expected groups are not filled with zero then (A103)
  CONSTANTS gc_max_agg_rows TYPE i VALUE 50000.

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

  "! Generic aggregate definitions (ZCD_HCK_AGG) of a check, with their expected groups
  "! (EXPECTED_GROUPS, A103; table consolidation 2026-11-08 - was ZCD_HCK_AGGGRP)
  METHODS get_agg_defs
    IMPORTING
      iv_check_id    TYPE zif_cd_hck_types=>ty_check_id
    RETURNING
      VALUE(rt_defs) TYPE zif_cd_hck_types=>tt_agg_def.

  "! Table is approved for HCK reads (ZCD_OPS_TABWL HCK / READ, whole table) and active
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

  "! Baseline history: the latest value of each of the last iv_max_rows COMPLETED runs
  "! (status S / W / E, not test mode), newest run first, measured up to iv_as_of
  "! (initial = no bound); running and aborted runs never contribute (audit A58)
  METHODS get_metric_history
    IMPORTING
      iv_check_id      TYPE zif_cd_hck_types=>ty_check_id
      iv_metric        TYPE zif_cd_hck_types=>ty_metric_name
      iv_dim1          TYPE zif_cd_hck_types=>ty_dim
      "! Second dimension of the series (audit A101: history at the persisted grain)
      iv_dim2          TYPE zif_cd_hck_types=>ty_dim OPTIONAL
      iv_max_rows      TYPE i
      iv_as_of         TYPE timestampl OPTIONAL
    RETURNING
      VALUE(rt_values) TYPE zif_cd_hck_types=>tt_value.

  "! Append metric history (duplicates of the same key in one run are ignored)
  METHODS save_metrics
    IMPORTING
      it_metrics TYPE zif_cd_hck_types=>tt_metric_hist
    RAISING
      zcx_cd_ops_error.

  "! Verdict of checks of a run (ZCD_HCK_RESULT, one row per run and check; a repeated row of the
  "! same run and check replaces the earlier one)
  METHODS save_results
    IMPORTING
      it_results TYPE zif_cd_hck_types=>tt_result_row
    RAISING
      zcx_cd_ops_error.

  "! Tables under configuration-drift control (ZCD_OPS_TABWL HCK / DRIFT, active)
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

  "! Steps of active job cycles (ZCD_JOB_CYCLE + ZCD_JOB_STEP), by cycle and step;
  "! it_cycle_ids: PCRE patterns on the cycle id (empty = every active cycle)
  METHODS get_cycle_steps
    IMPORTING
      it_cycle_ids    TYPE zif_cd_ops_types=>tt_pcre OPTIONAL
    RETURNING
      VALUE(rt_steps) TYPE zif_cd_hck_types=>tt_cycle_step.

  "! Date is a working day of the factory calendar (blank calendar = always)
  METHODS is_working_day
    IMPORTING
      iv_calendar       TYPE zif_cd_hck_types=>ty_calendar
      iv_date           TYPE d
    RETURNING
      VALUE(rv_working) TYPE abap_bool.

  "! Background job instances (TBTCO) planned or started in a date window, with program
  "! and variant of the first step (TBTCP); capped at ZIF_CD_HCK_TYPES=>GC_MAX_JOB_ROWS.
  "! it_jobnames: PCRE patterns on the complete job name (case ignored), applied in ABAP to
  "! the distinct job names of the window (capped at GC_MAX_JOB_NAMES: message 747)
  METHODS get_job_runs
    IMPORTING
      it_jobnames    TYPE zif_cd_ops_types=>tt_pcre
      iv_from        TYPE d
      iv_to          TYPE d
    RETURNING
      VALUE(rt_runs) TYPE zif_cd_hck_types=>tt_job_run
    RAISING
      zcx_cd_ops_error.

  "! Jobs not finished (running, ready, released, active) regardless of their date -
  "! an old stuck job never drops out of a date window (audit A44); capped at
  "! ZIF_CD_HCK_TYPES=>GC_MAX_JOB_ROWS, oldest planned start first
  METHODS get_unresolved_jobs DEFAULT IGNORE
    IMPORTING
      it_jobnames    TYPE zif_cd_ops_types=>tt_pcre
    RETURNING
      VALUE(rt_runs) TYPE zif_cd_hck_types=>tt_job_run
    RAISING
      zcx_cd_ops_error.
  "! Application-log message counters (BALHDR) per object / subobject for a day;
  "! it_objects / it_subobjects: PCRE patterns (complete value, case ignored), applied in
  "! ABAP to the grouped counters of the day; no object pattern = nothing read
  METHODS get_applog_stats
    IMPORTING
      it_objects     TYPE zif_cd_ops_types=>tt_pcre
      it_subobjects  TYPE zif_cd_ops_types=>tt_pcre OPTIONAL
      iv_date        TYPE d
    RETURNING
      VALUE(rt_stat) TYPE zif_cd_hck_types=>tt_applog_stat.

  "! Owned exceptions past their due date, per payment engine area (ZCD_OPS_FINDING)
  METHODS get_overdue_exceptions
    IMPORTING
      iv_today          TYPE d
    RETURNING
      VALUE(rt_overdue) TYPE zif_cd_hck_types=>tt_overdue.

  "! Oldest-due open owned exceptions (all payment engine areas), at most iv_max_rows
  METHODS get_open_exceptions
    IMPORTING
      iv_max_rows          TYPE i
    RETURNING
      VALUE(rt_exceptions) TYPE zif_cd_hck_types=>tt_open_exception.

  "! Reconciliation key and company code with totals records (DFKKSUMC) but no
  "! unreversed GL document of reference type iv_awtyp for that company code
  "! (DFKKSUMC-FIKEY = DFKKKO-FIKEY = BKPF-AWKEY), posting date in window (A43);
  "! at most iv_max_rows listed
  METHODS get_fikeys_without_gl
    IMPORTING
      iv_from        TYPE d
      iv_to          TYPE d
      iv_max_rows    TYPE i
      iv_awtyp       TYPE awtyp
    RETURNING
      VALUE(rt_gaps) TYPE zif_cd_hck_types=>tt_fikey_gap.
  "! Total number of gaps of get_fikeys_without_gl, independent of the display cap (A43)
  METHODS count_fikeys_without_gl DEFAULT IGNORE
    IMPORTING
      iv_from         TYPE d
      iv_to           TYPE d
      iv_awtyp        TYPE awtyp
    RETURNING
      VALUE(rv_count) TYPE i.

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

  "! Alert deliveries (ZCD_OPS_ALLOG) per channel and status in a window
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
