@EndUserText.label : 'Ops framework: break analysis buckets'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_brkbkt {
  key mandt     : abap.clnt not null;
  // Variance bucket of an open item / group (TIMING, RETRIEVAL_CUTOFF, ..., OTHER = not explained)
  key bucket    : abap.char(20) not null;
  description   : abap.char(60);
  // X = a break in this bucket is explained (pilot metric "share of breaks explained"); OTHER is never explained
  explained     : abap_boolean;
  // Layer that delivers the bucket (product S4CORE / FICA, a customer layer)
  layer_id      : abap.char(10);
  seq           : abap.int4;
  active        : abap_boolean;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
