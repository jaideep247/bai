// Artifact: zc_cd_fmonflowkpi.ddls.asddls
// Purpose: Consumption view of the KPI entity (tiles, overview-page KPI and analytical cards,
//          service ZUI_CD_FMON_FLOW): one row per business date, measures already summed and
//          summable again ($apply) across dates. Read access: DCL ZC_CD_FMONFLOW. Read-only.
// Modification log: 2026-11-06 | Initial version (FMON file monitoring dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'FMON file monitoring dashboard - KPI'
@Metadata.allowExtensions: true
define root view entity ZC_CD_FmonFlowKpi
  provider contract transactional_query
  as projection on ZR_CD_FmonFlowKpi
{
  key BusinessDate,
      PaymentEngineArea,
      IsToday,
      AsOfAt,
      @Aggregation.default: #MAX
      MonitorAgeMinutes,
      MonitorIsStale,
      MonitorCriticality,
      @Aggregation.default: #SUM
      FileCount,
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
      SuccessFileCount,
      @Aggregation.default: #SUM
      ProcessedFileCount,
      @Aggregation.default: #SUM
      SentFileCount,
      @Aggregation.default: #SUM
      UnprocessedFileCount,
      @Aggregation.default: #SUM
      UnprocessedCount,
      @Aggregation.default: #SUM
      BreachedFileCount,
      @Aggregation.default: #SUM
      LateFileCount,
      @Aggregation.default: #SUM
      OpenFindingCount,
      @Aggregation.default: #SUM
      RecordCount,
      DayCriticality
}
