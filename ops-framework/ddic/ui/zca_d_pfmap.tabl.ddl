@EndUserText.label : 'Draft: Payment file status mapping'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_pfmap {
  key mandt : abap.clnt not null;
  key area : zca_param_area_id not null;
  key sourceid : abap.char(10) not null;
  key status : abap.char(30) not null;
  singletonid : abap.int1;
  milestone : abap.char(10);
  outcome : abap.char(10);
  description : abap.char(60);
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
