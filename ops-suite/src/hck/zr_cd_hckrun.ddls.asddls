// Artifact: zr_cd_hckrun.ddls.asddls
// Purpose: Morning report runs of the last 31 days (health check dashboard, scorecard trend):
//          overall RAG, checks green / amber / red / warm-up (ZCL_CD_HCK_ENGINE->CLOSE_RUN counters),
//          findings, runtime, run message (health score and critical / high counts as text), run
//          date. Test-mode runs are not listed. Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
//                   2026-11-10 | Company-code isolation: one row per run slice (ZI_CD_HckRunSlice, key CompanyCode; the window moved there);
//                                run counters on the area-level slice only; FindingCount per company code from the findings (was the run
//                                header's count of every company code).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK health check dashboard - run'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #MIXED }
define root view entity ZR_CD_HckRun
  as select from    ZI_CD_HckRunSlice as Slice
    inner join      zca_ops_run       as Run  on  Run.run_id = Slice.RunId
    left outer join ZI_CD_HckRunFind  as Find on  Find.RunId       = Slice.RunId
                                              and Find.CompanyCode = Slice.CompanyCode
  association [0..*] to ZR_CD_HckFind as _Findings on $projection.RunId = _Findings.RunId
{
  key Run.run_id                                            as RunId,
      // Blank = the area-level slice (run counters and findings without company code)
  key Slice.CompanyCode,
      cast( 'CD_HCK' as abap.char( 16 ) )                       as PaymentEngineArea,
      Run.variant                                               as RunVariant,
      Run.started_at                                            as StartedAt,
      Run.ended_at                                              as EndedAt,
      tstmp_to_dats( cast( Run.started_at as timestamp ), 'UTC', $session.client, 'NULL' ) as RunDate,
      Run.status                                                as RunStatus,
      Run.rag                                                   as RunRag,
      cast( case Run.rag when 'R' then 1
                     when 'A' then 2
                     when 'G' then 3
                     else 0 end as abap.int1 )              as RagCriticality,
      Run.runtime_ms                                            as RuntimeMs,
      Run.message                                               as RunMessage,
      // Run counters: area-level, on the area-level slice only; findings of each company code on its slice
      cast( case Slice.CompanyCode when ' ' then 1 else 0 end as abap.int4 ) as RunCount,
      cast( case when Slice.CompanyCode = ' ' and Run.rag = 'R' then 1 else 0 end as abap.int4 ) as RedRunCount,
      cast( case Slice.CompanyCode when ' ' then Run.total_items else 0 end as abap.int4 )   as CheckCount,
      cast( case Slice.CompanyCode when ' ' then Run.passed_items else 0 end as abap.int4 )  as GreenCheckCount,
      cast( case Slice.CompanyCode when ' ' then Run.warning_items else 0 end as abap.int4 ) as AmberCheckCount,
      cast( case Slice.CompanyCode when ' ' then Run.failed_items else 0 end as abap.int4 )  as RedCheckCount,
      cast( case Slice.CompanyCode when ' '
                 then Run.total_items - Run.passed_items - Run.warning_items - Run.failed_items
                 else 0 end as abap.int4 )                  as WarmupCheckCount,
      cast( coalesce( Find.FindingCount, 0 ) as abap.int4 ) as FindingCount,
      _Findings
}
