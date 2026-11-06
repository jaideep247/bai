@EndUserText.label : 'Draft: Generic aggregates'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_hckagg {
  key mandt : abap.clnt not null;
  key checkid : abap.char(20) not null;
  key aggid : abap.char(10) not null;
  singletonid : abap.int1;
  description : abap.char(60);
  tabname : abap.char(30);
  aggfunc : abap.char(5);
  sumfield : abap.char(30);
  datefield : abap.char(30);
  datemode : abap.char(3);
  agedaysmin : abap.int4;
  groupfield : abap.char(30);
  cond1field : abap.char(30);
  cond1op : abap.char(2);
  cond1value : abap.char(70);
  cond2field : abap.char(30);
  cond2op : abap.char(2);
  cond2value : abap.char(70);
  cond3field : abap.char(30);
  cond3op : abap.char(2);
  cond3value : abap.char(70);
  changedby : syuname;
  changedat : timestampl;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
