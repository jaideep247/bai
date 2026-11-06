// Artifact: zc_cd_ebsrun.ddls.asddls
// Purpose: Consumption view of the EBS validation runs (service ZUI_CD_EBS_DASH): run history with line
//          counters and finding counts, default aggregation of every measure, drill-down to
//          the findings of the run.
//          Read access: DCL ZC_CD_EBSDASH (ZCD_OPS, ZCD_PE_AREA = EBS, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'EBS validation dashboard - run'
@Metadata.allowExtensions: true
define root view entity ZC_CD_EbsRun
  provider contract transactional_query
  as projection on ZR_CD_EbsRun
{
  key RunId,
      PaymentEngineArea,
      RunVariant,
      StartedAt,
      EndedAt,
      RunDate,
      RunStatus,
      RunRag,
      RagCriticality,
      IsCompleted,
      IsAsOfRun,
      RuntimeMs,
      RunMessage,
      @Aggregation.default: #SUM
      RunCount,
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
      @Aggregation.default: #SUM
      LinesWithFindings,
      _Findings : redirected to ZC_CD_EbsFind
}
