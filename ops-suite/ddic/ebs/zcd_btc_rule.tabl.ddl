@EndUserText.label : 'EBS: rule assignment per rule group (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_btc_rule {
  key mandt      : abap.clnt not null;
  // Rule group of ZCD_BTC_MAP, or * for every statement / every mapped line
  key rule_group : abap.char(10) not null;
  // R01..R20, S01..S12 (ZCD_EBS_RULE_DEF)
  key rule_id    : abap.char(10) not null;
  seq            : abap.int2;
  // Overrides the registry default when filled: B / E / W / I
  severity       : abap.char(1);
  action         : abap.char(10);
  param1         : abap.char(40);
  param2         : abap.char(40);
  param3         : abap.char(40);
  tolerance      : abap.dec(15,2);
  window_days    : abap.int4;
  active         : abap_boolean;
  changed_by     : syuname;
  changed_at     : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
