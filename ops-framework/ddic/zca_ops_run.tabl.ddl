@EndUserText.label : 'Ops framework: run header'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_run {
  key mandt     : abap.clnt not null;
  key run_id    : sysuuid_x16 not null;
  area        : zca_param_area_id;
  variant       : abap.char(30);
  test_mode     : abap_boolean;
  started_at    : timestampl;
  ended_at      : timestampl;
  status        : abap.char(1);
  rag           : abap.char(1);
  total_items   : abap.int4;
  passed_items  : abap.int4;
  failed_items  : abap.int4;
  blocked_items : abap.int4;
  warning_items : abap.int4;
  finding_count : abap.int4;
  runtime_ms    : abap.int4;
  message       : abap.char(255);
  created_by    : syuname;
  // Batch job of the run (SM37: job name + count; blank in dialog) and the system (2026-11-10)
  jobname       : btcjob;
  jobcount      : btcjobcnt;
  sysid         : sysysid;
}
// Secondary index MOD: morning report / last-run lookups
// @index MOD: MANDT, AREA, STARTED_AT
