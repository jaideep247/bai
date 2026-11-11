@EndUserText.label : 'Ops framework: payment model dimension texts'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_pmdim {
  key mandt     : abap.clnt not null;
  // Language of the text (one row per language; translated rows travel by transport)
  key langu     : spras not null;
  // Dimension of the payment model: FLOW, SOURCE, TRANSACTION, REQ_STATUS, PAY_STATUS, METHOD_CLASS
  key dimension : abap.char(20) not null;
  // Value as the consumer's adapter view delivers it (e.g. a source system code or a payment status)
  key dim_value : abap.char(40) not null;
  // Text shown on the cards instead of the technical value (business users: no technical codes)
  text          : abap.char(60);
  // Display order of the value on cards and in value helps (0 = after the ordered values)
  seq           : abap.int4;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read only by CDS (ZI_CA_PaymDimText): texts and order of the dimension values of every consumer's payment
// model (docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md). A value without a row is shown as delivered.
