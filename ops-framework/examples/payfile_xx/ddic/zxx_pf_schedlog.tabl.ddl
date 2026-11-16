@EndUserText.label : 'Example XX: scheduler run log'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zxx_pf_schedlog {
  key mandt     : abap.clnt not null;
  // The run of the customer's own scheduler that created the payment medium of a payment run (not SAP jobs)
  key run_key   : abap.char(40) not null;
  job_name      : abap.char(32);
  run_date      : abap.dats;
  run_id        : abap.char(5);
  bukrs         : bukrs;
  // DONE, ABEND, RUN
  status        : abap.char(6);
  ended_at      : timestampl;
}
