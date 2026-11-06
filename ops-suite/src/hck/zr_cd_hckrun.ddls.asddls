// Artifact: zr_cd_hckrun.ddls.asddls
// Purpose: Morning report runs of the last 31 days (health check dashboard, scorecard trend):
//          overall RAG, checks green / amber / red / warm-up (ZCL_CD_HCK_ENGINE->CLOSE_RUN counters),
//          findings, runtime, run message (health score and critical / high counts as text), run
//          date. Test-mode runs are not listed. Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK health check dashboard - run'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #MIXED }
define root view entity ZR_CD_HckRun
  as select from zcd_ops_run
  association [0..*] to ZR_CD_HckFind as _Findings on $projection.RunId = _Findings.RunId
{
  key run_id                                                as RunId,
      cast( 'HCK' as abap.char( 4 ) )                       as PaymentEngineArea,
      variant                                               as RunVariant,
      started_at                                            as StartedAt,
      ended_at                                              as EndedAt,
      tstmp_to_dats( cast( started_at as timestamp ), 'UTC', $session.client, 'NULL' ) as RunDate,
      status                                                as RunStatus,
      rag                                                   as RunRag,
      cast( case rag when 'R' then 1
                     when 'A' then 2
                     when 'G' then 3
                     else 0 end as abap.int1 )              as RagCriticality,
      runtime_ms                                            as RuntimeMs,
      message                                               as RunMessage,
      cast( 1 as abap.int4 )                                as RunCount,
      cast( case rag when 'R' then 1 else 0 end as abap.int4 ) as RedRunCount,
      total_items                                           as CheckCount,
      passed_items                                          as GreenCheckCount,
      warning_items                                         as AmberCheckCount,
      failed_items                                          as RedCheckCount,
      cast( total_items - passed_items - warning_items - failed_items as abap.int4 ) as WarmupCheckCount,
      finding_count                                         as FindingCount,
      _Findings
}
where pe_area   = 'HCK'
  and test_mode = ' '
  and tstmp_to_dats( cast( started_at as timestamp ), 'UTC', $session.client, 'NULL' )
      >= dats_add_days( $session.system_date, -31, 'INITIAL' )
