// Artifact: zc_cd_hckmetricqry.ddls.asddls
// Purpose: Analytical query (dashboard "volume & trends"): metric value per day,
//          check, metric and dimension (source / LOB / job). Verify syntax on target release.
// Modification log: 2026-11-05 | Initial version (ops suite consolidation).
//                   2026-11-06 | Volume, level and weighted-rate measures instead of a plain SUM (audit A88).
//                   2026-11-10 | Company code (free axis; company-code isolation on the cube).
// Authorization: enforced on ZI_CD_HckMetricCube (DCL ZI_CD_OpsAnalytics).
@EndUserText.label: 'Health check metric trend - query'
define transient view entity ZC_CD_HckMetricQry
  provider contract analytical_query
  as projection on ZI_CD_HckMetricCube
{
  @AnalyticsDetails.query.axis: #ROWS
  @Consumption.filter: { selectionType: #INTERVAL, multipleSelections: false }
  MeasuredDate,
  @AnalyticsDetails.query.axis: #ROWS
  @Consumption.filter: { selectionType: #SINGLE, multipleSelections: true }
  CheckId,
  @AnalyticsDetails.query.axis: #ROWS
  @Consumption.filter: { selectionType: #SINGLE, multipleSelections: true }
  Metric,
  @AnalyticsDetails.query.axis: #FREE
  Dimension1,
  @AnalyticsDetails.query.axis: #FREE
  CompanyCode,
  @AnalyticsDetails.query.axis: #FREE
  Category,
  @AnalyticsDetails.query.axis: #FREE
  MetricKind,
  // A88: volumes add up; levels (durations, ages) show maximum and average; rates are
  // weighted by their denominator. VERIFY-ADT: formula syntax and hidden helper measures.
  @AnalyticsDetails.query.axis: #COLUMNS
  VolumeValue,
  @AnalyticsDetails.query.axis: #COLUMNS
  LevelMax,
  @AnalyticsDetails.query.hidden: true
  LevelSum,
  @AnalyticsDetails.query.hidden: true
  LevelSamples,
  @AnalyticsDetails.query.hidden: true
  RateWeightedSum,
  @AnalyticsDetails.query.hidden: true
  RateWeight,
  @EndUserText.label: 'Average level'
  @Aggregation.default: #FORMULA
  @AnalyticsDetails.query.axis: #COLUMNS
  $projection.LevelSum / $projection.LevelSamples   as LevelAverage,
  @EndUserText.label: 'Weighted rate'
  @Aggregation.default: #FORMULA
  @AnalyticsDetails.query.axis: #COLUMNS
  $projection.RateWeightedSum / $projection.RateWeight as WeightedRate,
  @AnalyticsDetails.query.axis: #COLUMNS
  MaxValue,
  @AnalyticsDetails.query.axis: #COLUMNS
  SampleCount
}
