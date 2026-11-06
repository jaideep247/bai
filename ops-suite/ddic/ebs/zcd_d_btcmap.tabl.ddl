@EndUserText.label : 'Draft: Bank transaction codes'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_btcmap {
  key mandt : abap.clnt not null;
  key scheme : abap.char(5) not null;
  key btccode : abap.char(35) not null;
  key bankkey : abap.char(15) not null;
  key flowtype : abap.char(1) not null;
  singletonid : abap.int1;
  category : abap.char(4);
  rulegroup : abap.char(10);
  expcdi : abap.char(1);
  paymethod : abap.char(10);
  postingrule : abap.char(4);
  retreason : abap.char(4);
  actioncode : abap.char(10);
  active : abap_boolean;
  description : abap.char(60);
  changedby : syuname;
  changedat : timestampl;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
