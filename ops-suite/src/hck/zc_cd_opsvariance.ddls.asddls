// Artifact: zc_cd_opsvariance.ddls.asddls
// Purpose: Consumption view of the reconciliation variances (overview page, entity ReconVariance): KPI "Open
//          variances" (unresolved on the selected date), "Classified as timing", list per group-day and leg
//          with expected, SAP actual, variance and disposition (exception workflow). Read access: DCL
//          ZC_CD_OPSOVERVIEW (area CD_HCK). Read-only - a variance is classified or resolved on its exception
//          in the exceptions app, never here.
// Modification log: 2026-11-10 | Initial version (control center: open variances).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Production support - reconciliation variances'
@Metadata.allowExtensions: true
define root view entity ZC_CD_OpsVariance
  provider contract transactional_query
  as projection on ZR_CD_OpsVariance
{
  key CheckId,
  key ReconGroup,
  key ReconDay,
  key Leg,
      BusinessDate,
      PaymentEngineArea,
      CompanyCode,
      GlAccount,
      Currency,
      RunId,
      MeasuredAt,
      ExpectedAmount,
      ActualAmount,
      VarianceAmount,
      Tolerance,
      FindingCode,
      ExceptionDisposition,
      ReasonCode,
      ExceptionOwner,
      VarianceDisposition,
      IsTiming,
      IsUnresolved,
      VarianceCriticality,
      IsCurrentDay,
      @Aggregation.default: #SUM
      VarianceCount
}
