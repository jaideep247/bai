// Artifact: zc_cd_opsfreshness.ddls.asddls
// Purpose: Consumption view of the monitor freshness per area (overview-page list card and the
//          "stale monitors" tile, service ZUI_CD_OPS_OVERVIEW).
//          Read access: DCL ZC_CD_OPSOVERVIEW (ZCD_OPS, ZCA_PARAR of the row, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (production-support overview page).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Production support - monitor freshness'
@Metadata.allowExtensions: true
define root view entity ZC_CD_OpsFreshness
  provider contract transactional_query
  as projection on ZR_CD_OpsFreshness
{
  key PaymentEngineArea,
      AreaText,
      RunId,
      AsOfAt,
      RunStatus,
      @Aggregation.default: #MAX
      AgeMinutes,
      StaleAfterMinutes,
      IsStale,
      StaleCriticality,
      @Aggregation.default: #SUM
      StaleMonitorCount
}
