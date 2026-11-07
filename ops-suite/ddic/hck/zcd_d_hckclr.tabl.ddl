@EndUserText.label : 'Draft: Clearing / return evidence rules'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_hckclr {
  key mandt : abap.clnt not null;
  key flow : abap.char(1) not null;
  key methodclass : abap.char(3) not null;
  key purpose : abap.char(10) not null;
  key seq : abap.numc(3) not null;
  singletonid : abap.int1;
  evidenceclass : abap.char(30);
  param1 : abap.char(40);
  param2 : abap.char(40);
  param3 : abap.char(40);
  required : abap.char(1);
  description : abap.char(60);
  active : abap_boolean;
  changedby : syuname;
  changedat : timestampl;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
