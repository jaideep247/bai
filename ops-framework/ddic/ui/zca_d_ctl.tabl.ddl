@EndUserText.label : 'Draft: Controls (daily review)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_ctl {
  key mandt : abap.clnt not null;
  key area : zca_param_area_id not null;
  key controlid : abap.char(20) not null;
  singletonid : abap.int1;
  description : abap.char(60);
  category : abap.char(30);
  owner : syuname;
  backup : syuname;
  team : abap.char(10);
  cutofftime : abap.tims;
  runbookurl : abap.char(255);
  active : abap_boolean;
  seq : abap.int4;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
