// Artifact: zc_cd_hckcheck.ddls.asddls
// Purpose: Consumption view of the health check dashboard (analytical list page, OData V4,
//          service ZUI_CD_HCK_DASH): active checks with their status in the last completed morning report run,
//          default aggregation of every measure, drill-down to the metric history and the
//          findings of the check. UI annotations in the metadata extension ZC_CD_HCKCHECK.
//          Read access: DCL ZC_CD_HCKDASH (ZCD_OPS, ZCD_PE_AREA = HCK, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'HCK health check dashboard'
@Metadata.allowExtensions: true
// VERIFY-ADT: OData V4 data aggregation of a transactional_query projection without
// behaviour definition (as ZC_CD_FmonFlow)
define root view entity ZC_CD_HckCheck
  provider contract transactional_query
  as projection on ZR_CD_HckCheck
{
  key CheckId,
      PaymentEngineArea,
      CheckText,
      Category,
      CategoryText,
      Priority,
      ClassName,
      CheckStatus,
      StatusCriticality,
      StatusOrder,
      OldestDueDate,
      AsOfRunId,
      AsOfRunRag,
      AsOfAt,
      MonitorAgeMinutes,
      MonitorIsStale,
      MonitorCriticality,
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
      MetricCount,
      @Aggregation.default: #SUM
      RunFindingCount,
      @Aggregation.default: #SUM
      OpenFindingCount,
      @Aggregation.default: #SUM
      OpenRedCount,
      @Aggregation.default: #SUM
      OpenAmberCount,
      _Metrics : redirected to ZC_CD_HckMetric,
      _Findings : redirected to ZC_CD_HckFind
}
