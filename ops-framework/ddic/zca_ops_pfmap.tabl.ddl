@EndUserText.label : 'Ops framework: payment file status mapping'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_pfmap {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  // Source of the status (ZCA_OPS_PFADP-SOURCE_ID) and its native value as the adapter delivers it (exact, case kept)
  key source_id : abap.char(10) not null;
  key status    : abap.char(30) not null;
  // What the value means in the product: the milestone it evidences and its outcome OK, REJECTED, PARTIAL, FAILED
  // or INFO (recorded as evidence, moves nothing)
  milestone     : abap.char(10);
  outcome       : abap.char(10);
  description   : abap.char(60);
  active        : abap_boolean;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// A value without an active row is recorded as unmapped evidence (outcome INFO) and counted in the source state.
