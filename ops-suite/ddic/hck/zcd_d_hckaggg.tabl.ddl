@EndUserText.label : 'Draft: Expected groups'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_hckaggg {
  key mandt : abap.clnt not null;
  key checkid : abap.char(20) not null;
  key aggid : abap.char(10) not null;
  key groupvalue : abap.char(70) not null;
  singletonid : abap.int1;
  description : abap.char(60);
  changedby : syuname;
  changedat : timestampl;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
