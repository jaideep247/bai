@EndUserText.label : 'Draft: Payment file adapters'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_pfadp {
  key mandt : abap.clnt not null;
  key area : zca_param_area_id not null;
  key filetype : abap.char(10) not null;
  key role : abap.char(10) not null;
  singletonid : abap.int1;
  sourceid : abap.char(10);
  classname : abap.char(30);
  setting : abap.char(255);
  sourcetype : abap.char(4);
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
