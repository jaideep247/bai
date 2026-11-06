// Artifact: zr_cd_ebsasof.ddls.asddls
// Purpose: "As of" of the EBS validation dashboard: the last completed EBS run (ZI_CD_EbsRunLast)
//          with run ID, variant, status, RAG and line counters, the age of its end time in
//          minutes and a stale flag. One row, also when no run qualifies (then stale, age null).
//          Every dashboard row carries these fields, so a validation that stopped is never
//          mistaken for clean statements. Read-only.
//          Stale default: 26 hours = daily run + 2 h slack, the same default as the morning
//          report's HCK_MAX_AGE_HOURS (literal 93600 s; CDS cannot read ZCD_OPS_PARAM).
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
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
      cast( 1560 as abap.int4 )                             as StaleAfterMinutes,
      case
        when Last.LastEndedAt is null
          then cast( 'X' as abap_boolean )
        when tstmp_seconds_between( cast( Last.LastEndedAt as timestamp ),
                                    tstmp_current_utctimestamp( ), 'NULL' ) > 93600
          then cast( 'X' as abap_boolean )
        else cast( ' ' as abap_boolean ) end                as IsStale,
      // Criticality for the header KPI / tile: 1 red (stale), 3 green
      cast( case
              when Last.LastEndedAt is null then 1
              when tstmp_seconds_between( cast( Last.LastEndedAt as timestamp ),
                                          tstmp_current_utctimestamp( ), 'NULL' ) > 93600 then 1
              else 3 end as abap.int1 )                     as StaleCriticality
}
