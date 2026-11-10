// Artifact: zr_cd_opsctlday.ddls.asddls
// Purpose: Control cards of the overview page (checks reviewed n / m and awaiting review, controls flagged,
//          daily health checks table, attention queue): the controls of the payment engine areas per business
//          date as the framework's daily control review derives them (ZR_CA_OpsCtlReview: status Healthy /
//          Watch / Action required from the live findings of the date, open exceptions, sign-off, awaiting
//          and overdue review) with the counters the KPI cards sum. One truth: the review app ZUI_CA_OPS_REV
//          and these cards read the same view. Read-only.
// Modification log: 2026-11-10 | Initial version (control center: daily controls on the overview page).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Production support - daily controls'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #MIXED }
define root view entity ZR_CD_OpsCtlDay
  as select from ZR_CA_OpsCtlReview as Ctl
  association [0..*] to ZI_CA_OpsCtlStatusT as _StatusText on $projection.ControlStatus = _StatusText.ControlStatus
{
  key Ctl.Area                                              as PaymentEngineArea,
  key Ctl.ControlId,
  key Ctl.BusinessDate,
      Ctl.ControlName,
      Ctl.Category,
      Ctl.Owner,
      Ctl.Team,
      Ctl.CutoffTime,
      Ctl.Sequence,
      @ObjectModel.text.association: '_StatusText'
      Ctl.ControlStatus,
      Ctl.StatusRank,
      Ctl.StatusCriticality,
      Ctl.OpenExceptions,
      Ctl.FindingCount,
      Ctl.EvidenceRun,
      Ctl.ReviewedBy,
      Ctl.ReviewedTimeLocal,
      Ctl.IsCurrentDay,
      Ctl.IsReviewed,
      Ctl.IsAwaitingReview,
      Ctl.IsReviewOverdue,
      Ctl.IsFlagged,
      Ctl.ControlCount,
      Ctl.ReviewedCount,
      Ctl.AwaitingCount,
      Ctl.OverdueCount,
      Ctl.ActionRequiredCount,
      Ctl.WatchCount,
      Ctl.FlaggedCount,
      _StatusText
}
