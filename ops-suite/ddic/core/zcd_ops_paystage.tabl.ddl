@EndUserText.label : 'Ops suite: payment lifecycle stages (overview)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_ops_paystage {
  key mandt     : abap.clnt not null;
  // Stage shown on the payment lifecycle card (e.g. ISSUED)
  key stage     : abap.char(20) not null;
  // Order of the bars
  seq           : abap.int4;
  // Text of the bar
  label         : abap.char(40);
  // Where the stage is counted: PAYRUN = DPAYH-ZZ_PAYMENT_STATUS of the newest payment run row of a payment
  // document (run date = business date); REQUEST = current payment request rows of the worklist
  // ZCD_PAY_OUTCOME due on the business date (outcome or stage = MATCH_VALUE)
  source        : abap.char(10);
  // The status value (PAYRUN) or the worklist outcome / request stage (REQUEST) counted for the stage
  match_value   : abap.char(30);
  active        : abap_boolean;
  // Process flow card (2026-11-11): calendar days after the business date (run date / due date) a payment or
  // request may still be in this stage; older ones are counted as stuck. 0 = no expected time (final stages)
  stuck_days    : abap.int4;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by ZR_CD_PayLifecycle and ZR_CD_PayFlow (overview page, payment lifecycle and process flow cards): counts are computed live from DPAYH and the
// worklist, never stored here. Delivered rows: config/pay_stages.csv. New rows only by transport (DV1).
