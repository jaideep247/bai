// Artifact: zi_ca_opsctlrunmax.ddls.asddls
// Purpose: Start of the latest run of a control's areas per business date (ZI_CA_OpsCtlArea x
//          ZI_CA_OpsCtlRunDay) - step 1 of the evidence of a sign-off (ZI_CA_OpsCtlEvid). Read-only.
// Modification log: 2026-11-10 | Initial version (control register and daily control review).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control review: latest run time per date'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsCtlRunMax
  as select from ZI_CA_OpsCtlArea   as Ctl
    inner join   ZI_CA_OpsCtlRunDay as Run on Run.Area = Ctl.CheckArea
{
  key Ctl.Area,
  key Ctl.ControlId,
  key Run.BusinessDate,
      max( Run.StartedAt )                                  as LastRunAt
}
group by
  Ctl.Area,
  Ctl.ControlId,
  Run.BusinessDate
