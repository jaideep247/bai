// Artifact: zc_cd_opscritexc.ddls.asddls
// Purpose: Consumption view of the open critical exceptions across areas (overview-page list card,
//          service ZUI_CD_OPS_OVERVIEW): open / assigned B and E findings, overdue first.
//          Read access: DCL ZC_CD_OPSOVERVIEW (ZCD_OPS, ZCA_PARAR of the row, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (production-support overview page).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Production support - critical exceptions'
@Metadata.allowExtensions: true
define root view entity ZC_CD_OpsCritExc
  provider contract transactional_query
  as projection on ZR_CD_OpsCritExc
{
  key RunId,
  key FindingNo,
      PaymentEngineArea,
      ObjectType,
      ObjectKey,
      Detail,
      RuleId,
      CheckCode,
      Severity,
      SeverityCriticality,
      FindingMessage,
      Disposition,
      Owner,
      DueDate,
      IsOverdue,
      @Aggregation.default: #MAX
      DaysOverdue,
      FirstSeenAt,
      CreatedAt,
      @Aggregation.default: #SUM
      ExceptionCount
}
