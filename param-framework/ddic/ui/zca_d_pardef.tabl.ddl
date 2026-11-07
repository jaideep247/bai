// Draft table of entity Definition (ZR_CA_ParamDef); field names = CDS element names.
@EndUserText.label : 'Draft: parameter definitions'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_pardef {
  key mandt          : abap.clnt not null;
  key area           : zca_param_area_id not null;
  key name           : zca_param_name not null;
  kind               : zca_param_kind;
  valuetype          : zca_param_vtype;
  minvalue           : zca_param_value;
  maxvalue           : zca_param_value;
  defaultvalue       : zca_param_value;
  allowedpcre        : zca_param_value;
  interfacename      : seoclsname;
  mandatory          : zca_param_mandatory;
  developerowned     : zca_param_dev_owned;
  description        : zca_param_descr;
  owner              : zca_param_owner;
  createdby          : abp_creation_user;
  createdat          : abp_creation_tstmpl;
  lastchangedby      : abp_lastchange_user;
  lastchangedat      : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin"           : include sych_bdl_draft_admin_inc;
}
