@EndUserText.label : 'Ops framework: payments of a payment file'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_pfpay {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  key file_id   : sysuuid_x16 not null;
  // The payment's key in its source (FI-CA: run date / run ID / payment number / sub-number); at most
  // PF_MAX_PAYMENTS per file are kept, the rest is counted in ZCA_OPS_PFFILE-PAY_COUNT
  key pay_key   : abap.char(40) not null;
  bukrs         : bukrs;
  // Amount in its own currency (never summed across currencies); AMOUNT_KNOWN blank = the source has no amount
  currency      : abap.char(5);
  amount        : abap.dec(23,2);
  amount_known  : abap_boolean;
  // Payee shown masked only (the full number is never stored)
  partner_masked : abap.char(20);
  // Payment document of the payment (FI-CA: DPAYH-DOC1R)
  pay_doc       : abap.char(24);
  pay_method    : abap.char(10);
  // Batch of the file the payment belongs to (batch-level acknowledgement)
  batch_id      : abap.char(35);
  // Payment-level acknowledgement: outcome and time (blank = none)
  ack_outcome   : abap.char(10);
  ack_at        : timestampl;
  // Another file of the area that carries the same payment (reissue): possible duplicate exposure
  other_file    : sysuuid_x16;
}
// PAY: the files of a payment (reissue and duplicate exposure, payment-level ACK)
// @index PAY: MANDT, AREA, PAY_KEY
