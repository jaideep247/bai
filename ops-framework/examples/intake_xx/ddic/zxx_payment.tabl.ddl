@EndUserText.label : 'Example XX: payment register'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zxx_payment {
  key mandt    : abap.clnt not null;
  // One row per payment as the customer's own payment register keeps it
  key pay_date : abap.dats not null;
  key run_id   : abap.char(10) not null;
  key pay_doc  : abap.char(12) not null;
  bukrs        : abap.char(4);
  // C collection, D disbursement
  flow         : abap.char(1);
  feeder       : abap.char(10);
  pay_status   : abap.char(20);
  pay_method   : abap.char(1);
  house_bank   : abap.char(5);
  account_id   : abap.char(5);
  waers        : abap.char(5);
  amount       : abap.dec(23,2);
}
