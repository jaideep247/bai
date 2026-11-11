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
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by ZCL_CA_OPS_JOB_DAO=>SCHEDULER_JOBS (active rows); new rows only by transport (DV1)
