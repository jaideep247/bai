@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Thresholds'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['CheckId', 'Metric', 'Bukrs']
define view entity ZC_CD_HckThreshold
  as projection on ZR_CD_HckThreshold
{
  key CheckId,
  key Metric,
  key Bukrs,
      @Consumption.hidden: true
      SingletonID,
      Amber,
      Red,
      HigherIsWorse,
      BaselineMode,
      ZLimit,
      LookbackRuns,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _HckCfgAll : redirected to parent ZC_CD_HckCfgAll
}
