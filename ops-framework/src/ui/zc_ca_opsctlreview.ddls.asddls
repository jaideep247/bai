// Artifact: zc_ca_opsctlreview.ddls.asddls
// Purpose: Consumption view of the daily control review (list report "Daily control review", service
//          ZUI_CA_OPS_REV): controls per business date with derived status, open exceptions, evidence,
//          guidance and the sign-off; search by control name or ID. Read access: DCL ZC_CA_OPSCTLREVIEW
//          (ZCA_OPS, ZCA_PARAR = area of the control, ACTVT 03); the sign-off needs ZCA_OPS 02 (behaviour
//          pool). Read-only apart from the action markReviewed.
// Modification log: 2026-11-10 | Initial version (control register and daily control review).
//                   2026-11-10 | Company code of the slice (company-code isolation; DCL with BUKRS).
//                   2026-11-11 | Planned downtime mark of the slice (operations response features).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Daily control review'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: [ 'Area', 'ControlId', 'BusinessDate', 'CompanyCode' ]
define root view entity ZC_CA_OpsCtlReview
  provider contract transactional_query
  as projection on ZR_CA_OpsCtlReview
{
  key Area,
  key ControlId,
  key BusinessDate,
  key CompanyCode,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      ControlName,
      Category,
      Owner,
      Backup,
      Team,
      CutoffTime,
      RunbookUrl,
      Sequence,
      Guidance,
      TimeZone,
      IsCurrentDay,
      @ObjectModel.text.element: [ 'StatusText' ]
      ControlStatus,
      _StatusText.StatusText                                as StatusText : localized,
      StatusRank,
      StatusCriticality,
      FindingCount,
      DowntimeFindings,
      IsPlannedDowntime,
      LastFindingAt,
      OpenExceptions,
      EvidenceRun,
      EvidenceRunAt,
      StatusAtReview,
      @ObjectModel.text.element: [ 'ResultText' ]
      ReviewResult,
      _ResultText.StatusText                                as ResultText : localized,
      ReviewedEvidenceRun,
      ReviewedBy,
      ReviewedAt,
      ReviewedOnLocal,
      ReviewedTimeLocal,
      Observation,
      NextAction,
      LastChangedAt,
      IsReviewed,
      IsAwaitingReview,
      IsFlagged,
      IsReviewOverdue
}
