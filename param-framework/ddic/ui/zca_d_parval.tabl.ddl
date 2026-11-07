// Draft table of entity Value (ZR_CA_ParamVal); field names = CDS element names.
@EndUserText.label : 'Draft: parameter values'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_parval {
  key mandt          : abap.clnt not null;
  key area           : zca_param_area_id not null;
  key name           : zca_param_name not null;
  key numb           : zca_param_numb not null;
  sign               : zca_param_sign;
  opti               : zca_param_option;
  low                : zca_param_value;
  high               : zca_param_value;
  createdby          : abp_creation_user;
  createdat          : abp_creation_tstmpl;
  lastchangedby      : abp_lastchange_user;
  lastchangedat      : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin"           : include sych_bdl_draft_admin_inc;
}
