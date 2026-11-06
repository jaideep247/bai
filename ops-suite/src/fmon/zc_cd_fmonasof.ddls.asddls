// Artifact: zc_cd_fmonasof.ddls.asddls
// Purpose: Consumption view of the monitor "as of" (header KPI of the file monitoring dashboard and
//          the "stale monitor" tile, service ZUI_CD_FMON_FLOW): last completed FMON run, age in
//          minutes, stale flag. Read access: DCL ZC_CD_FMONFLOW. Read-only.
// Modification log: 2026-11-06 | Initial version (FMON file monitoring dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'FMON monitor as of'
@Metadata.allowExtensions: true
define root view entity ZC_CD_FmonAsOf
  provider contract transactional_query
  as projection on ZR_CD_FmonAsOf
{
  key PaymentEngineArea,
      RunId,
      AsOfAt,
      RunStartedAt,
      RunStatus,
      RunRag,
      RunFindingCount,
      AgeMinutes,
      IsStale,
      StaleCriticality
}
