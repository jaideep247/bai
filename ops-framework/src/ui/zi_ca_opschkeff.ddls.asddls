// Artifact: zi_ca_opschkeff.ddls.asddls
// Purpose: Registered checks in effect today (2026-11-11): active checks of ZCA_OPS_CHECK whose business process
//          is in effect (ZI_CA_OpsProcEff), a technical check of the area without a process, or a check whose
//          process is not registered (it runs; the offline onboarding check reports it). The rows of the area
//          dashboard (ZI_CA_OpsChkSlice) - a check of a switched-off process is not shown, as the runner does
//          not run it. Nothing stored, read-only.
// Modification log: 2026-11-11 | Initial version (process catalogue with activation).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Registered checks in effect today'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
define view entity ZI_CA_OpsChkEff
  as select from    zca_ops_check    as Chk
    left outer join ZI_CA_OpsProcEff as Pe on  Pe.Area      = Chk.area
                                           and Pe.ProcessId = Chk.process_id
{
  key Chk.area                                              as Area,
  key Chk.check_id                                          as CheckId,
      Chk.process_id                                        as ProcessId
}
where
      Chk.active = 'X'
  and(
       Chk.process_id = ' '
    or Pe.ProcessId   is null
    or Pe.IsActive    = 'X'
  )
