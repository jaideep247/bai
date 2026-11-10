@EndUserText.label : 'Draft: Purge targets of consumers'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_purge {
  key mandt : abap.clnt not null;
  key target : abap.char(12) not null;
  singletonid : abap.int1;
  classname : seoclsname;
  paramarea : zca_param_area_id;
  paramname : abap.char(30);
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
