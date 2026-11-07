@EndUserText.label : 'Health check: settings of evidence kinds (in flight)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_hck_evset {
  key mandt        : abap.clnt not null;
  // set id named in PARAM1 of a ZCD_HCK_CLRRULE row (e.g. STRIPE)
  key set_id       : abap.char(10) not null;
  // setting of the evidence kind: *_FIELD = field of TABLE (DDIC-checked), else values
  key name         : abap.char(20) not null;
  // field / table name or comma list of values; inactive or missing = not configured
  value            : abap.char(40);
  description      : abap.char(60);
  active           : abap_boolean;
  changed_by       : syuname;
  changed_at       : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
