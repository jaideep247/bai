@EndUserText.label : 'Health check: thresholds and baselines (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_hck_thresh {
  key mandt       : abap.clnt not null;
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
  // baseline season of a day series (DIM2 = the counted day, DAY mode; 2026-11-11, missing-volume checks):
  // blank = the last LOOKBACK_RUNS runs of the series; DY = the previous LOOKBACK_RUNS days; WD = the same
  // weekday of the previous LOOKBACK_RUNS weeks ("below the usual Monday"). Ignored when DIM2 is not a day
  season          : abap.char(2);
  changed_by      : syuname;
  changed_at      : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
