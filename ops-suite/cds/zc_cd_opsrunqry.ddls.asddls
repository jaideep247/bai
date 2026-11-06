// Artifact: zc_cd_opsrunqry.ddls.asddls
// Purpose: Analytical query (dashboard tile "suite runs"): runs, red runs and
//          average runtime per payment engine area and day. Release-dependent syntax: verify on target release.
// Modification log: 2026-11-05 | Initial version (ops suite consolidation).
// Authorization: enforced on ZI_CD_OpsRunCube (DCL ZI_CD_OpsAnalytics).
@EndUserText.label: 'Ops suite runs - query'
define transient view entity ZC_CD_OpsRunQry
  provider contract analytical_query
  as projection on ZI_CD_OpsRunCube
{
  @AnalyticsDetails.query.axis: #ROWS
  PaymentEngineArea,
  @AnalyticsDetails.query.axis: #ROWS
  @Consumption.filter: { selectionType: #INTERVAL, multipleSelections: false }
  RunDate,
  @AnalyticsDetails.query.axis: #FREE
  Rag,
  @AnalyticsDetails.query.axis: #FREE
  RunStatus,
  @AnalyticsDetails.query.axis: #COLUMNS
  RunCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  RedRunCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  FindingCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  MaxRuntimeMs,
  @AnalyticsDetails.query.axis: #FREE
  RuntimeMs,
  // verify on target release: formula measure in a transient view entity
  @EndUserText.label: 'Avg runtime (ms)'
  @Aggregation.default: #FORMULA
  @AnalyticsDetails.query.axis: #COLUMNS
  $projection.RuntimeMs / $projection.RunCount as AvgRuntimeMs
}
