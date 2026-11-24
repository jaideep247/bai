// Parameter definitions: one row per parameter (area + name is the only identity).
// Delivery class C, table logging on (SCU3), fully buffered, maintained in SM30 / SPRO. Foreign key AREA -> ZCA_PARAM_AREA.
@EndUserText.label : 'Parameter framework: definitions'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_param_def {
  key client            : abap.clnt not null;
  @AbapCatalog.foreignKey.screenCheck : true
  key area              : zca_param_area_id not null
    with foreign key [0..*,1] zca_param_area
      where client = zca_param_def.client
        and area = zca_param_def.area;
  key name              : zca_param_name not null;
  kind                  : zca_param_kind;
  value_type            : zca_param_vtype;
  min_value             : zca_param_value;
  max_value             : zca_param_value;
  default_value         : zca_param_value;
  allowed_pcre          : zca_param_value;
  interface_name        : seoclsname;
  mandatory             : zca_param_mandatory;
  // context dimensions (e.g. SOURCE, TRANS_TYPE): value rows may be maintained per context;
  // dimension 1 is the most significant in the access sequence (docs/DESIGN.md section 3a)
  dim1                  : zca_param_dim1;
  dim2                  : zca_param_dim2;
  dim3                  : zca_param_dim3;
  dim4                  : zca_param_dim4;
  description           : zca_param_descr;
}
