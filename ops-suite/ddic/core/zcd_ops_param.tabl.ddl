@EndUserText.label : 'Ops suite: runtime parameters (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_ops_param {
  key mandt     : abap.clnt not null;
  key param_name : abap.char(30) not null;
  param_value   : abap.char(255);
  description   : abap.char(60);
  changed_by    : syuname;
  changed_at    : timestampl;
}
