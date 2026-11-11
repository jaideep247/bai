@EndUserText.label : 'Ops framework: link registry activation overrides'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_lnkact {
  key mandt       : abap.clnt not null;
  // L layer, K link of a lower layer than LAYER_ID: the delivered row stays unchanged, this row switches it
  key target_kind : abap.char(1) not null;
  key target_id   : abap.char(30) not null;
  // Layer of the customer that switches the target
  layer_id        : abap.char(10);
  active          : abap_boolean;
  reason          : abap.char(60);
  owner           : abap.char(30);
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
