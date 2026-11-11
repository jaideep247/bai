// Artifact: zc_ca_opspilotqry.ddls.asddls
// Purpose: Pilot pack - analytical query (transient view entity over ZI_CA_OpsPilotCube): rows area / business process /
//          check, free the day, month, week, company code, severity and reason code; columns raised, resolved, false
//          positives, the false-positive rate (false positives / resolved), the average minutes to detect against the
//          baseline and the average MTTA / MTTR (formulas over the summed minutes and counts of the selection).
// Modification log: 2026-11-11 | Initial version (build F: pilot pack).
// VERIFY-ADT: #FORMULA measures with division of two measures and a zero divisor (null) on 7.58 - V143.
@EndUserText.label: 'Pilot metrics - query'
@AccessControl.authorizationCheck: #NOT_ALLOWED
define transient view entity ZC_CA_OpsPilotQry
  provider contract analytical_query
  as projection on ZI_CA_OpsPilotCube
{
  @AnalyticsDetails.query.axis: #ROWS
  @AnalyticsDetails.query.totals: #SHOW
  Area,
  @AnalyticsDetails.query.axis: #ROWS
  ProcessId,
  @AnalyticsDetails.query.axis: #ROWS
  CheckId,
  @AnalyticsDetails.query.axis: #FREE
  CheckCode,
  @AnalyticsDetails.query.axis: #FREE
  CompanyCode,
  @AnalyticsDetails.query.axis: #FREE
  Severity,
  @AnalyticsDetails.query.axis: #FREE
  ReasonCode,
  @AnalyticsDetails.query.axis: #FREE
  RaisedDate,
  @AnalyticsDetails.query.axis: #FREE
  RaisedMonth,
  @AnalyticsDetails.query.axis: #FREE
  RaisedWeek,
  @AnalyticsDetails.query.axis: #COLUMNS
  RaisedCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  ResolvedCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  FalsePositiveCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  EarlierCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  DetectKnownCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  @Aggregation.default: #FORMULA
  @EndUserText.label: 'False-positive rate'
  $projection.FalsePositiveCount / $projection.ResolvedCount as FalsePositiveRate,
  @AnalyticsDetails.query.axis: #COLUMNS
  @Aggregation.default: #FORMULA
  @EndUserText.label: 'Minutes to detect (average)'
  $projection.MinutesToDetect / $projection.DetectKnownCount as AvgMinutesToDetect,
  @AnalyticsDetails.query.axis: #FREE
  MinutesToDetect,
  @AnalyticsDetails.query.axis: #FREE
  BaselineMinutes,
  @AnalyticsDetails.query.axis: #FREE
  MinutesToAssign,
  @AnalyticsDetails.query.axis: #FREE
  MinutesToResolve,
  @AnalyticsDetails.query.axis: #FREE
  AssignedCount,
  @AnalyticsDetails.query.axis: #FREE
  BaselineKnownCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  @Aggregation.default: #FORMULA
  @EndUserText.label: 'Previous detection minutes (average)'
  $projection.BaselineMinutes / $projection.BaselineKnownCount as AvgBaselineMinutes
}
