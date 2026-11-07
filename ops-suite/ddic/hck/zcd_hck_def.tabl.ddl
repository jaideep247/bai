@EndUserText.label : 'Health check: check definitions (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_hck_def {
  key mandt     : abap.clnt not null;
  key check_id  : abap.char(20) not null;
  description   : abap.char(60);
  // A financial integrity, B mass-run health, C exception queues, D config drift, E technical
  category      : abap.char(1);
  // Plug-in class implementing ZIF_CD_HCK_CHECK
  class_name    : abap.char(30);
  active        : abap_boolean;
  seq           : abap.int4;
  // H high, M medium, L low (score weight, report filter)
  priority      : abap.char(1);
  param1        : abap.char(100);
  param2        : abap.char(100);
  param3        : abap.char(100);
  param4        : abap.char(100);
  package_size  : abap.int4;
  // 0 = ZCA_PARAM HCK_TIMEOUT_SEC (default 300)
  timeout_sec   : abap.int4;
  changed_by    : syuname;
  changed_at    : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Alert routing is not a column here: ZCD_OPS_ALRULE matches on payment engine area HCK and GROUP2 = check id.
