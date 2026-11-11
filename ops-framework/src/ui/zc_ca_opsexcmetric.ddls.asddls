// Artifact: zc_ca_opsexcmetric.ddls.asddls
// Purpose: Consumption view of the response-time metrics (service ZUI_CA_OPS_MET, analytical list page "Exception
//          response times"; also exposed by a consumer's overview page for the card "Response times"): counters
//          summed, minutes averaged (MTTA, MTTR) over the episodes the user may read. Read access: DCL
//          ZC_CA_OPSEXCMETRIC (company-code rule of docs/auth_zca_ops.md section 3c). Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: response-time metrics).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Exception response-time metrics'
@Metadata.allowExtensions: true
define root view entity ZC_CA_OpsExcMetric
  provider contract transactional_query
  as projection on ZR_CA_OpsExcMetric
{
  key RunId,
  key FindingNo,
      Area,
      Team,
      CheckCode,
      Severity,
      CompanyCode,
      Disposition,
      RaisedDate,
      RaisedMonth,
      RaisedWeek,
      FirstSeenAt,
      FirstAssignedAt,
      ResolvedAt,
      @Aggregation.default: #SUM
      RaisedCount,
      @Aggregation.default: #SUM
      AssignedCount,
      @Aggregation.default: #SUM
      ResolvedCount,
      @Aggregation.default: #SUM
      OpenCount,
      @Aggregation.default: #SUM
      ReopenedCount,
      @Aggregation.default: #AVG
      MinutesToAssign,
      @Aggregation.default: #AVG
      MinutesToResolve,
      @Aggregation.default: #AVG
      OpenMinutes,
      @Aggregation.default: #SUM
      AssignedIn15Min,
      @Aggregation.default: #SUM
      AssignedIn1Hour,
      @Aggregation.default: #SUM
      AssignedIn4Hours,
      @Aggregation.default: #SUM
      AssignedIn1Day,
      @Aggregation.default: #SUM
      AssignedLater,
      @Aggregation.default: #SUM
      NotAssigned,
      @Aggregation.default: #SUM
      ResolvedIn1Hour,
      @Aggregation.default: #SUM
      ResolvedIn4Hours,
      @Aggregation.default: #SUM
      ResolvedIn1Day,
      @Aggregation.default: #SUM
      ResolvedIn3Days,
      @Aggregation.default: #SUM
      ResolvedLater,
      @Aggregation.default: #SUM
      OpenUnder1Day,
      @Aggregation.default: #SUM
      Open1To3Days,
      @Aggregation.default: #SUM
      Open3To7Days,
      @Aggregation.default: #SUM
      OpenOver7Days
}
