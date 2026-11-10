// Artifact: zi_cd_opsvaru.ddls.asddls
// Purpose: Variances of both compared legs of the three-way reconciliation (UNION of ZI_CD_OpsVarBank and
//          ZI_CD_OpsVarFica): one row per group, day and leg whose latest difference is beyond the tolerance.
//          Read-only.
// Modification log: 2026-11-10 | Initial version (control center: open variances).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Reconciliation variances (both legs)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CD_OpsVarU
  as select from ZI_CD_OpsVarBank
{
  key CheckId,
  key ReconGroup,
  key ReconDay,
  key Leg,
      ReconDate,
      RunId,
      MeasuredAt,
      Difference,
      Tolerance,
      ExpectedAmount,
      ActualAmount,
      FindingKey
}
union all select from ZI_CD_OpsVarFica
{
  key CheckId,
  key ReconGroup,
  key ReconDay,
  key Leg,
      ReconDate,
      RunId,
      MeasuredAt,
      Difference,
      Tolerance,
      ExpectedAmount,
      ActualAmount,
      FindingKey
}
