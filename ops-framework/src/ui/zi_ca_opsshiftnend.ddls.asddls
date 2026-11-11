// Artifact: zi_ca_opsshiftnend.ddls.asddls
// Purpose: End of the next shift per team: the earliest candidate start (ZI_CA_OpsShiftCand) after the start of the
//          next shift (ZI_CA_OpsShiftNext) - planned downtime windows starting before it start "next shift" in the
//          shift handover. Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: shift handover).
// VERIFY-ADT: comparison of two columns in the WHERE condition (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Shift handover: end of the next shift'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CA_OpsShiftNEnd
  as select from ZI_CA_OpsShiftCand as Cand
    inner join   ZI_CA_OpsShiftNext as Nxt on Nxt.Team = Cand.Team
{
  key Cand.Team,
      min( Cand.StartUtc )                                  as NextEndUtc
}
where
  Cand.StartUtc > Nxt.NextStartUtc
group by
  Cand.Team
