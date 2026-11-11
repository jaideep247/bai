// Artifact: zi_ca_opshovrsum.ddls.asddls
// Purpose: Counts of the shift handover per team, area and company code (ZI_CA_OpsHovrEvt, relevant rows only):
//          new exceptions, resolved, still open, escalated, controls awaiting sign-off, planned downtime windows
//          active and starting next shift. The company code stays a key, so a card's sum after the DCL never mixes
//          company codes. Aggregated on the database, nothing stored. Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: shift handover).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Shift handover: counts'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CA_OpsHovrSum
  as select from ZI_CA_OpsHovrEvt
{
  key Team,
  key Area,
  key CompanyCode,
      cast( sum( NewCount ) as abap.int4 )                  as NewExceptions,
      cast( sum( ResolvedCount ) as abap.int4 )             as ResolvedExceptions,
      cast( sum( OpenCount ) as abap.int4 )                 as OpenExceptions,
      cast( sum( EscalatedCount ) as abap.int4 )            as Escalations,
      cast( sum( AwaitingSignOff ) as abap.int4 )           as ControlsAwaitingSignOff,
      cast( sum( DowntimeActive ) as abap.int4 )            as DowntimeActive,
      cast( sum( DowntimeNextShift ) as abap.int4 )         as DowntimeNextShift
}
where
  IsRelevant = 'X'
group by
  Team,
  Area,
  CompanyCode
