// Artifact: zi_ca_opsshiftprev.ddls.asddls
// Purpose: Start of the previous shift per team: the latest candidate start (ZI_CA_OpsShiftCand) before the start
//          of the current shift (ZI_CA_OpsShiftCur) - the "since" of the shift handover. Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: shift handover).
// VERIFY-ADT: comparison of two columns in the WHERE condition (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Shift handover: previous shift start'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CA_OpsShiftPrev
  as select from ZI_CA_OpsShiftCand as Cand
    inner join   ZI_CA_OpsShiftCur  as Cur on Cur.Team = Cand.Team
{
  key Cand.Team,
      max( Cand.StartUtc )                                  as PreviousStartUtc
}
where
  Cand.StartUtc < Cur.CurrentStartUtc
group by
  Cand.Team
