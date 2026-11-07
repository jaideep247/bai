// Parameter areas: one row per team / application area that owns parameters.
// Delivery class C (customizing), table logging on (SCU3), fully buffered.
@EndUserText.label : 'Parameter framework: areas'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_param_area {
  key client            : abap.clnt not null;
  key area              : zca_param_area_id not null;
  description           : zca_param_descr;
  owner_team            : zca_param_owner;
  prod_editable         : zca_param_prod_edit;
  active                : zca_param_active;
  // customizing request of the last maintenance session in a transport client
  transport_request     : trkorr;
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
