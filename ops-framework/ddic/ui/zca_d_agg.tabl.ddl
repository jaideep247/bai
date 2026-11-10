@EndUserText.label : 'Draft: Aggregate checks (no code)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_agg {
  key mandt : abap.clnt not null;
  key area : zca_param_area_id not null;
  key checkid : abap.char(20) not null;
  key aggid : abap.char(10) not null;
  singletonid : abap.int1;
  description : abap.char(60);
  tabname : abap.char(30);
  aggfunc : abap.char(5);
  datefield : abap.char(30);
  minagedays : abap.int4;
  bukrsfield : abap.char(30);
  statusfield : abap.char(30);
  statusop : abap.char(2);
  statusvalue : abap.char(70);
  condfield : abap.char(30);
  condop : abap.char(2);
  condvalue : abap.char(70);
  amber : abap.int4;
  red : abap.int4;
  checkcode : abap.char(30);
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
