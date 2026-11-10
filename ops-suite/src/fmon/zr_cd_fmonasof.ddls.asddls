// Artifact: zr_cd_fmonasof.ddls.asddls
// Purpose: "As of" of the file monitoring dashboard: the last completed full FMON run
//          (ZI_CD_FmonRunLast) with its run ID, status, RAG and finding count, the age of
//          that end time in minutes and a stale flag. One row, also when no run qualifies
//          (then stale, age null). Every dashboard row carries these fields (ZR_CD_FmonFlow),
//          so a monitor that stopped is visible and never mistaken for quiet traffic. Read-only.
//          Stale after the ZCA_PARAM parameter MON_STALE_AFTER_MIN_FMON (ZI_CD_OpsStaleCfg: value, else
//          definition default; also read by the HCK self-check); without a definition the delivered 15 minutes =
//          3 x the 5-minute cadence (ZIF_CD_FMON_TYPES=>GC_DASHBOARD-STALE_AFTER_MIN, portable check
//          cds_abap_parity).
// Modification log: 2026-11-06 | Initial version (FMON file monitoring dashboard).
//                   2026-11-06 | Stale after 15 min: FMON runs every 5 min as a native SAP job.
//                   2026-11-07 | Stale threshold from ZCD_OPS_MONCFG (LEFT OUTER JOIN), 15 min when no row; StaleAfterMinutes added.
//                   2026-11-08 | Table consolidation: threshold from ZI_CD_OpsStaleCfg (ZCA_PARAM MON_STALE_AFTER_MIN_FMON).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FMON monitor as of (last completed run)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_FmonAsOf
  as select from    ZI_CD_FmonRunLast as Last
    // FMON runs never overlap (core lock, variant *), so the end time identifies one run
    left outer join zca_ops_run       as Run on  Run.area   = Last.PaymentEngineArea
                                             and Run.ended_at  = Last.LastEndedAt
                                             and Run.variant   = 'ALL'
                                             and Run.test_mode = ' '
    // Stale threshold per area: ZCA_PARAM MON_STALE_AFTER_MIN_<area> (value, else definition default;
    // ZI_CD_OpsStaleCfg, 2026-11-08 - was ZCD_OPS_MONCFG); no definition = delivered literal
    // VERIFY-ADT: coalesce over a LEFT OUTER JOIN column and int4 arithmetic in a comparison (7.58)
    left outer join ZI_CD_OpsStaleCfg as Cfg on Cfg.PaymentEngineArea = Last.PaymentEngineArea
{
  key Last.PaymentEngineArea                                as PaymentEngineArea,
      Run.run_id                                            as RunId,
      Last.LastEndedAt                                      as AsOfAt,
      Run.started_at                                        as RunStartedAt,
      Run.status                                            as RunStatus,
      Run.rag                                               as RunRag,
      Run.finding_count                                     as RunFindingCount,
      // VERIFY-ADT: TIMESTAMPL -> TIMESTAMP cast (as ZI_CD_OpsRun) and tstmp_seconds_between on 7.58
      cast( div( tstmp_seconds_between( cast( Last.LastEndedAt as timestamp ),
                                        tstmp_current_utctimestamp( ), 'NULL' ), 60 ) as abap.int4 ) as AgeMinutes,
      cast( coalesce( Cfg.StaleAfterMinutes, 15 ) as abap.int4 ) as StaleAfterMinutes,
      case
        when Last.LastEndedAt is null
          then cast( 'X' as abap_boolean )
        when tstmp_seconds_between( cast( Last.LastEndedAt as timestamp ),
                                    tstmp_current_utctimestamp( ), 'NULL' ) > coalesce( Cfg.StaleAfterMinutes, 15 ) * 60
          then cast( 'X' as abap_boolean )
        else cast( ' ' as abap_boolean ) end                as IsStale,
      // Criticality for the header KPI / tile: 1 red (stale), 3 green
      cast( case
              when Last.LastEndedAt is null then 1
              when tstmp_seconds_between( cast( Last.LastEndedAt as timestamp ),
                                          tstmp_current_utctimestamp( ), 'NULL' ) > coalesce( Cfg.StaleAfterMinutes, 15 ) * 60 then 1
              else 3 end as abap.int1 )                     as StaleCriticality
}
