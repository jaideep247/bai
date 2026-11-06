@EndUserText.label : 'FMON: file registry'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_fmon_file {
  key mandt         : abap.clnt not null;
  key file_id       : sysuuid_x16 not null;
  iface_id          : abap.char(20);
  // Cross-source correlation key (file key field, else file name; upper case)
  file_ref          : abap.char(70);
  direction         : abap.char(1);
  file_type         : abap.char(10);
  source_sys        : abap.char(10);
  lob               : abap.char(10);
  pay_method        : abap.char(10);
  file_name         : abap.char(255);
  business_date     : abap.dats;
  size_bytes        : abap.int8;
  size_known        : abap_boolean;
  record_count      : abap.int4;
  control_total     : abap.dec(23,2);
  checksum          : abap.char(64);
  // Latest stage reached (never regresses)
  stage             : abap.char(20);
  // Terminal outcome: ACK_RECEIVED, NACK_REJECTED, FULLY/PARTIALLY_PROCESSED, FAILED
  outcome           : abap.char(20);
  unprocessed_count : abap.int4;
  ack_count         : abap.int4;
  ack_amount        : abap.dec(23,2);
  // ACK/NACK count reported by the source (X); blank = not reported (not zero)
  ack_known         : abap_boolean;
  nack_count        : abap.int4;
  // Source rows of the first stage (> 1 = generated/received more than once)
  origin_rows       : abap.int4;
  first_event_at    : timestampl;
  last_event_at     : timestampl;
  src_id            : abap.char(10);
  src_key           : abap.char(70);
  created_at        : timestampl;
  changed_at        : timestampl;
  changed_by        : syuname;
}
// Secondary indexes (serialized to abapGit by tools/abapgit_serialize.py):
//   REF (UNIQUE): file instance = interface + reference + business date (audit A49) -
//   identical daily file names are separate instances, never merged
// @index REF UNIQUE: MANDT, IFACE_ID, FILE_REF, BUSINESS_DATE
// @index BDT: MANDT, BUSINESS_DATE, IFACE_ID
// @index OUT: MANDT, OUTCOME, BUSINESS_DATE
// @index NAM: MANDT, FILE_NAME
// @index CHK: MANDT, CHECKSUM
