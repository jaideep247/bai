// Artifact: zr_cd_ebskpi.ddls.asddls
// Purpose: KPI entity of the EBS validation dashboard (tiles, production-support overview page):
//          one row per run date of the last 31 days with the counters of the last completed EBS
//          run of that date (ZI_CD_EbsRunDay) - lines validated, passed, warning, failed, blocked,
//          unevaluated, findings by severity, POSTING_INCOMPLETE statements, duplicates, unmapped
//          codes - and the as-of / age / stale fields on every row. IsLatest marks the row of the
//          as-of run. A day without a completed run has no row: the as-of entity still shows the
//          age. Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
//                   2026-11-10 | Company-code isolation: one row per run date and slice of the run (key CompanyCode,
//                                ZR_CD_EbsRun); counters of the run and of the day on the area-level slice only.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS validation dashboard - KPI per day'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #S, dataClass: #MIXED }
define root view entity ZR_CD_EbsKpi
  as select from ZI_CD_EbsRunDay as Day
    inner join   ZR_CD_EbsRun    as Run on  Run.RunDate     = Day.RunDate
                                        and Run.EndedAt     = Day.LastEndedAt
                                        and Run.IsCompleted = 'X'
    cross join   ZR_CD_EbsAsOf   as AsOf
{
  key Day.RunDate,
  key Run.CompanyCode,
      Run.PaymentEngineArea,
      Run.RunId,
      Run.RunVariant,
      Run.RunRag,
      Run.RagCriticality,
      case when Day.RunDate = $session.system_date
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end             as IsToday,
      Run.IsAsOfRun                                         as IsLatest,
      cast( case Run.CompanyCode when ' ' then Day.CompletedRunCount else 0 end as abap.int4 ) as CompletedRunCount,
      AsOf.AsOfAt,
      AsOf.AgeMinutes                                       as MonitorAgeMinutes,
      AsOf.IsStale                                          as MonitorIsStale,
      AsOf.StaleCriticality                                 as MonitorCriticality,
      Run.LineCount,
      Run.PassedLineCount,
      Run.WarningLineCount,
      Run.FailedLineCount,
      Run.BlockedLineCount,
      Run.UnevaluatedLineCount,
      Run.FindingCount,
      Run.BlockFindingCount,
      Run.ErrorFindingCount,
      Run.WarningFindingCount,
      Run.PostingIncompleteCount,
      Run.DuplicateCount,
      Run.UnmappedCodeCount,
      Run.StatementsWithFindings,
      // Day criticality: 1 red (blocked or failed lines), 2 yellow (unevaluated, warning,
      // posting incomplete), 3 green
      cast( case
              when Run.BlockedLineCount > 0 or Run.FailedLineCount > 0             then 1
              when Run.UnevaluatedLineCount > 0 or Run.WarningLineCount > 0
                or Run.PostingIncompleteCount > 0                                   then 2
              else 3 end as abap.int1 )                     as DayCriticality
}
