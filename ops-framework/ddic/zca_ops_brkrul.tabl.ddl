@EndUserText.label : 'Ops framework: break analysis bucket rules'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_brkrul {
  key mandt     : abap.clnt not null;
  // Area of the accounts the rule applies to; * = every area (product rules)
  key area      : zca_param_area_id not null;
  // Rule ID (starts with the prefix of its layer); recorded on the line and the group it explains
  key rule_id   : abap.char(20) not null;
  layer_id      : abap.char(10);
  // Order: the first rule whose conditions all hold explains the line (first match wins)
  seq           : abap.int4;
  bucket        : abap.char(20);
  // Accounts the rule applies to (PCRE on the account ID, complete value; blank = every account)
  acct_pattern  : abap.char(70);
  // Explanation shown with the rule ID on the line and the group (reason text)
  reason        : abap.char(120);
  description   : abap.char(60);
  active        : abap_boolean;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
