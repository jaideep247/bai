@EndUserText.label : 'Ops framework: purge targets of consumers'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_purge {
  key mandt     : abap.clnt not null;
  // Purge target of a consumer (the framework's own RUN and ALERT_LOG are built in)
  key target    : abap.char(12) not null;
  // Implements ZIF_CA_OPS_PURGE_TARGET (checked on save)
  class_name    : seoclsname;
  // Retention days: parameter of ZCA_PARAM (area + name; must exist, checked on save)
  param_area    : zca_param_area_id;
  param_name    : abap.char(30);
  active        : abap_boolean;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by ZCL_CA_OPS_PURGE_DAO=>GET_TARGETS (active rows, by target); new rows only by transport (DV1)
