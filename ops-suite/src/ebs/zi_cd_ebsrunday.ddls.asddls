// Artifact: zi_cd_ebsrunday.ddls.asddls
// Purpose: End time of the last completed EBS run per run date (UTC day of the start) in the
//          last 31 days - the run whose counters the KPI shows for that day. Summing the runs of
//          a day would count re-validated lines twice (an intraday re-run validates the same
//          statements again). Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS last completed run per day'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_EbsRunDay
  as select from ZI_CD_EbsRunBase
{
  key RunDate,
      max( EndedAt )                                        as LastEndedAt,
      cast( count( * ) as abap.int4 )                       as CompletedRunCount
}
where IsCompleted = 'X'
group by
  RunDate
