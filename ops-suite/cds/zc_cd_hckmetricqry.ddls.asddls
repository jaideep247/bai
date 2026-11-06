// Artifact: zc_cd_hckmetricqry.ddls.asddls
// Purpose: Analytical query (dashboard "volume & trends"): metric value per day,
//          check, metric and dimension (source / LOB / job). Verify syntax on target release.
// Modification log: 2026-11-05 | Initial version (ops suite consolidation).
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
  Category,
  @AnalyticsDetails.query.axis: #COLUMNS
  MetricValue,
  @AnalyticsDetails.query.axis: #COLUMNS
  MaxValue,
  @AnalyticsDetails.query.axis: #COLUMNS
  SampleCount
}
