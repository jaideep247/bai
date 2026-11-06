// Artifact: zi_cd_hckcheckres.ddls.asddls
// Purpose: Result of each check in each morning report run, from the findings the run stored
//          (ZI_CD_HckFinding grouped by run and check id): worst severity without warm-up
//          information, number of warm-up findings and of all findings. A GREEN check without
//          findings has no row here - ZR_CD_HckCheck tells it from "no result" by its metric rows.
//          Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK check result per run'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_HckCheckRes
  as select from ZI_CD_HckFinding
{
  key RunId,
  key CheckId,
      cast( max( case IsWarmup when 'X' then 0 else SeverityRank end ) as abap.int1 ) as WorstSeverityRank,
      cast( sum( case IsWarmup when 'X' then 1 else 0 end ) as abap.int4 )            as WarmupFindingCount,
      cast( count( * ) as abap.int4 )                                                 as RunFindingCount
}
group by
  RunId,
  CheckId
