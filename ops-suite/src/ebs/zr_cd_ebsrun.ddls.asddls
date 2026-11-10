// Artifact: zr_cd_ebsrun.ddls.asddls
// Purpose: EBS validation runs of the last 31 days (EBS validation dashboard, run history): line
//          counters of the run (validated, passed, warning, failed, blocked, unevaluated), findings
//          of the run by severity, POSTING_INCOMPLETE (S13), duplicates, unmapped codes, statements
//          and lines with findings, RAG, and whether the run is the one the dashboard is "as of".
//          Drill-down: the findings of the run. Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
//                   2026-11-10 | Company-code isolation: one row per run slice (ZI_CD_EbsRunSlice, key CompanyCode);
//                                the run's line counters and RunCount on the area-level slice only, the finding
//                                counts of each company code on its own slice; run attributes on every slice.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS validation dashboard - run'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #MIXED }
define root view entity ZR_CD_EbsRun
  as select from    ZI_CD_EbsRunSlice as Slice
    inner join      ZI_CD_EbsRunBase  as Run  on  Run.RunId = Slice.RunId
    left outer join ZI_CD_EbsRunFind  as Find on  Find.RunId       = Slice.RunId
                                              and Find.CompanyCode = Slice.CompanyCode
    cross join      ZR_CD_EbsAsOf     as AsOf
  association [0..*] to ZR_CD_EbsFind as _Findings on $projection.RunId = _Findings.RunId
{
  key Run.RunId,
      // Blank = the area-level slice (run counters and findings without company code)
  key Slice.CompanyCode,
      Run.PaymentEngineArea,
      Run.RunVariant,
      Run.StartedAt,
      Run.EndedAt,
      Run.RunDate,
      Run.RunStatus,
      Run.RunRag,
      // UI criticality of the RAG: 1 red, 2 amber, 3 green, 0 grey / running
      cast( case Run.RunRag when 'R' then 1
                            when 'A' then 2
                            when 'G' then 3
                            else 0 end as abap.int1 )       as RagCriticality,
      Run.IsCompleted,
      case when Run.RunId = AsOf.RunId
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end             as IsAsOfRun,
      Run.RuntimeMs,
      Run.RunMessage,
      // Run counters: area-level, on the area-level slice only (a sum over the slices counts them once)
      cast( case Slice.CompanyCode when ' ' then 1 else 0 end as abap.int4 ) as RunCount,
      cast( case Slice.CompanyCode when ' ' then Run.LineCount else 0 end as abap.int4 )            as LineCount,
      cast( case Slice.CompanyCode when ' ' then Run.PassedLineCount else 0 end as abap.int4 )      as PassedLineCount,
      cast( case Slice.CompanyCode when ' ' then Run.WarningLineCount else 0 end as abap.int4 )     as WarningLineCount,
      cast( case Slice.CompanyCode when ' ' then Run.FailedLineCount else 0 end as abap.int4 )      as FailedLineCount,
      cast( case Slice.CompanyCode when ' ' then Run.BlockedLineCount else 0 end as abap.int4 )     as BlockedLineCount,
      cast( case Slice.CompanyCode when ' ' then Run.UnevaluatedLineCount else 0 end as abap.int4 ) as UnevaluatedLineCount,
      cast( coalesce( Find.FindingCount, 0 ) as abap.int4 )           as FindingCount,
      cast( coalesce( Find.BlockFindingCount, 0 ) as abap.int4 )      as BlockFindingCount,
      cast( coalesce( Find.ErrorFindingCount, 0 ) as abap.int4 )      as ErrorFindingCount,
      cast( coalesce( Find.WarningFindingCount, 0 ) as abap.int4 )    as WarningFindingCount,
      cast( coalesce( Find.PostingIncompleteCount, 0 ) as abap.int4 ) as PostingIncompleteCount,
      cast( coalesce( Find.DuplicateCount, 0 ) as abap.int4 )         as DuplicateCount,
      cast( coalesce( Find.UnmappedCodeCount, 0 ) as abap.int4 )      as UnmappedCodeCount,
      cast( coalesce( Find.StatementsWithFindings, 0 ) as abap.int4 ) as StatementsWithFindings,
      cast( coalesce( Find.LinesWithFindings, 0 ) as abap.int4 )      as LinesWithFindings,
      _Findings
}
