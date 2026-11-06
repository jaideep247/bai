@EndUserText.label : 'Health check: tables under config drift control'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_hck_drift {
  key mandt     : abap.clnt not null;
  key tabname   : abap.char(30) not null;
  description   : abap.char(60);
  active        : abap_boolean;
  changed_by    : syuname;
  changed_at    : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Only customizing tables (small). The hash reads the whole table ordered by primary key.
