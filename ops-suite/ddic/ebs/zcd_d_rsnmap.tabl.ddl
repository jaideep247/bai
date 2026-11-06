@EndUserText.label : 'Draft: Return / NOC reasons'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_rsnmap {
  key mandt : abap.clnt not null;
  key reason : abap.char(4) not null;
  singletonid : abap.int1;
  ficareason : abap.char(3);
  isnoc : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
