@EndUserText.label : 'Draft: Business processes'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_proc {
  key mandt : abap.clnt not null;
  key area : zca_param_area_id not null;
  key processid : abap.char(20) not null;
  singletonid : abap.int1;
  description : abap.char(60);
  owner : syuname;
  backup : syuname;
  runbookurl : abap.char(255);
  authrole : abap.char(30);
  owndata : abap_boolean;
  purgetarget : abap.char(12);
  catprocess : abap.char(20);
  active : abap_boolean;
  seq : abap.int4;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
