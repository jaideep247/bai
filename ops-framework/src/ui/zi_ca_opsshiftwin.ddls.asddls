// Artifact: zi_ca_opsshiftwin.ddls.asddls
// Purpose: Shift window per team (UTC): start of the previous shift (the "since" of the handover), of the current
//          and of the next shift, and the end of the next shift. Team blank = the default shift
//          (SHIFT_TIMES_DEFAULT), used for teams without own times. Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: shift handover).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Shift handover: shift window per team'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CA_OpsShiftWin
  as select from    ZI_CA_OpsShiftCur  as Cur
    left outer join ZI_CA_OpsShiftPrev as Prv on Prv.Team = Cur.Team
    left outer join ZI_CA_OpsShiftNext as Nxt on Nxt.Team = Cur.Team
    left outer join ZI_CA_OpsShiftNEnd as Nnd on Nnd.Team = Cur.Team
{
  key Cur.Team,
      coalesce( Prv.PreviousStartUtc, Cur.CurrentStartUtc ) as PreviousStartUtc,
      Cur.CurrentStartUtc,
      Nxt.NextStartUtc,
      Nnd.NextEndUtc
}
