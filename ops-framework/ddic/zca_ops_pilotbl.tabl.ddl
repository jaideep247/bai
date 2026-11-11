@EndUserText.label : 'Ops framework: pilot detection baselines'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_pilotbl {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  // Registered check (ZCA_OPS_CHECK-CHECK_ID = GROUP2 of its findings)
  key check_id  : abap.char(20) not null;
  // Previous detection time: minutes after the business event at which the issue was found before the framework
  // ran (e.g. a next-day reconciliation = 1 440) - the pilot compares the measured time to detect with it
  baseline_min  : abap.int4;
  // Where the baseline comes from (e.g. incident history, the month-end reconciliation review) - evidence of the pilot
  source        : abap.char(60);
  description   : abap.char(60);
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read only by the pilot CDS (ZI_CA_OpsPilotDetect, docs/PILOT_PACK.md); no engine reads it.
