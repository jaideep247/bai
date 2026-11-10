@EndUserText.label : 'Ops framework: control guidance per language'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_ctlt {
  key mandt     : abap.clnt not null;
  // Language of the text (one row per language, translated rows travel by transport)
  key langu     : spras not null;
  key area      : zca_param_area_id not null;
  key control_id : abap.char(20) not null;
  // What the reviewer checks before signing the control off
  guidance      : abap.char(255);
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Text rows of ZCA_OPS_CONTROL (same key + language). VERIFY-SE11: declare it the text table of ZCA_OPS_CONTROL
// (foreign key LANGU / AREA / CONTROL_ID, key type TEXT_KEY) when the landscape translates customizing in SE63.
