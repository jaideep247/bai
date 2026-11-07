@EndUserText.label : 'Ops suite: monitor freshness per area'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_ops_moncfg {
  key mandt       : abap.clnt not null;
  key pe_area     : abap.char(4) not null;
  // Minutes after the last completed run before the monitor counts as stale (> 0). Read by the
  // "as of" CDS views (LEFT OUTER JOIN, delivered literal without a row) and first by the HCK
  // self-check. Time zone per area: not here (future; dashboards compare UTC time stamps).
  stale_after_min : abap.int4;
  description     : abap.char(60);
  changed_by      : syuname;
  changed_at      : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
