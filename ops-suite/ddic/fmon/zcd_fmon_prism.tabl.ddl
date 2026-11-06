@EndUserText.label : 'FMON: PRISM status events (PRISM status API)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_fmon_prism {
  key mandt     : abap.clnt not null;
  // PRISM's unique event ID (idempotency key: a re-sent event is answered, never stored twice)
  key event_id  : abap.char(64) not null;
  // fileReference as sent: file name SAP generated / PRISM delivered, or the message reference
  // of an API flow; FMON reads it as FILE_NAME_FIELD (same file-key rules as other sources)
  file_ref      : abap.char(255);
  // interfaceId as sent (evidence; FMON resolves the interface by name pattern)
  iface_id      : abap.char(20);
  // O outbound (SAP -> PRISM -> target), I inbound (source -> PRISM -> SAP)
  direction     : abap.char(1);
  // RECEIVED, DELIVERED, FAILED (ZCD_FMON_SRCMAP maps them to PRISM_RECEIVED / _DELIVERED / _FAILED)
  milestone     : abap.char(10);
  // PRISM's own time of the milestone (UTC)
  occurred_at   : timestampl;
  // Bank, IRIS, BLACKLINE, OFSAA, STRIPE, BRIDGER, source system ... (format checked only)
  counterparty  : abap.char(20);
  prism_ref     : abap.char(64);
  record_count  : abap.int4;
  // recordCount was sent (X); blank = not reported (not zero)
  count_sent    : abap_boolean;
  control_total : abap.dec(23,2);
  currency      : waers;
  error_code    : abap.char(20);
  // Masked (runs of 8+ digits keep the last 4) and truncated; must not carry member / bank data
  error_text    : abap.char(255);
  // occurredAt converted to FMON_TIME_ZONE (the generic adapter's TS_FIELD rule)
  business_date : abap.dats;
  // SAP receipt of the call (UTC) and the technical user that called
  received_at   : timestampl;
  received_by   : syuname;
  // FMON applied the event (instant bgPF unit); initial = the 5-minute run reads it (safety net)
  processed_at  : timestampl;
}
// Secondary indexes (serialized to abapGit by tools/abapgit_serialize.py):
//   UNP: the 5-minute run reads unprocessed events received in its window (ZCL_CD_FMON_ADAPTER_PRISM)
//   REF: trace / dashboard lookup by file reference
//   BDT: dashboards and retention by business date
// @index UNP: MANDT, PROCESSED_AT, RECEIVED_AT
// @index REF: MANDT, FILE_REF
// @index BDT: MANDT, BUSINESS_DATE
// Retention: 400 days (purge target to be added to ZCL_CD_OPS_PURGE, see docs/PRISM_Status_API.md)
