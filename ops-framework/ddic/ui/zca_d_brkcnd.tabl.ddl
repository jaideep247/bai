@EndUserText.label : 'Draft: Break analysis rule conditions'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_brkcnd {
  key mandt : abap.clnt not null;
  key area : zca_param_area_id not null;
  key ruleid : abap.char(20) not null;
  key condno : abap.numc(3) not null;
  singletonid : abap.int1;
  condkind : abap.char(5);
  field : abap.char(30);
  operator : abap.char(2);
  condvalue : abap.char(120);
  linkid : abap.char(30);
  mincount : abap.int4;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
