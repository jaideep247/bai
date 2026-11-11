*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_job_dao.intf.abap
*& Purpose:
*& Data access of the SAP job monitor: reads of the SAP job tables TBTCO /
*& TBTCP and of the application log headers BALHDR (read only, jobs of the
*& logon client, bounded by status, a date / time window and a row cap),
*& and the monitor's own tables - evidence ZCA_OPS_JOB, _JOBSTEP, _JOBMSG,
*& _JOBALOG, _JOBBO, watermark ZCA_OPS_JOBWM, external scheduler mapping
*& ZCA_OPS_JOBSCH. SAVE writes the evidence and the watermark without a
*& commit (the generic runner commits the run's LUW).
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - SAP job monitor data access</p>
"! Never writes a SAP table: no job is changed, released, cancelled or restarted.
INTERFACE zif_ca_ops_job_dao
  PUBLIC.

  "! Cancelled jobs (status A) that ended in the window, oldest end first, at most iv_max
  METHODS aborted_jobs
    IMPORTING
      is_window      TYPE zif_ca_ops_job_types=>ty_window
      iv_max         TYPE i
    RETURNING
      VALUE(rt_jobs) TYPE zif_ca_ops_job_types=>tt_job.

  "! Finished jobs (status F) that ended in the window and have a step of one of the programs,
  "! oldest end first, at most iv_max; no program = nothing read
  METHODS finished_jobs
    IMPORTING
      is_window      TYPE zif_ca_ops_job_types=>ty_window
      it_programs    TYPE zif_ca_ops_types=>tt_param_range
      iv_max         TYPE i
    RETURNING
      VALUE(rt_jobs) TYPE zif_ca_ops_job_types=>tt_job.

  "! Active jobs (R, Z) started before the point, oldest start first, at most iv_max
  METHODS active_jobs
    IMPORTING
      is_started_before TYPE zif_ca_ops_job_types=>ty_point
      iv_max            TYPE i
    RETURNING
      VALUE(rt_jobs)    TYPE zif_ca_ops_job_types=>tt_job.

  "! Jobs in one of the statuses with a planned start before the point (not event-triggered),
  "! oldest planned start first, at most iv_max
  METHODS waiting_jobs
    IMPORTING
      it_statuses       TYPE zif_ca_ops_types=>tt_param_range
      is_planned_before TYPE zif_ca_ops_job_types=>ty_point
      iv_max            TYPE i
    RETURNING
      VALUE(rt_jobs)    TYPE zif_ca_ops_job_types=>tt_job.

  "! Jobs by key (any status)
  METHODS jobs
    IMPORTING
      it_keys        TYPE zif_ca_ops_job_types=>tt_job_key
    RETURNING
      VALUE(rt_jobs) TYPE zif_ca_ops_job_types=>tt_job.

  "! Jobs created (scheduled) in the window by one of the users, at most iv_max (children candidates)
  METHODS jobs_created
    IMPORTING
      is_window      TYPE zif_ca_ops_job_types=>ty_window
      it_users       TYPE zif_ca_ops_types=>tt_param_range
      iv_max         TYPE i
    RETURNING
      VALUE(rt_jobs) TYPE zif_ca_ops_job_types=>tt_job.

  "! Jobs that ran (started, and ended or still active) at some point of the window and have a step of
  "! one of the programs (blank = any), at most iv_max (parent candidates)
  METHODS jobs_running
    IMPORTING
      is_window      TYPE zif_ca_ops_job_types=>ty_window
      it_programs    TYPE zif_ca_ops_types=>tt_param_range
      iv_max         TYPE i
    RETURNING
      VALUE(rt_jobs) TYPE zif_ca_ops_job_types=>tt_job.

  "! Jobs waiting for / started by one of the events with exactly that event parameter
  METHODS jobs_by_event
    IMPORTING
      it_events      TYPE zif_ca_ops_job_types=>tt_job
      iv_max         TYPE i
    RETURNING
      VALUE(rt_jobs) TYPE zif_ca_ops_job_types=>tt_job.

  "! Steps of the jobs (TBTCP), by job and step
  METHODS steps
    IMPORTING
      it_keys         TYPE zif_ca_ops_job_types=>tt_job_key
    RETURNING
      VALUE(rt_steps) TYPE zif_ca_ops_job_types=>tt_step.

  "! Application log headers (BALHDR) created in the window by one of the users and programs, at
  "! most iv_max - matched to a job by the caller (user, program, run time)
  METHODS applogs
    IMPORTING
      is_window         TYPE zif_ca_ops_job_types=>ty_window
      it_users          TYPE zif_ca_ops_types=>tt_param_range
      it_programs       TYPE zif_ca_ops_types=>tt_param_range
      iv_max            TYPE i
    RETURNING
      VALUE(rt_applogs) TYPE zif_ca_ops_job_types=>tt_applog.

  "! Parent of each job from two TBTCO fields named by configuration (checked against the runtime
  "! DDIC by the caller before; dynamic field list built only from those two names)
  METHODS parents_by_fields
    IMPORTING
      it_keys         TYPE zif_ca_ops_job_types=>tt_job_key
      iv_name_field   TYPE zif_ca_ops_job_types=>ty_fieldname
      iv_count_field  TYPE zif_ca_ops_job_types=>ty_fieldname
    RETURNING
      VALUE(rt_links) TYPE zif_ca_ops_job_types=>tt_link
    RAISING
      zcx_ca_ops_error.

  "! Children of each job from the same two fields, at most iv_max
  METHODS children_by_fields
    IMPORTING
      it_keys         TYPE zif_ca_ops_job_types=>tt_job_key
      iv_name_field   TYPE zif_ca_ops_job_types=>ty_fieldname
      iv_count_field  TYPE zif_ca_ops_job_types=>ty_fieldname
      iv_max          TYPE i
    RETURNING
      VALUE(rt_links) TYPE zif_ca_ops_job_types=>tt_link
    RAISING
      zcx_ca_ops_error.

  "! Jobs of the list already kept as a failure (role F) - the overlap is never reported twice
  "! @parameter iv_failures_only | X = kept with a failure code (cancelled, child failed, log error);
  "! blank = kept with any finding (also long-running / not started)
  METHODS reported
    IMPORTING
      it_keys          TYPE zif_ca_ops_job_types=>tt_job_key
      iv_failures_only TYPE abap_bool DEFAULT abap_true
    RETURNING
      VALUE(rt_keys) TYPE zif_ca_ops_job_types=>tt_job_key.

  "! Active jobs of the external scheduler and their SAP job name patterns (ZCA_OPS_JOBSCH), in sequence
  METHODS scheduler_jobs
    RETURNING
      VALUE(rt_sched) TYPE zif_ca_ops_job_types=>tt_sched.

  "! Watermark of an area and check (blank point = none yet)
  METHODS watermark
    IMPORTING
      iv_area             TYPE zif_ca_ops_types=>ty_area
      iv_check_id         TYPE zif_ca_ops_chk_types=>ty_check_id
    RETURNING
      VALUE(rs_watermark) TYPE zif_ca_ops_job_types=>ty_watermark.

  "! Write the evidence (insert or replace by key) and the watermark - no commit
  "! @raising zcx_ca_ops_error | 129 a row could not be written
  METHODS save
    IMPORTING
      is_evidence  TYPE zif_ca_ops_job_types=>ty_evidence_set
      is_watermark TYPE zif_ca_ops_job_types=>ty_watermark OPTIONAL
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
