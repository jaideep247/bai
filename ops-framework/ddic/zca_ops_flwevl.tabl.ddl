@EndUserText.label : 'Ops framework: account flow evaluation'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_flwevl {
  key mandt     : abap.clnt not null;
  // One evaluation of one flow at one key date (report ZCA_OPS_FLOW_RUN): what the existing checks account for in
  // the closing position of each account; written only by ZCL_CA_OPS_FLOW_DAO
  key eval_id   : sysuuid_x16 not null;
  area          : zca_param_area_id;
  flow_id       : abap.char(10);
  key_date      : abap.dats;
  // S complete, P partial (an account could not be evaluated - its item rows say why)
  status        : abap.char(1);
  // Configuration version: SHA-1 of the flow, its accounts, stages, controls, rules and the FLOW_ parameter values
  cfg_version   : abap.char(40);
  acct_count    : abap.int4;
  not_evaluated : abap.int4;
  started_at    : timestampl;
  ended_at      : timestampl;
  created_by    : syuname;
  message       : abap.char(255);
}
// FLW: the latest evaluation of a flow at a key date (ZI_CA_OpsFlowEvlMax)
// @index FLW: MANDT, AREA, FLOW_ID, KEY_DATE
// Retention: evaluations older than FLOW_RETENTION_DAYS are deleted by the next evaluation of the flow
