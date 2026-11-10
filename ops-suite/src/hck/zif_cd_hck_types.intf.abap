*&---------------------------------------------------------------------*
*& Artifact: zif_cd_hck_types.intf.abap
*& Purpose:
*& Types and constants of the health check (HCK) payment engine area: customizing rows,
*& metrics, check results, job-cycle states and the morning report model.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | ATC-equivalent fixes: ORDER BY, CHECK before FOR ALL ENTRIES, sy-subrc, keyless SORT.
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | RUN_HUNG, CHECKS_NOT_CONFIGURED, hung runs and check counts (audit A06, A60).
*& 2026-11-06 | Job step program/variant, retries and late start; job read cap (audit A42, A44).
*& 2026-11-06 | Aggregate query carries its definition for re-validation at the DAO (audit A56).
*& 2026-11-06 | Baseline hash version; CONFIG_BASELINE_OUTDATED (audit A57).
*& 2026-11-06 | Check time budget in the context; CHECK_BUDGET_EXHAUSTED (audit A18).
*& 2026-11-06 | Metric kind and weight: aggregation by metric semantics (audit A88).
*& 2026-11-06 | BASELINE_WARMUP code, warm-up flag and counts (audit A102).
*& 2026-11-06 | Expected group set of an aggregate, ZCD_HCK_AGGGRP (audit A103).
*& 2026-11-06 | Sorted/hashed sweep: keyed lookups by sorted secondary keys / hashed tables (Performance_Review.md).
*& 2026-11-06 | Modern-syntax sweep: alert tables ZCA_OPS_ALCHN / ALLOG / ALRULE.
*& 2026-11-06 | PCRE patterns: object / subobject / cycle / pattern ranges removed (patterns are lists of PCRE,
*&              zif_ca_ops_types=>tt_pcre); PATTERN_INVALID, SUPPRESSION_PATTERN_INVALID, messages 371-373,
*&              gc_max_job_names.
*& 2026-11-07 | GC_PARAM_DEFAULT-MAX_AGE_HOURS (was inline in the engine), GC_DASHBOARD-WINDOW_DAYS
*&            | (single source of the CDS literals, cds_abap_parity).
*& 2026-11-07 | GC_PARAM moved here from ZCL_CD_HCK_ENGINE; GC_PARAM_DEFAULT complete (inline 300 / 8 / 20,
*&            | watched areas, mail route, runtime limit); row caps as parameters HCK_MAX_JOB_ROWS (5,000) and
*&            | HCK_MAX_JOB_NAMES (20,000); GC_MAX_JOB_ROWS / GC_MAX_JOB_NAMES are now the hard ceilings (50,000 /
*&            | 200,000).
*& 2026-11-07 | TY_MONITOR_CFG (ZCD_OPS_MONCFG); TY_PE_AREA_STATUS-STALE_AFTER_MIN / AGE_MIN.
*& 2026-11-07 | Check code PARAM_INVALID (configuration check ZCL_CD_HCK_C_PARAM, parameters in ZCA_PARAM).
*& 2026-11-07 | CONFIG_CHANGED_IN_PROD / message 374 withdrawn (user decision: new rows by transport, D-3).
*& 2026-11-07 | Design review: verdict of each check per run persisted (ZCD_HCK_RESULT, TY_RESULT_ROW):
*&            | check status, completion, evidence availability, baseline mode, run scope (message 300).
*& 2026-11-08 | Table consolidation: approved tables (HCK / READ) and drift tables (HCK / DRIFT) read from
*&            | ZCD_OPS_TABWL (was ZCD_HCK_TABWL, ZCD_HCK_DRIFT).
*& 2026-11-08 | Table consolidation: GC_BTC_USAGE (ZCD_HCK_BTCROLE-USAGE LIFECYCLE / RECON; ZCD_HCK_RCBTC
*&            | merged).
*& 2026-11-08 | Table consolidation: TY_MONITOR_CFG removed (ZCD_OPS_MONCFG retired; stale threshold =
*&            | parameter MON_STALE_AFTER_MIN_<area>).
*& 2026-11-08 | Table consolidation: TY_AGG_DEF-EXPECTED_GROUPS (comma list, TY_GROUP_LIST) replaces
*&            | ZCD_HCK_AGGGRP; TY_AGG_GROUP removed.
*& 2026-11-08 | Customer posting areas: GC_BTC_USAGE is key USAGE of ZBTR; check code POSTAREA_INVALID.
*& 2026-11-10 | Alert status C (claimed) and HCK_ALERT_CLAIM_MIN: claims never completed (alert health).
*& 2026-11-10 | HCK_MAIL_TEMPLATE (morning report e-mail template); message 839 (check line of a finding).
*& 2026-11-10 | Company-code isolation: TY_METRIC-COMPANY_CODE / TY_METRIC_HIST-BUKRS, GC_COMPANY_CODE_FIELD.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - types and constants</p>
"! Shared by the HCK engine, the check plug-ins, the DAO, the HTML renderer
"! and the morning report. Every customizing row (ZCD_HCK_*, ZCD_JOB_*) has a
"! structure here; method parameters always use these named types.
INTERFACE zif_cd_hck_types
  PUBLIC.

  TYPES ty_check_id      TYPE c LENGTH 20.
  "! A financial integrity, B mass-run health, C exception queues,
  "! D config drift, E technical health
  TYPES ty_category      TYPE c LENGTH 1.
  "! H high, M medium, L low
  TYPES ty_priority      TYPE c LENGTH 1.
  TYPES ty_metric_name   TYPE c LENGTH 30.
  TYPES ty_metric_kind   TYPE c LENGTH 1.

  "! How a metric aggregates across runs, days and dimensions (analytics, audit A88):
  "! volumes add up, levels (durations, ages, sizes) take MAX / AVG, rates are weighted
  "! by their denominator (WEIGHT). Blank is stored as volume.
  CONSTANTS:
    BEGIN OF gc_metric_kind,
      volume TYPE ty_metric_kind VALUE 'V',
      level  TYPE ty_metric_kind VALUE 'L',
      rate   TYPE ty_metric_kind VALUE 'R',
    END OF gc_metric_kind.
  TYPES ty_dim           TYPE c LENGTH 35.
  "! Threshold key: company code or another 4-character dimension value; '*' = default
  TYPES ty_thresh_key    TYPE c LENGTH 4.
  TYPES ty_param         TYPE c LENGTH 100.
  TYPES ty_value         TYPE decfloat34.
  TYPES tt_value         TYPE STANDARD TABLE OF ty_value WITH EMPTY KEY.
  TYPES ty_baseline_mode TYPE c LENGTH 6.
  "! Version of the drift-hash serialization (ZCL_CD_HCK_CANONICAL=>GC_HASH_VERSION)
  TYPES ty_hash_version  TYPE c LENGTH 2.
  TYPES ty_tabname       TYPE c LENGTH 30.
  TYPES ty_fieldname     TYPE c LENGTH 30.
  TYPES ty_agg_id        TYPE c LENGTH 10.
  TYPES ty_agg_func      TYPE c LENGTH 5.
  TYPES ty_date_mode     TYPE c LENGTH 3.
  TYPES ty_operator      TYPE c LENGTH 2.
  TYPES ty_cond_value    TYPE c LENGTH 70.
  TYPES ty_group_value   TYPE c LENGTH 70.
  "! ZCD_HCK_AGG-EXPECTED_GROUPS: comma list of expected group values (A103, was ZCD_HCK_AGGGRP)
  TYPES ty_group_list    TYPE c LENGTH 255.
  TYPES ty_type_kind     TYPE c LENGTH 1.
  TYPES ty_cycle_id      TYPE c LENGTH 20.
  TYPES ty_step_no       TYPE n LENGTH 3.
  TYPES ty_jobname       TYPE c LENGTH 32.
  TYPES ty_jobcount      TYPE c LENGTH 8.
  TYPES ty_job_status    TYPE c LENGTH 1.
  TYPES ty_program       TYPE c LENGTH 40.
  TYPES ty_job_variant   TYPE c LENGTH 14.
  TYPES ty_calendar      TYPE c LENGTH 2.
  TYPES ty_step_state    TYPE c LENGTH 12.
  TYPES ty_hash          TYPE c LENGTH 64.
  TYPES ty_text          TYPE c LENGTH 60.
  TYPES ty_fikey         TYPE c LENGTH 12.
  TYPES ty_bal_object    TYPE c LENGTH 20.
  TYPES ty_bal_subobject TYPE c LENGTH 20.
  TYPES ty_score         TYPE i.
  TYPES ty_channel       TYPE c LENGTH 10.
  "! ZCA_OPS_FINDING-DISPOSITION: O open, A assigned, I information, R resolved, W waived
  TYPES ty_disposition   TYPE c LENGTH 1.
  "! ZCA_OPS_ALLOG-STATUS: S sent, F failed, T throttled
  TYPES ty_alert_status  TYPE c LENGTH 1.

  TYPES tt_category_range TYPE RANGE OF ty_category.
  TYPES tt_priority_range TYPE RANGE OF ty_priority.
  TYPES tt_check_range    TYPE RANGE OF ty_check_id.

  CONSTANTS:
    BEGIN OF gc_category,
      financial  TYPE ty_category VALUE 'A',
      mass_run   TYPE ty_category VALUE 'B',
      exceptions TYPE ty_category VALUE 'C',
      config     TYPE ty_category VALUE 'D',
      technical  TYPE ty_category VALUE 'E',
    END OF gc_category.

  CONSTANTS:
    BEGIN OF gc_priority,
      high   TYPE ty_priority VALUE 'H',
      medium TYPE ty_priority VALUE 'M',
      low    TYPE ty_priority VALUE 'L',
    END OF gc_priority.

  CONSTANTS:
    BEGIN OF gc_baseline,
      none   TYPE ty_baseline_mode VALUE 'NONE',
      zscore TYPE ty_baseline_mode VALUE 'ZSCORE',
      iqr    TYPE ty_baseline_mode VALUE 'IQR',
    END OF gc_baseline.

  CONSTANTS:
    BEGIN OF gc_agg_func,
      count TYPE ty_agg_func VALUE 'COUNT',
      sum   TYPE ty_agg_func VALUE 'SUM',
    END OF gc_agg_func.

  "! AGE: date field older than AGE_DAYS_MIN days; DAY: date field = reference date - AGE_DAYS_MIN
  CONSTANTS:
    BEGIN OF gc_date_mode,
      none TYPE ty_date_mode VALUE '',
      age  TYPE ty_date_mode VALUE 'AGE',
      day  TYPE ty_date_mode VALUE 'DAY',
    END OF gc_date_mode.

  CONSTANTS:
    BEGIN OF gc_operator,
      eq     TYPE ty_operator VALUE 'EQ',
      ne     TYPE ty_operator VALUE 'NE',
      gt     TYPE ty_operator VALUE 'GT',
      lt     TYPE ty_operator VALUE 'LT',
      ge     TYPE ty_operator VALUE 'GE',
      le     TYPE ty_operator VALUE 'LE',
      in_set TYPE ty_operator VALUE 'IN',
    END OF gc_operator.

  CONSTANTS:
    BEGIN OF gc_step_state,
      not_started TYPE ty_step_state VALUE 'NOT_STARTED',
      running     TYPE ty_step_state VALUE 'RUNNING',
      completed   TYPE ty_step_state VALUE 'COMPLETED',
      failed      TYPE ty_step_state VALUE 'FAILED',
      stuck       TYPE ty_step_state VALUE 'STUCK',
      missed      TYPE ty_step_state VALUE 'MISSED',
    END OF gc_step_state.

  "! TBTCO-STATUS values (standard background processing, include LBTCHDEF)
  CONSTANTS:
    BEGIN OF gc_job_status,
      running   TYPE ty_job_status VALUE 'R',
      finished  TYPE ty_job_status VALUE 'F',
      aborted   TYPE ty_job_status VALUE 'A',
      released  TYPE ty_job_status VALUE 'S',
      scheduled TYPE ty_job_status VALUE 'P',
      ready     TYPE ty_job_status VALUE 'Y',
      put_activ TYPE ty_job_status VALUE 'Z',
    END OF gc_job_status.

  "! Finding check codes written by the engine and the delivered checks
  CONSTANTS:
    BEGIN OF gc_code,
      plugin_error     TYPE zif_ca_ops_types=>ty_check_code VALUE 'PLUGIN_ERROR',
      threshold_red    TYPE zif_ca_ops_types=>ty_check_code VALUE 'THRESHOLD_RED',
      threshold_amber  TYPE zif_ca_ops_types=>ty_check_code VALUE 'THRESHOLD_AMBER',
      baseline_outlier TYPE zif_ca_ops_types=>ty_check_code VALUE 'BASELINE_OUTLIER',
      timeout          TYPE zif_ca_ops_types=>ty_check_code VALUE 'TIMEOUT_OVERRUN',
      pe_area_stale     TYPE zif_ca_ops_types=>ty_check_code VALUE 'MODULE_STALE',
      alert_failed     TYPE zif_ca_ops_types=>ty_check_code VALUE 'ALERT_FAILED',
      gl_gap           TYPE zif_ca_ops_types=>ty_check_code VALUE 'GL_TRANSFER_GAP',
      job_cancelled    TYPE zif_ca_ops_types=>ty_check_code VALUE 'JOB_CANCELLED',
      job_long_running TYPE zif_ca_ops_types=>ty_check_code VALUE 'JOB_LONG_RUNNING',
      job_late_start   TYPE zif_ca_ops_types=>ty_check_code VALUE 'JOB_LATE_START',
      step_missed      TYPE zif_ca_ops_types=>ty_check_code VALUE 'STEP_MISSED',
      step_failed      TYPE zif_ca_ops_types=>ty_check_code VALUE 'STEP_FAILED',
      step_stuck       TYPE zif_ca_ops_types=>ty_check_code VALUE 'STEP_STUCK',
      step_overrun     TYPE zif_ca_ops_types=>ty_check_code VALUE 'STEP_OVERRUN',
      step_blocked     TYPE zif_ca_ops_types=>ty_check_code VALUE 'STEP_BLOCKED',
      config_drift     TYPE zif_ca_ops_types=>ty_check_code VALUE 'CONFIG_DRIFT',
      agg_invalid      TYPE zif_ca_ops_types=>ty_check_code VALUE 'AGG_CONFIG_INVALID',
      no_baseline      TYPE zif_ca_ops_types=>ty_check_code VALUE 'CONFIG_NO_BASELINE',
      run_hung         TYPE zif_ca_ops_types=>ty_check_code VALUE 'RUN_HUNG',
      no_checks        TYPE zif_ca_ops_types=>ty_check_code VALUE 'CHECKS_NOT_CONFIGURED',
      step_retried     TYPE zif_ca_ops_types=>ty_check_code VALUE 'STEP_RETRIED',
      step_late        TYPE zif_ca_ops_types=>ty_check_code VALUE 'STEP_LATE',
      job_read_capped  TYPE zif_ca_ops_types=>ty_check_code VALUE 'JOB_READ_CAPPED',
      baseline_outdated TYPE zif_ca_ops_types=>ty_check_code VALUE 'CONFIG_BASELINE_OUTDATED',
      budget_exhausted TYPE zif_ca_ops_types=>ty_check_code VALUE 'CHECK_BUDGET_EXHAUSTED',
      "! Baseline has fewer than the minimum history runs: no baseline verdict yet (A102)
      baseline_warmup  TYPE zif_ca_ops_types=>ty_check_code VALUE 'BASELINE_WARMUP',
      "! A job-step job name (ZCD_JOB_STEP-JOBNAME) is not valid PCRE - step not evaluated
      pattern_invalid  TYPE zif_ca_ops_types=>ty_check_code VALUE 'PATTERN_INVALID',
      "! A suppression key pattern is not valid PCRE - suppression not applied
      suppression_invalid TYPE zif_ca_ops_types=>ty_check_code VALUE 'SUPPRESSION_PATTERN_INVALID',
      "! A parameter of the suite that ZCA_PARAM refuses (ZCL_CD_HCK_C_PARAM)
      param_invalid    TYPE zif_ca_ops_types=>ty_check_code VALUE 'PARAM_INVALID',
      "! An entry of a customer posting area ZRSN / ZPMC / ZBTM / ZBTR its reader cannot use
      "! (ZCL_CD_HCK_C_POSTAREA, ZCL_CD_OPS_CFG_CHECKS=>CHECK_POSTING_AREAS)
      postarea_invalid TYPE zif_ca_ops_types=>ty_check_code VALUE 'POSTAREA_INVALID',
    END OF gc_code.

  CONSTANTS:
    BEGIN OF gc_disposition,
      open     TYPE ty_disposition VALUE 'O',
      assigned TYPE ty_disposition VALUE 'A',
    END OF gc_disposition.

  CONSTANTS:
    BEGIN OF gc_alert_status,
      sent      TYPE ty_alert_status VALUE 'S',
      failed    TYPE ty_alert_status VALUE 'F',
      throttled TYPE ty_alert_status VALUE 'T',
      "! Claimed before the send and never completed (dispatcher stopped between claim and send)
      claimed   TYPE ty_alert_status VALUE 'C',
    END OF gc_alert_status.

  "! Score points per RAG and weights per priority (defaults; ZCA_PARAM overrides)
  TYPES:
    BEGIN OF ty_score_rules,
      points_green  TYPE i,
      points_amber  TYPE i,
      points_red    TYPE i,
      weight_high   TYPE i,
      weight_medium TYPE i,
      weight_low    TYPE i,
      green_min     TYPE i,
      amber_min     TYPE i,
    END OF ty_score_rules.

  CONSTANTS gc_object_type TYPE zif_ca_ops_types=>ty_object_type VALUE 'CHECK'.
  CONSTANTS gc_default_key TYPE ty_thresh_key VALUE '*'.
  "! Group field of a generic aggregate (ZCD_HCK_AGG-GROUP_FIELD) whose values are company codes: its metrics
  "! and findings carry the company code (company-code isolation, 2026-11-10)
  CONSTANTS gc_company_code_field TYPE fieldname VALUE 'BUKRS'.
  CONSTANTS gc_self_check  TYPE ty_check_id VALUE 'HCK_SELF'.
  "! Result row raised when no business check is selected / active (audit A60)
  CONSTANTS gc_config_check TYPE ty_check_id VALUE 'HCK_CONFIG'.
  "! Plug-in interface every configured check class implements (factory check, A62)
  CONSTANTS gc_check_intf TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZIF_CD_HCK_CHECK'.
  "! Row cap of one job read (TBTCO); a read that reaches it is reported (audit A44)
  CONSTANTS gc_max_job_rows TYPE i VALUE 50000.
  "! Cap of the distinct job names read for the PCRE filter (TBTCO, date window or open
  "! status); reaching it raises message 747 - the check fails loudly, never partly
  CONSTANTS gc_max_job_names TYPE i VALUE 200000.

  "! ZCD_HCK_DEF
  TYPES:
    BEGIN OF ty_check_def,
      check_id     TYPE ty_check_id,
      description  TYPE ty_text,
      category     TYPE ty_category,
      class_name   TYPE zif_ca_ops_types=>ty_class_name,
      active       TYPE abap_bool,
      seq          TYPE i,
      priority     TYPE ty_priority,
      param1       TYPE ty_param,
      param2       TYPE ty_param,
      param3       TYPE ty_param,
      param4       TYPE ty_param,
      package_size TYPE i,
      timeout_sec  TYPE i,
    END OF ty_check_def.
  TYPES tt_check_def TYPE STANDARD TABLE OF ty_check_def WITH EMPTY KEY.

  "! ZCD_HCK_THRESH
  TYPES:
    BEGIN OF ty_threshold,
      check_id        TYPE ty_check_id,
      metric          TYPE ty_metric_name,
      bukrs           TYPE ty_thresh_key,
      amber           TYPE ty_value,
      red             TYPE ty_value,
      higher_is_worse TYPE abap_bool,
      baseline_mode   TYPE ty_baseline_mode,
      z_limit         TYPE ty_value,
      lookback_runs   TYPE i,
    END OF ty_threshold.
  TYPES tt_threshold TYPE STANDARD TABLE OF ty_threshold WITH EMPTY KEY.

  "! ZCD_HCK_AGG
  TYPES:
    BEGIN OF ty_agg_def,
      check_id     TYPE ty_check_id,
      agg_id       TYPE ty_agg_id,
      description  TYPE ty_text,
      tabname      TYPE ty_tabname,
      agg_func     TYPE ty_agg_func,
      sum_field    TYPE ty_fieldname,
      date_field   TYPE ty_fieldname,
      date_mode    TYPE ty_date_mode,
      age_days_min TYPE i,
      group_field  TYPE ty_fieldname,
      "! Expected GROUP_FIELD values, comma list (A103) - parsed once per aggregate by
      "! ZCL_CD_HCK_AGG_QUERY=>EXPECTED_GROUPS
      expected_groups TYPE ty_group_list,
      cond1_field  TYPE ty_fieldname,
      cond1_op     TYPE ty_operator,
      cond1_value  TYPE ty_cond_value,
      cond2_field  TYPE ty_fieldname,
      cond2_op     TYPE ty_operator,
      cond2_value  TYPE ty_cond_value,
      cond3_field  TYPE ty_fieldname,
      cond3_op     TYPE ty_operator,
      cond3_value  TYPE ty_cond_value,
    END OF ty_agg_def.
  TYPES tt_agg_def TYPE STANDARD TABLE OF ty_agg_def WITH EMPTY KEY.

  "! One DDIC field of a table (from the runtime DDIC, never from code)
  TYPES:
    BEGIN OF ty_field,
      fieldname TYPE ty_fieldname,
      type_kind TYPE ty_type_kind,
      keyflag   TYPE abap_bool,
    END OF ty_field.
  TYPES tt_field TYPE STANDARD TABLE OF ty_field WITH EMPTY KEY.

  "! A validated aggregate: names checked against DDIC, literals quoted
  TYPES:
    BEGIN OF ty_agg_query,
      agg_id       TYPE ty_agg_id,
      tabname      TYPE ty_tabname,
      agg_func     TYPE ty_agg_func,
      sum_field    TYPE ty_fieldname,
      group_field  TYPE ty_fieldname,
      where_clause TYPE string,
      "! Source of the query: the DAO rebuilds the SQL from it and ignores the strings
      "! above (audit A56 - validation is enforced at the SQL boundary)
      def          TYPE ty_agg_def,
      ref_date     TYPE d,
    END OF ty_agg_query.

  TYPES:
    BEGIN OF ty_agg_row,
      group_value TYPE ty_group_value,
      row_count   TYPE int8,
      total       TYPE ty_value,
    END OF ty_agg_row.
  TYPES tt_agg_row TYPE STANDARD TABLE OF ty_agg_row WITH EMPTY KEY.

  "! Expected GROUP_FIELD values of an aggregate (audit A103), parsed from ZCD_HCK_AGG-EXPECTED_GROUPS
  TYPES tt_group_value TYPE STANDARD TABLE OF ty_group_value WITH EMPTY KEY.

  "! A measured key figure (ZCD_HCK_METRIC without run id / time stamp)
  TYPES:
    BEGIN OF ty_metric,
      metric TYPE ty_metric_name,
      dim1   TYPE ty_dim,
      dim2   TYPE ty_dim,
      value  TYPE ty_value,
      "! aggregation semantics (gc_metric_kind; blank = volume)
      kind   TYPE ty_metric_kind,
      "! rates: the denominator the rate was computed over (e.g. messages read)
      weight TYPE ty_value,
      "! Company code the metric is about (blank = not company-specific): set by the check when a dimension
      "! is a company code (generic aggregate grouped by GC_COMPANY_CODE_FIELD, reconciliation set); stored
      "! with the metric and carried to its findings (company-code isolation, 2026-11-10)
      company_code TYPE bukrs,
    END OF ty_metric.
  TYPES tt_metric TYPE STANDARD TABLE OF ty_metric WITH EMPTY KEY.

  "! ZCD_HCK_METRIC
  TYPES:
    BEGIN OF ty_metric_hist,
      run_id      TYPE zif_ca_ops_types=>ty_run_id,
      check_id    TYPE ty_check_id,
      metric      TYPE ty_metric_name,
      dim1        TYPE ty_dim,
      dim2        TYPE ty_dim,
      value       TYPE ty_value,
      measured_at TYPE timestampl,
      kind        TYPE ty_metric_kind,
      weight      TYPE ty_value,
      bukrs       TYPE bukrs,
    END OF ty_metric_hist.
  TYPES tt_metric_hist TYPE STANDARD TABLE OF ty_metric_hist WITH EMPTY KEY.

  "! How far a check ran (ZCD_HCK_RESULT-COMPLETION) and how much evidence it could read (EVIDENCE)
  TYPES ty_completion TYPE c LENGTH 10.
  TYPES ty_check_status TYPE c LENGTH 10.
  CONSTANTS:
    BEGIN OF gc_completion,
      complete TYPE ty_completion VALUE 'COMPLETE',
      "! Ran but stopped or read less than all (timeout overrun, time budget, capped read)
      partial  TYPE ty_completion VALUE 'PARTIAL',
      "! The plug-in failed (PLUGIN_ERROR): no verdict about the business - never green
      failed   TYPE ty_completion VALUE 'FAILED',
      "! Active but not selected by the run's scope (category / priority / check filter)
      skipped  TYPE ty_completion VALUE 'SKIPPED',
    END OF gc_completion.
  CONSTANTS:
    BEGIN OF gc_evidence,
      all     TYPE ty_completion VALUE 'ALL',
      partial TYPE ty_completion VALUE 'PARTIAL',
      none    TYPE ty_completion VALUE 'NONE',
    END OF gc_evidence.
  "! Status of a check in a run as the report decided it (ZCD_HCK_RESULT-CHECK_STATUS; the dashboard
  "! shows it and adds NO_RESULT for an active check without a row in the run)
  CONSTANTS:
    BEGIN OF gc_check_status,
      red     TYPE ty_check_status VALUE 'RED',
      amber   TYPE ty_check_status VALUE 'AMBER',
      green   TYPE ty_check_status VALUE 'GREEN',
      warmup  TYPE ty_check_status VALUE 'WARMUP',
      grey    TYPE ty_check_status VALUE 'GREY',
      failed  TYPE ty_check_status VALUE 'FAILED',
      skipped TYPE ty_check_status VALUE 'SKIPPED',
    END OF gc_check_status.
  "! Baseline modes of the thresholds a check was evaluated with: several different = MIXED
  CONSTANTS gc_baseline_mixed TYPE ty_baseline_mode VALUE 'MIXED'.
  "! Part of the run scope that selects everything (empty range)
  CONSTANTS gc_scope_all TYPE string VALUE `*`.
  CONSTANTS gc_scope_sep TYPE string VALUE `, `.

  "! ZCD_HCK_RESULT: the verdict of one check in one run, from the same decision the report uses
  TYPES:
    BEGIN OF ty_result_row,
      run_id        TYPE zif_ca_ops_types=>ty_run_id,
      check_id      TYPE ty_check_id,
      executed_at   TYPE timestampl,
      category      TYPE ty_category,
      priority      TYPE ty_priority,
      verdict       TYPE zif_ca_ops_types=>ty_rag,
      check_status  TYPE ty_check_status,
      completion    TYPE ty_completion,
      evidence      TYPE ty_completion,
      run_scope     TYPE zif_ca_ops_types=>ty_message,
      metric_count  TYPE i,
      finding_count TYPE i,
      error_count   TYPE i,
      warning_count TYPE i,
      baseline_mode TYPE ty_baseline_mode,
      warmup        TYPE abap_bool,
      runtime_ms    TYPE i,
      message       TYPE zif_ca_ops_types=>ty_message,
    END OF ty_result_row.
  TYPES tt_result_row TYPE STANDARD TABLE OF ty_result_row WITH EMPTY KEY.

  "! Result of evaluating one metric against its threshold / baseline
  TYPES:
    BEGIN OF ty_evaluation,
      rag        TYPE zif_ca_ops_types=>ty_rag,
      check_code TYPE zif_ca_ops_types=>ty_check_code,
      z_score    TYPE ty_value,
      mean       TYPE ty_value,
      points     TYPE i,
    END OF ty_evaluation.

  "! ZCD_JOB_CYCLE + ZCD_JOB_STEP (joined)
  TYPES:
    BEGIN OF ty_cycle_step,
      cycle_id        TYPE ty_cycle_id,
      cycle_text      TYPE ty_text,
      calendar        TYPE ty_calendar,
      step_no         TYPE ty_step_no,
      step_text       TYPE ty_text,
      jobname         TYPE ty_jobname,
      program         TYPE ty_program,
      variant         TYPE ty_job_variant,
      pred_step       TYPE ty_step_no,
      day_offset      TYPE i,
      window_from     TYPE t,
      window_to       TYPE t,
      max_runtime_min TYPE i,
      skippable       TYPE abap_bool,
      critical        TYPE abap_bool,
    END OF ty_cycle_step.
  TYPES tt_cycle_step TYPE STANDARD TABLE OF ty_cycle_step WITH EMPTY KEY.

  "! One TBTCO job instance
  TYPES:
    BEGIN OF ty_job_run,
      jobname   TYPE ty_jobname,
      jobcount  TYPE ty_jobcount,
      status    TYPE ty_job_status,
      sdlstrtdt TYPE d,
      sdlstrttm TYPE t,
      strtdate  TYPE d,
      strttime  TYPE t,
      enddate   TYPE d,
      endtime   TYPE t,
      "! Program and variant of the job's first step (TBTCP) - audit A42
      progname  TYPE ty_program,
      variant   TYPE ty_job_variant,
    END OF ty_job_run.
  TYPES tt_job_run TYPE STANDARD TABLE OF ty_job_run WITH EMPTY KEY.

  "! Derived state of one cycle step (job cycle board)
  TYPES:
    BEGIN OF ty_step_status,
      cycle_id    TYPE ty_cycle_id,
      step_no     TYPE ty_step_no,
      jobname     TYPE ty_jobname,
      jobcount    TYPE ty_jobcount,
      state       TYPE ty_step_state,
      cycle_date  TYPE d,
      started_on  TYPE d,
      started_at  TYPE t,
      runtime_min TYPE i,
      overrun     TYPE abap_bool,
      blocked     TYPE abap_bool,
      "! Matching attempts in the window; a later success after an abort = retried (A42)
      attempts    TYPE i,
      retried     TYPE abap_bool,
      "! The deciding attempt started after WINDOW_TO
      late_start  TYPE abap_bool,
    END OF ty_step_status.
  TYPES tt_step_status TYPE STANDARD TABLE OF ty_step_status WITH EMPTY KEY.

  "! BALHDR message counters aggregated per object / subobject
  TYPES:
    BEGIN OF ty_applog_stat,
      object    TYPE ty_bal_object,
      subobject TYPE ty_bal_subobject,
      log_count TYPE int8,
      msg_total TYPE int8,
      msg_error TYPE int8,
      msg_abort TYPE int8,
    END OF ty_applog_stat.
  TYPES tt_applog_stat TYPE STANDARD TABLE OF ty_applog_stat WITH EMPTY KEY.

  "! Overdue owned exceptions per payment engine area (ZCA_OPS_FINDING)
  TYPES:
    BEGIN OF ty_overdue,
      pe_area     TYPE zif_ca_ops_types=>ty_area,
      "! Company code of the overdue exceptions (blank = area-level; company-code isolation)
      bukrs      TYPE bukrs,
      item_count TYPE int8,
      oldest_due TYPE d,
    END OF ty_overdue.
  TYPES tt_overdue TYPE STANDARD TABLE OF ty_overdue WITH EMPTY KEY.

  "! Open owned exception for the morning report (top N)
  TYPES:
    BEGIN OF ty_open_exception,
      pe_area       TYPE zif_ca_ops_types=>ty_area,
      group1       TYPE zif_ca_ops_types=>ty_group,
      group2       TYPE zif_ca_ops_types=>ty_group,
      object_key   TYPE zif_ca_ops_types=>ty_object_key,
      check_code   TYPE zif_ca_ops_types=>ty_check_code,
      severity     TYPE zif_ca_ops_types=>ty_severity,
      message      TYPE zif_ca_ops_types=>ty_message,
      disposition  TYPE ty_disposition,
      owner        TYPE syuname,
      due_date     TYPE d,
      created_at   TYPE timestampl,
      age_days     TYPE i,
      overdue_days TYPE i,
    END OF ty_open_exception.
  TYPES tt_open_exception TYPE STANDARD TABLE OF ty_open_exception WITH EMPTY KEY.

  "! payment engine reconciliation key without a GL document
  TYPES:
    BEGIN OF ty_fikey_gap,
      fikey TYPE ty_fikey,
      "! A gap is per company code: a partial transfer leaves the other company open (A43)
      bukrs TYPE bukrs,
    END OF ty_fikey_gap.
  TYPES tt_fikey_gap TYPE STANDARD TABLE OF ty_fikey_gap WITH EMPTY KEY.

  "! ZCD_OPS_TABWL rows HCK / DRIFT (tables under configuration-drift control)
  TYPES:
    BEGIN OF ty_drift_def,
      tabname     TYPE ty_tabname,
      description TYPE ty_text,
    END OF ty_drift_def.
  TYPES tt_drift_def TYPE STANDARD TABLE OF ty_drift_def WITH EMPTY KEY.

  "! ZCD_HCK_BASELINE (and a freshly computed hash)
  TYPES:
    BEGIN OF ty_baseline,
      tabname      TYPE ty_tabname,
      hash         TYPE ty_hash,
      row_count    TYPE i,
      taken_at     TYPE timestampl,
      taken_by     TYPE syuname,
      hash_version TYPE ty_hash_version,
    END OF ty_baseline.
  "! Sweep: secondary key BY_TABLE - the drift check reads the baseline of each table
  TYPES tt_baseline TYPE STANDARD TABLE OF ty_baseline WITH EMPTY KEY
                    WITH NON-UNIQUE SORTED KEY by_table COMPONENTS tabname.

  "! ZCA_OPS_ALLOG deliveries aggregated per channel and status
  TYPES:
    BEGIN OF ty_alert_stat,
      channel    TYPE ty_channel,
      status     TYPE ty_alert_status,
      item_count TYPE int8,
    END OF ty_alert_stat.
  TYPES tt_alert_stat TYPE STANDARD TABLE OF ty_alert_stat WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_tech_stat,
      short_dumps      TYPE i,
      update_errors    TYPE i,
      lock_entries     TYPE i,
      lock_max_age_min TYPE i,
    END OF ty_tech_stat.

  "! Execution context handed to every check
  TYPES:
    BEGIN OF ty_context,
      report_date TYPE d,
      now_date    TYPE d,
      now_time    TYPE t,
      run_id      TYPE zif_ca_ops_types=>ty_run_id,
      test_mode   TYPE abap_bool,
      "! Time budget of the running check (start + TIMEOUT_SEC); checks that work in
      "! items stop between items once it has passed (audit A18)
      deadline    TYPE timestampl,
      budget_sec  TYPE i,
    END OF ty_context.

  "! Result of one check (plug-in output enriched by the engine)
  TYPES:
    BEGIN OF ty_check_result,
      check_id     TYPE ty_check_id,
      description  TYPE ty_text,
      category     TYPE ty_category,
      priority     TYPE ty_priority,
      rag          TYPE zif_ca_ops_types=>ty_rag,
      runtime_ms   TYPE i,
      timed_out    TYPE abap_bool,
      plugin_error TYPE abap_bool,
      summary      TYPE zif_ca_ops_types=>ty_message,
      metrics      TYPE tt_metric,
      findings     TYPE zif_ca_ops_types=>tt_finding,
      step_status  TYPE tt_step_status,
      "! A baseline-only metric is still warming up: the check is grey, not GREEN (A102)
      warmup       TYPE abap_bool,
      "! Set by a check that read less than all (blank = COMPLETE / ALL unless the engine decides
      "! otherwise: plug-in error FAILED / NONE, overrun or budget PARTIAL)
      completion   TYPE ty_completion,
      evidence     TYPE ty_completion,
      "! Baseline mode of the evaluated thresholds (set by the engine)
      baseline_mode TYPE ty_baseline_mode,
      "! Start of the check (set by the engine)
      executed_at  TYPE timestampl,
    END OF ty_check_result.
  TYPES tt_check_result TYPE STANDARD TABLE OF ty_check_result WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_category_status,
      category    TYPE ty_category,
      rag         TYPE zif_ca_ops_types=>ty_rag,
      check_count TYPE i,
      red_count   TYPE i,
      amber_count TYPE i,
      green_count TYPE i,
      warmup_count TYPE i,
    END OF ty_category_status.
  TYPES tt_category_status TYPE STANDARD TABLE OF ty_category_status WITH EMPTY KEY.

  "! Scorecard computed from check results (pure, see ZCL_CD_HCK_SCORE)
  TYPES:
    BEGIN OF ty_summary,
      score          TYPE ty_score,
      overall_rag    TYPE zif_ca_ops_types=>ty_rag,
      critical_count TYPE i,
      high_count     TYPE i,
      "! Checks in baseline warm-up: listed, not scored (A102)
      warmup_count   TYPE i,
      categories     TYPE tt_category_status,
    END OF ty_summary.

  "! Last-run status of a suite payment engine area (EBS, FMON, HCK) - health of the health check
  TYPES:
    BEGIN OF ty_pe_area_status,
      pe_area        TYPE zif_ca_ops_types=>ty_area,
      last_run_at   TYPE timestampl,
      status        TYPE zif_ca_ops_types=>ty_run_status,
      rag           TYPE zif_ca_ops_types=>ty_rag,
      finding_count TYPE i,
      error_count   TYPE i,
      warning_count TYPE i,
      age_hours     TYPE i,
      max_age_hours TYPE i,
      "! MON_STALE_AFTER_MIN_<area> (0 = not readable: hours rule HCK_MAX_AGE_H_*)
      stale_after_min TYPE i,
      age_min       TYPE i,
      stale         TYPE abap_bool,
      "! Runs still running past HCK_MAX_RUN_MIN_<area> (dump / hang) - audit A06
      hung_runs     TYPE i,
      max_run_min   TYPE i,
    END OF ty_pe_area_status.
  TYPES tt_pe_area_status TYPE STANDARD TABLE OF ty_pe_area_status WITH EMPTY KEY.

  "! Selection of one engine run (morning report selection screen)
  TYPES:
    BEGIN OF ty_selection,
      report_date     TYPE d,
      categories      TYPE tt_category_range,
      priorities      TYPE tt_priority_range,
      check_ids       TYPE tt_check_range,
      include_pe_areas TYPE abap_bool,
      send_mail       TYPE abap_bool,
      test_mode       TYPE abap_bool,
      variant         TYPE zif_ca_ops_types=>ty_variant,
    END OF ty_selection.

  "! Morning report: scorecard + results + payment engine areas + open exceptions
  TYPES:
    BEGIN OF ty_report,
      run            TYPE zif_ca_ops_types=>ty_run,
      report_date    TYPE d,
      score          TYPE ty_score,
      overall_rag    TYPE zif_ca_ops_types=>ty_rag,
      critical_count TYPE i,
      high_count     TYPE i,
      warmup_count   TYPE i,
      categories     TYPE tt_category_status,
      results        TYPE tt_check_result,
      pe_areas        TYPE tt_pe_area_status,
      exceptions     TYPE tt_open_exception,
      "! Business checks selected and active / executed without plug-in error (A60)
      configured_checks TYPE i,
      executed_checks   TYPE i,
    END OF ty_report.

  "! Parameter-name prefixes completed by a payment engine area (e.g. HCK_MAX_AGE_H_EBS)
  CONSTANTS:
    BEGIN OF gc_param_prefix,
      max_age TYPE c LENGTH 14 VALUE 'HCK_MAX_AGE_H_',
      max_run TYPE c LENGTH 16 VALUE 'HCK_MAX_RUN_MIN_',
    END OF gc_param_prefix.

  "! Delivered defaults of HCK parameters. MAX_AGE_HOURS (HCK_MAX_AGE_HOURS) is also the stale
  "! threshold of the EBS and HCK dashboards (26 h = 1560 min = 93600 s in ZR_CD_EbsAsOf /
  "! ZR_CD_HckAsOf; compared by the portable check cds_abap_parity)
  CONSTANTS:
    BEGIN OF gc_param_default,
      max_age_hours TYPE i VALUE 26,
      "! A06: runtime limit of a run before it counts as hung
      max_run_min    TYPE i VALUE 120,
      timeout_sec    TYPE i VALUE 300,
      lookback       TYPE i VALUE 8,
      top_n          TYPE i VALUE 20,
      watch_pe_areas TYPE string VALUE `CD_EBS,CD_FMON,CD_HCK`,
      mail_route     TYPE zif_ca_ops_types=>ty_param_name VALUE 'MORNING',
      "! E-mail template of the morning report (SAP e-mail templates; the report is its TABLE_MAIN)
      mail_template  TYPE zif_ca_ops_types=>ty_param_value VALUE 'ZCD_OPS_MORNING_REPORT',
      "! Row caps (HCK_MAX_JOB_ROWS / _JOB_NAMES / _AGG_ROWS); a larger value is cut to the
      "! hard ceiling GC_MAX_JOB_ROWS / GC_MAX_JOB_NAMES / ZIF_CD_HCK_DAO=>GC_MAX_AGG_ROWS
      max_job_rows   TYPE i VALUE 5000,
      max_job_names  TYPE i VALUE 20000,
      max_agg_rows   TYPE i VALUE 5000,
      "! A claimed alert not completed after this many minutes is stuck (alert health)
      alert_claim_min TYPE i VALUE 30,
    END OF gc_param_default.

  "! Parameters (ZCA_PARAM) of the health check engine and of its row caps
  CONSTANTS:
    BEGIN OF gc_param,
      watch_pe_areas TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_WATCH_PE_AREAS',
      max_age_hours  TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_MAX_AGE_HOURS',
      timeout_sec    TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_TIMEOUT_SEC',
      lookback       TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_LOOKBACK_RUNS',
      top_n          TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_TOP_N',
      mail_route     TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_MAIL_ROUTE',
      mail_template  TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_MAIL_TEMPLATE',
      green_min      TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_SCORE_GREEN_MIN',
      amber_min      TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_SCORE_AMBER_MIN',
      weight_high    TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_WEIGHT_H',
      weight_medium  TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_WEIGHT_M',
      weight_low     TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_WEIGHT_L',
      max_run_min    TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_MAX_RUN_MIN',
      flat_tol_pct   TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_FLAT_TOL_PCT',
      max_job_rows   TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_MAX_JOB_ROWS',
      max_job_names  TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_MAX_JOB_NAMES',
      max_agg_rows   TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_MAX_AGG_ROWS',
      alert_claim_min TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_ALERT_CLAIM_MIN',
    END OF gc_param.

  "! Health check dashboard (CDS, docs/Dashboard_Health_Check.md): runs, findings and metrics of
  "! the last WINDOW_DAYS days (dats_add_days -31 in ZR_CD_HckRun, ZI_CD_HckFinding,
  "! ZI_CD_HckMetricBase; compared by the portable check cds_abap_parity)
  CONSTANTS:
    BEGIN OF gc_dashboard,
      window_days TYPE i VALUE 31,
    END OF gc_dashboard.

  "! Message numbers (class ZCD_OPS) of this area's user-facing texts
  CONSTANTS:
    BEGIN OF gc_msg,
      cheque_status_is_not_allowe TYPE zif_ca_ops_types=>ty_msgno VALUE '319',
      table_has_no_configuration  TYPE zif_ca_ops_types=>ty_msgno VALUE '324',
      reconciliation_key_has_tota TYPE zif_ca_ops_types=>ty_msgno VALUE '325',
      payment_request_is_cancelle TYPE zif_ca_ops_types=>ty_msgno VALUE '326',
      payment_request_failed_with TYPE zif_ca_ops_types=>ty_msgno VALUE '327',
      job_cancelled_started       TYPE zif_ca_ops_types=>ty_msgno VALUE '328',
      job_active_for_min_limit    TYPE zif_ca_ops_types=>ty_msgno VALUE '329',
      job_planned_has_not_started TYPE zif_ca_ops_types=>ty_msgno VALUE '330',
      cycle_step                  TYPE zif_ca_ops_types=>ty_msgno VALUE '331',
      after_min_max               TYPE zif_ca_ops_types=>ty_msgno VALUE '332',
      in_min_max                  TYPE zif_ca_ops_types=>ty_msgno VALUE '333',
      blocked_by_predecessor      TYPE zif_ca_ops_types=>ty_msgno VALUE '334',
      check_ran_ms_timeout_s      TYPE zif_ca_ops_types=>ty_msgno VALUE '335',
      health_score_100_red_amber  TYPE zif_ca_ops_types=>ty_msgno VALUE '336',
      suppressed_until_by         TYPE zif_ca_ops_types=>ty_msgno VALUE '337',
      config_drift                TYPE zif_ca_ops_types=>ty_msgno VALUE '338',
      html_report_meta            TYPE zif_ca_ops_types=>ty_msgno VALUE '339',
      html_score_counts           TYPE zif_ca_ops_types=>ty_msgno VALUE '340',
      mail_subject_1              TYPE zif_ca_ops_types=>ty_msgno VALUE '341',
      mail_subject_2              TYPE zif_ca_ops_types=>ty_msgno VALUE '342',
      stale_age                   TYPE zif_ca_ops_types=>ty_msgno VALUE '343',
      no_job_cycle                TYPE zif_ca_ops_types=>ty_msgno VALUE '347',
      summary_ok                  TYPE zif_ca_ops_types=>ty_msgno VALUE '348',
      summary_more                TYPE zif_ca_ops_types=>ty_msgno VALUE '349',
      self_check_text             TYPE zif_ca_ops_types=>ty_msgno VALUE '350',
      area_never_ran              TYPE zif_ca_ops_types=>ty_msgno VALUE '351',
      area_last_ran               TYPE zif_ca_ops_types=>ty_msgno VALUE '352',
      report_list_header          TYPE zif_ca_ops_types=>ty_msgno VALUE '356',
      report_category             TYPE zif_ca_ops_types=>ty_msgno VALUE '357',
      report_area                 TYPE zif_ca_ops_types=>ty_msgno VALUE '358',
      report_last_run             TYPE zif_ca_ops_types=>ty_msgno VALUE '359',
      area_runs_hung              TYPE zif_ca_ops_types=>ty_msgno VALUE '360',
      no_business_checks          TYPE zif_ca_ops_types=>ty_msgno VALUE '361',
      config_check_text           TYPE zif_ca_ops_types=>ty_msgno VALUE '362',
      step_retried                TYPE zif_ca_ops_types=>ty_msgno VALUE '363',
      step_started_late           TYPE zif_ca_ops_types=>ty_msgno VALUE '364',
      job_read_capped             TYPE zif_ca_ops_types=>ty_msgno VALUE '365',
      gl_gaps_total               TYPE zif_ca_ops_types=>ty_msgno VALUE '366',
      baseline_outdated           TYPE zif_ca_ops_types=>ty_msgno VALUE '367',
      budget_exhausted            TYPE zif_ca_ops_types=>ty_msgno VALUE '369',
      baseline_warmup             TYPE zif_ca_ops_types=>ty_msgno VALUE '370',
      step_pattern_invalid        TYPE zif_ca_ops_types=>ty_msgno VALUE '371',
      suppression_invalid         TYPE zif_ca_ops_types=>ty_msgno VALUE '372',
      "! Scope of a run in ZCD_HCK_RESULT-RUN_SCOPE (variant and the selection ranges)
      run_scope                   TYPE zif_ca_ops_types=>ty_msgno VALUE '300',
      "! Detail line of every finding: health check &1 (category &2, priority &3): &4 (alert e-mail context)
      check_context               TYPE zif_ca_ops_types=>ty_msgno VALUE '839',
    END OF gc_msg.

  "! Usage of a bank code role, key USAGE of the customer posting area ZBTR (was ZCD_HCK_BTCROLE-USAGE,
  "! table consolidation 2026-11-08): the role of a bank code in the payment
  "! lifecycle (A_INFLIGHT; SCOPE = flow + method class) or in a reconciliation set (A_RECON_3WAY;
  "! SCOPE = set id, was ZCD_HCK_RCBTC). Each reader reads only its own usage.
  TYPES ty_btc_usage TYPE c LENGTH 10.
  CONSTANTS:
    BEGIN OF gc_btc_usage,
      lifecycle TYPE ty_btc_usage VALUE 'LIFECYCLE',
      recon     TYPE ty_btc_usage VALUE 'RECON',
    END OF gc_btc_usage.

ENDINTERFACE.
