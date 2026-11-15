@EndUserText.label : 'Draft: Account flow tiles from stages'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_flwtil {
  key mandt : abap.clnt not null;
  key area : zca_param_area_id not null;
  key flowid : abap.char(10) not null;
  key tile : abap.char(10) not null;
  key stageid : abap.char(20) not null;
  key role : abap.char(15) not null;
  singletonid : abap.int1;
  side : abap.char(1);
  description : abap.char(60);
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
