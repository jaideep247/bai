@EndUserText.label : 'FMON: legacy status value to stage (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_fmon_srcmap {
  key mandt        : abap.clnt not null;
  key src_id       : abap.char(10) not null;
  // Value of the source's status field; '*' = every other value
  key status_value : abap.char(40) not null;
  // GENERATED_IN_SAP ... NACK_REJECTED / FILE_RECEIVED ... FAILED
  stage            : abap.char(20);
  info             : abap.char(60);
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Values without a row (and without '*') raise UNMAPPED_STATUS (W) - never silently dropped.
