@EndUserText.label : 'Draft: Control guidance per language'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_ctlt {
  key mandt : abap.clnt not null;
  key langu : spras not null;
  key area : zca_param_area_id not null;
  key controlid : abap.char(20) not null;
  singletonid : abap.int1;
  guidance : abap.char(255);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
