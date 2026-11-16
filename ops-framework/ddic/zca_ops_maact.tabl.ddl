@EndUserText.label : 'Ops framework: mass activity expectations'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_maact {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  // One FI-CA mass activity the area watches (docs/EXPECTED_RUNS_AND_MASS_ACTIVITIES.md section 3): its runs, their
  // intervals and their document output
  key act_id    : abap.char(10) not null;
  description   : abap.char(60);
  // Mass activity type (TFK090A-AKTYP of the site; a value not confirmed on the reference system stays a
  // placeholder and the row inactive)
  aktyp         : abap.char(10);
  // The run's parent job: program of a step (exact, e.g. the mass activity scheduler; blank = any) and the job
  // name (PCRE, complete name, case ignored)
  parent_program : abap.char(40);
  job_pattern   : abap.char(70);
  // Document output of a run: PAYDOC payment documents of the payment run (DPAYH), DUNNING dunning notices
  // (FKKMAKO), NONE no output rule
  output_kind   : abap.char(10);
  // A run's output below this many documents is short (0 = no minimum)
  min_output    : abap.int4;
  // Minutes an interval may run before it is reported (0 = parameter MA_RUN_LIMIT_MIN)
  run_limit_min : abap.int4;
  active        : abap_boolean;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by ZCL_CA_OPS_MA_DAO=>ACTIVITIES (active rows of an area; check ZCL_CA_OPS_CHK_MA_INTERVAL, package
// ZCA_OPS_CASH); rows by transport (DV1)
