@EndUserText.label : 'Ops framework: link registry business objects'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_lnkobj {
  key mandt     : abap.clnt not null;
  // Starts with the prefix of its layer (e.g. CA_OPEN_ITEM)
  key object_id : abap.char(30) not null;
  layer_id      : abap.char(10);
  // Table or CDS view entity read by the walker (approved per area in ZCA_OPS_TABWL, S_TABU_NAM display)
  source_name   : abap.char(30);
  // T table, V CDS view entity
  source_kind   : abap.char(1);
  // Fields that identify a row for the walker (comma list, each a field row of ZCA_OPS_LNKFLD of the same layer)
  key_fields    : abap.char(255);
  description   : abap.char(60);
  active        : abap_boolean;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
