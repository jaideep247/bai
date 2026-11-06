@EndUserText.label : 'EBS: rule registry (rule id -> class)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_ebs_rule_def {
  key mandt        : abap.clnt not null;
  key rule_id      : abap.char(10) not null;
  // S statement / L line
  rule_level       : abap.char(1);
  // Implements ZIF_CD_EBS_RULE
  class_name       : seoclsname;
  default_severity : abap.char(1);
  default_action   : abap.char(10);
  description      : abap.char(60);
  active           : abap_boolean;
}
