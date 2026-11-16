// Artifact: zr_ca_opscheckstatus.ddls.asddls
// Purpose: Area dashboard of the check registry (process onboarding): one row per active registered check and
//          company-code slice (ZI_CA_OpsChkSlice) - process, check, schedule group, the latest completed run of
//          the area and schedule group (status, RAG, start, age), the open exceptions of the check now and their
//          worst status (H healthy, W watch, A action required: domain ZCA_OPS_CTL_STATUS), and the freshness:
//          stale when no run completed or the latest is older than CHECK_STALE_MIN_<area> (else
//          CHECK_STALE_MIN_DEFAULT) minutes. Run telemetry and freshness sit on the area-level slice only
//          (a run has no company code); a company-code slice carries the exceptions of its own company code
//          only, so a sum over the slices never mixes company codes (docs/auth_zca_ops.md section 3c).
//          Nothing stored, read-only (no behaviour definition).
// Modification log: 2026-11-10 | Initial version (process onboarding: area dashboard and freshness).
//                   2026-11-10 | Overview card counters: CheckCount (one per registered check, area-level slice
//                              | only), StaleCount, IsAttention (open exception or stale) - for a consumer's
//                              | overview page KPI and list cards (summed after the DCL).
//                   2026-11-11 | Planned downtime mark of the area (ZI_CA_OpsDtwActive, area-level slice only):
//                              | IsPlannedDowntime and the active windows (operations response features).
//                   2026-11-11 | Process catalogue: rows of checks in effect only (ZI_CA_OpsChkSlice); the
//                              | catalogue process of the business process and its dashboard card.
//                   2026-11-16 | Evaluation state (build O, docs/EVALUATION_AND_COVERAGE.md): the latest evaluation of
//                              | the check (ZI_CA_OpsEvalNow, area-level slice only) - state with its text (NOT_EVAL,
//                              | STALE, PARTIAL shown apart from OK, never green), completeness, result class, reason,
//                              | expected scope, source freshness, watermark, last valid result; IsAttention also for
//                              | an unknown evaluation; card counters UnknownCount, NotEvaluatedCount, PartialCount.
// VERIFY-ADT: cross join with left outer joins, a literal in the ON condition of a left outer join, the
//             TIMESTAMPL -> TIMESTAMP cast and tstmp_seconds_between (as the consumers' "as of" views), coalesce
//             over a LEFT OUTER JOIN column (7.58).
// Extension point CHECK_STATUS (2026-11-15, build H; config/extension_points.json, docs/EXTENDING_WITH_CUSTOMER_DATA.md):
//          base view; a customer adds its own elements with extend view entity from its package,
//          never by changing this view. Anchors COMPANY, CHECK: their elements stay stable.
// VERIFY-ADT (V153): the extensibility annotations below on 7.58.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Area dashboard: status per check'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #MIXED }
@AbapCatalog.extensibility.extensible: true
@AbapCatalog.extensibility.elementSuffix: 'ZOP'
@AbapCatalog.extensibility.allowNewDatasources: true
@AbapCatalog.extensibility.dataSources: [ 'Sl' ]
@AbapCatalog.extensibility.quota.maximumFields: 50
@AbapCatalog.extensibility.quota.maximumBytes: 2000
define root view entity ZR_CA_OpsCheckStatus
  as select from    ZI_CA_OpsChkSlice  as Sl
    cross join      ZI_CA_OpsChkStaleD as StD
    inner join      zca_ops_check      as Chk  on  Chk.area     = Sl.Area
                                               and Chk.check_id = Sl.CheckId
    left outer join zca_ops_proc       as Proc on  Proc.area       = Chk.area
                                               and Proc.process_id = Chk.process_id
    left outer join zca_ops_catprc     as Cat  on  Cat.process_id  = Proc.cat_process
    left outer join ZI_CA_OpsChkOpen   as Op   on  Op.Area        = Sl.Area
                                               and Op.CheckId     = Sl.CheckId
                                               and Op.CompanyCode = Sl.CompanyCode
    left outer join ZI_CA_OpsChkLast   as Last on  Last.Area      = Sl.Area
                                               and Last.Variant   = Chk.sched_group
                                               and Sl.CompanyCode = ' '
    left outer join zca_ops_run        as Run  on  Run.area       = Last.Area
                                               and Run.variant    = Last.Variant
                                               and Run.started_at = Last.LastRunAt
                                               and Run.test_mode  = ' '
    left outer join ZI_CA_OpsChkStaleA as StA  on  StA.Area = Sl.Area
    left outer join ZI_CA_OpsDtwActive as Dtw  on  Dtw.Area       = Sl.Area
                                               and Sl.CompanyCode = ' '
    left outer join ZI_CA_OpsEvalNow   as En   on  En.Area        = Sl.Area
                                               and En.CheckId     = Sl.CheckId
                                               and Sl.CompanyCode = ' '
  association [0..*] to ZI_CA_OpsEvalStateT as _EvalText on $projection.EvaluationState = _EvalText.EvaluationState
{
  key Sl.Area                                               as Area,
  key Sl.CheckId                                            as CheckId,
  key Sl.CompanyCode                                        as CompanyCode,
      Chk.process_id                                        as ProcessId,
      Proc.description                                      as ProcessName,
      Proc.cat_process                                      as CatalogueProcess,
      Cat.dash_card                                         as DashboardCard,
      Chk.description                                       as CheckName,
      Chk.sched_group                                       as ScheduleGroup,
      Chk.class_name                                        as ClassName,
      Chk.bukrs_aware                                       as IsCompanyCodeAware,
      Run.run_id                                            as LastRunId,
      Run.started_at                                        as LastRunAt,
      Run.status                                            as LastRunStatus,
      Run.rag                                               as LastRunRag,
      cast( case Run.rag when 'R' then 1
                         when 'A' then 2
                         when 'G' then 3
                         else 0 end as abap.int1 )          as RunCriticality,
      cast( coalesce( Op.OpenExceptions, 0 ) as abap.int4 ) as OpenExceptions,
      // Worst open exception of the slice now (ranks of ZIF_CA_OPS_CTL_TYPES=>GC_RANK)
      cast( case coalesce( Op.WorstRank, 0 ) when 2 then 'A'
                                             when 1 then 'W'
                                             else 'H' end as zca_ops_ctl_status ) as Status,
      cast( case coalesce( Op.WorstRank, 0 ) when 2 then 1
                                             when 1 then 2
                                             else 3 end as abap.int1 )            as StatusCriticality,
      cast( coalesce( StA.StaleAfterMinutes, StD.StaleAfterMinutes ) as abap.int4 ) as StaleAfterMinutes,
      cast( div( tstmp_seconds_between( cast( Run.started_at as timestamp ),
                                        tstmp_current_utctimestamp( ), 'NULL' ), 60 ) as abap.int4 ) as AgeMinutes,
      case
        when Sl.CompanyCode <> ' '
          then cast( ' ' as abap_boolean )
        when Run.started_at is null
          then cast( 'X' as abap_boolean )
        when tstmp_seconds_between( cast( Run.started_at as timestamp ),
                                    tstmp_current_utctimestamp( ), 'NULL' )
             > coalesce( StA.StaleAfterMinutes, StD.StaleAfterMinutes ) * 60
          then cast( 'X' as abap_boolean )
        else cast( ' ' as abap_boolean ) end                as IsStale,
      cast( case
              when Sl.CompanyCode <> ' ' then 0
              when Run.started_at is null then 1
              when tstmp_seconds_between( cast( Run.started_at as timestamp ),
                                          tstmp_current_utctimestamp( ), 'NULL' )
                   > coalesce( StA.StaleAfterMinutes, StD.StaleAfterMinutes ) * 60 then 1
              else 3 end as abap.int1 )                     as StaleCriticality,
      // Counters for cards (sum over the slices the user may read)
      // Planned downtime of the area now (area-level slice only: a window has no company code)
      cast( coalesce( Dtw.ActiveWindows, 0 ) as abap.int4 ) as PlannedDowntimeWindows,
      cast( case when Dtw.ActiveWindows is null then ' ' else 'X' end as abap_boolean ) as IsPlannedDowntime,
      // Evaluation state (2026-11-16): the latest evaluation of the check (area-level slice only: an evaluation is of
      // the check's run, its company codes are its scope)
      @ObjectModel.text.association: '_EvalText'
      En.EvaluationState                                    as EvaluationState,
      cast( coalesce( En.EvaluationCriticality, 0 ) as abap.int1 ) as EvaluationCriticality,
      En.Completeness                                       as EvaluationCompleteness,
      En.ResultClass                                        as EvaluationResult,
      En.Reason                                             as EvaluationReason,
      En.EvaluatedAt                                        as EvaluatedAt,
      En.BusinessDate                                       as ScopeDate,
      En.Period                                             as ScopePeriod,
      En.CompanyCodes                                       as ScopeCompanyCodes,
      En.ExpectedCount                                      as ExpectedCount,
      En.ObservedCount                                      as ObservedCount,
      En.SourceFreshAt                                      as SourceFreshAt,
      En.FreshSource                                        as FreshSource,
      En.Watermark                                          as Watermark,
      En.LastValidAt                                        as LastValidAt,
      En.LastValidResult                                    as LastValidResult,
      cast( coalesce( En.IsUnknown, ' ' ) as abap_boolean ) as IsEvaluationUnknown,
      cast( case En.IsUnknown when 'X' then 1 else 0 end as abap.int4 ) as UnknownCount,
      cast( case En.EvaluationState when 'NOT_EVAL' then 1 else 0 end as abap.int4 ) as NotEvaluatedCount,
      cast( case En.EvaluationState when 'PARTIAL' then 1 else 0 end as abap.int4 ) as PartialCount,
      cast( 1 as abap.int4 )                                as SliceCount,
      cast( case when coalesce( Op.WorstRank, 0 ) > 0 then 1 else 0 end as abap.int4 ) as FlaggedCount,
      // One per registered check (area-level slice only), so a company-code slice never counts a check twice
      cast( case when Sl.CompanyCode = ' ' then 1 else 0 end as abap.int4 ) as CheckCount,
      // Stale checks: area-level slice only (a run has no company code)
      cast( case
              when Sl.CompanyCode <> ' ' then 0
              when Run.started_at is null then 1
              when tstmp_seconds_between( cast( Run.started_at as timestamp ),
                                          tstmp_current_utctimestamp( ), 'NULL' )
                   > coalesce( StA.StaleAfterMinutes, StD.StaleAfterMinutes ) * 60 then 1
              else 0 end as abap.int4 )                     as StaleCount,
      // Needs attention: an open exception on the slice, or the area-level slice is stale or its evaluation unknown
      case
        when coalesce( Op.WorstRank, 0 ) > 0
          then cast( 'X' as abap_boolean )
        when En.IsUnknown = 'X'
          then cast( 'X' as abap_boolean )
        when Sl.CompanyCode <> ' '
          then cast( ' ' as abap_boolean )
        when Run.started_at is null
          then cast( 'X' as abap_boolean )
        when tstmp_seconds_between( cast( Run.started_at as timestamp ),
                                    tstmp_current_utctimestamp( ), 'NULL' )
             > coalesce( StA.StaleAfterMinutes, StD.StaleAfterMinutes ) * 60
          then cast( 'X' as abap_boolean )
        else cast( ' ' as abap_boolean ) end                as IsAttention,
      _EvalText
}
where
  Chk.active = 'X'
