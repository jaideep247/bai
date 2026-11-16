@EndUserText.label : 'Ops framework: scheduler jobs and SAP job names'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_jobsch {
  key mandt     : abap.clnt not null;
  // Folder and job of the external workload scheduler (values of the scheduler export)
  key sched_folder : abap.char(40) not null;
  key sched_job   : abap.char(64) not null;
  // SAP job name(s) the scheduler job starts: PCRE matched to the complete name, case ignored
  sap_pattern   : abap.char(70);
  // H / M / L - shown on the board next to the failure
  criticality   : abap.char(1);
  description   : abap.char(60);
  active        : abap_boolean;
  // First matching row in sequence wins
  seq           : abap.int4;
  // Expected runs by configuration (2026-11-16, build P; docs/EXPECTED_RUNS_AND_MASS_ACTIVITIES.md): the days of
  // the week the scheduler job runs (7 characters Monday ... Sunday, X = runs; blank = no expected run from this row)
  plan_days     : abap.char(7);
  // Planned start (system time of the SAP server, as TBTCO) and the minutes after it until the run counts as late
  // (0 = parameter XRUN_LATE_MIN)
  plan_time     : abap.tims;
  late_min      : abap.int4;
  // Factory calendar of the run days (blank = the weekdays of PLAN_DAYS only, no holidays)
  calendar_id   : abap.char(2);
  // Predecessor: the scheduler job that must have ended successfully before this one starts (blank = none)
  pred_folder   : abap.char(40);
  pred_job      : abap.char(64);
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by ZCL_CA_OPS_JOB_DAO=>SCHEDULER_JOBS (active rows; the plan columns by the expected-run source
// ZCL_CA_OPS_XRUN_SRC_JOBSCH); new rows only by transport (DV1)
