@EndUserText.label : 'Ops framework: evaluation record of a check run'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_eval {
  key mandt     : abap.clnt not null;
  // Evaluation and coverage (2026-11-16, build O, docs/EVALUATION_AND_COVERAGE.md): one row per registered check
  // and run of ZCL_CA_OPS_CHECK_RUNNER (also for a check not run: licence refused, process not in effect), written
  // only by ZCL_CA_OPS_EVAL_DAO in the run's unit of work, never in test mode
  key run_id    : sysuuid_x16 not null;
  key check_id  : abap.char(20) not null;
  area          : zca_param_area_id;
  process_id    : abap.char(20);
  sched_group   : abap.char(10);
  evaluated_at  : timestampl;
  // Expected scope: business date, accounting period (YYYYMM) and company codes (comma list, blank = the area)
  bus_date      : abap.dats;
  period        : abap.numc(6);
  bukrs_list    : abap.char(120);
  // Expected and observed objects when the check counts them (0 = not counted)
  expected_cnt  : abap.int4;
  observed_cnt  : abap.int4;
  item_count    : abap.int4;
  // Owned exceptions (severity B / E / W) the check raised in the run
  finding_cnt   : abap.int4;
  // C complete, P partial, N not evaluated
  completeness  : zca_ops_eval_cmpl;
  // OK, ZERO_OK, HOLIDAY, PER_CLOSED, STALE, NOT_EVAL, FINDINGS (the result class)
  result_class  : zca_ops_eval_state;
  // The one state support sees (completeness first): NOT_EVAL, STALE, PARTIAL, else the result class
  eval_state    : zca_ops_eval_state;
  reason_code   : abap.char(20);
  reason        : abap.char(255);
  // Source freshness: the oldest of the newest observations of the sources the check names, and that source
  fresh_at      : timestampl;
  fresh_source  : abap.char(30);
  watermark     : timestampl;
  // Licence of the check's modules in the run: blank covered, W warned (LIC_ENFORCE W), R refused (X)
  lic_state     : abap.char(1);
  lic_module    : abap.char(20);
  // Last valid result: the latest run of the check that was complete (this run when it is)
  last_valid_run : sysuuid_x16;
  last_valid_at : timestampl;
  last_valid_cls : zca_ops_eval_state;
}
// Secondary index LST: latest evaluation of a check (dashboard, coverage, daily review)
// @index LST: MANDT, AREA, CHECK_ID, EVALUATED_AT
