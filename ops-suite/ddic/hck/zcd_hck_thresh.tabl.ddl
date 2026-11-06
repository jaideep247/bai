@EndUserText.label : 'Health check: thresholds and baselines (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_hck_thresh {
  key client      : abap.clnt not null;
  key check_id    : abap.char(20) not null;
  // metric name or '*' (all metrics of the check)
  key metric      : abap.char(30) not null;
  // company code / 4-char dimension value of DIM1, or '*' = default row
  key bukrs       : abap.char(4) not null;
  amber           : abap.dec(23,4);
  red             : abap.dec(23,4);
  // X: value >= limit is bad (zero limit = not set); blank: value <= limit is bad
  higher_is_worse : abap_boolean;
  // NONE / ZSCORE / IQR
  baseline_mode   : abap.char(6);
  // ZSCORE: |z| limit (default 3); IQR: fence factor k (default 1.5)
  z_limit         : abap.dec(5,2);
  // history points read for the baseline (0 = HCK_LOOKBACK_RUNS, default 8)
  lookback_runs   : abap.int4;
  changed_by      : syuname;
  changed_at      : timestampl;
}
