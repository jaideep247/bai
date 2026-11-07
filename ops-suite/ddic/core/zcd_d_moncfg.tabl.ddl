@EndUserText.label : 'Draft: Monitor freshness'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_moncfg {
  key mandt : abap.clnt not null;
  key paymentenginearea : abap.char(4) not null;
  singletonid : abap.int1;
  staleaftermin : abap.int4;
  description : abap.char(60);
  changedby : syuname;
  changedat : timestampl;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
