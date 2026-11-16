@EndUserText.label : 'Draft: Bank transaction codes (typed ZBTM)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_mapbtm {
  key mandt : abap.clnt not null;
  key version : abap.numc(4) not null;
  key scheme : abap.char(5) not null;
  key code : abap.char(35) not null;
  key family : abap.char(35) not null;
  key subfamily : abap.char(35) not null;
  key bank : abap.char(15) not null;
  key flow : abap.char(1) not null;
  singletonid : abap.int1;
  category : abap.char(4);
  rulegroup : abap.char(10);
  expcdi : abap.char(1);
  paymethod : abap.char(10);
  postingrule : abap.char(4);
  actioncode : abap.char(10);
  disposition : abap.char(10);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
