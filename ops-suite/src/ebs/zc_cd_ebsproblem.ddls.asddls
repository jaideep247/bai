// Artifact: zc_cd_ebsproblem.ddls.asddls
// Purpose: Consumption view of the latest EBS problems (overview-page list card, service ZUI_CD_EBS_DASH):
//          open B / E findings and open POSTING_INCOMPLETE, newest first.
//          Read access: DCL ZC_CD_EBSDASH (ZCD_OPS, ZCA_PARAR = EBS, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'EBS validation dashboard - problems'
@Metadata.allowExtensions: true
define root view entity ZC_CD_EbsProblem
  provider contract transactional_query
  as projection on ZR_CD_EbsProblem
{
  key RunId,
  key FindingNo,
      PaymentEngineArea,
      CompanyCode,
      ObjectType,
      ObjectKey,
      StmtObjectKey,
      LineNo,
      BaiCode,
      BankKey,
      RuleId,
      RuleText,
      CheckCode,
      Severity,
      SeverityCriticality,
      FindingMessage,
      Owner,
      DueDate,
      CreatedAt,
      CreatedDate
}
