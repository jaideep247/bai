// Artifact: zi_cd_hckcheckopen.ddls.asddls
// Purpose: Open morning report exceptions (O open, A assigned) per check id, whatever run raised
//          them: count, B / E and W counts, oldest due date. Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK open exceptions per check'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_HckCheckOpen
  as select from ZI_CD_HckFinding
{
  key CheckId,
      cast( count( * ) as abap.int4 )                                                     as OpenFindingCount,
      cast( sum( case when SeverityRank >= 3 then 1 else 0 end ) as abap.int4 )           as OpenRedCount,
      cast( sum( case when SeverityRank = 2 then 1 else 0 end ) as abap.int4 )            as OpenAmberCount,
      min( DueDate )                                                                      as OldestDueDate
}
where IsOpen = 'X'
group by
  CheckId
