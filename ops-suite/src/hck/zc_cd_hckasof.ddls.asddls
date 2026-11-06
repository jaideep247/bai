// Artifact: zc_cd_hckasof.ddls.asddls
// Purpose: Consumption view of the morning report "as of" (header KPI and the "stale report"
//          tile, service ZUI_CD_HCK_DASH): last completed run, RAG, check counters, age, stale flag.
//          Read access: DCL ZC_CD_HCKDASH (ZCD_OPS, ZCD_PE_AREA = HCK, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
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
      RunFindingCount,
      RunMessage,
      AgeMinutes,
      StaleAfterMinutes,
      IsStale,
      StaleCriticality
}
