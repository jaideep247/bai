// Artifact: zr_ca_opspilot.ddls.asddls
// Purpose: Pilot pack - proof of value in shadow mode (analytical list page "Pilot metrics", service ZUI_CA_OPS_PILOT,
//          cube ZI_CA_OpsPilotCube): one row per exception episode with the dimensions area, business process, check,
//          check code, severity, company code, day / month / week of the raise, reason code, and the measures raised,
//          assigned, resolved, false positives (resolved as not an issue), minutes to assign / to resolve (MTTA /
//          MTTR, reused from ZI_CA_OpsExcTimes), minutes to detect (first seen - event time or business date) against
//          the previous detection time of the check (baseline) and the minutes the framework detected earlier.
//          Averages in the projection; the company code is a key of the dimensions (DCL before aggregation).
//          Read-only, nothing stored.
// Modification log: 2026-11-11 | Initial version (build F: pilot pack).
// VERIFY-ADT: division( ) over the INT8 of tstmp_seconds_between into DEC 15,1 (as ZR_CA_OpsExcMetric) - V143.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pilot metrics'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define root view entity ZR_CA_OpsPilot
  as select from ZI_CA_OpsPilotEp as Ep
{
  key Ep.RunId,
  key Ep.FindingNo,
      Ep.Area,
      Ep.ProcessId,
      Ep.CheckId,
      Ep.CheckCode,
      Ep.CompanyCode,
      Ep.Severity,
      Ep.Disposition,
      Ep.ReasonCode,
      Ep.ConfigVersion,
      Ep.RaisedDate,
      Ep.RaisedMonth,
      Ep.RaisedWeek,
      Ep.FirstSeenAt,
      Ep.BusinessDate,
      Ep.EventAt,
      Ep.IsFalsePositive,
      Ep.BaselineSource,
      cast( 1 as abap.int4 )                                as RaisedCount,
      cast( case Ep.IsAssigned when 'X' then 1 else 0 end as abap.int4 ) as AssignedCount,
      cast( case Ep.IsResolved when 'X' then 1 else 0 end as abap.int4 ) as ResolvedCount,
      cast( case Ep.IsFalsePositive when 'X' then 1 else 0 end as abap.int4 ) as FalsePositiveCount,
      cast( case Ep.IsDetectKnown when 'X' then 1 else 0 end as abap.int4 ) as DetectKnownCount,
      cast( case Ep.HasBaseline when 'X' then 1 else 0 end as abap.int4 ) as BaselineKnownCount,
      cast( case Ep.IsAssigned when 'X' then division( Ep.AssignSeconds, 60, 1 ) end as abap.dec( 15, 1 ) ) as MinutesToAssign,
      cast( case Ep.IsResolved when 'X' then division( Ep.ResolveSeconds, 60, 1 ) end as abap.dec( 15, 1 ) ) as MinutesToResolve,
      cast( case Ep.IsDetectKnown when 'X' then division( Ep.DetectSeconds, 60, 1 ) end as abap.dec( 15, 1 ) ) as MinutesToDetect,
      cast( case Ep.HasBaseline when 'X' then Ep.BaselineMinutes end as abap.dec( 15, 1 ) ) as BaselineMinutes,
      cast( case when Ep.HasBaseline = 'X' and Ep.IsDetectKnown = 'X'
                 then Ep.BaselineMinutes - division( Ep.DetectSeconds, 60, 1 ) end as abap.dec( 15, 1 ) ) as MinutesEarlier,
      cast( case when Ep.HasBaseline = 'X' and Ep.IsDetectKnown = 'X'
                  and division( Ep.DetectSeconds, 60, 1 ) < Ep.BaselineMinutes then 1 else 0 end as abap.int4 ) as EarlierCount
}
