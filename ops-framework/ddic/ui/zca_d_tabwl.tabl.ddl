@EndUserText.label : 'Draft: Tables approved for aggregate checks'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_tabwl {
  key mandt : abap.clnt not null;
  key area : zca_param_area_id not null;
  key tablename : abap.char(30) not null;
  singletonid : abap.int1;
  active : abap_boolean;
  approvedby : syuname;
  description : abap.char(60);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
