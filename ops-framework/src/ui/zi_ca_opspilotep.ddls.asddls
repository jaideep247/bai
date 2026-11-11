// Artifact: zi_ca_opspilotep.ddls.asddls
// Purpose: Pilot pack (docs/PILOT_PACK.md): one row per exception episode (ZI_CA_OpsExcTimes - first raise, first
//          assignment, resolution, month, week) with the pilot measures: business process (GROUP1) and check (GROUP2),
//          reason code, false positive (resolved with the reason of PILOT_FP_REASON, default NOT_AN_ISSUE), time to
//          detect = first seen - event time of the finding (EVENT_AT; else 00:00 UTC of its business date BUS_DATE;
//          not measurable without either), and the previous detection time of the check (ZCA_OPS_PILOTBL) for the
//          comparison. Read-only, nothing stored; production data stays in the system (the pilot exports figures).
// Modification log: 2026-11-11 | Initial version (build F: pilot pack).
// VERIFY-ADT: dats_tims_to_tstmp with a literal time zone, tstmp_seconds_between over TIMESTAMPL casts, CASE without
//             ELSE (null ignored by averages) - V143.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pilot pack: exception episodes'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsPilotEp
  as select from    ZI_CA_OpsExcTimes as T
    inner join      zca_ops_finding   as Fnd on  Fnd.run_id     = T.RunId
                                             and Fnd.finding_no = T.FindingNo
    inner join      ZI_CA_OpsPilotCfg as Cfg on  Cfg.Language = $session.system_language
    left outer join zca_ops_pilotbl   as Bl  on  Bl.area     = Fnd.area
                                             and Bl.check_id = Fnd.group2
{
  key T.RunId,
  key T.FindingNo,
      T.Area,
      Fnd.group1                                            as ProcessId,
      Fnd.group2                                            as CheckId,
      T.CheckCode,
      T.CompanyCode,
      T.Severity,
      T.Disposition,
      Fnd.reason_code                                       as ReasonCode,
      Fnd.cfg_version                                       as ConfigVersion,
      T.RaisedDate,
      T.RaisedMonth,
      T.RaisedWeek,
      T.FirstSeenAt,
      Fnd.bus_date                                          as BusinessDate,
      Fnd.event_at                                          as EventAt,
      T.IsAssigned,
      T.IsResolved,
      T.IsOpen,
      T.AssignSeconds,
      T.ResolveSeconds,
      cast( case when T.IsResolved = 'X' and Fnd.reason_code = Cfg.FalsePositiveReason then 'X' else ' ' end
            as abap_boolean )                               as IsFalsePositive,
      case when Fnd.event_at is not initial
           then tstmp_seconds_between( cast( Fnd.event_at as timestamp ), cast( T.FirstSeenAt as timestamp ), 'NULL' )
           when Fnd.bus_date is not initial
           then tstmp_seconds_between( dats_tims_to_tstmp( Fnd.bus_date, cast( '000000' as abap.tims ), 'UTC',
                                                           $session.client, 'NULL' ),
                                       cast( T.FirstSeenAt as timestamp ), 'NULL' ) end as DetectSeconds,
      cast( case when Fnd.event_at is not initial or Fnd.bus_date is not initial then 'X' else ' ' end
            as abap_boolean )                               as IsDetectKnown,
      Bl.baseline_min                                       as BaselineMinutes,
      Bl.source                                             as BaselineSource,
      cast( case when Bl.baseline_min is null then ' ' else 'X' end as abap_boolean ) as HasBaseline
}
