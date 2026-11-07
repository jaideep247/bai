// Parameter values: rows of a parameter, ordered by NUMB. Kind P has at most one row.
// Delivery class C, table logging on, fully buffered. Foreign key (AREA, NAME) -> ZCA_PARAM_DEF.
@EndUserText.label : 'Parameter framework: values'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_param_val {
  key client            : abap.clnt not null;
  key area              : zca_param_area_id not null;
  @AbapCatalog.foreignKey.screenCheck : true
  key name              : zca_param_name not null
    with foreign key [0..*,1] zca_param_def
      where client = zca_param_val.client
        and area = zca_param_val.area
        and name = zca_param_val.name;
  key numb              : zca_param_numb not null;
  sign                  : zca_param_sign;
  opti                  : zca_param_option;
  low                   : zca_param_value;
  high                  : zca_param_value;
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
