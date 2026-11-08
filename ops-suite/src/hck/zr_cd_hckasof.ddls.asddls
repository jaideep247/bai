// Artifact: zr_cd_hckasof.ddls.asddls
// Purpose: "As of" of the health check dashboard: the last completed morning report run
//          (ZI_CD_HckRunLast) with run ID, variant, overall RAG and the check counters the engine
//          stores (ZCL_CD_HCK_ENGINE->CLOSE_RUN: total = checks, passed = GREEN, warning = AMBER,
//          failed = RED / not executed; warm-up = the rest), the run message (health score and
//          critical / high counts as text), the age in minutes and a stale flag. One row, also
//          when no run qualifies (then stale). Read-only.
//          Stale after the ZCA_PARAM parameter MON_STALE_AFTER_MIN_HCK (ZI_CD_OpsStaleCfg: value, else
//          definition default; also read by the HCK self-check); without a definition the delivered 1560 minutes
//          = 26 h (HCK_MAX_AGE_HOURS default, portable check cds_abap_parity).
// Modification log: 2026-11-06 | Initial version (health check dashboard).
//                   2026-11-07 | Stale threshold from ZCD_OPS_MONCFG (LEFT OUTER JOIN), 1560 min when no row.
//                   2026-11-08 | Table consolidation: threshold from ZI_CD_OpsStaleCfg (ZCA_PARAM MON_STALE_AFTER_MIN_<area>).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK health check as of (last completed run)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_HckAsOf
  as select from    ZI_CD_HckRunLast as Last
    left outer join zcd_ops_run      as Run on  Run.pe_area   = Last.PaymentEngineArea
                                            and Run.ended_at  = Last.LastEndedAt
                                            and Run.test_mode = ' '
    // Stale threshold per area: ZCA_PARAM MON_STALE_AFTER_MIN_<area> (value, else definition default;
    // ZI_CD_OpsStaleCfg, 2026-11-08 - was ZCD_OPS_MONCFG); no definition = delivered literal
    // VERIFY-ADT: coalesce over a LEFT OUTER JOIN column and int4 arithmetic in a comparison (7.58)
    left outer join ZI_CD_OpsStaleCfg as Cfg on Cfg.PaymentEngineArea = Last.PaymentEngineArea
{
  key Last.PaymentEngineArea                                as PaymentEngineArea,
      Run.run_id                                            as RunId,
      Run.variant                                           as RunVariant,
      Last.LastEndedAt                                      as AsOfAt,
      Run.started_at                                        as RunStartedAt,
      Run.status                                            as RunStatus,
      Run.rag                                               as RunRag,
      cast( case Run.rag when 'R' then 1
                         when 'A' then 2
                         when 'G' then 3
                         else 0 end as abap.int1 )          as RagCriticality,
      Run.total_items                                       as CheckCount,
      Run.passed_items                                      as GreenCheckCount,
      Run.warning_items                                     as AmberCheckCount,
      Run.failed_items                                      as RedCheckCount,
      // A102: warm-up checks are counted in the total only (neither passed nor failed)
      cast( Run.total_items - Run.passed_items - Run.warning_items - Run.failed_items as abap.int4 ) as WarmupCheckCount,
      Run.finding_count                                     as RunFindingCount,
      // Health score 0-100 and critical / high counts: only in this text (message of the run)
      Run.message                                           as RunMessage,
      // VERIFY-ADT: TIMESTAMPL -> TIMESTAMP cast and tstmp_seconds_between (as ZR_CD_FmonAsOf)
      cast( div( tstmp_seconds_between( cast( Last.LastEndedAt as timestamp ),
                                        tstmp_current_utctimestamp( ), 'NULL' ), 60 ) as abap.int4 ) as AgeMinutes,
      cast( coalesce( Cfg.StaleAfterMinutes, 1560 ) as abap.int4 ) as StaleAfterMinutes,
      case
        when Last.LastEndedAt is null
          then cast( 'X' as abap_boolean )
        when tstmp_seconds_between( cast( Last.LastEndedAt as timestamp ),
                                    tstmp_current_utctimestamp( ), 'NULL' ) > coalesce( Cfg.StaleAfterMinutes, 1560 ) * 60
          then cast( 'X' as abap_boolean )
        else cast( ' ' as abap_boolean ) end                as IsStale,
      cast( case
              when Last.LastEndedAt is null then 1
              when tstmp_seconds_between( cast( Last.LastEndedAt as timestamp ),
                                          tstmp_current_utctimestamp( ), 'NULL' ) > coalesce( Cfg.StaleAfterMinutes, 1560 ) * 60 then 1
              else 3 end as abap.int1 )                     as StaleCriticality
}
