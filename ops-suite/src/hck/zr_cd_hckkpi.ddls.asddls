// Artifact: zr_cd_hckkpi.ddls.asddls
// Purpose: KPI entity of the health check dashboard (tiles, production-support overview page):
//          one row = the last completed morning report run (overall RAG, checks green / amber /
//          red / warm-up, run message with the health score, age, stale) and the open morning
//          report exceptions now (total, red, amber, overdue). Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
//                   2026-11-10 | Company-code isolation: one row per slice (ZI_CD_HckOpenSlice, key CompanyCode); the as-of run's check
//                                counters on the area-level slice only, the open exceptions of a company code on its own slice.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK health check dashboard - KPI'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #S, dataClass: #MIXED }
define root view entity ZR_CD_HckKpi
  as select from    ZR_CD_HckAsOf      as AsOf
    cross join      ZI_CD_HckOpenSlice as Slice
    left outer join ZI_CD_HckOpenSum   as OpenSum on OpenSum.CompanyCode = Slice.CompanyCode
{
  key AsOf.PaymentEngineArea,
      // Blank = the area-level slice (the as-of run's check counters and exceptions without company code)
  key Slice.CompanyCode,
      AsOf.RunId,
      AsOf.RunVariant,
      AsOf.AsOfAt,
      AsOf.RunRag,
      AsOf.RagCriticality,
      AsOf.RunMessage,
      AsOf.AgeMinutes,
      AsOf.IsStale,
      AsOf.StaleCriticality,
      cast( case Slice.CompanyCode when ' ' then AsOf.CheckCount else 0 end as abap.int4 )       as CheckCount,
      cast( case Slice.CompanyCode when ' ' then AsOf.GreenCheckCount else 0 end as abap.int4 )  as GreenCheckCount,
      cast( case Slice.CompanyCode when ' ' then AsOf.AmberCheckCount else 0 end as abap.int4 )  as AmberCheckCount,
      cast( case Slice.CompanyCode when ' ' then AsOf.RedCheckCount else 0 end as abap.int4 )    as RedCheckCount,
      cast( case Slice.CompanyCode when ' ' then AsOf.WarmupCheckCount else 0 end as abap.int4 ) as WarmupCheckCount,
      cast( coalesce( OpenSum.OpenFindingCount, 0 ) as abap.int4 ) as OpenFindingCount,
      cast( coalesce( OpenSum.OpenRedCount, 0 ) as abap.int4 ) as OpenRedCount,
      cast( coalesce( OpenSum.OpenAmberCount, 0 ) as abap.int4 ) as OpenAmberCount,
      cast( coalesce( OpenSum.OverdueCount, 0 ) as abap.int4 ) as OverdueCount
}
