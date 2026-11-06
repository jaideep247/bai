@EndUserText.label : 'Job cycle monitor: cycle header (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_job_cycle {
  key mandt     : abap.clnt not null;
  key cycle_id  : abap.char(20) not null;
  description   : abap.char(60);
  // factory calendar (SCAL); blank = every day; non-working days are not monitored
  calendar      : abap.char(2);
  active        : abap_boolean;
  changed_by    : syuname;
  changed_at    : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
