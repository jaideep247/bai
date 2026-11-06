// Artifact: zc_cd_ebsstmt.ddls.asddls
// Purpose: Consumption view of the EBS validation dashboard (analytical list page, OData V4,
//          service ZUI_CD_EBS_DASH): imported statements with validation status, default aggregation
//          of every measure, drill-down to lines and open findings. UI annotations in the
//          metadata extension ZC_CD_EBSSTMT.
//          Read access: DCL ZC_CD_EBSDASH (ZCD_OPS, ZCD_PE_AREA = EBS, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'EBS validation dashboard'
@Metadata.allowExtensions: true
// VERIFY-ADT: OData V4 data aggregation of a transactional_query projection without
// behaviour definition (as ZC_CD_FmonFlow)
define root view entity ZC_CD_EbsStmt
  provider contract transactional_query
  as projection on ZR_CD_EbsStmt
{
  key Kukey,
      StmtObjectKey,
      PaymentEngineArea,
      CompanyCode,
      HouseBank,
      HouseBankAccount,
      StatementNo,
      StatementDate,
      Currency,
      IsToday,
      ValidationStatus,
      ValidationCriticality,
      WorstSeverity,
      AsOfAt,
      AsOfRunId,
      MonitorAgeMinutes,
      MonitorIsStale,
      MonitorCriticality,
      @Aggregation.default: #SUM
      StatementCount,
      @Aggregation.default: #SUM
      LineCount,
      @Aggregation.default: #SUM
      PostedLineCount,
      @Aggregation.default: #SUM
      OpenFindingCount,
      @Aggregation.default: #SUM
      BlockFindingCount,
      @Aggregation.default: #SUM
      ErrorFindingCount,
      @Aggregation.default: #SUM
      WarningFindingCount,
      @Aggregation.default: #SUM
      LineFindingCount,
      @Aggregation.default: #SUM
      DuplicateCount,
      @Aggregation.default: #SUM
      PostingIncompleteStmtCount,
      @Aggregation.default: #SUM
      NoFindingStmtCount,
      _Lines : redirected to ZC_CD_EbsLine,
      _Findings : redirected to ZC_CD_EbsFind
}
