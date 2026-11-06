// Artifact: zc_cd_fmonflowfail.ddls.asddls
// Purpose: Consumption view of the "latest failures" list (launchpad / overview-page list card,
//          service ZUI_CD_FMON_FLOW): rejected, partial and SLA-breached files, newest first.
//          Read access: DCL ZC_CD_FMONFLOW. Read-only.
// Modification log: 2026-11-06 | Initial version (FMON file monitoring dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'FMON file monitoring dashboard - failures'
@Metadata.allowExtensions: true
define root view entity ZC_CD_FmonFlowFail
  provider contract transactional_query
  as projection on ZR_CD_FmonFlowFail
{
  key FileId,
      PaymentEngineArea,
      BusinessDate,
      IsToday,
      IfaceId,
      Direction,
      SourceSystem,
      Lob,
      PaymentMethod,
      BankKey,
      FileName,
      FlowBucket,
      FlowCriticality,
      SlaStatus,
      SlaCriticality,
      WorstSeverity,
      LastEventAt,
      RecordCount,
      UnprocessedCount,
      NackCount,
      OpenFindingCount
}
