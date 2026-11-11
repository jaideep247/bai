@EndUserText.label : 'Ops framework: feeder systems of the payment model'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_feeder {
  key mandt     : abap.clnt not null;
  // Feeder system = the source value of the payment model (the system that sent the payment request)
  key feeder    : abap.char(10) not null;
  description   : abap.char(60);
  // Deep link into the feeder's own UI: https URL with the placeholder REF in braces for the feeder reference;
  // blank = no link. The browser of the user opens it - the system never calls the feeder
  url_template  : abap.char(255);
  // X = the feeder reference is not sensitive and is shown in full; blank (default) = masked to the last
  // four characters and no deep link is offered
  ref_visible   : abap_boolean;
  // Display order on cards and value helps
  seq           : abap.int4;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read only by CDS (ZI_CA_PaymFeeder). New rows by transport (customizing, as every framework table).
