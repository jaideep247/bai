// Artifact: zr_cd_fmonflow.ddls.asddls
// Purpose: Root of the file monitoring dashboard (Fiori elements analytical list page, OData V4,
//          docs/Dashboard_File_Monitoring.md): one row per monitored file with dimensions (source,
//          LOB, payment method, bank, interface, direction, business date, flow bucket, SLA
//          status), per-file measures, the SLA status from the open FMON exceptions of the file
//          and the monitor "as of" (last completed FMON run, age, stale flag) on every row.
//          Drill-down: file events and open exceptions. Read-only: no behaviour definition.
//          SLA status: NO_FINDINGS (no open exception), BREACHED (an SLA stage not reached in
//          time), LATE (reached late), OK (open exceptions, none about the SLA).
// Modification log: 2026-11-06 | Initial version (FMON file monitoring dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FMON file monitoring dashboard - file'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #MIXED }
// VERIFY-ADT: CROSS JOIN with the one-row as-of view in a root view entity (7.58)
define root view entity ZR_CD_FmonFlow
  as select from ZI_CD_FmonFlowFile as File
    cross join   ZR_CD_FmonAsOf     as AsOf
  association [0..1] to ZI_CD_FmonFileExc  as _Exc          on $projection.FileIdHex = _Exc.FileIdHex
  association [0..*] to ZR_CD_FmonFlowEvt  as _Events       on $projection.FileId = _Events.FileId
  association [0..*] to ZR_CD_FmonFlowFind as _OpenFindings on $projection.FileIdHex = _OpenFindings.FileIdHex
{
  key File.FileId,
      File.FileIdHex,
      File.PaymentEngineArea,
      File.IfaceId,
      File.IfaceDescription,
      File.Direction,
      File.FileType,
      File.SourceSystem,
      File.Lob,
      File.PaymentMethod,
      File.BankKey,
      File.TargetSystem,
      File.IfaceOwner,
      File.AckExpected,
      File.AckLevel,
      File.FileRef,
      File.FileName,
      File.BusinessDate,
      File.IsToday,
      File.Stage,
      File.Outcome,
      File.FlowBucket,
      // UI criticality of the bucket: 1 red (rejected), 2 yellow (partial, unknown), 3 green, 0 in flight
      cast( case File.FlowBucket
              when 'REJECTED'     then 1
              when 'PARTIAL'      then 2
              when 'UNKNOWN'      then 2
              when 'ACKNOWLEDGED' then 3
              else 0 end as abap.int1 )                     as FlowCriticality,
      File.IsSuccess,
      File.FirstEventAt,
      File.LastEventAt,
      // ---------------------------------------------------------------- SLA / exceptions
      cast( case
              when _Exc.OpenFindingCount is null then 'NO_FINDINGS'
              when _Exc.BreachedCount > 0        then 'BREACHED'
              when _Exc.LateCount > 0            then 'LATE'
              else 'OK' end as abap.char( 12 ) )            as SlaStatus,
      cast( case
              when _Exc.OpenFindingCount is null then 3
              when _Exc.BreachedCount > 0        then 1
              when _Exc.LateCount > 0            then 2
              else 3 end as abap.int1 )                     as SlaCriticality,
      // Worst open severity: B, E, W, I; blank = no open exception
      cast( case _Exc.WorstSeverityRank
              when 4 then 'B'
              when 3 then 'E'
              when 2 then 'W'
              when 1 then 'I'
              else ' ' end as abap.char( 1 ) )              as WorstSeverity,
      // ---------------------------------------------------------------- monitor as of
      AsOf.AsOfAt,
      AsOf.RunId                                            as AsOfRunId,
      AsOf.RunStatus                                        as AsOfRunStatus,
      AsOf.AgeMinutes                                       as MonitorAgeMinutes,
      AsOf.IsStale                                          as MonitorIsStale,
      AsOf.StaleCriticality                                 as MonitorCriticality,
      // ---------------------------------------------------------------- measures (per file)
      File.FileCount,
      File.SuccessFileCount,
      File.ProcessedFileCount,
      File.SentFileCount,
      // One count per flow bucket (current position; the bucket counts add up to FileCount)
      cast( case File.FlowBucket when 'RECEIVED'     then 1 else 0 end as abap.int4 ) as ReceivedFileCount,
      cast( case File.FlowBucket when 'AT_PRISM'     then 1 else 0 end as abap.int4 ) as AtPrismFileCount,
      cast( case File.FlowBucket when 'SENT'         then 1 else 0 end as abap.int4 ) as InTransitFileCount,
      cast( case File.FlowBucket when 'PROCESSED'    then 1 else 0 end as abap.int4 ) as InProcessFileCount,
      cast( case File.FlowBucket when 'ACKNOWLEDGED' then 1 else 0 end as abap.int4 ) as AckFileCount,
      cast( case File.FlowBucket when 'REJECTED'     then 1 else 0 end as abap.int4 ) as RejectedFileCount,
      cast( case File.FlowBucket when 'PARTIAL'      then 1 else 0 end as abap.int4 ) as PartialFileCount,
      cast( case File.FlowBucket when 'UNKNOWN'      then 1 else 0 end as abap.int4 ) as UnknownFileCount,
      // Files with items not yet accounted for (partially processed, open lot items)
      cast( case when File.UnprocessedCount > 0 then 1 else 0 end as abap.int4 ) as UnprocessedFileCount,
      cast( case when _Exc.BreachedCount > 0 then 1 else 0 end as abap.int4 ) as BreachedFileCount,
      cast( case when _Exc.BreachedCount > 0 then 0
                 when _Exc.LateCount > 0     then 1
                 else 0 end as abap.int4 )                  as LateFileCount,
      cast( coalesce( _Exc.OpenFindingCount, 0 ) as abap.int4 ) as OpenFindingCount,
      File.RecordCount,
      File.ControlTotal,
      File.AckCount,
      File.AckAmount,
      File.AckCountKnown,
      File.NackCount,
      File.UnprocessedCount,
      File.OriginRows,
      _Events,
      _OpenFindings
}
