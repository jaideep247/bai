@EndUserText.label : 'Ops framework: payment file evidence'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_pfevt {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  // Evidence at source grain (docs/PAYMENT_FILE_LIFECYCLE.md section 6): SHA-1 of source, source event ID, event
  // version, file and payment - the same observation read twice (overlapping windows) is stored once
  key event_key : abap.char(40) not null;
  // File the event belongs to (blank = observed but not matched to a file: CORR_QUALITY U)
  file_id       : sysuuid_x16;
  milestone     : abap.char(10);
  outcome       : abap.char(10);
  native_status : abap.char(30);
  source_id     : abap.char(10);
  // SAP, MW (middleware / transfer), BANK
  source_type   : abap.char(4);
  // Logical system and client of the record (blank = this system)
  logsys        : abap.char(10);
  sys_client    : abap.char(3);
  bukrs         : bukrs;
  // The file's key as the source names it and the source's own record / message / bank reference ID and version
  native_key    : abap.char(70);
  source_event_id : abap.char(70);
  event_version : abap.int4;
  // When it happened at the source (UTC) and when the product read it (UTC); business date of the source
  occurred_at   : timestampl;
  observed_at   : timestampl;
  bus_date      : abap.dats;
  amount        : abap.dec(23,2);
  currency      : abap.char(5);
  item_count    : abap.int4;
  // Granularity: F file, B batch (BATCH_ID), P payment (PAY_KEY)
  ack_scope     : abap.char(1);
  batch_id      : abap.char(35);
  pay_key       : abap.char(40);
  // C confirmed by a key, P probable (time window, heuristic), U unmatched
  corr_quality  : abap.char(1);
  // Repeated bank reference: number of earlier events of the source with the same source event ID (0 = first)
  repeat_no     : abap.int4;
  // Link registry object and key values ("FIELD=value;...") the walker can start from
  link_object   : abap.char(30);
  link_value    : abap.char(200);
  info          : abap.char(120);
  created_at    : timestampl;
}
// FIL: the evidence of a file; SRC: repeated references of a source
// @index FIL: MANDT, AREA, FILE_ID
// @index SRC: MANDT, AREA, SOURCE_ID, SOURCE_EVENT_ID
