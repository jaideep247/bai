@EndUserText.label : 'Ops framework: checks covered by a control'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_ctlchk {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  key control_id : abap.char(20) not null;
  // Area of the findings (ZCA_OPS_FINDING-AREA) the row selects
  key check_area : zca_param_area_id not null;
  // Field of the finding compared: RULE_ID, CHECK_CODE or GROUP2 (exact value, one row per value)
  key match_field : abap.char(10) not null;
  key match_value : abap.char(35) not null;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Exact values, not patterns: the status of a control is joined in CDS (overview cards, review app) and a
// PCRE cannot be evaluated in a join; a family of checks is one row per check. Read by ZI_CA_OpsCtlFind.
