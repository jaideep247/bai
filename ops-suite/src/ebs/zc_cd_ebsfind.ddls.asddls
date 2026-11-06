// Artifact: zc_cd_ebsfind.ddls.asddls
// Purpose: Consumption view of the EBS findings (service ZUI_CD_EBS_DASH): findings by rule and severity
//          (analytical list page "EBS findings"), leaf of every drill-down. Account numbers
//          are masked; statement messages of the file source are not exposed.
//          Read access: DCL ZC_CD_EBSDASH (ZCD_OPS, ZCD_PE_AREA = EBS, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'EBS validation dashboard - finding'
@Metadata.allowExtensions: true
define root view entity ZC_CD_EbsFind
  provider contract transactional_query
  as projection on ZR_CD_EbsFind
{
  key RunId,
  key FindingNo,
      PaymentEngineArea,
      ObjectType,
      ObjectKey,
      StatementSource,
      StmtObjectKey,
      LineObjectKey,
      LineNo,
      BaiCode,
      Category,
      BankKey,
      AccountMasked,
      RuleId,
      RuleText,
      CheckCode,
      Severity,
      SeverityCriticality,
      FindingAction,
      Amount,
      Currency,
      Reference,
      FindingMessage,
      Disposition,
      IsOpen,
      IsPostingIncomplete,
      IsDuplicate,
      Owner,
      DueDate,
      FirstSeenAt,
      Occurrences,
      CreatedAt,
      CreatedDate,
      @Aggregation.default: #SUM
      FindingCount,
      @Aggregation.default: #SUM
      OpenFindingCount
}
