// Artifact: zi_ca_opsctlstate.ddls.asddls
// Purpose: Derived state of a control on a business date (rules of ZCL_CA_OPS_REVIEW_POLICY):
//          status H healthy / W watch / A action required from the rank of the date's live findings;
//          signed off (a review row); REOPENED = signed off, and since then a covered finding is new, changed in
//          severity or amount, or produced by another configuration version, or the status is worse than at the
//          sign-off - with the reason (domain ZCA_OPS_REOPEN, first that applies: NEW, STATUS, AMOUNT, CONFIG,
//          WORSE); AWAITING REVIEW = not signed off, or reopened; flagged = watch or action required.
//          Read-only.
// Modification log: 2026-11-10 | Initial version (control register and daily control review).
//                   2026-11-10 | Company code of the slice (company-code isolation).
//                   2026-11-11 | Planned downtime mark: findings of the date in an approved window.
//                   2026-11-11 | Explainable, versioned results: a sign-off is REOPENED with a reason (ReopenReason,
//                                IsReopened); a finding raised again unchanged after the sign-off no longer makes the
//                                control await review (it was "any finding after the sign-off").
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control review: derived state'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #MIXED }
define view entity ZI_CA_OpsCtlState
  as select from ZI_CA_OpsCtlDay as D
{
  key D.Area,
  key D.ControlId,
  key D.BusinessDate,
  key D.CompanyCode,
      D.ControlName,
      D.Category,
      D.Owner,
      D.Backup,
      D.Team,
      D.CutoffTime,
      D.RunbookUrl,
      D.Sequence,
      D.Guidance,
      D.TimeZone,
      D.Today,
      D.NowTime,
      D.IsCurrentDay,
      D.StatusRank,
      cast( case D.StatusRank when 2 then 'A'
                              when 1 then 'W'
                              else 'H' end as zca_ops_ctl_status ) as ControlStatus,
      D.FindingCount,
      D.DowntimeFindings,
      cast( case when D.DowntimeFindings > 0 then 'X' else ' ' end as abap_boolean ) as IsPlannedDowntime,
      D.LastFindingAt,
      D.OpenExceptions,
      D.EvidenceRun,
      D.EvidenceRunAt,
      D.StatusAtReview,
      D.ReviewResult,
      D.ReviewedEvidenceRun,
      D.ReviewedBy,
      D.ReviewedAt,
      D.Observation,
      D.NextAction,
      D.LastChangedAt,
      cast( case when D.StatusAtReview is null or D.StatusAtReview = ' '
                 then ' ' else 'X' end as abap_boolean )   as IsReviewed,
      cast( case when D.StatusAtReview is null or D.StatusAtReview = ' ' then ' '
                 when D.ReopenNewCount > 0 then 'NEW'
                 when D.ReopenStatusCount > 0 then 'STATUS'
                 when D.ReopenAmountCount > 0 then 'AMOUNT'
                 when D.ReopenConfigCount > 0 then 'CONFIG'
                 when D.StatusRank > D.ReviewRank then 'WORSE'
                 else ' ' end as zca_ops_reopen )           as ReopenReason,
      cast( case when D.StatusAtReview is null or D.StatusAtReview = ' ' then ' '
                 when D.ReopenNewCount > 0 or D.ReopenStatusCount > 0 or D.ReopenAmountCount > 0
                   or D.ReopenConfigCount > 0 or D.StatusRank > D.ReviewRank then 'X'
                 else ' ' end as abap_boolean )             as IsReopened,
      cast( D.ReopenNewCount + D.ReopenStatusCount + D.ReopenAmountCount + D.ReopenConfigCount
            as abap.int4 )                                  as ReopenFindings,
      D.ReopenNewCount,
      D.ReopenStatusCount,
      D.ReopenAmountCount,
      D.ReopenConfigCount,
      cast( case when D.StatusAtReview is null or D.StatusAtReview = ' ' then 'X'
                 when D.ReopenNewCount > 0 or D.ReopenStatusCount > 0 or D.ReopenAmountCount > 0
                   or D.ReopenConfigCount > 0 then 'X'
                 when D.StatusRank > D.ReviewRank then 'X'
                 else ' ' end as abap_boolean )             as IsAwaitingReview,
      cast( case when D.StatusRank > 0 then 'X' else ' ' end as abap_boolean ) as IsFlagged
}
