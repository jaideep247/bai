@EndUserText.label : 'Ops framework: alert correlation rules'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_corr {
  key mandt     : abap.clnt not null;
  // Area of the findings (a parameter area of ZCA_PARAM)
  key area      : zca_param_area_id not null;
  // Rule ID; when several active rules of the area select a finding, the lowest ID decides
  key corr_rule : abap.char(10) not null;
  description   : abap.char(60);
  // PCRE on the check code of the finding (complete value, case ignored); blank = every check code
  check_pattern : abap.char(35);
  // Finding fields the correlation key is built from, comma list in order (OBJECT_KEY, OBJECT_TYPE, GROUP1,
  // GROUP2, RULE_ID, CHECK_CODE), joined with '|'; the company code is always part of the key
  key_fields    : abap.char(60);
  // Optional PCRE with one capture group applied to the joined value (complete value, case ignored): the key
  // is the captured text; blank = the joined value; no match = the finding is not correlated
  key_pattern   : abap.char(70);
  // Minutes after the first exception of a key (the parent) during which later ones become its children
  window_min    : abap.int4;
  active        : abap_boolean;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Applied by the store when it records new open exceptions (ZCL_CA_OPS_CORRELATOR); the parent / child mark
// is ZCA_OPS_FINDING-CORR_ID / CORR_ROLE / CORR_KEY. New rows only by transport (DV1).
