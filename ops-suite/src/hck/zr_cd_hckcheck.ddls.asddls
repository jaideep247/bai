// Artifact: zr_cd_hckcheck.ddls.asddls
// Purpose: Root of the health check dashboard (analytical list page, OData V4,
//          docs/Dashboard_Health_Check.md): one row per active check (ZCD_HCK_DEF) with its
//          category, priority and its verdict in the last completed morning report run (the as-of
//          run) as the engine persisted it (ZI_CD_HckResult over ZCD_HCK_RESULT - the decision the
//          report uses, never re-derived): RED, AMBER, GREEN, WARMUP, GREY, FAILED (plug-in error,
//          never green), SKIPPED (outside the run's scope), NO_RESULT (no row in that run, e.g. a
//          check created after it). Completion, evidence availability, run scope, baseline mode
//          and the summary come with the verdict. The run's overall RAG and score stay
//          authoritative in ZCD_OPS_RUN (ZR_CD_HckAsOf). Open exceptions per check (any run) and the
//          as-of fields on every row. Drill-down: check -> metric history -> findings.
//          Read-only: no behaviour definition.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
//                   2026-11-07 | Verdict from ZCD_HCK_RESULT (ZI_CD_HckResult) instead of findings and metric
//                              | rows (ZI_CD_HckCheckRes / ZI_CD_HckRunMetric removed): dashboard = report.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK health check dashboard - check'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #S, dataClass: #MIXED }
// VERIFY-ADT: LEFT OUTER JOIN conditions on fields of the cross-joined as-of row (7.58)
define root view entity ZR_CD_HckCheck
  as select from    zcd_hck_def        as Def
    cross join      ZR_CD_HckAsOf      as AsOf
    left outer join ZI_CD_HckResult    as Res  on  Res.RunId   = AsOf.RunId
                                               and Res.CheckId = Def.check_id
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
      // The verdict as the morning report decided it; no row in the as-of run = NO_RESULT
      cast( coalesce( Res.CheckStatus, 'NO_RESULT' ) as abap.char( 10 ) ) as CheckStatus,
      // UI criticality: 1 red (also a failed check), 2 amber, 3 green, 0 grey (warm-up, grey, skipped, no result)
      cast( case Res.CheckStatus
              when 'RED'    then 1
              when 'FAILED' then 1
              when 'AMBER'  then 2
              when 'GREEN'  then 3
              else 0 end as abap.int1 )                     as StatusCriticality,
      // Sort order of the list: red / failed, amber, warm-up / grey, skipped / no result, green
      cast( case Res.CheckStatus
              when 'RED'    then 1
              when 'FAILED' then 1
              when 'AMBER'  then 2
              when 'WARMUP' then 3
              when 'GREY'   then 3
              when 'GREEN'  then 5
              else 4 end as abap.int1 )                     as StatusOrder,
      Res.Completion                                        as CheckCompletion,
      Res.EvidenceAvailability                              as EvidenceAvailability,
      Res.RunScope                                          as RunScope,
      Res.BaselineMode                                      as BaselineMode,
      Res.ResultMessage                                     as ResultMessage,
      Res.ExecutedAt                                        as ExecutedAt,
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
      cast( case Res.CheckStatus when 'RED' then 1 when 'FAILED' then 1 else 0 end as abap.int4 ) as RedCheckCount,
      cast( case Res.CheckStatus when 'FAILED' then 1 else 0 end as abap.int4 ) as FailedCheckCount,
      cast( case Res.CheckStatus when 'AMBER' then 1 else 0 end as abap.int4 )  as AmberCheckCount,
      cast( case Res.CheckStatus when 'WARMUP' then 1 else 0 end as abap.int4 ) as WarmupCheckCount,
      cast( case Res.CheckStatus when 'GREEN' then 1 else 0 end as abap.int4 )  as GreenCheckCount,
      cast( case Res.CheckStatus when 'RED'    then 0
                                 when 'FAILED' then 0
                                 when 'AMBER'  then 0
                                 when 'WARMUP' then 0
                                 when 'GREEN'  then 0
                                 else 1 end as abap.int4 )  as NoResultCheckCount,
      cast( coalesce( Res.MetricCount, 0 ) as abap.int4 )   as MetricCount,
      cast( coalesce( Res.RunFindingCount, 0 ) as abap.int4 ) as RunFindingCount,
      cast( coalesce( OpenExc.OpenFindingCount, 0 ) as abap.int4 ) as OpenFindingCount,
      cast( coalesce( OpenExc.OpenRedCount, 0 ) as abap.int4 )     as OpenRedCount,
      cast( coalesce( OpenExc.OpenAmberCount, 0 ) as abap.int4 )   as OpenAmberCount,
      _Metrics,
      _Findings
}
where Def.active = 'X'
