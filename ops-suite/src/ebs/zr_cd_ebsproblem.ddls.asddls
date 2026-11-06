// Artifact: zr_cd_ebsproblem.ddls.asddls
// Purpose: "Latest problems" list of the EBS validation dashboard (launchpad list tile and the
//          production-support overview page list card): open EBS findings of severity B (block)
//          or E (error), and every open POSTING_INCOMPLETE (S13, posting-dependent rules not
//          evaluated) - newest first (presentation variant), the card shows the top n. Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS validation dashboard - latest problems'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #MIXED }
define root view entity ZR_CD_EbsProblem
  as select from ZR_CD_EbsFind
{
  key RunId,
  key FindingNo,
      PaymentEngineArea,
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
where IsOpen = 'X'
  and ( Severity = 'B' or Severity = 'E' or IsPostingIncomplete = 'X' )
