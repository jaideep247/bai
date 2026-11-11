@EndUserText.label : 'Ops framework: SAP job failure evidence'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_job {
  key mandt       : abap.clnt not null;
  // Job of TBTCO (the standard reorganisation deletes the TBTCO row, its steps and its log)
  key jobname     : btcjob not null;
  key jobcount    : btcjobcnt not null;
  // Area of the monitor run that kept the job (read authorisation of the board: ZCA_OPS 03)
  area            : zca_param_area_id;
  // Company code from an enricher (blank = area-level) - company-code isolation of the board
  bukrs           : bukrs;
  // F = failure with its own finding, A = ancestor (parent / root), C = child kept as context
  job_role        : abap.char(1);
  // Check code and severity of the finding (blank for A / C) and its object key (join to ZCA_OPS_FINDING)
  check_code      : abap.char(30);
  severity        : abap.char(1);
  object_key      : abap.char(70);
  // TBTCO status at detection (the live status is joined while TBTCO still has the row)
  status          : abap.char(1);
  // Planned start, created (released by a parent), start and end - proof of the time-window links
  planned_date    : abap.dats;
  planned_time    : abap.tims;
  created_date    : abap.dats;
  created_time    : abap.tims;
  start_date      : abap.dats;
  start_time      : abap.tims;
  end_date        : abap.dats;
  end_time        : abap.tims;
  // Scheduled by (for a child: the parent's step user) and the server it ran on
  sched_user      : syuname;
  server          : abap.char(20);
  // Start event and parameter - proof of an event link
  event_id        : abap.char(32);
  event_parm      : abap.char(64);
  // Parent found by the first resolver that linked the job, and the evidence quality (C / P)
  parent_jobname  : btcjob;
  parent_jobcount : btcjobcnt;
  link_resolver   : abap.char(10);
  link_quality    : abap.char(1);
  // Topmost ancestor (what the scheduler started), its status at detection and the depth below it
  root_jobname    : btcjob;
  root_jobcount   : btcjobcnt;
  root_status     : abap.char(1);
  depth           : abap.int1;
  // Job of the external scheduler that started the root (ZCA_OPS_JOBSCH pattern) and its criticality H / M / L
  sched_folder    : abap.char(40);
  sched_job       : abap.char(64);
  criticality     : abap.char(1);
  // Error / abort lines of the job log; failed descendants of an ancestor
  log_errors      : abap.int4;
  failed_children : abap.int4;
  // Another monitor reports this job's own failure (de-duplication; the finding is information)
  claimed_by      : abap.char(35);
  // When and by which run it was kept (UTC) and the server date (board "today", purge)
  detected_at     : timestampl;
  detected_on     : abap.dats;
  run_id          : sysuuid_x16;
}
// Written only by the SAP job monitor (ZCL_CA_OPS_JOB_MONITOR through ZCL_CA_OPS_JOB_DAO=>SAVE, in the
// LUW of the run of ZCA_OPS_CHECK_RUN); read by the board ZUI_CA_OPS_JOBS. No copy of what stays readable:
// program texts, variant contents and the spool stay in SAP. Purge target JOB_EVIDENCE
// (ZCL_CA_OPS_JOB_PURGE, RETENTION_DAYS_JOB_EVIDENCE, 180 days) by DETECTED_AT.
// @index DET: MANDT, DETECTED_AT
// @index PAR: MANDT, PARENT_JOBNAME, PARENT_JOBCOUNT
// @index ROL: MANDT, AREA, JOB_ROLE, DETECTED_ON
