@EndUserText.label : 'Draft: Runbook links per check'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_runbook {
  key mandt : abap.clnt not null;
  key area : zca_param_area_id not null;
  key matchfield : abap.char(10) not null;
  key matchvalue : abap.char(35) not null;
  singletonid : abap.int1;
  runbookurl : abap.char(255);
  firstaction : abap.char(120);
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
