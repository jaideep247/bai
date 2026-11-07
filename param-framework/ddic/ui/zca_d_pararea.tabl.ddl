// Draft table of entity Area (ZR_CA_ParamArea); field names = CDS element names.
@EndUserText.label : 'Draft: parameter areas'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_pararea {
  key mandt          : abap.clnt not null;
  key area           : zca_param_area_id not null;
  description        : zca_param_descr;
  ownerteam          : zca_param_owner;
  prodeditable       : zca_param_prod_edit;
  active             : zca_param_active;
  transportrequest   : trkorr;
  createdby          : abp_creation_user;
  createdat          : abp_creation_tstmpl;
  lastchangedby      : abp_lastchange_user;
  lastchangedat      : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin"           : include sych_bdl_draft_admin_inc;
}
