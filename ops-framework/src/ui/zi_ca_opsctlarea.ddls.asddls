// Artifact: zi_ca_opsctlarea.ddls.asddls
// Purpose: The areas of the findings a control covers (one row per control and area of ZCA_OPS_CTLCHK) -
//          the runs whose latest one is the evidence of a sign-off. Read-only.
// Modification log: 2026-11-10 | Initial version (control register and daily control review).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control review: areas of a control'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
define view entity ZI_CA_OpsCtlArea
  as select from zca_ops_ctlchk
{
  key area                                                  as Area,
  key control_id                                            as ControlId,
  key check_area                                            as CheckArea
}
group by
  area,
  control_id,
  check_area
