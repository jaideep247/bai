// Artifact: zc_cd_hckcategory.ddls.asddls
// Purpose: Consumption view of the scorecard per category (service ZUI_CD_HCK_DASH): status and check counts of
//          the last completed run, drill-down to the checks of the category.
//          Read access: DCL ZC_CD_HCKDASH (ZCD_OPS, ZCA_PARAR = HCK, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'HCK health check dashboard - category'
@Metadata.allowExtensions: true
define root view entity ZC_CD_HckCategory
  provider contract transactional_query
  as projection on ZR_CD_HckCategory
{
  key Category,
      CategoryText,
      PaymentEngineArea,
      AsOfRunId,
      AsOfAt,
      @Aggregation.default: #MAX
      MonitorAgeMinutes,
      MonitorIsStale,
      MonitorCriticality,
      CategoryStatus,
      StatusCriticality,
      @Aggregation.default: #SUM
      CheckCount,
      @Aggregation.default: #SUM
      RedCheckCount,
      @Aggregation.default: #SUM
      AmberCheckCount,
      @Aggregation.default: #SUM
      GreenCheckCount,
      @Aggregation.default: #SUM
      WarmupCheckCount,
      @Aggregation.default: #SUM
      NoResultCheckCount,
      @Aggregation.default: #SUM
      OpenFindingCount,
      _Checks : redirected to ZC_CD_HckCheck
}
