@EndUserText.label : 'BAI System Configuration'
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zbai_config {
  key client      : mandt not null;
  key param_name  : char30 not null;
  
  @AbapCatalog.dataType : #STRING
  @AbapCatalog.fieldLength : 255
  param_value     : abap.string(255);
  
  description     : char100;
  data_type       : char10;
  
  @Semantics.user.lastChangedBy
  changed_by      : syuname;
  
  @Semantics.systemDateTime.lastChangedAt
  changed_at      : timestampl;
}
