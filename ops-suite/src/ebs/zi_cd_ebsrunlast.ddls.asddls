// Artifact: zi_cd_ebsrunlast.ddls.asddls
// Purpose: End time of the last completed EBS validation run (EBS validation dashboard "as of",
//          docs/Dashboard_EBS_Validation.md). Completed = run status S, W, E (ZIF_CD_OPS_TYPES=>
//          GC_RUN_STATUS) or N (no data: the run looked and found no statement - still a complete
//          look). Running (R) and aborted (A) runs and test-mode runs never advance the as-of time.
//          Any variant counts (EBS variants differ by date window / house bank, not by depth).
//          Always exactly one row: aggregate without GROUP BY, null end time when no run qualifies.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS last completed run (end time)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
// VERIFY-ADT: aggregate without GROUP BY next to a literal element (as ZI_CD_FmonRunLast)
define view entity ZI_CD_EbsRunLast
  as select from zcd_ops_run
{
      cast( 'EBS' as abap.char( 4 ) )                       as PaymentEngineArea,
      max( ended_at )                                       as LastEndedAt
}
where pe_area   = 'EBS'
  and test_mode = ' '
  and ( status = 'S' or status = 'W' or status = 'E' or status = 'N' )
