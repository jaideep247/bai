// Artifact: zi_ca_opsshiftcur.ddls.asddls
// Purpose: Start of the current shift per team: the latest candidate start (ZI_CA_OpsShiftCand) not after now (UTC).
//          Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: shift handover).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Shift handover: current shift start'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CA_OpsShiftCur
  as select from ZI_CA_OpsShiftCand
{
  key Team,
      max( StartUtc )                                       as CurrentStartUtc
}
where
  StartUtc <= tstmp_current_utctimestamp()
group by
  Team
