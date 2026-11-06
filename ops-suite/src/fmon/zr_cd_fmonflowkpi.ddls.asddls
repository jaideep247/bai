// Artifact: zr_cd_fmonflowkpi.ddls.asddls
// Purpose: KPI entity of the file monitoring dashboard, pre-aggregated per business date so that
//          launchpad tiles and the production-support overview page (OVP KPI / analytical cards)
//          read one small row instead of aggregating file rows: files per flow bucket, successful,
//          rejected, partial, unprocessed, breached / late SLA, open exceptions, records - and the
//          monitor as of, age and stale flag on every row. "Today" = IsToday (server date).
//          A business date without any file has no row: the as-of entity ZC_CD_FmonAsOf still
//          shows the monitor age. Read-only.
// Modification log: 2026-11-06 | Initial version (FMON file monitoring dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FMON file monitoring dashboard - KPI per day'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #MIXED }
define root view entity ZR_CD_FmonFlowKpi
  as select from ZR_CD_FmonFlow
{
  key BusinessDate,
      PaymentEngineArea,
      IsToday,
      AsOfAt,
      MonitorAgeMinutes,
      MonitorIsStale,
      MonitorCriticality,
      cast( sum( FileCount ) as abap.int4 )                 as FileCount,
      cast( sum( ReceivedFileCount ) as abap.int4 )         as ReceivedFileCount,
      cast( sum( AtPrismFileCount ) as abap.int4 )          as AtPrismFileCount,
      cast( sum( InTransitFileCount ) as abap.int4 )        as InTransitFileCount,
      cast( sum( InProcessFileCount ) as abap.int4 )        as InProcessFileCount,
      cast( sum( AckFileCount ) as abap.int4 )              as AckFileCount,
      cast( sum( RejectedFileCount ) as abap.int4 )         as RejectedFileCount,
      cast( sum( PartialFileCount ) as abap.int4 )          as PartialFileCount,
      cast( sum( UnknownFileCount ) as abap.int4 )          as UnknownFileCount,
      cast( sum( SuccessFileCount ) as abap.int4 )          as SuccessFileCount,
      cast( sum( ProcessedFileCount ) as abap.int4 )        as ProcessedFileCount,
      cast( sum( SentFileCount ) as abap.int4 )             as SentFileCount,
      cast( sum( UnprocessedFileCount ) as abap.int4 )      as UnprocessedFileCount,
      cast( sum( UnprocessedCount ) as abap.int4 )          as UnprocessedCount,
      cast( sum( BreachedFileCount ) as abap.int4 )         as BreachedFileCount,
      cast( sum( LateFileCount ) as abap.int4 )             as LateFileCount,
      cast( sum( OpenFindingCount ) as abap.int4 )          as OpenFindingCount,
      cast( sum( RecordCount ) as abap.int4 )               as RecordCount,
      // KPI criticality: 1 red (rejected or breached), 2 yellow (partial, late, unprocessed), 3 green
      cast( case
              when sum( RejectedFileCount ) > 0 or sum( BreachedFileCount ) > 0 then 1
              when sum( PartialFileCount ) > 0 or sum( LateFileCount ) > 0
                or sum( UnprocessedFileCount ) > 0                               then 2
              else 3 end as abap.int1 )                     as DayCriticality
}
group by
  BusinessDate,
  PaymentEngineArea,
  IsToday,
  AsOfAt,
  MonitorAgeMinutes,
  MonitorIsStale,
  MonitorCriticality
