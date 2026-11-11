// Artifact: zi_ca_opsexctimes.ddls.asddls
// Purpose: Times of an exception episode (ZI_CA_OpsExcEpisode): seconds from the first raise to the first
//          assignment (ZI_CA_OpsExcAssign1; null = never assigned), to the resolution (resolved episodes; also an
//          auto-resolve by the next run of the check) and, while open or assigned, to now; re-opened (an earlier
//          resolved episode of the same object, check and company code, ZI_CA_OpsExcReopen); month (YYYYMM) and
//          week (YYYYWW, I_CalendarDate) of the raise in METRIC_TIME_ZONE. Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: response-time metrics).
// VERIFY-ADT: I_CalendarDate element YearWeek (fallback: CalendarYear and CalendarWeek); a CASE without ELSE over
//             tstmp_seconds_between is null (averages ignore it); left outer join on six elements (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Response times of an exception'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsExcTimes
  as select from    ZI_CA_OpsExcEpisode as Ep
    left outer join I_CalendarDate      as Cal on  Cal.CalendarDate = Ep.RaisedDate
    left outer join ZI_CA_OpsExcAssign1 as Asg on  Asg.Area        = Ep.Area
                                               and Asg.ObjectType  = Ep.ObjectType
                                               and Asg.ObjectKey   = Ep.ObjectKey
                                               and Asg.CheckCode   = Ep.CheckCode
                                               and Asg.CompanyCode = Ep.CompanyCode
                                               and Asg.FirstSeenAt = Ep.FirstSeenAt
    left outer join ZI_CA_OpsExcReopen  as Ro  on  Ro.RunId     = Ep.RunId
                                               and Ro.FindingNo = Ep.FindingNo
{
  key Ep.RunId,
  key Ep.FindingNo,
      Ep.Area,
      Ep.CompanyCode,
      Ep.Team,
      Ep.CheckCode,
      Ep.Severity,
      Ep.Disposition,
      Ep.RaisedDate,
      cast( substring( cast( Ep.RaisedDate as abap.char( 8 ) ), 1, 6 ) as abap.numc( 6 ) ) as RaisedMonth,
      Cal.YearWeek                                          as RaisedWeek,
      Ep.FirstSeenAt,
      Asg.FirstAssignedAt,
      Ep.ResolvedAt,
      case when Asg.FirstAssignedAt is not null
           then tstmp_seconds_between( cast( Ep.FirstSeenAt as timestamp ), cast( Asg.FirstAssignedAt as timestamp ),
                                       'NULL' ) end         as AssignSeconds,
      case when Ep.Disposition = 'R'
           then tstmp_seconds_between( cast( Ep.FirstSeenAt as timestamp ), cast( Ep.ResolvedAt as timestamp ),
                                       'NULL' ) end         as ResolveSeconds,
      case when Ep.Disposition = 'O' or Ep.Disposition = 'A'
           then tstmp_seconds_between( cast( Ep.FirstSeenAt as timestamp ), tstmp_current_utctimestamp( ),
                                       'NULL' ) end         as OpenSeconds,
      cast( case when Ro.EarlierResolved is null then 0 else 1 end as abap.int4 ) as ReopenedCount,
      // Flags beside the seconds: the metrics count by them (a null is not a value a test double can hold)
      cast( case when Asg.FirstAssignedAt is null then ' ' else 'X' end as abap_boolean ) as IsAssigned,
      cast( case Ep.Disposition when 'R' then 'X' else ' ' end as abap_boolean ) as IsResolved,
      cast( case when Ep.Disposition = 'O' or Ep.Disposition = 'A' then 'X' else ' ' end as abap_boolean ) as IsOpen
}
