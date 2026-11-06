@EndUserText.label : 'FMON: file event audit trail'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_fmon_event {
  key mandt    : abap.clnt not null;
  key file_id  : sysuuid_x16 not null;
  key event_no : abap.int4 not null;
  // Stage as reported by the source (also when capped or ignored by the state machine)
  stage        : abap.char(20);
  event_at     : timestampl;
  // Source adapter, or LOT for outcomes derived from returns/NOC lot completeness
  src_id       : abap.char(10);
  // File reference of the source rows (LOT: file ID in hex)
  src_key      : abap.char(70);
  record_count : abap.int4;
  amount       : abap.dec(23,2);
  info         : abap.char(255);
  created_by   : syuname;
  created_at   : timestampl;
}
// Secondary index ZCD_FMON_EVENT~SRC (UNIQUE): MANDT, SRC_ID, SRC_KEY, STAGE  (idempotent event insert)
