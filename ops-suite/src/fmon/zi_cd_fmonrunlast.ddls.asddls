// Artifact: zi_cd_fmonrunlast.ddls.asddls
// Purpose: End time of the last completed full FMON run (file monitoring dashboard "as of").
//          Completed = run status S, W or E of zif_ca_ops_types=>GC_RUN_STATUS (the monitor
//          finished; E = it finished with error findings). Running (R) and aborted (A) runs,
//          test-mode runs and single-interface runs (variant = interface ID instead of ALL,
//          ZCL_CD_FMON_ENGINE) never advance the as-of time. Always exactly one row: an
//          aggregate without GROUP BY, null end time when no run qualifies. Read-only.
// Modification log: 2026-11-06 | Initial version (FMON file monitoring dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FMON last completed run (end time)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
// VERIFY-ADT: aggregate without GROUP BY next to a literal element in a view entity (7.58)
define view entity ZI_CD_FmonRunLast
  as select from zca_ops_run
{
      cast( 'CD_FMON' as abap.char( 16 ) )                      as PaymentEngineArea,
      max( ended_at )                                       as LastEndedAt
}
where area   = 'CD_FMON'
  and variant   = 'ALL'
  and test_mode = ' '
  and ( status = 'S' or status = 'W' or status = 'E' )
