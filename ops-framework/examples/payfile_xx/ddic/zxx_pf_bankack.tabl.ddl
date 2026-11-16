@EndUserText.label : 'Example XX: bank acknowledgements'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zxx_pf_bankack {
  key mandt     : abap.clnt not null;
  // One answer of the bank as the customer's own inbound program stores it: the bank's reference and its version
  key ack_id    : abap.char(35) not null;
  key version   : abap.int4 not null;
  file_name     : abap.char(70);
  // Payment reference for a payment-level answer (blank = the whole file)
  pay_ref       : abap.char(40);
  // RCVD (received), ACCP (accepted), RJCT (rejected), PART (partly accepted)
  status        : abap.char(4);
  received_at   : timestampl;
  amount        : abap.dec(23,2);
  currency      : abap.char(5);
}
