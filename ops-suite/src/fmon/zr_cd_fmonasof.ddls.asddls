// Artifact: zr_cd_fmonasof.ddls.asddls
// Purpose: "As of" of the file monitoring dashboard: the last completed full FMON run
//          (ZI_CD_FmonRunLast) with its run ID, status, RAG and finding count, the age of
//          that end time in minutes and a stale flag. One row, also when no run qualifies
//          (then stale, age null). Every dashboard row carries these fields (ZR_CD_FmonFlow),
//          so a monitor that stopped is visible and never mistaken for quiet traffic. Read-only.
//          Stale default: 15 minutes = 3 x the FMON cadence of 5 minutes (native SAP job;
//          literal,
//          CDS cannot read ZCD_OPS_PARAM; tiles may apply their own threshold on the age).
// Modification log: 2026-11-06 | Initial version (FMON file monitoring dashboard).
//                   2026-11-06 | Stale after 15 min: FMON runs every 5 min as a native SAP job.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FMON monitor as of (last completed run)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_FmonAsOf
  as select from    ZI_CD_FmonRunLast as Last
    // FMON runs never overlap (core lock, variant *), so the end time identifies one run
    left outer join zcd_ops_run       as Run on  Run.pe_area   = Last.PaymentEngineArea
                                             and Run.ended_at  = Last.LastEndedAt
                                             and Run.variant   = 'ALL'
                                             and Run.test_mode = ' '
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
      case
        when Last.LastEndedAt is null
          then cast( 'X' as abap_boolean )
        when tstmp_seconds_between( cast( Last.LastEndedAt as timestamp ),
                                    tstmp_current_utctimestamp( ), 'NULL' ) > 900
          then cast( 'X' as abap_boolean )
        else cast( ' ' as abap_boolean ) end                as IsStale,
      // Criticality for the header KPI / tile: 1 red (stale), 3 green
      cast( case
              when Last.LastEndedAt is null then 1
              when tstmp_seconds_between( cast( Last.LastEndedAt as timestamp ),
                                          tstmp_current_utctimestamp( ), 'NULL' ) > 900 then 1
              else 3 end as abap.int1 )                     as StaleCriticality
}
