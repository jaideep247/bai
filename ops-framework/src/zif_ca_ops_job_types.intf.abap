*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_job_types.intf.abap
*& Purpose:
*& Types and constants of the SAP job monitor of the operations framework
*& (docs/JOB_MONITORING.md): jobs of the client read from TBTCO / TBTCP
*& (read only), job log lines (BP_JOBLOG_READ), linked application logs
*& (BALHDR), parent / child links with the resolver and evidence quality
*& (C confirmed by key, P probable by heuristic), business objects of the
*& enrichers, claims of other monitors (de-duplication), the evidence kept
*& in the framework tables ZCA_OPS_JOB, _JOBSTEP, _JOBMSG, _JOBALOG,
*& _JOBBO, the watermark ZCA_OPS_JOBWM and the external scheduler mapping
*& ZCA_OPS_JOBSCH; check codes, parameters (prefix JOB_, area CA_OPS)
*& and messages 110-139 of ZCA_OPS. No logic.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor: failures, parent / child links, evidence chain).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - SAP job monitor types</p>
"! TBTCO is cross-client: every read filters AUTHCKMAN = the logon client. Times of TBTCO are
"! server date and time; the monitor compares them with the server clock (SY-DATUM / SY-UZEIT).
INTERFACE zif_ca_ops_job_types
  PUBLIC.

  TYPES ty_status       TYPE c LENGTH 1.
  TYPES ty_resolver_id  TYPE c LENGTH 10.
  TYPES ty_quality      TYPE c LENGTH 1.
  TYPES ty_role         TYPE c LENGTH 1.
  TYPES ty_server       TYPE c LENGTH 20.
  TYPES ty_eventid      TYPE c LENGTH 32.
  TYPES ty_eventparm    TYPE c LENGTH 64.
  TYPES ty_progname     TYPE c LENGTH 40.
  TYPES ty_variant      TYPE c LENGTH 14.
  TYPES ty_spool_id     TYPE n LENGTH 10.
  TYPES ty_log_text     TYPE c LENGTH 255.
  TYPES ty_lognumber    TYPE c LENGTH 20.
  TYPES ty_log_object   TYPE c LENGTH 20.
  TYPES ty_extnumber    TYPE c LENGTH 100.
  TYPES ty_bo_type      TYPE c LENGTH 20.
  TYPES ty_bo_key       TYPE c LENGTH 70.
  TYPES ty_bo_label     TYPE c LENGTH 60.
  TYPES ty_sched_folder   TYPE c LENGTH 40.
  TYPES ty_sched_job      TYPE c LENGTH 64.
  TYPES ty_criticality  TYPE c LENGTH 1.
  TYPES ty_fieldname    TYPE c LENGTH 30.

  "! TBTCO-STATUS (VERIFY-SE11 V58: values of the 7.58 job status, as the health check reads them)
  CONSTANTS:
    BEGIN OF gc_status,
      aborted    TYPE ty_status VALUE 'A',
      finished   TYPE ty_status VALUE 'F',
      running    TYPE ty_status VALUE 'R',
      ready      TYPE ty_status VALUE 'Y',
      released   TYPE ty_status VALUE 'S',
      scheduled  TYPE ty_status VALUE 'P',
      put_active TYPE ty_status VALUE 'Z',
    END OF gc_status.

  "! Evidence quality of a link or a business object: C = confirmed by a key (a field, an event
  "! parameter, a job log line naming name and count), P = probable (heuristic, name pattern, time window)
  CONSTANTS:
    BEGIN OF gc_quality,
      confirmed TYPE ty_quality VALUE 'C',
      probable  TYPE ty_quality VALUE 'P',
    END OF gc_quality.

  "! Role of a job in the evidence: F = a failure with its own finding, A = an ancestor (parent, root),
  "! C = a child of a failing job's parent kept as context (status at detection)
  CONSTANTS:
    BEGIN OF gc_role,
      failed   TYPE ty_role VALUE 'F',
      ancestor TYPE ty_role VALUE 'A',
      child    TYPE ty_role VALUE 'C',
    END OF gc_role.

  "! Resolver IDs of the delivered resolvers (a consumer's resolver names its own)
  CONSTANTS:
    BEGIN OF gc_resolver,
      field     TYPE ty_resolver_id VALUE 'FIELD',
      event     TYPE ty_resolver_id VALUE 'EVENT',
      job_log   TYPE ty_resolver_id VALUE 'JOBLOG',
      heuristic TYPE ty_resolver_id VALUE 'HEURISTIC',
    END OF gc_resolver.

  "! Plug-in interfaces (checked by RTTI before creation, ZCL_CA_OPS_FACTORY=>GET_PLUGIN)
  CONSTANTS:
    BEGIN OF gc_plugin_intf,
      resolver TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZIF_CA_OPS_JOB_RESOLVER',
      enricher TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZIF_CA_OPS_JOB_ENRICHER',
      claim    TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZIF_CA_OPS_JOB_CLAIM',
    END OF gc_plugin_intf.

  "! Object type and rule ID of the monitor's findings (object key = job name / job count)
  CONSTANTS gc_object_type TYPE zif_ca_ops_types=>ty_object_type VALUE 'JOB'.
  CONSTANTS gc_rule_id TYPE zif_ca_ops_types=>ty_rule_id VALUE 'JOBMON'.
  "! Separator of job name and job count in the object key
  CONSTANTS gc_key_separator TYPE string VALUE `/`.

  "! Check codes of the job monitor
  CONSTANTS:
    BEGIN OF gc_code,
      "! Cancelled job (TBTCO status A) without a linked ancestor that finished or still runs
      aborted       TYPE zif_ca_ops_types=>ty_check_code VALUE 'JOB_ABORTED',
      "! A child / descendant failed while its root (what the scheduler sees) did not abort
      child_failed  TYPE zif_ca_ops_types=>ty_check_code VALUE 'JOB_CHILD_FAILED',
      "! Finished job of a watched program whose job log holds error / abort messages
      log_error     TYPE zif_ca_ops_types=>ty_check_code VALUE 'JOB_LOG_ERROR',
      "! Active far beyond JOB_LONG_RUNNING_MIN (long-running or orphaned)
      long_running  TYPE zif_ca_ops_types=>ty_check_code VALUE 'JOB_LONG_RUNNING',
      "! Released / ready, not started JOB_NOT_STARTED_MIN after its planned start
      not_started   TYPE zif_ca_ops_types=>ty_check_code VALUE 'JOB_NOT_STARTED',
      "! A read reached its cap: the window continues in the next run
      read_capped   TYPE zif_ca_ops_types=>ty_check_code VALUE 'JOB_READ_CAPPED',
      "! A parameter of the monitor is not usable (pattern, field, class)
      config        TYPE zif_ca_ops_types=>ty_check_code VALUE 'JOB_CONFIG_INVALID',
      "! A resolver, enricher or claim plug-in raised: its links / objects are missing
      plugin_failed TYPE zif_ca_ops_types=>ty_check_code VALUE 'JOB_PLUGIN_FAILED',
    END OF gc_code.

  "! Parameters of the job monitor (area CA_OPS, prefix JOB_; docs/PARAMETERS.md)
  CONSTANTS:
    BEGIN OF gc_param,
      "! Minutes read back on the first run (no watermark yet) [60]
      lookback_min     TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_LOOKBACK_MIN',
      "! Minutes re-read before the watermark (late end times); re-read jobs are not reported twice [10]
      overlap_min      TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_OVERLAP_MIN',
      "! Jobs read per run and kind (cancelled, finished of watched programs, active, waiting) [2000]
      max_jobs         TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_MAX_JOBS',
      "! Job logs read per run (failed and watched jobs, resolver candidates) [50]
      max_log_reads    TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_MAX_LOG_READS',
      "! Error / abort messages of a job log kept as evidence per job [20]
      max_messages     TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_MAX_MESSAGES',
      "! Ancestors followed upwards from a failed job [3]
      max_depth        TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_MAX_DEPTH',
      "! Children of a failing job's parent kept as context [50]
      max_children     TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_MAX_CHILDREN',
      "! Application logs linked per job [20]
      max_applogs      TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_MAX_APPLOGS',
      "! Job names never reported (PCRE list, complete name, case ignored) - noise
      exclude          TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_EXCLUDE_PCRE',
      "! Programs (exact names) whose finished jobs have their job log checked for errors
      log_programs     TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_LOG_PROGRAMS',
      "! Message types of a job log line that count as an error [E,A,X]
      log_error_types  TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_LOG_ERROR_TYPES',
      "! Minutes a job may be active before it is long-running [240]
      long_running_min TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_LONG_RUNNING_MIN',
      "! Minutes after the planned start a released job may wait [30]
      not_started_min  TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_NOT_STARTED_MIN',
      "! Statuses of a job that waits to start [S,Y]
      waiting_statuses TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_WAITING_STATUSES',
      "! Parent / child resolvers in order (classes implementing ZIF_CA_OPS_JOB_RESOLVER)
      resolvers        TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_RESOLVERS',
      "! Enrichers (business context; ZIF_CA_OPS_JOB_ENRICHER) - blank = none
      enrichers        TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_ENRICHERS',
      "! Claims of other monitors (ZIF_CA_OPS_JOB_CLAIM) - blank = none
      claims           TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_CLAIMS',
      "! Resolver FIELD: TBTCO fields of the parent job name and count (two names; blank = off)
      parent_fields    TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_PARENT_FIELDS',
      "! Resolver EVENT: events whose EVENTPARM is the predecessor's job name (32) + count (8)
      event_ids        TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_EVENT_IDS',
      "! Resolver JOBLOG: messages (MSGID/MSGNO) of a job log that announce a released job
      child_msg_ids    TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_CHILD_MSG_IDS',
      "! Resolver JOBLOG: PCRE on the text of such a line, group 1 = job name, group 2 = job count
      child_msg_pcre   TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_CHILD_MSG_PCRE',
      "! Resolvers JOBLOG / HEURISTIC: programs (exact) of the jobs that may start children (blank = any)
      parent_programs  TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_PARENT_PROGRAMS',
      "! Retention of the job evidence (purge target JOB_EVIDENCE) [180]
      retention_days   TYPE zif_ca_ops_types=>ty_param_name VALUE 'RETENTION_DAYS_JOB_EVIDENCE',
    END OF gc_param.

  "! Delivered defaults of the parameters
  CONSTANTS:
    BEGIN OF gc_param_default,
      lookback_min     TYPE i VALUE 60,
      overlap_min      TYPE i VALUE 10,
      max_jobs         TYPE i VALUE 2000,
      max_log_reads    TYPE i VALUE 50,
      max_messages     TYPE i VALUE 20,
      max_depth        TYPE i VALUE 3,
      max_children     TYPE i VALUE 50,
      max_applogs      TYPE i VALUE 20,
      log_error_types  TYPE string VALUE `E,A,X`,
      long_running_min TYPE i VALUE 240,
      not_started_min  TYPE i VALUE 30,
      waiting_statuses TYPE string VALUE `S,Y`,
      "! Delivered active: the resolvers that need no confirmed configuration; FIELD and JOBLOG are added
      "! when their parameters are confirmed (VERIFY V62)
      resolvers        TYPE string VALUE `ZCL_CA_OPS_JOB_RES_EVENT,ZCL_CA_OPS_JOB_RES_HEUR`,
      "! VERIFY-SE11 V61: event of a job started after another job and the layout of its EVENTPARM
      event_ids        TYPE string VALUE `SAP_END_OF_JOB`,
      retention_days   TYPE i VALUE 180,
    END OF gc_param_default.

  "! Hard ceilings of the caps (a maintained parameter above is cut to them)
  CONSTANTS:
    BEGIN OF gc_ceiling,
      jobs      TYPE i VALUE 50000,
      log_reads TYPE i VALUE 500,
      messages  TYPE i VALUE 200,
      depth     TYPE i VALUE 10,
      children  TYPE i VALUE 1000,
      applogs   TYPE i VALUE 200,
    END OF gc_ceiling.

  "! Lengths of the predecessor key in EVENTPARM (VERIFY-SE11 V61)
  CONSTANTS:
    BEGIN OF gc_eventparm,
      name_length  TYPE i VALUE 32,
      count_length TYPE i VALUE 8,
    END OF gc_eventparm.

  "! Purge target of the evidence tables (registry ZCA_OPS_PURGE, class ZCL_CA_OPS_JOB_PURGE)
  CONSTANTS gc_purge_target TYPE zif_ca_ops_purge_target=>ty_target VALUE 'JOB_EVIDENCE'.

  "! Messages of the job monitor (message class ZCA_OPS, range 110-139)
  CONSTANTS:
    BEGIN OF gc_msg,
      aborted        TYPE zif_ca_ops_types=>ty_msgno VALUE '110',
      child_failed   TYPE zif_ca_ops_types=>ty_msgno VALUE '111',
      log_error      TYPE zif_ca_ops_types=>ty_msgno VALUE '112',
      long_running   TYPE zif_ca_ops_types=>ty_msgno VALUE '113',
      not_started    TYPE zif_ca_ops_types=>ty_msgno VALUE '114',
      claimed        TYPE zif_ca_ops_types=>ty_msgno VALUE '115',
      ctx_parent     TYPE zif_ca_ops_types=>ty_msgno VALUE '116',
      ctx_root       TYPE zif_ca_ops_types=>ty_msgno VALUE '117',
      ctx_sched        TYPE zif_ca_ops_types=>ty_msgno VALUE '118',
      ctx_step       TYPE zif_ca_ops_types=>ty_msgno VALUE '119',
      read_capped    TYPE zif_ca_ops_types=>ty_msgno VALUE '120',
      config         TYPE zif_ca_ops_types=>ty_msgno VALUE '121',
      plugin_failed  TYPE zif_ca_ops_types=>ty_msgno VALUE '122',
      log_read       TYPE zif_ca_ops_types=>ty_msgno VALUE '123',
      ctx_failed     TYPE zif_ca_ops_types=>ty_msgno VALUE '124',
      ctx_applog     TYPE zif_ca_ops_types=>ty_msgno VALUE '125',
      ctx_object     TYPE zif_ca_ops_types=>ty_msgno VALUE '126',
      field_unknown  TYPE zif_ca_ops_types=>ty_msgno VALUE '127',
      root_active    TYPE zif_ca_ops_types=>ty_msgno VALUE '128',
      save_failed    TYPE zif_ca_ops_types=>ty_msgno VALUE '129',
    END OF gc_msg.

  "! Identity of a job (TBTCO key)
  TYPES:
    BEGIN OF ty_job_key,
      jobname  TYPE btcjob,
      jobcount TYPE btcjobcnt,
    END OF ty_job_key.
  TYPES tt_job_key TYPE SORTED TABLE OF ty_job_key WITH UNIQUE KEY jobname jobcount.

  "! A job of TBTCO (read only; VERIFY-SE11 V58: fields of 7.58)
  TYPES:
    BEGIN OF ty_job,
      jobname   TYPE btcjob,
      jobcount  TYPE btcjobcnt,
      status    TYPE ty_status,
      "! Planned start
      sdlstrtdt TYPE d,
      sdlstrttm TYPE t,
      "! Created (scheduled at) - when a parent released it
      sdldate   TYPE d,
      sdltime   TYPE t,
      "! Scheduled by (the parent's step user for a child released by a program)
      sdluname  TYPE syuname,
      strtdate  TYPE d,
      strttime  TYPE t,
      enddate   TYPE d,
      endtime   TYPE t,
      "! Server the job ran on
      reaxserver TYPE ty_server,
      "! Start event and its parameter (event-triggered jobs, start after another job)
      eventid   TYPE ty_eventid,
      eventparm TYPE ty_eventparm,
    END OF ty_job.
  TYPES tt_job TYPE STANDARD TABLE OF ty_job WITH EMPTY KEY.

  "! A step of a job (TBTCP; VERIFY-SE11 V58)
  TYPES:
    BEGIN OF ty_step,
      jobname   TYPE btcjob,
      jobcount  TYPE btcjobcnt,
      stepcount TYPE i,
      progname  TYPE ty_progname,
      variant   TYPE ty_variant,
      "! User the step runs under (also the scheduler of the jobs the step releases)
      authcknam TYPE syuname,
      "! Spool list of the step (blank = none)
      listident TYPE ty_spool_id,
    END OF ty_step.
  TYPES tt_step TYPE STANDARD TABLE OF ty_step WITH EMPTY KEY.

  "! A line of a job log (BP_JOBLOG_READ, structure TBTC5; VERIFY-SE37 V60)
  TYPES:
    BEGIN OF ty_log_line,
      enterdate TYPE d,
      entertime TYPE t,
      msgid     TYPE symsgid,
      msgno     TYPE symsgno,
      msgtype   TYPE symsgty,
      text      TYPE ty_log_text,
    END OF ty_log_line.
  TYPES tt_log_line TYPE STANDARD TABLE OF ty_log_line WITH EMPTY KEY.

  "! An application log header (BALHDR; VERIFY-SE11 V59)
  TYPES:
    BEGIN OF ty_applog,
      lognumber TYPE ty_lognumber,
      object    TYPE ty_log_object,
      subobject TYPE ty_log_object,
      extnumber TYPE ty_extnumber,
      aldate    TYPE d,
      altime    TYPE t,
      aluser    TYPE syuname,
      alprog    TYPE ty_progname,
      msg_cnt_e TYPE i,
      msg_cnt_a TYPE i,
    END OF ty_applog.
  TYPES tt_applog TYPE STANDARD TABLE OF ty_applog WITH EMPTY KEY.

  "! Parent / child link found by a resolver
  TYPES:
    BEGIN OF ty_link,
      parent_name  TYPE btcjob,
      parent_count TYPE btcjobcnt,
      child_name   TYPE btcjob,
      child_count  TYPE btcjobcnt,
      resolver     TYPE ty_resolver_id,
      quality      TYPE ty_quality,
    END OF ty_link.
  TYPES tt_link TYPE STANDARD TABLE OF ty_link WITH EMPTY KEY.

  "! A business object a consumer's enricher links to a job (payment run, mass activity run, ...)
  TYPES:
    BEGIN OF ty_bus_object,
      jobname     TYPE btcjob,
      jobcount    TYPE btcjobcnt,
      enricher    TYPE zif_ca_ops_types=>ty_class_name,
      object_type TYPE ty_bo_type,
      object_key  TYPE ty_bo_key,
      "! Text shown on the board (a message of the consumer's class)
      label       TYPE ty_bo_label,
      "! Company code of the object (blank = none): the company code of the job's finding
      bukrs       TYPE bukrs,
      item_count  TYPE i,
      quality     TYPE ty_quality,
    END OF ty_bus_object.
  TYPES tt_bus_object TYPE STANDARD TABLE OF ty_bus_object WITH EMPTY KEY.

  "! Another monitor reports the failure of this job itself (de-duplication): the job monitor keeps
  "! the evidence and an information finding only
  TYPES:
    BEGIN OF ty_claim,
      jobname  TYPE btcjob,
      jobcount TYPE btcjobcnt,
      "! Who reports it (check / cycle step), shown in the information finding
      claimer  TYPE zif_ca_ops_types=>ty_reference,
    END OF ty_claim.
  TYPES tt_claim TYPE STANDARD TABLE OF ty_claim WITH EMPTY KEY.

  "! A job of the external scheduler and the SAP job names it starts (ZCA_OPS_JOBSCH)
  TYPES:
    BEGIN OF ty_sched,
      sched_folder  TYPE ty_sched_folder,
      sched_job     TYPE ty_sched_job,
      sap_pattern TYPE zif_ca_ops_types=>ty_object_key,
      criticality TYPE ty_criticality,
      seq         TYPE i,
    END OF ty_sched.
  TYPES tt_sched TYPE STANDARD TABLE OF ty_sched WITH EMPTY KEY.

  "! Evidence of one job (ZCA_OPS_JOB) - what proves the failure after the reorganisation of
  "! the job tables
  TYPES:
    BEGIN OF ty_evidence,
      jobname         TYPE btcjob,
      jobcount        TYPE btcjobcnt,
      area            TYPE zif_ca_ops_types=>ty_area,
      bukrs           TYPE bukrs,
      role            TYPE ty_role,
      check_code      TYPE zif_ca_ops_types=>ty_check_code,
      severity        TYPE zif_ca_ops_types=>ty_severity,
      object_key      TYPE zif_ca_ops_types=>ty_object_key,
      status          TYPE ty_status,
      planned_date    TYPE d,
      planned_time    TYPE t,
      created_date    TYPE d,
      created_time    TYPE t,
      start_date      TYPE d,
      start_time      TYPE t,
      end_date        TYPE d,
      end_time        TYPE t,
      sched_user      TYPE syuname,
      server          TYPE ty_server,
      event_id        TYPE ty_eventid,
      event_parm      TYPE ty_eventparm,
      parent_jobname  TYPE btcjob,
      parent_jobcount TYPE btcjobcnt,
      link_resolver   TYPE ty_resolver_id,
      link_quality    TYPE ty_quality,
      root_jobname    TYPE btcjob,
      root_jobcount   TYPE btcjobcnt,
      root_status     TYPE ty_status,
      depth           TYPE i,
      sched_folder      TYPE ty_sched_folder,
      sched_job         TYPE ty_sched_job,
      criticality     TYPE ty_criticality,
      log_errors      TYPE i,
      failed_children TYPE i,
      claimed_by      TYPE zif_ca_ops_types=>ty_reference,
      detected_at     TYPE timestampl,
      detected_on     TYPE d,
      run_id          TYPE zif_ca_ops_types=>ty_run_id,
    END OF ty_evidence.
  TYPES tt_evidence TYPE STANDARD TABLE OF ty_evidence WITH EMPTY KEY.

  "! A kept job log line of a failed job (ZCA_OPS_JOBMSG)
  TYPES:
    BEGIN OF ty_kept_line,
      jobname  TYPE btcjob,
      jobcount TYPE btcjobcnt,
      line_no  TYPE i,
      line     TYPE ty_log_line,
    END OF ty_kept_line.
  TYPES tt_kept_line TYPE STANDARD TABLE OF ty_kept_line WITH EMPTY KEY.

  "! An application log linked to a job (ZCA_OPS_JOBALOG)
  TYPES:
    BEGIN OF ty_job_applog,
      jobname  TYPE btcjob,
      jobcount TYPE btcjobcnt,
      applog   TYPE ty_applog,
      quality  TYPE ty_quality,
    END OF ty_job_applog.
  TYPES tt_job_applog TYPE STANDARD TABLE OF ty_job_applog WITH EMPTY KEY.

  "! Everything one run keeps (written in the runner's LUW, never in test mode)
  TYPES:
    BEGIN OF ty_evidence_set,
      jobs     TYPE tt_evidence,
      steps    TYPE tt_step,
      lines    TYPE tt_kept_line,
      applogs  TYPE tt_job_applog,
      objects  TYPE tt_bus_object,
    END OF ty_evidence_set.

  "! A point in server time (date and time of TBTCO)
  TYPES:
    BEGIN OF ty_point,
      date TYPE d,
      time TYPE t,
    END OF ty_point.

  "! The read window of an incremental run
  TYPES:
    BEGIN OF ty_window,
      from  TYPE ty_point,
      to    TYPE ty_point,
      "! X = no watermark yet: the look-back applied
      first TYPE abap_bool,
    END OF ty_window.

  "! Watermark of an area and check (ZCA_OPS_JOBWM): end of the last window evaluated completely
  TYPES:
    BEGIN OF ty_watermark,
      area     TYPE zif_ca_ops_types=>ty_area,
      check_id TYPE zif_ca_ops_chk_types=>ty_check_id,
      point    TYPE ty_point,
      run_id   TYPE zif_ca_ops_types=>ty_run_id,
    END OF ty_watermark.

  "! Settings of one run (parameters read once, caps cut to the ceilings)
  TYPES:
    BEGIN OF ty_config,
      lookback_min     TYPE i,
      overlap_min      TYPE i,
      max_jobs         TYPE i,
      max_log_reads    TYPE i,
      max_messages     TYPE i,
      max_depth        TYPE i,
      max_children     TYPE i,
      max_applogs      TYPE i,
      long_running_min TYPE i,
      not_started_min  TYPE i,
      exclude          TYPE zif_ca_ops_types=>tt_pcre,
      log_programs     TYPE zif_ca_ops_types=>tt_param_range,
      parent_programs  TYPE zif_ca_ops_types=>tt_param_range,
      log_error_types  TYPE zif_ca_ops_types=>tt_param_range,
      waiting_statuses TYPE zif_ca_ops_types=>tt_param_range,
      resolvers        TYPE string_table,
      enrichers        TYPE string_table,
      claims           TYPE string_table,
    END OF ty_config.

ENDINTERFACE.
