@EndUserText.label : 'Example XX: intake of payment requests'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zxx_intake {
  key mandt   : abap.clnt not null;
  // Technical number of the intake (one row per payment request received)
  key intake_id : abap.char(20) not null;
  // Logical system of the feeder that sent the request: a payment reference is unique per feeder and company code
  logsys      : abap.char(10);
  bukrs       : abap.char(4);
  // Payment reference of the request; the customer posts it into its custom field ZZXX_PAYREF of the items
  pay_ref     : abap.char(20);
  received_on : abap.dats;
  // NEW, POSTED, PAID, REJECTED
  status      : abap.char(10);
  waers       : abap.char(5);
  amount      : abap.dec(23,2);
}
