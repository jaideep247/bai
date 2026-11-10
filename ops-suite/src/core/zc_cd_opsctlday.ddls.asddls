// Artifact: zc_cd_opsctlday.ddls.asddls
// Purpose: Consumption view of the daily controls (overview page, service ZUI_CD_OPS_OVERVIEW, entity
//          ControlDay): KPI cards "Checks reviewed" (reviewed of controls, awaiting, overdue) and "Controls
//          flagged" (action required, watch), list cards "Daily health checks" and "Attention queue". Read
//          access: DCL ZC_CD_OPSOVERVIEW (ZCA_OPS, ZCA_PARAR = area of the control, ACTVT 03). Read-only.
// Modification log: 2026-11-10 | Initial version (control center: daily controls on the overview page).
//                   2026-11-10 | Company code of the control slice (company-code isolation).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Production support - daily controls'
@Metadata.allowExtensions: true
define root view entity ZC_CD_OpsCtlDay
  provider contract transactional_query
  as projection on ZR_CD_OpsCtlDay
{
  key PaymentEngineArea,
  key ControlId,
  key BusinessDate,
  key CompanyCode,
      ControlName,
      Category,
      Owner,
      Team,
      CutoffTime,
      Sequence,
      @ObjectModel.text.element: [ 'StatusText' ]
      ControlStatus,
      _StatusText.StatusText                                as StatusText : localized,
      StatusRank,
      StatusCriticality,
      @Aggregation.default: #SUM
      OpenExceptions,
      FindingCount,
      EvidenceRun,
      ReviewedBy,
      ReviewedTimeLocal,
      IsCurrentDay,
      IsReviewed,
      IsAwaitingReview,
      IsReviewOverdue,
      IsFlagged,
      @Aggregation.default: #SUM
      ControlCount,
      @Aggregation.default: #SUM
      ReviewedCount,
      @Aggregation.default: #SUM
      AwaitingCount,
      @Aggregation.default: #SUM
      OverdueCount,
      @Aggregation.default: #SUM
      ActionRequiredCount,
      @Aggregation.default: #SUM
      WatchCount,
      @Aggregation.default: #SUM
      FlaggedCount
}
