// Artifact: zr_cd_hckcheck.ddls.asddls
// Purpose: Root of the health check dashboard (analytical list page, OData V4,
//          docs/Dashboard_Health_Check.md): one row per active check (ZCD_HCK_DEF) with its
//          category, priority and its status in the last completed morning report run (the as-of
//          run): RED (B / E finding of the run), AMBER (W), WARMUP (only BASELINE_WARMUP
//          information - the baseline has fewer than 3 points), GREEN (ran: metric rows or only
//          information findings), NO_RESULT (no metric and no finding in that run: not selected by
//          the run's variant, or a check that measures nothing). The run's overall RAG and score
//          stay authoritative in ZCD_OPS_RUN (ZR_CD_HckAsOf). Open exceptions per check (any run)
//          and the as-of fields on every row. Drill-down: check -> metric history -> findings.
//          Read-only: no behaviour definition.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK health check dashboard - check'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #S, dataClass: #MIXED }
// VERIFY-ADT: LEFT OUTER JOIN conditions on fields of the cross-joined as-of row (7.58)
define root view entity ZR_CD_HckCheck
  as select from    zcd_hck_def        as Def
    cross join      ZR_CD_HckAsOf      as AsOf
    left outer join ZI_CD_HckCheckRes  as Res  on  Res.RunId   = AsOf.RunId
                                               and Res.CheckId = Def.check_id
    left outer join ZI_CD_HckRunMetric as Met  on  Met.RunId   = AsOf.RunId
                                               and Met.CheckId = Def.check_id
    left outer join ZI_CD_HckCheckOpen as OpenExc on  OpenExc.CheckId = Def.check_id
  association [0..*] to ZR_CD_HckMetric as _Metrics  on $projection.CheckId = _Metrics.CheckId
  association [0..*] to ZR_CD_HckFind   as _Findings on $projection.CheckId = _Findings.CheckId
{
  key Def.check_id                                          as CheckId,
      cast( 'HCK' as abap.char( 4 ) )                       as PaymentEngineArea,
      Def.description                                       as CheckText,
      Def.category                                          as Category,
      cast( case Def.category when 'A' then 'Financial integrity'
                              when 'B' then 'Mass-run and job health'
                              when 'C' then 'Exception queues'
                              when 'D' then 'Configuration drift'
                              when 'E' then 'Technical health'
                              else 'Other' end as abap.char( 30 ) ) as CategoryText,
      Def.priority                                          as Priority,
      Def.class_name                                        as ClassName,
      cast( case
              when Res.WorstSeverityRank >= 3   then 'RED'
              when Res.WorstSeverityRank = 2    then 'AMBER'
              when Res.WarmupFindingCount > 0   then 'WARMUP'
              when Res.RunFindingCount > 0 or Met.MetricCount > 0 then 'GREEN'
              else 'NO_RESULT' end as abap.char( 10 ) )     as CheckStatus,
      // UI criticality: 1 red, 2 amber, 3 green, 0 grey (warm-up, no result)
      cast( case
              when Res.WorstSeverityRank >= 3   then 1
              when Res.WorstSeverityRank = 2    then 2
              when Res.WarmupFindingCount > 0   then 0
              when Res.RunFindingCount > 0 or Met.MetricCount > 0 then 3
              else 0 end as abap.int1 )                     as StatusCriticality,
      // Sort order of the list: red, amber, warm-up, no result, green
      cast( case
              when Res.WorstSeverityRank >= 3   then 1
              when Res.WorstSeverityRank = 2    then 2
              when Res.WarmupFindingCount > 0   then 3
              when Res.RunFindingCount > 0 or Met.MetricCount > 0 then 5
              else 4 end as abap.int1 )                     as StatusOrder,
      OpenExc.OldestDueDate                                    as OldestDueDate,
      // ---------------------------------------------------------------- as of
      AsOf.RunId                                            as AsOfRunId,
      AsOf.AsOfAt,
      AsOf.RunRag                                           as AsOfRunRag,
      AsOf.AgeMinutes                                       as MonitorAgeMinutes,
      AsOf.IsStale                                          as MonitorIsStale,
      AsOf.StaleCriticality                                 as MonitorCriticality,
      // ---------------------------------------------------------------- measures
      cast( 1 as abap.int4 )                                as CheckCount,
      cast( case when Res.WorstSeverityRank >= 3 then 1 else 0 end as abap.int4 ) as RedCheckCount,
      cast( case when Res.WorstSeverityRank = 2 then 1 else 0 end as abap.int4 )  as AmberCheckCount,
      cast( case when Res.WorstSeverityRank >= 2 then 0
                 when Res.WarmupFindingCount > 0 then 1
                 else 0 end as abap.int4 )                  as WarmupCheckCount,
      cast( case when Res.WorstSeverityRank >= 2 or Res.WarmupFindingCount > 0 then 0
                 when Res.RunFindingCount > 0 or Met.MetricCount > 0 then 1
                 else 0 end as abap.int4 )                  as GreenCheckCount,
      cast( case when Res.RunFindingCount is null and Met.MetricCount is null then 1
                 else 0 end as abap.int4 )                  as NoResultCheckCount,
      cast( coalesce( Met.MetricCount, 0 ) as abap.int4 )   as MetricCount,
      cast( coalesce( Res.RunFindingCount, 0 ) as abap.int4 ) as RunFindingCount,
      cast( coalesce( OpenExc.OpenFindingCount, 0 ) as abap.int4 ) as OpenFindingCount,
      cast( coalesce( OpenExc.OpenRedCount, 0 ) as abap.int4 )     as OpenRedCount,
      cast( coalesce( OpenExc.OpenAmberCount, 0 ) as abap.int4 )   as OpenAmberCount,
      _Metrics,
      _Findings
}
where Def.active = 'X'
