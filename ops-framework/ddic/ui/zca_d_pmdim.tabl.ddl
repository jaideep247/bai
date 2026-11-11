@EndUserText.label : 'Draft: Payment model dimension texts'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_pmdim {
  key mandt : abap.clnt not null;
  key langu : spras not null;
  key dimension : abap.char(20) not null;
  key dimvalue : abap.char(40) not null;
  singletonid : abap.int1;
  text : abap.char(60);
  seq : abap.int4;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
