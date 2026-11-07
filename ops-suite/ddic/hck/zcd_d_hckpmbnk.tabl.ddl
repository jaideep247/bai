@EndUserText.label : 'Draft: Factory calendar per house bank'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_hckpmbnk {
  key mandt : abap.clnt not null;
  key flow : abap.char(1) not null;
  key methodclass : abap.char(3) not null;
  key hbkid : abap.char(5) not null;
  singletonid : abap.int1;
  calendar : abap.char(2);
  description : abap.char(60);
  active : abap_boolean;
  changedby : syuname;
  changedat : timestampl;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
