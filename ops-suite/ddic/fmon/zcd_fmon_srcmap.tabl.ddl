@EndUserText.label : 'FMON: legacy status value to stage (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_fmon_srcmap {
  key client       : abap.clnt not null;
  key src_id       : abap.char(10) not null;
  // Value of the source's status field; '*' = every other value
  key status_value : abap.char(40) not null;
  // GENERATED_IN_SAP ... NACK_REJECTED / FILE_RECEIVED ... FAILED
  stage            : abap.char(20);
  info             : abap.char(60);
}
// Values without a row (and without '*') raise UNMAPPED_STATUS (W) - never silently dropped.
