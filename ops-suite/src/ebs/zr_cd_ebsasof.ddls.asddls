// Artifact: zr_cd_ebsasof.ddls.asddls
// Purpose: "As of" of the EBS validation dashboard: the last completed EBS run (ZI_CD_EbsRunLast)
//          with run ID, variant, status, RAG and line counters, the age of its end time in
//          minutes and a stale flag. One row, also when no run qualifies (then stale, age null).
//          Every dashboard row carries these fields, so a validation that stopped is never
//          mistaken for clean statements. Read-only.
//          Stale after ZCD_OPS_MONCFG-STALE_AFTER_MIN of area EBS (configuration app "Monitor
//          freshness", also read by the HCK self-check); without a row the delivered 1560 minutes
//          = 26 h (HCK_MAX_AGE_HOURS default, portable check cds_abap_parity).
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
//                   2026-11-07 | Stale threshold from ZCD_OPS_MONCFG (LEFT OUTER JOIN), 1560 min when no row.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS validation as of (last completed run)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_EbsAsOf
  as select from    ZI_CD_EbsRunLast as Last
    // Two EBS runs ending in the same 100 ns are not expected; the end time names the run
    left outer join zcd_ops_run      as Run on  Run.pe_area   = Last.PaymentEngineArea
                                            and Run.ended_at  = Last.LastEndedAt
                                            and Run.test_mode = ' '
    // Stale threshold per area (configuration app "Monitor freshness"); no row = delivered literal
    // VERIFY-ADT: coalesce over a LEFT OUTER JOIN column and int4 arithmetic in a comparison (7.58)
    left outer join zcd_ops_moncfg   as Cfg on  Cfg.pe_area   = Last.PaymentEngineArea
{
  key Last.PaymentEngineArea                                as PaymentEngineArea,
      Run.run_id                                            as RunId,
      Run.variant                                           as RunVariant,
      Last.LastEndedAt                                      as AsOfAt,
      Run.started_at                                        as RunStartedAt,
      Run.status                                            as RunStatus,
      Run.rag                                               as RunRag,
      Run.total_items                                       as RunLineCount,
      Run.finding_count                                     as RunFindingCount,
      // VERIFY-ADT: TIMESTAMPL -> TIMESTAMP cast and tstmp_seconds_between (as ZR_CD_FmonAsOf)
      cast( div( tstmp_seconds_between( cast( Last.LastEndedAt as timestamp ),
                                        tstmp_current_utctimestamp( ), 'NULL' ), 60 ) as abap.int4 ) as AgeMinutes,
      cast( coalesce( Cfg.stale_after_min, 1560 ) as abap.int4 ) as StaleAfterMinutes,
      case
        when Last.LastEndedAt is null
          then cast( 'X' as abap_boolean )
        when tstmp_seconds_between( cast( Last.LastEndedAt as timestamp ),
                                    tstmp_current_utctimestamp( ), 'NULL' ) > coalesce( Cfg.stale_after_min, 1560 ) * 60
          then cast( 'X' as abap_boolean )
        else cast( ' ' as abap_boolean ) end                as IsStale,
      // Criticality for the header KPI / tile: 1 red (stale), 3 green
      cast( case
              when Last.LastEndedAt is null then 1
              when tstmp_seconds_between( cast( Last.LastEndedAt as timestamp ),
                                          tstmp_current_utctimestamp( ), 'NULL' ) > coalesce( Cfg.stale_after_min, 1560 ) * 60 then 1
              else 3 end as abap.int1 )                     as StaleCriticality
}
