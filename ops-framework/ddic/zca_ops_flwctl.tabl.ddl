@EndUserText.label : 'Ops framework: account flow stage controls'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_flwctl {
  key mandt      : abap.clnt not null;
  key area       : zca_param_area_id not null;
  key flow_id    : abap.char(10) not null;
  key stage_id   : abap.char(20) not null;
  // Check that controls the stage: area and check ID of its findings (ZCA_OPS_FINDING-AREA / GROUP2) - a check of
  // the registry (ZCA_OPS_CHECK) or of a consumer's own engine; its latest result is the stage's control tag
  key check_area : zca_param_area_id not null;
  key check_id   : abap.char(35) not null;
  description    : abap.char(60);
  active         : abap_boolean;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
