// Artifact: zc_cd_fmonflowqry.ddls.asddls
// Purpose: Analytical query of the file monitoring cube (Analysis for Office / query browser):
//          files, successful, rejected, records and control totals per source / LOB / payment
//          method and business date. Release-dependent syntax: verify on target release.
// Modification log: 2026-11-06 | Initial version (FMON file monitoring dashboard).
// Authorization: enforced on ZI_CD_FmonFlowCube (DCL ZI_CD_OpsAnalytics).
@EndUserText.label: 'FMON file monitoring - query'
define transient view entity ZC_CD_FmonFlowQry
  provider contract analytical_query
  as projection on ZI_CD_FmonFlowCube
{
  @AnalyticsDetails.query.axis: #ROWS
  SourceSystem,
  @AnalyticsDetails.query.axis: #ROWS
  Lob,
  @AnalyticsDetails.query.axis: #ROWS
  PaymentMethod,
  @AnalyticsDetails.query.axis: #FREE
  @Consumption.filter: { selectionType: #INTERVAL, multipleSelections: false }
  BusinessDate,
  @AnalyticsDetails.query.axis: #FREE
  IfaceId,
  @AnalyticsDetails.query.axis: #FREE
  Direction,
  @AnalyticsDetails.query.axis: #FREE
  BankKey,
  @AnalyticsDetails.query.axis: #FREE
  FlowBucket,
  @AnalyticsDetails.query.axis: #COLUMNS
  FileCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  SuccessFileCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  RejectedFileCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  PartialFileCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  RecordCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  ControlTotal,
  @AnalyticsDetails.query.axis: #FREE
  AckCount,
  @AnalyticsDetails.query.axis: #FREE
  NackCount,
  @AnalyticsDetails.query.axis: #FREE
  UnprocessedCount
}
