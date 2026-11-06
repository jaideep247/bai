@EndUserText.label : 'FMON: stage SLA per interface (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_fmon_sla {
  key mandt    : abap.clnt not null;
  key iface_id : abap.char(20) not null;
  // Stage that must be reached, e.g. SENT_TO_PRISM, ACK_RECEIVED, FULLY_PROCESSED
  key stage    : abap.char(20) not null;
  max_minutes  : abap.int4;
  // P = measured from the previous stage, G = from generation / first event
  basis        : abap.char(1);
  // Severity when the stage is overdue (late arrival uses check parameter LATE_SEVERITY)
  severity     : abap.char(1);
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
