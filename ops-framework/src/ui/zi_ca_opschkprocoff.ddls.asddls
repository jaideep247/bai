// Artifact: zi_ca_opschkprocoff.ddls.asddls
// Purpose: Active registered checks switched off by their business process today (2026-11-11): the process row
//          is inactive or its catalogue process is not active (ZI_CA_OpsProcEff). The runner does not run
//          them; a control that covers only such checks is not expected in the daily review
//          (ZI_CA_OpsCtlProcOff). Nothing stored, read-only.
// Modification log: 2026-11-11 | Initial version (process catalogue with activation).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Checks switched off by their process'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
define view entity ZI_CA_OpsChkProcOff
  as select from zca_ops_check    as Chk
    inner join   ZI_CA_OpsProcEff as Pe on  Pe.Area      = Chk.area
                                        and Pe.ProcessId = Chk.process_id
{
  key Chk.area                                              as Area,
  key Chk.check_id                                          as CheckId,
      Chk.process_id                                        as ProcessId
}
where
      Chk.active  = 'X'
  and Pe.IsActive = ' '
