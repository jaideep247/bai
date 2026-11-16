@EndUserText.label : 'Ops framework: payment files expected per day'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_pfday {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  key file_type : abap.char(10) not null;
  // Expected versus observed per business date (docs/PAYMENT_FILE_LIFECYCLE.md section 7)
  key bus_date  : abap.dats not null;
  // B business day, H holiday or weekend of the file type's calendar
  day_kind      : abap.char(1);
  expected      : abap.int4;
  observed      : abap.int4;
  // OK, ZERO_OK (valid day without files), HOLIDAY, STALE, NOT_EVAL, MISSING, PARTIAL, PENDING
  result        : abap.char(10);
  reason        : abap.char(255);
  // Freshness and watermark of the file source at the evaluation; C complete, P partial, N not evaluated
  as_of         : timestampl;
  watermark     : timestampl;
  completeness  : abap.char(1);
  eval_at       : timestampl;
  // Last result of a complete evaluation (kept when a later one could not be made)
  last_valid_result : abap.char(10);
  last_valid_at : timestampl;
}
