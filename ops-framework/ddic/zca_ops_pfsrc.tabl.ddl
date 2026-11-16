@EndUserText.label : 'Ops framework: payment file source state'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_pfsrc {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  // One adapter's source (ZCA_OPS_PFADP-SOURCE_ID): what was read and how fresh it is
  key source_id : abap.char(10) not null;
  role          : abap.char(10);
  // Watermark: end of the last window read completely (UTC); the next read starts PF_OVERLAP_MIN before it
  watermark     : timestampl;
  // Freshness: the time up to which the source says it is complete (its own as-of; UTC)
  as_of         : timestampl;
  last_run_at   : timestampl;
  last_ok_at    : timestampl;
  // S read, P read in part, F failed (not evaluated - never "no events")
  status        : abap.char(1);
  reason        : abap.char(255);
  read_count    : abap.int4;
  unmapped_count : abap.int4;
}
