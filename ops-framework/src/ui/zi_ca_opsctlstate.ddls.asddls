// Artifact: zi_ca_opsctlstate.ddls.asddls
// Purpose: Derived state of a control on a business date (rules of ZCL_CA_OPS_REVIEW_POLICY):
//          status H healthy / W watch / A action required from the rank of the date's live findings;
//          signed off (a review row); AWAITING REVIEW = not signed off, or the status now worse than at the
//          sign-off, or a finding raised after the sign-off; flagged = watch or action required.
//          Read-only.
// Modification log: 2026-11-10 | Initial version (control register and daily control review).
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
      cast( case when D.StatusAtReview is null or D.StatusAtReview = ' ' then 'X'
                 when D.StatusRank > D.ReviewRank then 'X'
                 when D.LastFindingAt is not null and D.LastFindingAt > D.ReviewedAt then 'X'
                 else ' ' end as abap_boolean )             as IsAwaitingReview,
      cast( case when D.StatusRank > 0 then 'X' else ' ' end as abap_boolean ) as IsFlagged
}
