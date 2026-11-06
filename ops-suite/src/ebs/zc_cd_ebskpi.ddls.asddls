// Artifact: zc_cd_ebskpi.ddls.asddls
// Purpose: Consumption view of the EBS KPI entity (tiles, overview-page KPI and analytical cards,
//          service ZUI_CD_EBS_DASH): one row per run date = the last completed run of that date.
//          Read access: DCL ZC_CD_EBSDASH (ZCD_OPS, ZCD_PE_AREA = EBS, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'EBS validation dashboard - KPI'
@Metadata.allowExtensions: true
define root view entity ZC_CD_EbsKpi
  provider contract transactional_query
  as projection on ZR_CD_EbsKpi
{
  key RunDate,
      PaymentEngineArea,
      RunId,
      RunVariant,
      RunRag,
      RagCriticality,
      IsToday,
      IsLatest,
      CompletedRunCount,
      AsOfAt,
      @Aggregation.default: #MAX
      MonitorAgeMinutes,
      MonitorIsStale,
      MonitorCriticality,
      @Aggregation.default: #SUM
      LineCount,
      @Aggregation.default: #SUM
      PassedLineCount,
      @Aggregation.default: #SUM
      WarningLineCount,
      @Aggregation.default: #SUM
      FailedLineCount,
      @Aggregation.default: #SUM
      BlockedLineCount,
      @Aggregation.default: #SUM
      UnevaluatedLineCount,
      @Aggregation.default: #SUM
      FindingCount,
      @Aggregation.default: #SUM
      BlockFindingCount,
      @Aggregation.default: #SUM
      ErrorFindingCount,
      @Aggregation.default: #SUM
      WarningFindingCount,
      @Aggregation.default: #SUM
      PostingIncompleteCount,
      @Aggregation.default: #SUM
      DuplicateCount,
      @Aggregation.default: #SUM
      UnmappedCodeCount,
      @Aggregation.default: #SUM
      StatementsWithFindings,
      DayCriticality
}
