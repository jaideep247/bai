@EndUserText.label : 'Health check: verdict of each check per run'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_hck_result {
  key mandt     : abap.clnt not null;
  key run_id    : sysuuid_x16 not null;
  key check_id  : abap.char(20) not null;
  // start of the check (run start for a check the run's scope left out)
  executed_at   : timestampl;
  category      : abap.char(1);
  priority      : abap.char(1);
  // the morning report's decision: R / A / G, blank = grey (warm-up, nothing rated)
  verdict       : abap.char(1);
  // RED / AMBER / GREEN / WARMUP / GREY / FAILED / SKIPPED (ZIF_CD_HCK_TYPES=>GC_CHECK_STATUS)
  check_status  : abap.char(10);
  // COMPLETE / PARTIAL (timeout, budget, capped read) / FAILED (plug-in error) / SKIPPED (not in scope)
  completion    : abap.char(10);
  // evidence the check could read: ALL / PARTIAL / NONE
  evidence      : abap.char(10);
  // scope of the run: variant, categories, priorities, check ids of the selection
  run_scope     : abap.char(255);
  metric_count  : abap.int4;
  finding_count : abap.int4;
  // findings of severity B / E and W
  error_count   : abap.int4;
  warning_count : abap.int4;
  // baseline mode of the evaluated thresholds: NONE / ZSCORE / IQR / MIXED (blank = no threshold)
  baseline_mode : abap.char(6);
  // a baseline-only metric is still warming up (A102)
  warmup        : abap_boolean;
  runtime_ms    : abap.int4;
  // summary line of the check in the report
  message       : abap.char(255);
}
// Written by ZCL_CD_HCK_ENGINE from the decision the report uses (one row per executed or skipped
// check per run, not in test mode); read by the health check dashboard (ZI_CD_HckResult).
// @index TIM: MANDT, EXECUTED_AT
// Retention: ZCA_OPS_RETENTION deletes rows older than parameter RETENTION_DAYS_HCK_RESULT (ZCA_PARAM).
