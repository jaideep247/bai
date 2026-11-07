@EndUserText.label : 'Draft: Evidence settings'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_hckevset {
  key mandt : abap.clnt not null;
  key setid : abap.char(10) not null;
  key name : abap.char(20) not null;
  singletonid : abap.int1;
  value : abap.char(40);
  description : abap.char(60);
  active : abap_boolean;
  changedby : syuname;
  changedat : timestampl;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
