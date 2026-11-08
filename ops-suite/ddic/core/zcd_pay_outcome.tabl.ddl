@EndUserText.label : 'Payment outcome: canonical verdict per payment, history'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_pay_outcome {
  key mandt       : abap.clnt not null;
  // FIN number of the payment request (= DFKKOP-ZZ_FIN_TRANS_NUM; width VERIFY-SE11)
  key fin_id      : abap.char(35) not null;
  // source of the request (ZCD_PAYM_REQ_LOG SOURCE, SUCCESS row rule); blank = no request row
  key source      : abap.char(10) not null;
  key bukrs       : abap.char(4) not null;
  // payment document = DFKKOP-AUGBL = DPAYH-DOC1R
  key augbl       : abap.char(12) not null;
  // payment run of the document evaluated (latest DPAYH row: run date, then run ID, descending)
  key laufd       : abap.dats not null;
  key laufi       : abap.char(6) not null;
  // start of the version (UTC); a version is written only when the outcome changes
  key valid_from  : timestamp not null;
  // end of the version (UTC); 99991231235959 = current version
  valid_to        : timestamp;
  // IN_FLIGHT / CLEARED / RETURNED / RETRIEVED / VOIDED / PENDING / UNDETERMINED / INCONSISTENT /
  // AMBIGUOUS / REVERSED (ZIF_CD_OPS_PAYOUT_TYPES=>GC_OUTCOME)
  outcome         : abap.char(20);
  // deciding evidence kind (ZCD_HCK_CLRRULE-EVIDENCE_CLASS) and its short reference
  evidence_kind   : abap.char(30);
  evidence_ref    : abap.char(100);
  // primary finding code of the payment (blank = none)
  finding         : abap.char(30);
  // time of the evaluation that wrote the version (UTC)
  evaluated_at    : timestamp;
}
// Written only by the 5-minute snapshot ZCL_CD_OPS_PAY_SNAPSHOT (job step ZCD_OPS_PAY_SNAPSHOT of
// ZCD_FMON_MONITOR_ALL); read by the transactions dashboard (ZI_CD_PayOutcome*) and the purge.
// No copies: amounts, dates, partner and method stay in DPAYH / DFKKOP / FEBEP / ZCD_PAYM_REQ_LOG
// and are joined by key. History exists from go-live only.
// @index DAT: MANDT, BUKRS, LAUFD
// @index OUT: MANDT, OUTCOME, VALID_TO
// @index FIN: MANDT, FIN_ID, SOURCE
// Retention (2026-11-08): ZCD_OPS_PURGE deletes versions closed before the cutoff and the current
// version of a payment whose outcome is final (CLEARED, RETURNED, RETRIEVED, VOIDED, REVERSED -
// ZCL_CD_OPS_PAY_OUTCOME=>FINAL_OUTCOMES) and whose run is before the cutoff (parameter
// RETENTION_DAYS_PAY_OUTCOME, 90 days); the current version of a payment that is not final is never
// deleted - A_INFLIGHT counts every payment in flight from it.
