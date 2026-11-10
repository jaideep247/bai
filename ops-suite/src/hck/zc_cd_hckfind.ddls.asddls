// Artifact: zc_cd_hckfind.ddls.asddls
// Purpose: Consumption view of the morning report findings (service ZUI_CD_HCK_DASH): leaf of the drill-down
//          (check / metric / run -> findings).
//          Read access: DCL ZC_CD_HCKDASH (ZCD_OPS, ZCA_PARAR = HCK, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'HCK health check dashboard - finding'
@Metadata.allowExtensions: true
define root view entity ZC_CD_HckFind
  provider contract transactional_query
  as projection on ZR_CD_HckFind
{
  key RunId,
  key FindingNo,
      PaymentEngineArea,
      CheckId,
      CheckText,
      Category,
      ObjectKey,
      Reference,
      CheckCode,
      Severity,
      SeverityCriticality,
      IsWarmup,
      FindingMessage,
      Disposition,
      IsOpen,
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
