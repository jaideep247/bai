// Artifact: zc_cd_fmonflow.ddls.asddls
// Purpose: Consumption view of the file monitoring dashboard (analytical list page, OData V4,
//          service ZUI_CD_FMON_FLOW): projection of ZR_CD_FmonFlow with the default aggregation
//          of every measure (OData V4 data aggregation, $apply) and the drill-down to file events
//          and open exceptions. UI annotations in the metadata extension ZC_CD_FMONFLOW.
//          Read access: DCL ZC_CD_FMONFLOW (ZCD_OPS, ZCA_PARAR = FMON, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (FMON file monitoring dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'FMON file monitoring dashboard'
@Metadata.allowExtensions: true
// VERIFY-ADT: OData V4 data aggregation of a transactional_query projection without behaviour
// definition ($apply, Aggregation.ApplySupported generated from @Aggregation.default)
define root view entity ZC_CD_FmonFlow
  provider contract transactional_query
  as projection on ZR_CD_FmonFlow
{
  key FileId,
      FileIdHex,
      PaymentEngineArea,
      IfaceId,
      IfaceDescription,
      Direction,
      FileType,
      SourceSystem,
      Lob,
      PaymentMethod,
      BankKey,
      TargetSystem,
      IfaceOwner,
      AckExpected,
      AckLevel,
      FileRef,
      FileName,
      BusinessDate,
      IsToday,
      Stage,
      Outcome,
      FlowBucket,
      FlowCriticality,
      IsSuccess,
      FirstEventAt,
      LastEventAt,
      SlaStatus,
      SlaCriticality,
      WorstSeverity,
      AsOfAt,
      AsOfRunId,
      AsOfRunStatus,
      MonitorAgeMinutes,
      MonitorIsStale,
      MonitorCriticality,
      @Aggregation.default: #SUM
      FileCount,
      @Aggregation.default: #SUM
      SuccessFileCount,
      @Aggregation.default: #SUM
      ProcessedFileCount,
      @Aggregation.default: #SUM
      SentFileCount,
      @Aggregation.default: #SUM
      ReceivedFileCount,
      @Aggregation.default: #SUM
      AtPrismFileCount,
      @Aggregation.default: #SUM
      InTransitFileCount,
      @Aggregation.default: #SUM
      InProcessFileCount,
      @Aggregation.default: #SUM
      AckFileCount,
      @Aggregation.default: #SUM
      RejectedFileCount,
      @Aggregation.default: #SUM
      PartialFileCount,
      @Aggregation.default: #SUM
      UnknownFileCount,
      @Aggregation.default: #SUM
      UnprocessedFileCount,
      @Aggregation.default: #SUM
      BreachedFileCount,
      @Aggregation.default: #SUM
      LateFileCount,
      @Aggregation.default: #SUM
      OpenFindingCount,
      @Aggregation.default: #SUM
      RecordCount,
      // No currency on the file row: slice by interface before reading totals (doc section 4)
      @Aggregation.default: #SUM
      ControlTotal,
      @Aggregation.default: #SUM
      AckCount,
      @Aggregation.default: #SUM
      AckAmount,
      AckCountKnown,
      @Aggregation.default: #SUM
      NackCount,
      @Aggregation.default: #SUM
      UnprocessedCount,
      OriginRows,
      _Events       : redirected to ZC_CD_FmonFlowEvt,
      _OpenFindings : redirected to ZC_CD_FmonFlowFind
}
