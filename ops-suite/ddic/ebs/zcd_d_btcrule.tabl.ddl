@EndUserText.label : 'Draft: Rule assignments'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_btcrule {
  key mandt : abap.clnt not null;
  key rulegroup : abap.char(10) not null;
  key ruleid : abap.char(10) not null;
  singletonid : abap.int1;
  seq : abap.int2;
  severity : abap.char(1);
  actioncode : abap.char(10);
  param1 : abap.char(40);
  param2 : abap.char(40);
  param3 : abap.char(40);
  tolerance : abap.dec(15,2);
  windowdays : abap.int4;
  active : abap_boolean;
  changedby : syuname;
  changedat : timestampl;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
