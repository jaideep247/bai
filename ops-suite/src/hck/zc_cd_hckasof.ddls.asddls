// Artifact: zc_cd_hckasof.ddls.asddls
// Purpose: Consumption view of the morning report "as of" (header KPI and the "stale report"
//          tile, service ZUI_CD_HCK_DASH): last completed run, RAG, check counters, age, stale flag.
//          Read access: DCL ZC_CD_HCKDASH (ZCD_OPS, ZCA_PARAR = HCK, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
//                   2026-11-10 | Company-code isolation: the run's finding count of every company code is no longer exposed.
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'HCK health check as of'
@Metadata.allowExtensions: true
define root view entity ZC_CD_HckAsOf
  provider contract transactional_query
  as projection on ZR_CD_HckAsOf
{
  key PaymentEngineArea,
      RunId,
      RunVariant,
      AsOfAt,
      RunStartedAt,
      RunStatus,
      RunRag,
      RagCriticality,
      CheckCount,
      GreenCheckCount,
      AmberCheckCount,
      RedCheckCount,
      WarmupCheckCount,
      RunMessage,
      AgeMinutes,
      StaleAfterMinutes,
      IsStale,
      StaleCriticality
}
