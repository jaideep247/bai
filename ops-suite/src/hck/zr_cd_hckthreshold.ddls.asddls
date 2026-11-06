@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Thresholds'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_HckThreshold
  as select from zcd_hck_thresh
  association to parent ZR_CD_HckCfgAll as _HckCfgAll on $projection.SingletonID = _HckCfgAll.SingletonID
{
      @EndUserText.label: 'Check ID'
  key check_id as CheckId,
      @EndUserText.label: 'Metric'
  key metric as Metric,
      @EndUserText.label: 'Company code'
  key bukrs as Bukrs,
      1 as SingletonID,
      @EndUserText.label: 'Amber'
      amber as Amber,
      @EndUserText.label: 'Red'
      red as Red,
      @EndUserText.label: 'Higher is worse'
      higher_is_worse as HigherIsWorse,
      @EndUserText.label: 'Baseline mode'
      baseline_mode as BaselineMode,
      @EndUserText.label: 'Z-score limit'
      z_limit as ZLimit,
      @EndUserText.label: 'Lookback runs'
      lookback_runs as LookbackRuns,
      @EndUserText.label: 'Changed by (SM30)'
      changed_by as ChangedBy,
      @EndUserText.label: 'Changed at (SM30)'
      changed_at as ChangedAt,
      @Semantics.user.lastChangedBy: true
      @EndUserText.label: 'Last changed by'
      last_changed_by as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      @EndUserText.label: 'Last changed at'
      last_changed_at as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      @EndUserText.label: 'Changed at (instance)'
      local_last_changed_at as LocalLastChangedAt,
      _HckCfgAll
}
