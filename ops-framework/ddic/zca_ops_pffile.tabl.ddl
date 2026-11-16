@EndUserText.label : 'Ops framework: payment file register'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_pffile {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  // One payment file as the file source adapter knows it (docs/PAYMENT_FILE_LIFECYCLE.md section 4); written only by
  // ZCL_CA_OPS_PF_DAO (ingestion ZCA_OPS_PF_RUN); identity = area, file type and native key
  key file_id   : sysuuid_x16 not null;
  file_type     : abap.char(10);
  source_id     : abap.char(10);
  // The file's own key in its source (file name, payment medium key, group key of the run) - never changes
  native_key    : abap.char(70);
  bukrs         : bukrs;
  // Payment run that produced the file (FI-CA: run date and run ID; blank when the source knows none)
  run_date      : abap.dats;
  run_id        : abap.char(5);
  pay_method    : abap.char(10);
  house_bank    : abap.char(5);
  account_id    : abap.char(5);
  // Business date (from the source, else the local generation date with the overnight cut-off and calendar)
  bus_date      : abap.dats;
  gen_at        : timestampl;
  // The SAP job that generated the file (scheduler adapter; blank = not known)
  gen_job       : abap.char(32);
  gen_jobcount  : abap.char(8);
  // Reissue: the file this one replaces (same payments in a new file); blank = an original
  predecessor   : sysuuid_x16;
  // Payments the source says the file holds, payments whose amount is not known, X = the payment list was cut
  // (PF_MAX_PAYMENTS) - the figures of the worklist are then a lower bound and the evaluation partial
  pay_count     : abap.int4;
  unknown_count : abap.int4;
  pay_partial   : abap_boolean;
  // Lifecycle (ZCL_CA_OPS_PF_LIFECYCLE): the last milestone reached in order (where the process stopped), the next
  // required milestone not reached, the state of the file (OPEN, DONE, REJECTED, PARTIAL, FAILED, REPLACED), its
  // deadline (UTC) and the minutes it is overdue (0 = not overdue)
  stage         : abap.char(10);
  next_ms       : abap.char(10);
  state         : abap.char(10);
  deadline_at   : timestampl;
  overdue_min   : abap.int4;
  calendar_id   : abap.char(2);
  // Acknowledgement: X = the bank sent accepted and rejected for the same scope; payments (or batches) rejected
  // and not yet answered; the first milestone reached after its deadline and by how many minutes
  ack_conflict  : abap_boolean;
  pay_rejected  : abap.int4;
  pay_open      : abap.int4;
  late_ms       : abap.char(10);
  late_min      : abap.int4;
  // Evaluation: C complete, P partial, N not evaluated (a source failed), S a source is stale; the reason and the
  // last complete evaluation (its state is kept when a later evaluation could not be made)
  eval_state    : abap.char(1);
  eval_reason   : abap.char(255);
  eval_at       : timestampl;
  last_valid_at : timestampl;
  last_valid_state : abap.char(10);
  // Ticket sink: the reference the ticket sink returned for the file (log-only sink: LOGGED)
  ticket_ref    : abap.char(40);
  created_at    : timestampl;
  changed_at    : timestampl;
}
// NAT: identity of a file in its source; BDT: files of a business date (day expectation, worklist)
// @index NAT: MANDT, AREA, FILE_TYPE, NATIVE_KEY
// @index BDT: MANDT, AREA, BUS_DATE
