@EndUserText.label : 'FMON: stage SLA per interface (duration or deadline)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_fmon_sla {
  key mandt    : abap.clnt not null;
  key iface_id : abap.char(20) not null;
  // Stage that must be reached, e.g. SENT_TO_PRISM, ACK_RECEIVED, FULLY_PROCESSED
  key stage    : abap.char(20) not null;
  // DURATION: within MAX_MINUTES of the basis stage (check ZCL_CD_FMON_CHK_SLA);
  // DEADLINE: by DUE_TIME of a business day (check ZCL_CD_FMON_CHK_DEADLINE; was ZCD_FMON_DEADL,
  // table consolidation 2026-11-08)
  key kind     : abap.char(8) not null;
  // NORMAL, MONTH_END, RETURNS_DAY or * (every day); a DEADLINE of MONTH_END / RETURNS_DAY falls
  // back to NORMAL, then *. A DURATION row is * (every day). A deadline is never evaluated on a
  // holiday or when ZCD_FMON_CAL expects no file.
  key day_type : abap.char(12) not null;
  // DURATION only (> 0; blank for DEADLINE)
  max_minutes  : abap.int4;
  // DURATION only: P = measured from the previous stage, G = from generation / first event
  basis        : abap.char(1);
  // DEADLINE only: clock time of the business day in the time zone of parameter FMON_TIME_ZONE
  due_time     : abap.tims;
  // Severity when the stage is overdue / the deadline is missed (DURATION: late arrival uses check
  // parameter LATE_SEVERITY; DEADLINE: blank = severity of the check row)
  severity     : abap.char(1);
  // Production edits an existing row (switched off here, never deleted); new rows by transport
  active       : abap_boolean;
  description  : abap.char(60);
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read once per run, active rows of both kinds (ZCL_CD_FMON_DAO=>GET_SLAS); each check filters its kind.
