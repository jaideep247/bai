@EndUserText.label : 'Payment outcome: watermark per evidence source'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_pay_outwm {
  key mandt   : abap.clnt not null;
  // DOCUMENTS / REVERSALS / STATEMENT / RETURNS / GL / RECHECK (ZIF_CD_OPS_PAYOUT_TYPES=>GC_SOURCE)
  key source  : abap.char(10) not null;
  // last evidence read: entry date / time (documents, reversals, returns, G/L clearing)
  wm_date     : abap.dats;
  wm_time     : abap.tims;
  // last key of that second (document number), statement short key, or recheck cursor (AUGBL)
  wm_key      : abap.char(70);
  // sequence within the key (statement line number ESNUM)
  wm_seq      : abap.int4;
  updated_at  : timestamp;
  // payment documents picked up by the last run of the source
  last_rows   : abap.int4;
}
// One row per evidence source, written by the 5-minute snapshot after each committed package.
// A missing row = first run: the source starts PAYOUT_INITIAL_DAYS before today.
