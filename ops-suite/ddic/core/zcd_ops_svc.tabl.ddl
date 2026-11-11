@EndUserText.label : 'Ops suite: business services of the health score'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_ops_svc {
  key mandt     : abap.clnt not null;
  // Business service shown on the "Service health" card (e.g. COLLECTIONS, DISBURSE, BANKSTMT)
  key service   : abap.char(12) not null;
  // Name on the card
  label         : abap.char(60);
  // Order on the card
  seq           : abap.int4;
  // Points one open finding takes from the score of 100, per severity (multiplied by the weight of the
  // mapping row that caught it); information findings take nothing
  weight_b      : abap.int4;
  weight_e      : abap.int4;
  weight_w      : abap.int4;
  // Points a stale monitor of a mapped area takes (current business date only)
  stale_points  : abap.int4;
  // Score bands: score >= GREEN_MIN = good (green), >= AMBER_MIN = watch (amber), below = critical (red)
  green_min     : abap.int4;
  amber_min     : abap.int4;
  active        : abap_boolean;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read only by CDS (ZR_CD_SvcHealth): the score is computed live from the open findings and the monitor freshness,
// never stored. Delivered rows: config/service_register.csv. New rows only by transport (DV1).
