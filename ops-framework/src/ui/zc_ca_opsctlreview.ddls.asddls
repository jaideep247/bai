// Artifact: zc_ca_opsctlreview.ddls.asddls
// Purpose: Consumption view of the daily control review (list report "Daily control review", service
//          ZUI_CA_OPS_REV): controls per business date with derived status, open exceptions, evidence,
//          guidance and the sign-off; search by control name or ID. Read access: DCL ZC_CA_OPSCTLREVIEW
//          (ZCA_OPS, ZCA_PARAR = area of the control, ACTVT 03); the sign-off needs ZCA_OPS 02 (behaviour
//          pool). Read-only apart from the action markReviewed.
// Modification log: 2026-11-10 | Initial version (control register and daily control review).
//                   2026-11-10 | Company code of the slice (company-code isolation; DCL with BUKRS).
//                   2026-11-11 | Planned downtime mark of the slice (operations response features).
//                   2026-11-11 | Reopened sign-off and its reason (explainable, versioned results).
//                   2026-11-16 | Evaluation of the covered checks with its text (build O).
// Extension point CTL_REVIEW (2026-11-15, build H; config/extension_points.json, docs/EXTENDING_WITH_CUSTOMER_DATA.md):
//          base view; a customer adds its own elements with extend view entity from its package,
//          never by changing this view. Anchors COMPANY, CONTROL: their elements stay stable.
// VERIFY-ADT (V153): the extensibility annotations below on 7.58.
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Daily control review'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: [ 'Area', 'ControlId', 'BusinessDate', 'CompanyCode' ]
@AbapCatalog.extensibility.extensible: true
@AbapCatalog.extensibility.elementSuffix: 'ZOP'
@AbapCatalog.extensibility.allowNewDatasources: true
@AbapCatalog.extensibility.quota.maximumFields: 50
@AbapCatalog.extensibility.quota.maximumBytes: 2000
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
      IsReopened,
      @ObjectModel.text.element: [ 'ReopenText' ]
      ReopenReason,
      _ReopenText.ReopenText                                as ReopenText : localized,
      ReopenFindings,
      ReopenNewCount,
      ReopenStatusCount,
      ReopenAmountCount,
      ReopenConfigCount,
      IsAwaitingReview,
      IsFlagged,
      IsReviewOverdue,
      CoveredChecks,
      UnknownChecks,
      NotRunChecks,
      @ObjectModel.text.element: [ 'EvaluationStateText' ]
      EvaluationState,
      _EvalText.EvaluationStateText                         as EvaluationStateText : localized,
      EvaluationCriticality,
      IsEvaluationUnknown
}
