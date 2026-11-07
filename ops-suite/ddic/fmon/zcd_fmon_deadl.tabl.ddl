@EndUserText.label : 'FMON: stage deadline (clock time) per interface'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_fmon_deadl {
  key mandt    : abap.clnt not null;
  key iface_id : abap.char(20) not null;
  // Stage that must be reached, e.g. FULLY_PROCESSED, FILE_RECEIVED, ACK_RECEIVED
  key stage    : abap.char(20) not null;
  // NORMAL, MONTH_END, RETURNS_DAY or * (any business day); MONTH_END / RETURNS_DAY fall back
  // to NORMAL, then *. Never evaluated on a holiday or when ZCD_FMON_CAL expects no file.
  key day_type : abap.char(12) not null;
  // Clock time of the business day in the time zone of parameter FMON_TIME_ZONE
  due_time     : abap.tims;
  // Severity of STAGE_DEADLINE_MISSED (blank = severity of the check row)
  severity     : abap.char(1);
  // Production-maintainable (RAP_Config_Apps.md 2): a row is switched off, never deleted
  active       : abap_boolean;
  description  : abap.char(60);
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
