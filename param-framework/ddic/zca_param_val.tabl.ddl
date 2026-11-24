// Parameter values: rows of a parameter, ordered by NUMB. Kind P has at most one row.
// Delivery class C, table logging on (SCU3), fully buffered, maintained in SM30 / SPRO. Foreign key (AREA, NAME) -> ZCA_PARAM_DEF.
@EndUserText.label : 'Parameter framework: values'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_param_val {
  key client            : abap.clnt not null;
  key area              : zca_param_area_id not null;
  @AbapCatalog.foreignKey.screenCheck : true
  key name              : zca_param_name not null
    with foreign key [0..*,1] zca_param_def
      where client = zca_param_val.client
        and area = zca_param_val.area
        and name = zca_param_val.name;
  // context of the rows (blank = any); only dimensions declared on the definition may be filled
  key ctx1              : zca_param_ctx1 not null;
  key ctx2              : zca_param_ctx2 not null;
  key ctx3              : zca_param_ctx3 not null;
  key ctx4              : zca_param_ctx4 not null;
  key numb              : zca_param_numb not null;
  sign                  : zca_param_sign;
  opti                  : zca_param_option;
  low                   : zca_param_value;
  high                  : zca_param_value;
}
