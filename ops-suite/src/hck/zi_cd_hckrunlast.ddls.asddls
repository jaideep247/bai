// Artifact: zi_cd_hckrunlast.ddls.asddls
// Purpose: End time of the last completed morning report run (health check dashboard "as of",
//          docs/Dashboard_Health_Check.md). Completed = run status S, W or E (ZCL_CD_HCK_ENGINE
//          closes GREEN as S, AMBER as W, RED and unrated as E, A60). Running (R) and aborted (A)
//          runs - incl. a run refused because another held the lock - and test-mode runs never
//          advance the as-of time. Any report variant counts. Always exactly one row: aggregate
//          without GROUP BY, null end time when no run qualifies.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK last completed run (end time)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
// VERIFY-ADT: aggregate without GROUP BY next to a literal element (as ZI_CD_FmonRunLast)
define view entity ZI_CD_HckRunLast
  as select from zca_ops_run
{
      cast( 'CD_HCK' as abap.char( 16 ) )                       as PaymentEngineArea,
      max( ended_at )                                       as LastEndedAt
}
where area   = 'CD_HCK'
  and test_mode = ' '
  and ( status = 'S' or status = 'W' or status = 'E' )
