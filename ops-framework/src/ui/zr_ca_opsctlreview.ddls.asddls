// Artifact: zr_ca_opsctlreview.ddls.asddls
// Purpose: Daily control review (RAP BO, root): one row per slice - active control, business date of the last
//          31 days and company code (blank = the area-level slice; ZI_CA_OpsCtlSlice) - all derived live - status (Healthy / Watch / Action required, texts of domain
//          ZCA_OPS_CTL_STATUS), open exceptions, evidence run, guidance, cut-off - and the sign-off of the
//          date (ZCA_OPS_REVIEW, the only persisted part: action markReviewed). AWAITING REVIEW as
//          ZI_CA_OpsCtlState; OVERDUE = awaiting and the business date is over, or today after the
//          control's cut-off (local time of CONTROL_TIME_ZONE; no cut-off = end of the day). Counters for
//          the consumers' cards (checks reviewed n / m, awaiting, overdue, action required, watch). The
//          time of the sign-off is shown in CONTROL_TIME_ZONE. Consumers read this view for their cards.
// Modification log: 2026-11-10 | Initial version (control register and daily control review).
//                   2026-11-10 | Company-code isolation: key CompanyCode (slice); every counter counts slices, so
//                                a card of a user of one company code sums only the slices he may read (DCL on
//                                the slice's own company code = filter before the cards' aggregation).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Daily control review'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #MIXED }
define root view entity ZR_CA_OpsCtlReview
  as select from ZI_CA_OpsCtlState as S
  association [0..*] to ZI_CA_OpsCtlStatusT as _StatusText on $projection.ControlStatus = _StatusText.ControlStatus
  association [0..*] to ZI_CA_OpsCtlStatusT as _ResultText on $projection.ReviewResult = _ResultText.ControlStatus
{
  key S.Area,
  key S.ControlId,
  key S.BusinessDate,
  key S.CompanyCode,
      S.ControlName,
      S.Category,
      S.Owner,
      S.Backup,
      S.Team,
      S.CutoffTime,
      S.RunbookUrl,
      S.Sequence,
      S.Guidance,
      S.TimeZone,
      S.IsCurrentDay,
      @ObjectModel.text.association: '_StatusText'
      S.ControlStatus,
      S.StatusRank,
      cast( case S.StatusRank when 2 then 1
                              when 1 then 2
                              else 3 end as abap.int1 )     as StatusCriticality,
      S.FindingCount,
      S.LastFindingAt,
      S.OpenExceptions,
      S.EvidenceRun,
      S.EvidenceRunAt,
      S.StatusAtReview,
      @ObjectModel.text.association: '_ResultText'
      S.ReviewResult,
      S.ReviewedEvidenceRun,
      S.ReviewedBy,
      S.ReviewedAt,
      tstmp_to_dats( cast( S.ReviewedAt as timestamp ), S.TimeZone, $session.client, 'NULL' ) as ReviewedOnLocal,
      tstmp_to_tims( cast( S.ReviewedAt as timestamp ), S.TimeZone, $session.client, 'NULL' ) as ReviewedTimeLocal,
      S.Observation,
      S.NextAction,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      S.LastChangedAt,
      S.IsReviewed,
      S.IsAwaitingReview,
      S.IsFlagged,
      cast( case when S.IsAwaitingReview = 'X'
                  and (    S.BusinessDate < S.Today
                        or ( S.BusinessDate = S.Today and S.CutoffTime <> '000000' and S.NowTime > S.CutoffTime ) )
                 then 'X' else ' ' end as abap_boolean )   as IsReviewOverdue,
      cast( 1 as abap.int4 )                                as ControlCount,
      cast( case S.IsReviewed when 'X' then 1 else 0 end as abap.int4 )       as ReviewedCount,
      cast( case S.IsAwaitingReview when 'X' then 1 else 0 end as abap.int4 ) as AwaitingCount,
      cast( case when S.IsAwaitingReview = 'X'
                  and (    S.BusinessDate < S.Today
                        or ( S.BusinessDate = S.Today and S.CutoffTime <> '000000' and S.NowTime > S.CutoffTime ) )
                 then 1 else 0 end as abap.int4 )           as OverdueCount,
      cast( case S.StatusRank when 2 then 1 else 0 end as abap.int4 ) as ActionRequiredCount,
      cast( case S.StatusRank when 1 then 1 else 0 end as abap.int4 ) as WatchCount,
      cast( case when S.StatusRank > 0 then 1 else 0 end as abap.int4 ) as FlaggedCount,
      _StatusText,
      _ResultText
}
