*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_xrun_types.intf.abap
*& Purpose:
*& Types and constants of the expected runs (docs/EXPECTED_RUNS_AND_
*& MASS_ACTIVITIES.md, build P): the plan of an external scheduler - an
*& expected job with its run ID, planned start, late limit, predecessor
*& and the state the scheduler reports (planned, started, ended OK, ended
*& not OK, held, not started) - as every expected-run source returns it
*& (ZIF_CA_OPS_EXPECTED_RUN_SRC), the verdicts of the comparison with the
*& SAP background jobs (never started, late, waiting for a predecessor,
*& held), the stages, check codes, parameters XRUN_* and messages
*& 600-614 of the check ZCL_CA_OPS_CHK_XRUN. No logic.
*& Modification log:
*& 2026-11-16 | Initial version (build P: expected runs from the scheduler).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - expected runs types</p>
"! Times of an expected run are system date and time of the SAP server, as TBTCO (the job monitor compares them with
"! the server clock); a source that receives another time zone converts before it returns its runs.
INTERFACE zif_ca_ops_xrun_types
  PUBLIC.

  TYPES ty_source_id   TYPE zif_ca_ops_exc_contract=>ty_source_id.
  TYPES ty_run_id      TYPE c LENGTH 40.
  TYPES ty_sched_state TYPE c LENGTH 12.
  TYPES ty_verdict     TYPE c LENGTH 12.
  TYPES ty_plan_days   TYPE c LENGTH 7.

  "! State of a run at the external scheduler (blank = the source does not know it, e.g. a configured plan)
  CONSTANTS:
    BEGIN OF gc_state,
      planned      TYPE ty_sched_state VALUE 'PLANNED',
      started      TYPE ty_sched_state VALUE 'STARTED',
      ended_ok     TYPE ty_sched_state VALUE 'ENDED_OK',
      ended_not_ok TYPE ty_sched_state VALUE 'ENDED_NOK',
      held         TYPE ty_sched_state VALUE 'HELD',
      not_started  TYPE ty_sched_state VALUE 'NOT_STARTED',
    END OF gc_state.

  "! Verdict of the comparison of one expected run with SAP's jobs (ZCL_CA_OPS_XRUN_MONITOR)
  CONSTANTS:
    BEGIN OF gc_verdict,
      "! Started in SAP in time
      ok            TYPE ty_verdict VALUE 'OK',
      "! Not due yet (planned start + late minutes not passed): no verdict
      pending       TYPE ty_verdict VALUE 'PENDING',
      started_late  TYPE ty_verdict VALUE 'LATE',
      never_started TYPE ty_verdict VALUE 'NEVER',
      pred_open     TYPE ty_verdict VALUE 'PRED_OPEN',
      held          TYPE ty_verdict VALUE 'HELD',
    END OF gc_verdict.

  "! Stage where the run stopped (RULE_ID and STAGE of the finding)
  CONSTANTS:
    BEGIN OF gc_stage,
      "! The scheduler never started the run (planned / not started / no state)
      scheduler  TYPE zif_ca_ops_types=>ty_rule_id VALUE 'SCHEDULER',
      "! The scheduler started or ended the run, SAP has no job: it failed before SAP
      handover   TYPE zif_ca_ops_types=>ty_rule_id VALUE 'HANDOVER',
      "! The SAP job is released or scheduled, it did not start
      sap_queue  TYPE zif_ca_ops_types=>ty_rule_id VALUE 'SAP_QUEUE',
      "! The predecessor has not ended successfully
      predecessor TYPE zif_ca_ops_types=>ty_rule_id VALUE 'WAIT_PRED',
      "! The SAP job started after the late limit
      late_start TYPE zif_ca_ops_types=>ty_rule_id VALUE 'LATE_START',
      "! The source itself (stale, not readable, not usable)
      source     TYPE zif_ca_ops_types=>ty_rule_id VALUE 'SOURCE',
    END OF gc_stage.

  "! Object type of the findings (object key = folder / job / planned date, or the source)
  CONSTANTS gc_object_type TYPE zif_ca_ops_types=>ty_object_type VALUE 'XRUN'.
  "! Separator of the parts of an object key and of the plan days (X = runs on that weekday)
  CONSTANTS gc_separator TYPE string VALUE `/`.
  CONSTANTS gc_day_runs TYPE c LENGTH 1 VALUE 'X'.

  "! Check codes of ZCL_CA_OPS_CHK_XRUN
  CONSTANTS:
    BEGIN OF gc_code,
      "! Expected, due and no SAP job started (stage SCHEDULER, HANDOVER or SAP_QUEUE)
      never_started  TYPE zif_ca_ops_types=>ty_check_code VALUE 'XRUN_NEVER_STARTED',
      "! Due, not started, and its predecessor has not ended successfully
      pred_open      TYPE zif_ca_ops_types=>ty_check_code VALUE 'XRUN_PRED_NOT_FINISHED',
      "! Held at the scheduler after its planned start
      held           TYPE zif_ca_ops_types=>ty_check_code VALUE 'XRUN_HELD',
      "! The SAP job started after the late limit
      started_late   TYPE zif_ca_ops_types=>ty_check_code VALUE 'XRUN_STARTED_LATE',
      "! The scheduler source is older than its limit: the plan may be outdated (evaluation STALE)
      source_stale   TYPE zif_ca_ops_types=>ty_check_code VALUE 'XRUN_SOURCE_STALE',
      "! The scheduler source could not be read (evaluation not evaluated, the check partial)
      source_failed  TYPE zif_ca_ops_types=>ty_check_code VALUE 'XRUN_SOURCE_FAILED',
      "! A source class, a pattern or a plan row is not usable (reported and left out, never "no plan")
      config_invalid TYPE zif_ca_ops_types=>ty_check_code VALUE 'XRUN_CONFIG_INVALID',
      "! The read of SAP jobs reached its cap (the check partial)
      capped         TYPE zif_ca_ops_types=>ty_check_code VALUE 'XRUN_READ_CAPPED',
    END OF gc_code.

  "! Plug-in interfaces (checked by RTTI before creation, ZCL_CA_OPS_FACTORY=>GET_PLUGIN)
  CONSTANTS:
    BEGIN OF gc_plugin_intf,
      source   TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZIF_CA_OPS_EXPECTED_RUN_SRC',
      calendar TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZIF_CA_OPS_XRUN_CALENDAR',
    END OF gc_plugin_intf.

  "! Parameters (area CA_OPS, prefix XRUN_; config/param_definitions.csv, docs/PARAMETERS.md)
  CONSTANTS:
    BEGIN OF gc_param,
      "! Expected-run sources in order (ZIF_CA_OPS_EXPECTED_RUN_SRC); a run of an earlier source wins
      sources      TYPE zif_ca_ops_types=>ty_param_name VALUE 'XRUN_SOURCES',
      "! Business calendar of the configured plan (ZIF_CA_OPS_XRUN_CALENDAR; blank = weekdays only)
      calendar     TYPE zif_ca_ops_types=>ty_param_name VALUE 'XRUN_CALENDAR_CLASS',
      "! Days of plan read back (0 = today only)
      lookback     TYPE zif_ca_ops_types=>ty_param_name VALUE 'XRUN_LOOKBACK_DAYS',
      "! Minutes after the planned start until a run is late / not started (a row's LATE_MIN wins)
      late_min     TYPE zif_ca_ops_types=>ty_param_name VALUE 'XRUN_LATE_MIN',
      "! Minutes before the planned start an SAP job still counts as the run (started early)
      early_min    TYPE zif_ca_ops_types=>ty_param_name VALUE 'XRUN_EARLY_MIN',
      "! Minutes after the planned start an SAP job still counts as the run (the next run's job is not this one)
      match_min    TYPE zif_ca_ops_types=>ty_param_name VALUE 'XRUN_MATCH_MIN',
      "! Minutes after which a scheduler source is stale (its own limit wins)
      stale_min    TYPE zif_ca_ops_types=>ty_param_name VALUE 'XRUN_SOURCE_STALE_MIN',
      "! SAP jobs read per run and kind (running / waiting)
      max_jobs     TYPE zif_ca_ops_types=>ty_param_name VALUE 'XRUN_MAX_JOBS',
      "! Statuses of an SAP job that waits to start (released, ready, scheduled)
      waiting      TYPE zif_ca_ops_types=>ty_param_name VALUE 'XRUN_WAITING_STATUSES',
    END OF gc_param.

  "! Code defaults (equal to the definition defaults)
  CONSTANTS:
    BEGIN OF gc_param_default,
      sources   TYPE string VALUE `ZCL_CA_OPS_XRUN_SRC_JOBSCH`,
      lookback  TYPE i VALUE 1,
      late_min  TYPE i VALUE 30,
      early_min TYPE i VALUE 60,
      match_min TYPE i VALUE 720,
      stale_min TYPE i VALUE 60,
      max_jobs  TYPE i VALUE 5000,
      waiting   TYPE string VALUE `P,S,Y`,
    END OF gc_param_default.

  "! Ceilings of the parameters (a maintained value above is cut to them)
  CONSTANTS:
    BEGIN OF gc_ceiling,
      lookback TYPE i VALUE 31,
      max_jobs TYPE i VALUE 50000,
      minutes  TYPE i VALUE 10080,
    END OF gc_ceiling.

  "! Messages of the expected runs (message class ZCA_OPS, 600-614)
  CONSTANTS:
    BEGIN OF gc_msg,
      never_started TYPE zif_ca_ops_types=>ty_msgno VALUE '600',
      handover      TYPE zif_ca_ops_types=>ty_msgno VALUE '601',
      sap_queue     TYPE zif_ca_ops_types=>ty_msgno VALUE '602',
      pred_open     TYPE zif_ca_ops_types=>ty_msgno VALUE '603',
      held          TYPE zif_ca_ops_types=>ty_msgno VALUE '604',
      started_late  TYPE zif_ca_ops_types=>ty_msgno VALUE '605',
      source_stale  TYPE zif_ca_ops_types=>ty_msgno VALUE '606',
      source_failed TYPE zif_ca_ops_types=>ty_msgno VALUE '607',
      config        TYPE zif_ca_ops_types=>ty_msgno VALUE '608',
      capped        TYPE zif_ca_ops_types=>ty_msgno VALUE '609',
      calendar      TYPE zif_ca_ops_types=>ty_msgno VALUE '610',
      ctx_sched     TYPE zif_ca_ops_types=>ty_msgno VALUE '611',
      ctx_job       TYPE zif_ca_ops_types=>ty_msgno VALUE '612',
      ctx_pred      TYPE zif_ca_ops_types=>ty_msgno VALUE '613',
      plan_days     TYPE zif_ca_ops_types=>ty_msgno VALUE '614',
    END OF gc_msg.

  "! One expected run of the scheduler's plan
  TYPES:
    BEGIN OF ty_expected,
      "! Source that named it (its ID; also the evidence row's source)
      source_id    TYPE ty_source_id,
      "! The scheduler's own run / order ID (blank = folder, job and planned start identify the run)
      run_id       TYPE ty_run_id,
      sched_folder TYPE zif_ca_ops_job_types=>ty_sched_folder,
      sched_job    TYPE zif_ca_ops_job_types=>ty_sched_job,
      "! SAP job names the run starts (PCRE, complete name, case ignored); blank = the pattern of the scheduler row
      "! of the same folder and job (ZCA_OPS_JOBSCH)
      sap_pattern  TYPE zif_ca_ops_types=>ty_object_key,
      plan_date    TYPE d,
      plan_time    TYPE t,
      "! Minutes after the planned start until the run is late / not started (0 = XRUN_LATE_MIN)
      late_min     TYPE i,
      "! Predecessor that must have ended successfully first (blank = none)
      pred_folder  TYPE zif_ca_ops_job_types=>ty_sched_folder,
      pred_job     TYPE zif_ca_ops_job_types=>ty_sched_job,
      "! State at the scheduler (GC_STATE; blank = not known) and when the scheduler recorded it (UTC)
      sched_state  TYPE ty_sched_state,
      state_at     TYPE timestampl,
      criticality  TYPE zif_ca_ops_job_types=>ty_criticality,
    END OF ty_expected.
  TYPES tt_expected TYPE STANDARD TABLE OF ty_expected WITH EMPTY KEY.

  "! A day of the plan on which a run is not expected (business calendar) or cannot be told (calendar unreadable)
  TYPES:
    BEGIN OF ty_plan_day,
      sched_folder TYPE zif_ca_ops_job_types=>ty_sched_folder,
      sched_job    TYPE zif_ca_ops_job_types=>ty_sched_job,
      plan_date    TYPE d,
      calendar_id  TYPE zif_ca_ops_exc_contract=>ty_calendar_id,
      reason       TYPE zif_ca_ops_types=>ty_message,
    END OF ty_plan_day.
  TYPES tt_plan_day TYPE STANDARD TABLE OF ty_plan_day WITH EMPTY KEY.

  "! What a source is asked for: the planned days and the most runs
  TYPES:
    BEGIN OF ty_request,
      from_date TYPE d,
      to_date   TYPE d,
      max       TYPE i,
      "! Now of the run (UTC) - a configured plan is as fresh as the read
      now       TYPE timestampl,
    END OF ty_request.

  "! What a source returns
  TYPES:
    BEGIN OF ty_plan,
      runs         TYPE tt_expected,
      "! Days the business calendar does not expect a run (holidays)
      not_expected TYPE tt_plan_day,
      "! Days whose expectation cannot be told (calendar not readable) - never "not expected"
      unknown      TYPE tt_plan_day,
      "! Rows of the source that are not usable (plan days, pattern) - reported, left out
      invalid      TYPE tt_plan_day,
      "! Newest record of the source (UTC; its freshness) and its own stale limit in minutes (0 = parameter)
      newest_at    TYPE timestampl,
      stale_min    TYPE i,
      "! X = the source returned less than its plan (cap reached)
      partial      TYPE abap_bool,
    END OF ty_plan.

  "! Verdict of one expected run with the SAP job that matched it (blank = none)
  TYPES:
    BEGIN OF ty_result,
      run           TYPE ty_expected,
      verdict       TYPE ty_verdict,
      stage         TYPE zif_ca_ops_types=>ty_rule_id,
      "! The SAP job of the run (started one first, else a waiting one) and the predecessor's
      job           TYPE zif_ca_ops_job_types=>ty_job,
      pred          TYPE ty_expected,
      pred_job      TYPE zif_ca_ops_job_types=>ty_job,
      "! Due point (planned start + late minutes) and the minutes the start was late
      due_date      TYPE d,
      due_time      TYPE t,
      late_minutes  TYPE i,
    END OF ty_result.
  TYPES tt_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY.

  "! Settings of one comparison (parameters resolved by the check)
  TYPES:
    BEGIN OF ty_config,
      late_min  TYPE i,
      early_min TYPE i,
      match_min TYPE i,
      max_jobs  TYPE i,
      waiting   TYPE zif_ca_ops_types=>tt_param_range,
    END OF ty_config.

ENDINTERFACE.
