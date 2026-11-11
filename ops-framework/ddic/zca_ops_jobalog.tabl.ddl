@EndUserText.label : 'Ops framework: SAP job failure evidence - application logs'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_jobalog {
  key mandt     : abap.clnt not null;
  key jobname   : btcjob not null;
  key jobcount  : btcjobcnt not null;
  // Log number of BALHDR (the messages stay in SLG1 until its expiry; only the header is kept)
  key lognumber : abap.char(20) not null;
  object        : abap.char(20);
  subobject     : abap.char(20);
  extnumber     : abap.char(100);
  log_date      : abap.dats;
  log_time      : abap.tims;
  log_user      : syuname;
  log_prog      : abap.char(40);
  // Error and abort message counters of the header
  msg_cnt_e     : abap.int4;
  msg_cnt_a     : abap.int4;
  // P = linked by step user, program and run time (no BALHDR field names the job)
  quality       : abap.char(1);
}
// Purged with the job (target JOB_EVIDENCE).
