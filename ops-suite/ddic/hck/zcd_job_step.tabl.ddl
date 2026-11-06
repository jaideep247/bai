@EndUserText.label : 'Job cycle monitor: cycle steps (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_job_step {
  key mandt       : abap.clnt not null;
  key cycle_id    : abap.char(20) not null;
  key step_no     : abap.numc(3) not null;
  description     : abap.char(60);
  // SM37 job name or pattern (* allowed), e.g. ZCD_PAYM_WIRE_*
  jobname         : abap.char(32);
  // documentation now, used by the retrigger phase later
  program         : abap.char(40);
  variant         : abap.char(14);
  pred_step       : abap.numc(3);
  // step runs on cycle date + offset (0 same day, 1 next day after midnight)
  day_offset      : abap.int1;
  window_from     : abap.tims;
  window_to       : abap.tims;
  max_runtime_min : abap.int4;
  skippable       : abap_boolean;
  critical        : abap_boolean;
  changed_by      : syuname;
  changed_at      : timestampl;
}
