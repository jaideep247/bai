// Artifact: zc_ca_opspilot.ddls.asddls
// Purpose: Consumption view of the pilot metrics (service ZUI_CA_OPS_PILOT, analytical list page "Pilot metrics"):
//          counters summed, minutes averaged (time to detect, baseline, MTTA, MTTR) over the episodes the user may read;
//          the false-positive rate is FalsePositiveCount / ResolvedCount of the selection (query ZC_CA_OpsPilotQry and
//          the export compute it). Read access: DCL ZC_CA_OPSPILOT (company-code rule of docs/auth_zca_ops.md 3c).
//          Read-only; Export to Spreadsheet of the list for the pilot evidence.
// Modification log: 2026-11-11 | Initial version (build F: pilot pack).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Pilot metrics'
@Metadata.allowExtensions: true
define root view entity ZC_CA_OpsPilot
  provider contract transactional_query
  as projection on ZR_CA_OpsPilot
{
  key RunId,
  key FindingNo,
      Area,
      ProcessId,
      CheckId,
      CheckCode,
      CompanyCode,
      Severity,
      Disposition,
      ReasonCode,
      ConfigVersion,
      RaisedDate,
      RaisedMonth,
      RaisedWeek,
      FirstSeenAt,
      BusinessDate,
      EventAt,
      IsFalsePositive,
      BaselineSource,
      @Aggregation.default: #SUM
      RaisedCount,
      @Aggregation.default: #SUM
      AssignedCount,
      @Aggregation.default: #SUM
      ResolvedCount,
      @Aggregation.default: #SUM
      FalsePositiveCount,
      @Aggregation.default: #SUM
      DetectKnownCount,
      @Aggregation.default: #SUM
      BaselineKnownCount,
      @Aggregation.default: #AVG
      MinutesToAssign,
      @Aggregation.default: #AVG
      MinutesToResolve,
      @Aggregation.default: #AVG
      MinutesToDetect,
      @Aggregation.default: #AVG
      BaselineMinutes,
      @Aggregation.default: #AVG
      MinutesEarlier,
      @Aggregation.default: #SUM
      EarlierCount
}
