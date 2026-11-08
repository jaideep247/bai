// Artifact: zi_cd_payoutlag.ddls.asddls
// Purpose: Snapshot lag of the canonical payment outcome (2026-11-08): minutes between now and the
//          instant up to which every evidence source of the 5-minute snapshot is processed
//          (ZI_CD_PayOutLagMin), stale above the ZCA_PARAM parameter MON_STALE_AFTER_MIN_CORE
//          (ZI_CD_OpsStaleCfg: value, else definition default; A_INFLIGHT reads the same parameter
//          through the API and reports its evidence PARTIAL when stale); without a definition the
//          delivered 30 minutes (ZIF_CD_OPS_PAYOUT_TYPES=>GC_PARAM_DEFAULT-STALE_AFTER_MIN, portable
//          check cds_abap_parity). Last completed snapshot run for the run ID and status. One row
//          (area CORE), also when the snapshot never ran (then stale, age null). Used by the
//          production-support freshness view (ZI_CD_OpsFreshU) and the transactions dashboard header
//          (ZR_CD_TrxFlow). Read-only.
// Modification log: 2026-11-08 | Initial version (snapshot lag, 2 million payments a peak day).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment outcome snapshot lag'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_PayOutLag
  as select from    ZI_CD_PayOutLagMin  as Lag
    left outer join ZI_CD_PayOutRunLast as Last on Last.PaymentEngineArea = Lag.PaymentEngineArea
    // The snapshot never overlaps itself (run lock), so the end time identifies one run
    left outer join zcd_ops_run         as Run  on  Run.pe_area   = Last.PaymentEngineArea
                                                and Run.ended_at  = Last.LastEndedAt
                                                and Run.variant   = 'PAY_OUTCOME'
                                                and Run.test_mode = ' '
    // VERIFY-ADT: coalesce over a LEFT OUTER JOIN column and int4 arithmetic in a comparison (7.58)
    left outer join ZI_CD_OpsStaleCfg   as Cfg  on Cfg.PaymentEngineArea = Lag.PaymentEngineArea
{
  key Lag.PaymentEngineArea                                 as PaymentEngineArea,
      Run.run_id                                            as RunId,
      Lag.ProcessedTo                                       as AsOfAt,
      Run.status                                            as RunStatus,
      // VERIFY-ADT: TIMESTAMPL -> TIMESTAMP cast and tstmp_seconds_between (as ZR_CD_FmonAsOf)
      cast( div( tstmp_seconds_between( cast( Lag.ProcessedTo as timestamp ),
                                        tstmp_current_utctimestamp( ), 'NULL' ), 60 ) as abap.int4 ) as AgeMinutes,
      cast( coalesce( Cfg.StaleAfterMinutes, 30 ) as abap.int4 ) as StaleAfterMinutes,
      case
        when Lag.ProcessedTo is null
          then cast( 'X' as abap_boolean )
        when tstmp_seconds_between( cast( Lag.ProcessedTo as timestamp ),
                                    tstmp_current_utctimestamp( ), 'NULL' ) > coalesce( Cfg.StaleAfterMinutes, 30 ) * 60
          then cast( 'X' as abap_boolean )
        else cast( ' ' as abap_boolean ) end                as IsStale,
      // Criticality for the freshness card and the dashboard header: 1 red (stale), 3 green
      cast( case
              when Lag.ProcessedTo is null then 1
              when tstmp_seconds_between( cast( Lag.ProcessedTo as timestamp ),
                                          tstmp_current_utctimestamp( ), 'NULL' ) > coalesce( Cfg.StaleAfterMinutes, 30 ) * 60 then 1
              else 3 end as abap.int1 )                     as StaleCriticality
}
