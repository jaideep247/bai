@EndUserText.label : 'Ops framework: payment file milestone status'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_pfmst {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  key file_id   : sysuuid_x16 not null;
  // One configured milestone of the file (stage timeline of the worklist), replaced at every evaluation
  key milestone : abap.char(10) not null;
  seq           : abap.int4;
  required      : abap_boolean;
  // REACHED, LATE (reached after the deadline), IMPLIED (a later milestone was reached), PENDING (deadline not yet
  // passed), MISSING (deadline passed), REJECTED, PARTIAL, FAILED, UNKNOWN (its source failed or is stale)
  status        : abap.char(10);
  outcome       : abap.char(10);
  due_at        : timestampl;
  observed_at   : timestampl;
  late_min      : abap.int4;
  // The evidence row that decided the status (ZCA_OPS_PFEVT)
  event_key     : abap.char(40);
  evaluated_at  : timestampl;
}
