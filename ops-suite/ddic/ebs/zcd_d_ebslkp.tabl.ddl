@EndUserText.label : 'Draft: Lookups (rule R21)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_ebslkp {
  key mandt : abap.clnt not null;
  key lookupid : abap.char(10) not null;
  singletonid : abap.int1;
  tablename : abap.char(30);
  keyfield : abap.char(30);
  keykind : abap.char(10);
  keylength : abap.int4;
  statusfield : abap.char(30);
  allowedvalues : abap.char(255);
  notfoundcode : abap.char(30);
  statuscode : abap.char(30);
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
