// Artifact: zc_cd_fmonflowevt.ddls.asddls
// Purpose: Consumption view of the file events (drill-down of the file monitoring dashboard,
//          service ZUI_CD_FMON_FLOW). Read access: DCL ZC_CD_FMONFLOW. Read-only.
// Modification log: 2026-11-06 | Initial version (FMON file monitoring dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'FMON file monitoring - file event'
@Metadata.allowExtensions: true
define root view entity ZC_CD_FmonFlowEvt
  provider contract transactional_query
  as projection on ZR_CD_FmonFlowEvt
{
  key FileId,
  key EventNo,
      PaymentEngineArea,
      Stage,
      EventAt,
      SourceId,
      SourceKey,
      RecordCount,
      Amount,
      EventInfo,
      CreatedBy,
      CreatedAt
}
