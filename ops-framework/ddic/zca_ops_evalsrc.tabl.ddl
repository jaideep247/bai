@EndUserText.label : 'Ops framework: source freshness of an evaluation'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_evalsrc {
  key mandt     : abap.clnt not null;
  // Evaluation and coverage (2026-11-16, build O): one row per source a check names in a run (ZCA_OPS_EVAL)
  key run_id    : sysuuid_x16 not null;
  key check_id  : abap.char(20) not null;
  key source_id : abap.char(30) not null;
  area          : zca_param_area_id;
  // Newest observation of the source the check saw (UTC; initial = nothing observed)
  newest_at     : timestampl;
  // Stale limit in minutes (the source's own, else EVAL_SOURCE_STALE_MIN) and the verdict of the run (X = stale)
  stale_min     : abap.int4;
  is_stale      : abap.char(1);
}
