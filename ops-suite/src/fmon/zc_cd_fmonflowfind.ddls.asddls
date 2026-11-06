// Artifact: zc_cd_fmonflowfind.ddls.asddls
// Purpose: Consumption view of the open FMON exceptions (drill-down of the file monitoring
//          dashboard and source of the "missing files" tile, service ZUI_CD_FMON_FLOW).
//          Read access: DCL ZC_CD_FMONFLOW. Read-only - exceptions are worked in ZUI_CD_OPS_EXC_O4.
// Modification log: 2026-11-06 | Initial version (FMON file monitoring dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'FMON file monitoring - open exception'
@Metadata.allowExtensions: true
define root view entity ZC_CD_FmonFlowFind
  provider contract transactional_query
  as projection on ZR_CD_FmonFlowFind
{
  key RunId,
  key FindingNo,
      PaymentEngineArea,
      FileIdHex,
      ObjectKey,
      IfaceId,
      PaymentMethod,
      CheckCode,
      SlaClass,
      Severity,
      SeverityCriticality,
      Disposition,
      Owner,
      DueDate,
      FindingMessage,
      FirstSeenAt,
      Occurrences,
      CreatedAt
}
