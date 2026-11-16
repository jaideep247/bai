@EndUserText.label : 'Ops framework: payment file types'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_pftyp {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  // Payment file type of the site (docs/PAYMENT_FILE_LIFECYCLE.md section 5): one kind of outgoing payment file,
  // e.g. one payment method to one bank - its milestones, deadlines and adapters are configured per type
  key file_type : abap.char(10) not null;
  description   : abap.char(60);
  // Business process of the area (ZCA_OPS_PROC): owner of the findings when no control covers the check
  process_id    : abap.char(20);
  // D = disbursement (money leaves), C = collection (money is collected from the payer's bank)
  direction     : abap.char(1);
  // Granularity of the bank acknowledgement: F file, B batch, P payment, N none (the file type has no ACK)
  ack_level     : abap.char(1);
  // X = one acknowledgement may cover several files (an ACK of the bank names more than one file)
  ack_multi     : abap_boolean;
  // Business calendar: factory calendar ID (SCAL) and the time zone of the clock times of the type
  calendar_id   : abap.char(2);
  time_zone     : abap.char(6);
  // Overnight cut-off (local time): a file generated at or after it belongs to the next business date (initial = none)
  day_cutoff    : abap.tims;
  // Files expected per business day (0 = none expected; with ZERO_OK = X a business day without files is valid)
  expected_files : abap.int4;
  zero_ok       : abap_boolean;
  // A source whose data is older than this many minutes is stale: its milestones are unknown, never missing (0 = parameter)
  stale_min     : abap.int4;
  // Days a file stays under watch after its business date (0 = parameter PF_OPEN_DAYS)
  open_days     : abap.int4;
  active        : abap_boolean;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by ZCL_CA_OPS_PF_DAO=>GET_FILE_TYPES (ingestion, check) and the worklist CDS (ZI_CA_OpsPfFile).
