// Artifact: zr_ca_opshandover.ddls.asddls
// Purpose: Shift handover (root, read-only): per team, area and company code since the start of the previous shift
//          of the team (local time of SHIFT_TIME_ZONE) - new exceptions, resolved, still open, escalated, controls
//          of today awaiting sign-off, planned downtime windows active now or starting before the end of the next
//          shift; the shift window (since, current and next start, local and UTC); needs attention = open or
//          escalated exceptions or controls awaiting sign-off. Nothing stored: no handover note (decision of
//          2026-11-11, docs/OPERATIONS_FEATURES.md section 6). Team blank = exceptions of checks no control covers.
// Modification log: 2026-11-11 | Initial version (operations response features: shift handover).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Shift handover'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #MIXED }
define root view entity ZR_CA_OpsHandover
  as select from    ZI_CA_OpsHovrSum  as Sm
    inner join      ZI_CA_OpsShiftTz  as Tz  on Tz.Language = $session.system_language
    left outer join ZI_CA_OpsShiftWin as Own on Own.Team = Sm.Team
    left outer join ZI_CA_OpsShiftWin as Dft on Dft.Team = ' '
{
      @EndUserText.label: 'Team'
  key Sm.Team,
      @EndUserText.label: 'Area'
  key Sm.Area,
      @EndUserText.label: 'Company code'
  key Sm.CompanyCode,
      @EndUserText.label: 'Since (UTC)'
      coalesce( Own.PreviousStartUtc, Dft.PreviousStartUtc ) as SinceUtc,
      @EndUserText.label: 'Since (date)'
      tstmp_to_dats( coalesce( Own.PreviousStartUtc, Dft.PreviousStartUtc ), Tz.TimeZone, $session.client, 'NULL' )
                                                            as SinceDate,
      @EndUserText.label: 'Since (time)'
      tstmp_to_tims( coalesce( Own.PreviousStartUtc, Dft.PreviousStartUtc ), Tz.TimeZone, $session.client, 'NULL' )
                                                            as SinceTime,
      @EndUserText.label: 'Current shift since (time)'
      tstmp_to_tims( coalesce( Own.CurrentStartUtc, Dft.CurrentStartUtc ), Tz.TimeZone, $session.client, 'NULL' )
                                                            as ShiftStartTime,
      @EndUserText.label: 'Next shift (time)'
      tstmp_to_tims( coalesce( Own.NextStartUtc, Dft.NextStartUtc ), Tz.TimeZone, $session.client, 'NULL' )
                                                            as NextShiftTime,
      @EndUserText.label: 'Time zone'
      Tz.TimeZone,
      @EndUserText.label: 'New exceptions'
      Sm.NewExceptions,
      @EndUserText.label: 'Resolved'
      Sm.ResolvedExceptions,
      @EndUserText.label: 'Still open'
      Sm.OpenExceptions,
      @EndUserText.label: 'Escalated'
      Sm.Escalations,
      @EndUserText.label: 'Controls awaiting sign-off'
      Sm.ControlsAwaitingSignOff,
      @EndUserText.label: 'Planned downtime active'
      Sm.DowntimeActive,
      @EndUserText.label: 'Planned downtime next shift'
      Sm.DowntimeNextShift,
      @EndUserText.label: 'Needs attention'
      cast( case when Sm.OpenExceptions > 0 or Sm.Escalations > 0 or Sm.ControlsAwaitingSignOff > 0
                 then 'X' else ' ' end as abap_boolean )    as IsAttention,
      cast( case when Sm.Escalations > 0 then 1
                 when Sm.OpenExceptions > 0 or Sm.ControlsAwaitingSignOff > 0 then 2
                 else 3 end as abap.int1 )                  as AttentionCriticality
}
