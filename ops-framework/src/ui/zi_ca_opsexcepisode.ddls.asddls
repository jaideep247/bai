// Artifact: zi_ca_opsexcepisode.ddls.asddls
// Purpose: One row per exception episode - the current row of an exception (severity B / E / W, disposition not
//          superseded and not information): the carry-forward keeps one current row per exception and carries
//          its first time seen, so an episode is identified by area, object type, object key, check code,
//          company code and first time seen. With the owner team (ZI_CA_OpsFindTeam) and the local date of the
//          raise in METRIC_TIME_ZONE. Base of the response-time metrics and the shift handover. Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: metrics and shift handover).
// VERIFY-ADT: tstmp_to_dats over the TIMESTAMPL cast with a time zone element (V27).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Exception episodes (current rows)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsExcEpisode
  as select from zca_ops_finding   as Fnd
    inner join   ZI_CA_OpsFindTeam as Tm on  Tm.RunId     = Fnd.run_id
                                         and Tm.FindingNo = Fnd.finding_no
    inner join   ZI_CA_OpsMetricTz as Tz on  Tz.Language = $session.system_language
{
  key Fnd.run_id                                            as RunId,
  key Fnd.finding_no                                        as FindingNo,
      Fnd.area                                              as Area,
      Fnd.bukrs                                             as CompanyCode,
      Fnd.object_type                                       as ObjectType,
      Fnd.object_key                                        as ObjectKey,
      Fnd.check_code                                        as CheckCode,
      Fnd.rule_id                                           as RuleId,
      Fnd.severity                                          as Severity,
      Fnd.disposition                                       as Disposition,
      Fnd.owner                                             as Owner,
      Fnd.first_seen_at                                     as FirstSeenAt,
      Fnd.resolved_at                                       as ResolvedAt,
      Fnd.corr_role                                         as CorrelationRole,
      Tm.Team,
      tstmp_to_dats( cast( Fnd.first_seen_at as timestamp ), Tz.TimeZone, $session.client, 'NULL' ) as RaisedDate
}
where
  (
       Fnd.severity    = 'B'
    or Fnd.severity    = 'E'
    or Fnd.severity    = 'W'
  )
  and  Fnd.disposition <> 'S'
  and  Fnd.disposition <> 'I'
