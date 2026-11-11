// Artifact: zi_ca_opsshiftcand.ddls.asddls
// Purpose: Candidate shift starts per team: every start time of the team (ZI_CA_OpsShiftDef) on every local date
//          from two days before to two days after today (SHIFT_TIME_ZONE), as a UTC time stamp - enough to find the
//          current, previous, next and the following shift start of a team with one or more shifts a day. Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: shift handover).
// VERIFY-ADT: cross join with I_CalendarDate and an inner join (as ZR_CA_OpsCheckStatus); dats_tims_to_tstmp with a
//             time zone element; dats_add_days over tstmp_to_dats in the WHERE condition (as ZI_CA_OpsBusDay).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Shift handover: candidate shift starts'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CA_OpsShiftCand
  as select from ZI_CA_OpsShiftDef as Def
    cross join   I_CalendarDate    as Cal
    inner join   ZI_CA_OpsShiftTz  as Tz on Tz.Language = $session.system_language
{
  key Def.Team,
  key Cal.CalendarDate                                      as ShiftDate,
  key Def.StartTime,
      dats_tims_to_tstmp( Cal.CalendarDate, Def.StartTime, Tz.TimeZone, $session.client, 'NULL' ) as StartUtc
}
where
      Cal.CalendarDate >= dats_add_days( tstmp_to_dats( tstmp_current_utctimestamp(), Tz.TimeZone, $session.client, 'NULL' ),
                                         -2, 'INITIAL' )
  and Cal.CalendarDate <= dats_add_days( tstmp_to_dats( tstmp_current_utctimestamp(), Tz.TimeZone, $session.client, 'NULL' ),
                                         2, 'INITIAL' )
