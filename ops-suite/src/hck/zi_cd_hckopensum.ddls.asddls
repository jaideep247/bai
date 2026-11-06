// Artifact: zi_cd_hckopensum.ddls.asddls
// Purpose: Open morning report exceptions now (O open, A assigned), one row: total, red (B / E),
//          amber (W), overdue (due date before today). For the KPI entity ZR_CD_HckKpi. Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK open exceptions (one row)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
// VERIFY-ADT: aggregate without GROUP BY next to a literal element (as ZI_CD_FmonRunLast)
define view entity ZI_CD_HckOpenSum
  as select from ZI_CD_HckFinding
{
      cast( 'HCK' as abap.char( 4 ) )                                                   as PaymentEngineArea,
      cast( count( * ) as abap.int4 )                                                   as OpenFindingCount,
      cast( sum( case when SeverityRank >= 3 then 1 else 0 end ) as abap.int4 )         as OpenRedCount,
      cast( sum( case when SeverityRank = 2 then 1 else 0 end ) as abap.int4 )          as OpenAmberCount,
      cast( sum( case when DueDate < $session.system_date and DueDate <> '00000000'
                      then 1 else 0 end ) as abap.int4 )                                as OverdueCount
}
where IsOpen = 'X'
