// Artifact: zi_ca_opsctlfindday.ddls.asddls
// Purpose: Derived status of a control per business date: the worst status rank of its live findings of the
//          date (ZI_CA_OpsCtlFind: 2 action required, 1 watch, 0 healthy), how many there are and when the
//          latest was raised (UTC; a finding after the sign-off makes the control await review again).
//          Aggregated on the database, nothing stored. Read-only.
// Modification log: 2026-11-10 | Initial version (control register and daily control review).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control review: status per business date'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsCtlFindDay
  as select from ZI_CA_OpsCtlFind
{
  key Area,
  key ControlId,
  key BusinessDate,
      max( StatusRank )                                     as StatusRank,
      max( CreatedAt )                                      as LastFindingAt,
      cast( count( * ) as abap.int4 )                       as FindingCount
}
group by
  Area,
  ControlId,
  BusinessDate
