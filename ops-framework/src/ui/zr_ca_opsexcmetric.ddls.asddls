// Artifact: zr_ca_opsexcmetric.ddls.asddls
// Purpose: Response-time metrics of exceptions (MTTA / MTTR): one row per exception episode with its dimensions -
//          area, owner team (where a control covers the check), check code, severity, company code, month and
//          week of the raise (METRIC_TIME_ZONE) - and measures: raised, assigned, resolved, open, re-opened (raised
//          again after a resolution), minutes to assign / to resolve (averages: @Aggregation.default #AVG in the
//          projection; null when not assigned / not resolved), open minutes, and counters per time bucket (CDS has
//          no percentile: the buckets are the distribution). Bucket bounds in seconds: assigned within 15 min,
//          1 h, 4 h, 1 day, later, never; resolved within 1 h, 4 h, 1 day, 3 days, later; open less than 1 day,
//          1-3 days, 3-7 days, more (ZIF_CA_OPS_RESP_TYPES=>GC_METRIC_SECONDS). The company code is a key of the
//          dimensions, so a sum after the DCL never mixes company codes. Read-only, nothing stored.
// Modification log: 2026-11-11 | Initial version (operations response features: response-time metrics).
// VERIFY-ADT: division( ) over the INT8 of tstmp_seconds_between into DEC 15,1; OData V4 $apply average over the
//             null values of a CASE without ELSE (analytical list page, overview card).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Exception response-time metrics'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define root view entity ZR_CA_OpsExcMetric
  as select from ZI_CA_OpsExcTimes as T
{
  key T.RunId,
  key T.FindingNo,
      T.Area,
      T.Team,
      T.CheckCode,
      T.Severity,
      T.CompanyCode,
      T.Disposition,
      T.RaisedDate,
      T.RaisedMonth,
      T.RaisedWeek,
      T.FirstSeenAt,
      T.FirstAssignedAt,
      T.ResolvedAt,
      cast( 1 as abap.int4 )                                as RaisedCount,
      cast( case T.IsAssigned when 'X' then 1 else 0 end as abap.int4 ) as AssignedCount,
      cast( case T.IsResolved when 'X' then 1 else 0 end as abap.int4 ) as ResolvedCount,
      cast( case T.IsOpen when 'X' then 1 else 0 end as abap.int4 ) as OpenCount,
      T.ReopenedCount,
      cast( case T.IsAssigned when 'X' then division( T.AssignSeconds, 60, 1 ) end as abap.dec( 15, 1 ) ) as MinutesToAssign,
      cast( case T.IsResolved when 'X' then division( T.ResolveSeconds, 60, 1 ) end as abap.dec( 15, 1 ) ) as MinutesToResolve,
      cast( case T.IsOpen when 'X' then division( T.OpenSeconds, 60, 1 ) end as abap.dec( 15, 1 ) ) as OpenMinutes,
      // Time to assign: 15 min, 1 h, 4 h, 1 day, later, never
      cast( case when T.IsAssigned = 'X' and T.AssignSeconds <= 900 then 1 else 0 end as abap.int4 ) as AssignedIn15Min,
      cast( case when T.IsAssigned = 'X' and T.AssignSeconds > 900 and T.AssignSeconds <= 3600
                 then 1 else 0 end as abap.int4 )           as AssignedIn1Hour,
      cast( case when T.IsAssigned = 'X' and T.AssignSeconds > 3600 and T.AssignSeconds <= 14400
                 then 1 else 0 end as abap.int4 )           as AssignedIn4Hours,
      cast( case when T.IsAssigned = 'X' and T.AssignSeconds > 14400 and T.AssignSeconds <= 86400
                 then 1 else 0 end as abap.int4 )           as AssignedIn1Day,
      cast( case when T.IsAssigned = 'X' and T.AssignSeconds > 86400 then 1 else 0 end as abap.int4 ) as AssignedLater,
      cast( case T.IsAssigned when 'X' then 0 else 1 end as abap.int4 ) as NotAssigned,
      // Time to resolve: 1 h, 4 h, 1 day, 3 days, later
      cast( case when T.IsResolved = 'X' and T.ResolveSeconds <= 3600 then 1 else 0 end as abap.int4 ) as ResolvedIn1Hour,
      cast( case when T.IsResolved = 'X' and T.ResolveSeconds > 3600 and T.ResolveSeconds <= 14400
                 then 1 else 0 end as abap.int4 )           as ResolvedIn4Hours,
      cast( case when T.IsResolved = 'X' and T.ResolveSeconds > 14400 and T.ResolveSeconds <= 86400
                 then 1 else 0 end as abap.int4 )           as ResolvedIn1Day,
      cast( case when T.IsResolved = 'X' and T.ResolveSeconds > 86400 and T.ResolveSeconds <= 259200
                 then 1 else 0 end as abap.int4 )           as ResolvedIn3Days,
      cast( case when T.IsResolved = 'X' and T.ResolveSeconds > 259200 then 1 else 0 end as abap.int4 ) as ResolvedLater,
      // Open exceptions by age: less than 1 day, 1-3 days, 3-7 days, more
      cast( case when T.IsOpen = 'X' and T.OpenSeconds <= 86400 then 1 else 0 end as abap.int4 ) as OpenUnder1Day,
      cast( case when T.IsOpen = 'X' and T.OpenSeconds > 86400 and T.OpenSeconds <= 259200
                 then 1 else 0 end as abap.int4 )           as Open1To3Days,
      cast( case when T.IsOpen = 'X' and T.OpenSeconds > 259200 and T.OpenSeconds <= 604800
                 then 1 else 0 end as abap.int4 )           as Open3To7Days,
      cast( case when T.IsOpen = 'X' and T.OpenSeconds > 604800 then 1 else 0 end as abap.int4 ) as OpenOver7Days
}
