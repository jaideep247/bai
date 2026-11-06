@EndUserText.label : 'EBS: house bank account configuration'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_ebs_acct {
  key mandt    : abap.clnt not null;
  key bukrs    : abap.char(4) not null;
  key hbkid    : abap.char(5) not null;
  key hktid    : abap.char(5) not null;
  // Payment engine bank account, 10 characters, as derived from FEBEP-XBLNR (bank text removed,
  // e.g. JPMC8XX1174412334 -> 8XX1174412; user decision 2026-11-06). Upper case, no leading blank.
  // Only statements whose every line carries an active account are validated and on the dashboard.
  // Bank file source: also matched against the account of the file (BAI2 03 / CAMT Acct/Id)
  account_no   : abap.char(35);
  // JPMC, BOA, PNC ... selects bank-specific ZCD_BTC_MAP rows
  bank_key     : abap.char(15);
  // BAI2 / CAMT053 / CAMT054
  format       : abap.char(8);
  // D disbursement / C collection
  flow_default : abap.char(1);
  currency     : abap.char(5);
  // Bank G/L account for R18
  gl_account   : abap.char(10);
  active       : abap_boolean;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Secondary index ACC: file statements and the payment engine account scope
// @index ACC: MANDT, ACCOUNT_NO
