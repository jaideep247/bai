@EndUserText.label : 'Payment worklist: open payments, requests, exceptions'
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
  // payment document = DFKKOP-AUGBL = DPAYH-DOC1R; blank = a payment request row (FIN + source)
  key augbl       : abap.char(12) not null;
  // payment run of the document evaluated (latest DPAYH row: run date, then run ID, descending)
  key laufd       : abap.dats not null;
  key laufi       : abap.char(6) not null;
  // start of the row (UTC): open rows keep the instant they were first seen, exception versions
  // the instant of the change
  key valid_from  : timestamp not null;
  // end of the version (UTC); 99991231235959 = current row
  valid_to        : timestamp;
  // IN_FLIGHT / PENDING (open) / UNDETERMINED / INCONSISTENT / AMBIGUOUS / final outcomes (closing
  // version of an exception only) / REQ_OPEN / REQ_NOT_PAID / REQ_PAID_LATE
  // (ZIF_CD_OPS_PAYOUT_TYPES=>GC_OUTCOME)
  outcome         : abap.char(20);
  // deciding evidence kind (ZCD_HCK_CLRRULE-EVIDENCE_CLASS) and its short reference; for a request
  // row the stage reached (PRQ_NO_ITEM, PRQ_PAYMENT_BLOCK, PRQ_NOT_IN_RUN, PRQ_CLEARED_NO_RUN,
  // PRQ_PAID_LATE) and its text
  evidence_kind   : abap.char(30);
  evidence_ref    : abap.char(100);
  // primary finding code (blank = open row, no exception); PAY_STATUS_PENDING = the bank evidence
  // decides but the payment status job has not followed yet; PAYMENT_NOT_CLEARED = late beyond the
  // AMBER / RED age of A_INFLIGHT; PRQ_NOT_PAID = request not paid by the end of its due date
  finding         : abap.char(30);
  // severity of the primary finding (E / W / I, blank = none)
  severity        : abap.char(1);
  // time of the evaluation that wrote the row (UTC)
  evaluated_at    : timestamp;
  // flow + method class of the payment (e.g. DWIR, posting area ZPMC; blank for a request row)
  flow_class      : abap.char(4);
  // due date of a payment request (requested payment date, cut-off per source, next business day)
  due_date        : abap.dats;
}
// Exceptions-only worklist (user decision 2026-11-08, was: a version for every payment). Written
// only by ZCL_CD_OPS_PAY_SNAPSHOT (program ZCD_OPS_PAY_SNAPSHOT: FAST every 5 minutes as step 2 of
// ZCD_FMON_MONITOR_ALL, NIGHTLY once a night, SWEEP on demand); read by A_INFLIGHT, A_PRQ_NOT_PAID,
// the transactions dashboard (ZI_CD_PayWorkItem), the payment trace and the purge.
//   - a payment with a final, clean outcome (CLEARED / RETURNED / RETRIEVED / VOIDED / REVERSED, no
//     finding) has no row: its open row is deleted; detail stays in the standard tables;
//   - an open payment (in flight within the AMBER age, incl. uncashed cheques) and an open request
//     (not yet due) keep ONE current row, changed in place (no history);
//   - an exception (any finding) keeps its versions; when it closes (clean outcome, request paid late)
//     its last version is closed and a closing version (VALID_FROM = VALID_TO) records how it ended.
// No copies: amounts, dates, partner and method stay in DPAYH / DFKKOP / FEBEP / ZCD_PAYM_REQ_LOG and
// are joined by key. A payment without an item with a FIN has FIN_ID and SOURCE blank.
// @index DAT: MANDT, BUKRS, LAUFD
// @index OUT: MANDT, OUTCOME, VALID_TO
// @index FIN: MANDT, FIN_ID, SOURCE
// @index DOC: MANDT, AUGBL
// @index DUE: MANDT, DUE_DATE
// Retention (2026-11-08): ZCD_OPS_PURGE deletes versions closed before the cutoff (exception history:
// RETENTION_DAYS_PAY_OUTCOME, 90 days after the exception closed) and a current row with a final
// outcome whose run is before the cutoff; an open row is never deleted.
