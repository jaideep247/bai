@EndUserText.label : 'Ops framework: link registry links'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_link {
  key mandt   : abap.clnt not null;
  // Starts with the prefix of its layer
  key link_id : abap.char(30) not null;
  layer_id    : abap.char(10);
  from_object : abap.char(30);
  to_object   : abap.char(30);
  // 11, 1N, N1, NM - a "to one" side covers the key fields of its object or prefers one row
  cardinality : abap.char(2);
  // Evidence quality of the join: C confirmed, P probable (the walker reports P on every node behind it)
  quality     : abap.char(1);
  // Tried only for the source rows the link named here found nothing for (same objects; a chain, no cycle)
  fallback_of : abap.char(30);
  // A link of a lower layer this one replaces while its layer is active
  replaces    : abap.char(30);
  active      : abap_boolean;
  owner       : abap.char(30);
  verify_ref  : abap.char(20);
  description : abap.char(60);
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
