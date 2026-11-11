// Artifact: zi_ca_opsshiftnext.ddls.asddls
// Purpose: Start of the next shift per team: the earliest candidate start (ZI_CA_OpsShiftCand) after now (UTC).
//          Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: shift handover).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Shift handover: next shift start'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CA_OpsShiftNext
  as select from ZI_CA_OpsShiftCand
{
  key Team,
      min( StartUtc )                                       as NextStartUtc
}
where
  StartUtc > tstmp_current_utctimestamp()
group by
  Team
