// Artifact: zc_cd_hckmetric.ddls.asddls
// Purpose: Consumption view of the metric history (service ZUI_CD_HCK_DASH): trend per check, metric, DIM1 and
//          DIM2 series. MetricValue aggregates as MAX (the highest measurement of a day / series);
//          drill-down to the open findings of the check.
//          Read access: DCL ZC_CD_HCKDASH (ZCD_OPS, ZCA_PARAR = HCK, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
//                   2026-11-10 | Company code of the metric (company-code isolation).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'HCK health check dashboard - metric'
@Metadata.allowExtensions: true
define root view entity ZC_CD_HckMetric
  provider contract transactional_query
  as projection on ZR_CD_HckMetric
{
  key RunId,
  key CheckId,
  key Metric,
  key Dimension1,
  key Dimension2,
      PaymentEngineArea,
      CompanyCode,
      CheckText,
      Category,
      MetricKind,
      @Aggregation.default: #MAX
      MetricValue,
      Weight,
      MeasuredAt,
      MeasuredDate,
      @Aggregation.default: #SUM
      SampleCount,
      _Findings : redirected to ZC_CD_HckFind
}
