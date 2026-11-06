// Artifact: zr_cd_hckkpi.ddls.asddls
// Purpose: KPI entity of the health check dashboard (tiles, production-support overview page):
//          one row = the last completed morning report run (overall RAG, checks green / amber /
//          red / warm-up, run message with the health score, age, stale) and the open morning
//          report exceptions now (total, red, amber, overdue). Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK health check dashboard - KPI'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #S, dataClass: #MIXED }
define root view entity ZR_CD_HckKpi
  as select from ZR_CD_HckAsOf    as AsOf
    cross join   ZI_CD_HckOpenSum as OpenSum
{
  key AsOf.PaymentEngineArea,
      AsOf.RunId,
      AsOf.RunVariant,
      AsOf.AsOfAt,
      AsOf.RunRag,
      AsOf.RagCriticality,
      AsOf.RunMessage,
      AsOf.AgeMinutes,
      AsOf.IsStale,
      AsOf.StaleCriticality,
      AsOf.CheckCount,
      AsOf.GreenCheckCount,
      AsOf.AmberCheckCount,
      AsOf.RedCheckCount,
      AsOf.WarmupCheckCount,
      cast( coalesce( OpenSum.OpenFindingCount, 0 ) as abap.int4 ) as OpenFindingCount,
      cast( coalesce( OpenSum.OpenRedCount, 0 ) as abap.int4 ) as OpenRedCount,
      cast( coalesce( OpenSum.OpenAmberCount, 0 ) as abap.int4 ) as OpenAmberCount,
      cast( coalesce( OpenSum.OverdueCount, 0 ) as abap.int4 ) as OverdueCount
}
