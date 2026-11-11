// Artifact: zi_ca_opshovrevt.ddls.asddls
// Purpose: Events of the shift handover per team, area and company code, since the start of the previous shift
//          of the team (ZI_CA_OpsShiftWin; a team without own times uses the default shift, team blank):
//          EXC - exception episodes (ZI_CA_OpsExcEpisode): new (first raised since), resolved since, still open
//                or assigned now;
//          ESC - escalations sent since (ZCA_OPS_ALLOG with ESC_STEP, the escalated exception's area, company
//                code and team);
//          CTL - controls of the current business date awaiting sign-off (ZR_CA_OpsCtlReview, slice per company
//                code, team of the control);
//          DTW - approved planned downtime windows of an area active now or starting before the end of the next
//                shift, for every team with shift times (a window has no team and no company code).
//          IsRelevant marks the rows the handover counts. Read-only; the reading entity's DCL decides.
// Modification log: 2026-11-11 | Initial version (operations response features: shift handover).
// VERIFY-ADT: UNION ALL of four branches with identical elements and a cross join in the last; coalesce over the
//             columns of two left outer joins of the same view in a CASE condition (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Shift handover: events'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CA_OpsHovrEvt
  as select from    ZI_CA_OpsExcEpisode as Ep
    left outer join ZI_CA_OpsShiftWin   as Own on Own.Team = Ep.Team
    left outer join ZI_CA_OpsShiftWin   as Dft on Dft.Team = ' '
{
  key cast( Ep.Team as abap.char( 10 ) )                    as Team,
  key Ep.Area                                               as Area,
  key Ep.CompanyCode                                        as CompanyCode,
  key cast( 'EXC' as abap.char( 4 ) )                       as Source,
      cast( case when cast( Ep.FirstSeenAt as timestamp ) >= coalesce( Own.PreviousStartUtc, Dft.PreviousStartUtc )
                 then 1 else 0 end as abap.int4 )           as NewCount,
      cast( case when Ep.Disposition = 'R'
                  and cast( Ep.ResolvedAt as timestamp ) >= coalesce( Own.PreviousStartUtc, Dft.PreviousStartUtc )
                 then 1 else 0 end as abap.int4 )           as ResolvedCount,
      cast( case when Ep.Disposition = 'O' or Ep.Disposition = 'A'
                 then 1 else 0 end as abap.int4 )           as OpenCount,
      cast( 0 as abap.int4 )                                as EscalatedCount,
      cast( 0 as abap.int4 )                                as AwaitingSignOff,
      cast( 0 as abap.int4 )                                as DowntimeActive,
      cast( 0 as abap.int4 )                                as DowntimeNextShift,
      cast( case when Ep.Disposition = 'O' or Ep.Disposition = 'A' then 'X'
                 when cast( Ep.FirstSeenAt as timestamp ) >= coalesce( Own.PreviousStartUtc, Dft.PreviousStartUtc )
                 then 'X'
                 when Ep.Disposition = 'R'
                  and cast( Ep.ResolvedAt as timestamp ) >= coalesce( Own.PreviousStartUtc, Dft.PreviousStartUtc )
                 then 'X'
                 else ' ' end as abap_boolean )             as IsRelevant
}

union all

select from       zca_ops_allog     as Lg
  inner join      zca_ops_finding   as Fnd on  Fnd.run_id     = Lg.run_id
                                           and Fnd.finding_no = Lg.finding_no
  inner join      ZI_CA_OpsFindTeam as Tm  on  Tm.RunId       = Lg.run_id
                                           and Tm.FindingNo   = Lg.finding_no
  left outer join ZI_CA_OpsShiftWin as Own on  Own.Team       = Tm.Team
  left outer join ZI_CA_OpsShiftWin as Dft on  Dft.Team       = ' '
{
  key cast( Tm.Team as abap.char( 10 ) )                    as Team,
  key Fnd.area                                              as Area,
  key Fnd.bukrs                                             as CompanyCode,
  key cast( 'ESC' as abap.char( 4 ) )                       as Source,
      cast( 0 as abap.int4 )                                as NewCount,
      cast( 0 as abap.int4 )                                as ResolvedCount,
      cast( 0 as abap.int4 )                                as OpenCount,
      cast( case when cast( Lg.sent_at as timestamp ) >= coalesce( Own.PreviousStartUtc, Dft.PreviousStartUtc )
                 then 1 else 0 end as abap.int4 )           as EscalatedCount,
      cast( 0 as abap.int4 )                                as AwaitingSignOff,
      cast( 0 as abap.int4 )                                as DowntimeActive,
      cast( 0 as abap.int4 )                                as DowntimeNextShift,
      cast( case when cast( Lg.sent_at as timestamp ) >= coalesce( Own.PreviousStartUtc, Dft.PreviousStartUtc )
                 then 'X' else ' ' end as abap_boolean )    as IsRelevant
}
where
      Lg.esc_step > 0
  and Lg.status   = 'S'

union all

select from ZR_CA_OpsCtlReview as Rv
{
  key cast( Rv.Team as abap.char( 10 ) )                    as Team,
  key Rv.Area                                               as Area,
  key Rv.CompanyCode                                        as CompanyCode,
  key cast( 'CTL' as abap.char( 4 ) )                       as Source,
      cast( 0 as abap.int4 )                                as NewCount,
      cast( 0 as abap.int4 )                                as ResolvedCount,
      cast( 0 as abap.int4 )                                as OpenCount,
      cast( 0 as abap.int4 )                                as EscalatedCount,
      cast( 1 as abap.int4 )                                as AwaitingSignOff,
      cast( 0 as abap.int4 )                                as DowntimeActive,
      cast( 0 as abap.int4 )                                as DowntimeNextShift,
      cast( 'X' as abap_boolean )                           as IsRelevant
}
where
      Rv.IsCurrentDay     = 'X'
  and Rv.IsAwaitingReview = 'X'

union all

select from ZI_CA_OpsDtwNow   as Dw
  cross join ZI_CA_OpsShiftWin as Sw
{
  key cast( Sw.Team as abap.char( 10 ) )                    as Team,
  key Dw.Area                                               as Area,
  key cast( ' ' as bukrs )                                  as CompanyCode,
  key cast( 'DTW' as abap.char( 4 ) )                       as Source,
      cast( 0 as abap.int4 )                                as NewCount,
      cast( 0 as abap.int4 )                                as ResolvedCount,
      cast( 0 as abap.int4 )                                as OpenCount,
      cast( 0 as abap.int4 )                                as EscalatedCount,
      cast( 0 as abap.int4 )                                as AwaitingSignOff,
      cast( case Dw.IsActive when 'X' then 1 else 0 end as abap.int4 ) as DowntimeActive,
      cast( case when Dw.StartsInSeconds > 0 and cast( Dw.FromUtc as timestamp ) < Sw.NextEndUtc
                 then 1 else 0 end as abap.int4 )           as DowntimeNextShift,
      cast( case when Dw.IsActive = 'X' then 'X'
                 when Dw.StartsInSeconds > 0 and cast( Dw.FromUtc as timestamp ) < Sw.NextEndUtc then 'X'
                 else ' ' end as abap_boolean )             as IsRelevant
}
where
      Dw.IsApproved    = 'X'
  and Dw.EndsInSeconds > 0
