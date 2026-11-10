// Artifact: zc_cd_hckrun.ddls.asddls
// Purpose: Consumption view of the morning report run history (service ZUI_CD_HCK_DASH): RAG and check counters per
//          run (scorecard trend), drill-down to the findings of the run.
//          Read access: DCL ZC_CD_HCKDASH (ZCD_OPS, ZCA_PARAR = HCK, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'HCK health check dashboard - run'
@Metadata.allowExtensions: true
define root view entity ZC_CD_HckRun
  provider contract transactional_query
  as projection on ZR_CD_HckRun
{
  key RunId,
      PaymentEngineArea,
      RunVariant,
      StartedAt,
      EndedAt,
      RunDate,
      RunStatus,
      RunRag,
      RagCriticality,
      RuntimeMs,
      RunMessage,
      @Aggregation.default: #SUM
      RunCount,
      @Aggregation.default: #SUM
      RedRunCount,
      @Aggregation.default: #SUM
      CheckCount,
      @Aggregation.default: #SUM
      GreenCheckCount,
      @Aggregation.default: #SUM
      AmberCheckCount,
      @Aggregation.default: #SUM
      RedCheckCount,
      @Aggregation.default: #SUM
      WarmupCheckCount,
      @Aggregation.default: #SUM
      FindingCount,
      _Findings : redirected to ZC_CD_HckFind
}
