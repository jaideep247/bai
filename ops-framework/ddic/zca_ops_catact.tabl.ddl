@EndUserText.label : 'Ops framework: process catalogue activation'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_catact {
  key mandt      : abap.clnt not null;
  // Catalogue process switched on or off by the customer (the delivered process row stays unchanged)
  key process_id : abap.char(20) not null;
  // Effective from this date; the row with the latest VALID_FROM on or before the day decides
  key valid_from : abap.dats not null;
  active         : abap_boolean;
  // Customer layer (package of kind C) that decides
  pkg_id         : abap.char(10);
  reason         : abap.char(80);
  // Four-eyes: the business approver of the decision (a user of the client, not the user who saves the row)
  approved_by    : syuname;
  approved_on    : abap.dats;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by ZCL_CA_OPS_CAT_DAO and the effective-activation view ZI_CA_OpsCatActLast. New rows only by transport (DV1).
