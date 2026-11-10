// Artifact: zc_cd_opsfindingqry.ddls.asddls
// Purpose: Analytical query (dashboard "exception queue"): findings, open and
//          overdue items, oldest age per payment engine area / category / check. Verify syntax on target release.
// Modification log: 2026-11-05 | Initial version (ops suite consolidation).
//                   2026-11-10 | Company code (free axis; company-code isolation on the cube).
// Authorization: enforced on ZI_CD_OpsFindingCube (DCL ZI_CD_OpsAnalytics).
@EndUserText.label: 'Ops suite findings - query'
define transient view entity ZC_CD_OpsFindingQry
  provider contract analytical_query
  as projection on ZI_CD_OpsFindingCube
{
  @AnalyticsDetails.query.axis: #ROWS
  PaymentEngineArea,
  @AnalyticsDetails.query.axis: #ROWS
  Group1,
  @AnalyticsDetails.query.axis: #FREE
  CompanyCode,
  @AnalyticsDetails.query.axis: #FREE
  Group2,
  @AnalyticsDetails.query.axis: #FREE
  Severity,
  @AnalyticsDetails.query.axis: #FREE
  Owner,
  @AnalyticsDetails.query.axis: #FREE
  Currency,
  @AnalyticsDetails.query.axis: #FREE
  @Consumption.filter: { selectionType: #INTERVAL, multipleSelections: false }
  CreatedDate,
  @Consumption.filter: { selectionType: #SINGLE, multipleSelections: false, defaultValue: '' }
  IsTestMode,
  @AnalyticsDetails.query.axis: #COLUMNS
  FindingCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  OpenCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  OverdueCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  MaxDaysPastDue,
  @AnalyticsDetails.query.axis: #COLUMNS
  Amount
}
