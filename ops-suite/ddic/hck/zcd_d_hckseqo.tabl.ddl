@EndUserText.label : 'Draft: Role sequence outcomes'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_hckseqo {
  key mandt : abap.clnt not null;
  key flow : abap.char(1) not null;
  key methodclass : abap.char(3) not null;
  key seq : abap.numc(3) not null;
  singletonid : abap.int1;
  seqpattern : abap.char(200);
  outcome : abap.char(20);
  expecteddfkkrp : abap.char(1);
  maxagedays : abap.int4;
  severity : abap.char(1);
  description : abap.char(60);
  active : abap_boolean;
  changedby : syuname;
  changedat : timestampl;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
