@EndUserText.label : 'Example: scheduler plan export'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zxx_xrun_plan {
  key mandt     : abap.clnt not null;
  // One run of the external scheduler's daily plan as its export delivers it (loaded by the site's own file
  // transfer; the product never writes it)
  key plan_date : abap.dats not null;
  key sched_folder : abap.char(40) not null;
  key sched_job : abap.char(64) not null;
  key run_id    : abap.char(40) not null;
  // Planned start in the system time of the SAP server
  plan_time     : abap.tims;
  // The scheduler's own status word: WAITING, RUNNING, OK, NOTOK, HOLD (mapped by the example class)
  status        : abap.char(10);
  status_at     : timestampl;
  pred_folder   : abap.char(40);
  pred_job      : abap.char(64);
  // When the export was loaded: the freshness of the plan
  loaded_at     : timestampl;
}
