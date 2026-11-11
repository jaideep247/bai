// Artifact: zi_ca_opspilotcube.ddls.asddls
// Purpose: Pilot pack - analytical cube (Analysis for Office, multidimensional reports): exception episodes x area x
//          business process x check x company code x day / month / week x severity x reason code with the measures
//          raised, assigned, resolved, false positives, detection measurable, minutes to detect / baseline / to assign
//          / to resolve (totals; the query divides) and the earlier detections. Rows of ZR_CA_OpsPilot; read access:
//          DCL ZI_CA_OPSPILOTCUBE. Query: ZC_CA_OpsPilotQry.
// Modification log: 2026-11-11 | Initial version (build F: pilot pack).
// VERIFY-ADT: @Analytics.dataCategory #CUBE over a root view entity (7.58) - V143.
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Pilot metrics - cube'
@Analytics.dataCategory: #CUBE
@VDM.viewType: #COMPOSITE
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsPilotCube
  as select from ZR_CA_OpsPilot as P
{
  key P.RunId,
  key P.FindingNo,
      P.Area,
      P.ProcessId,
      P.CheckId,
      P.CheckCode,
      P.CompanyCode,
      P.Severity,
      P.ReasonCode,
      P.RaisedDate,
      P.RaisedMonth,
      P.RaisedWeek,
      @Aggregation.default: #SUM
      P.RaisedCount,
      @Aggregation.default: #SUM
      P.AssignedCount,
      @Aggregation.default: #SUM
      P.ResolvedCount,
      @Aggregation.default: #SUM
      P.FalsePositiveCount,
      @Aggregation.default: #SUM
      P.DetectKnownCount,
      @Aggregation.default: #SUM
      P.BaselineKnownCount,
      @Aggregation.default: #SUM
      P.EarlierCount,
      @Aggregation.default: #SUM
      P.MinutesToDetect,
      @Aggregation.default: #SUM
      P.BaselineMinutes,
      @Aggregation.default: #SUM
      P.MinutesToAssign,
      @Aggregation.default: #SUM
      P.MinutesToResolve
}
