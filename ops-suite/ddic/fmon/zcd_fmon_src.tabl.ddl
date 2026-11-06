@EndUserText.label : 'FMON: legacy source adapter (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_fmon_src {
  key client      : abap.clnt not null;
  key src_id      : abap.char(10) not null;
  // Blank = derive the interface from the file name pattern
  iface_id        : abap.char(20);
  // Existing custom table, e.g. ZCDT_REGUT, ZCD_ACH_ACK (names validated against the DDIC at runtime)
  table_name      : abap.char(30);
  // Cross-source correlation key; blank = file name is the key
  file_key_field  : abap.char(30);
  file_name_field : abap.char(30);
  // DATS field, or TS_FIELD (DEC timestamp, UTC); TIME_FIELD optional
  date_field      : abap.char(30);
  time_field      : abap.char(30);
  ts_field        : abap.char(30);
  // Blank = every row reports DEFAULT_STAGE
  status_field    : abap.char(30);
  count_field     : abap.char(30);
  amount_field    : abap.char(30);
  size_field      : abap.char(30);
  checksum_field  : abap.char(30);
  source_field    : abap.char(30);
  lob_field       : abap.char(30);
  default_stage   : abap.char(20);
  // Blank = ZCL_CD_FMON_ADAPTER_GENERIC; else a class implementing ZIF_CD_FMON_ADAPTER
  adapter_class   : abap.char(30);
  active          : abap_boolean;
  description     : abap.char(60);
}
