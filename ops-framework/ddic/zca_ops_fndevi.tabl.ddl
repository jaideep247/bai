@EndUserText.label : 'Ops framework: evidence of findings'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_fndevi {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  // Exception contract (docs/EXCEPTION_CONTRACT.md): the evidence key of a finding (ZCA_OPS_FINDING-EVID_KEY, SHA-1
  // of area, check, object key and company code - stable over the carry-forward), replaced by every run that
  // raises the finding again; written only by ZCL_CA_OPS_EVIDENCE through the runner
  key evid_key  : abap.char(40) not null;
  key seq       : abap.int4 not null;
  // SAP, MW (middleware / transfer), BANK, OPS (the product's own record)
  kind          : abap.char(4);
  // RUN, JOB, PAYDOC, FILE, MSG, ACK, STMT, EVENT
  ev_type       : abap.char(10);
  label         : abap.char(60);
  // The record's own key in its source (file name, message ID, ACK reference, job name and count)
  native_key    : abap.char(120);
  // Link registry object and its key values ("FIELD=value;..."): a start of the link walker
  link_object   : abap.char(30);
  link_value    : abap.char(200);
  occurred_at   : timestampl;
  observed_at   : timestampl;
  // C confirmed by a key, P probable, U unmatched
  quality       : abap.char(1);
  source_id     : abap.char(10);
  // Run that wrote the row
  run_id        : sysuuid_x16;
  created_at    : timestampl;
}
