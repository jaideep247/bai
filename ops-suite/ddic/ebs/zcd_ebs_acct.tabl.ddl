@EndUserText.label : 'EBS: house bank account configuration'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_ebs_acct {
  key client   : abap.clnt not null;
  key bukrs    : abap.char(4) not null;
  key hbkid    : abap.char(5) not null;
  key hktid    : abap.char(5) not null;
  // Account number as the bank sends it (BAI2 03 / CAMT Acct/Id)
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
}
// Secondary index ZCD_EBS_ACCT~ACC : CLIENT, ACCOUNT_NO (file statements)
