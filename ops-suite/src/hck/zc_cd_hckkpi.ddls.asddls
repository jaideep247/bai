// Artifact: zc_cd_hckkpi.ddls.asddls
// Purpose: Consumption view of the morning report KPI (tiles, overview-page KPI card, service ZUI_CD_HCK_DASH):
//          last completed run and the open exceptions now, one row.
//          Read access: DCL ZC_CD_HCKDASH (ZCD_OPS, ZCA_PARAR = HCK, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
//                   2026-11-10 | Company code of the KPI slice (company-code isolation).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'HCK health check dashboard - KPI'
@Metadata.allowExtensions: true
define root view entity ZC_CD_HckKpi
  provider contract transactional_query
  as projection on ZR_CD_HckKpi
{
  key PaymentEngineArea,
  key CompanyCode,
      RunId,
      RunVariant,
      AsOfAt,
      RunRag,
      RagCriticality,
      RunMessage,
      AgeMinutes,
      IsStale,
      StaleCriticality,
      CheckCount,
      GreenCheckCount,
      AmberCheckCount,
      RedCheckCount,
      WarmupCheckCount,
      OpenFindingCount,
      OpenRedCount,
      OpenAmberCount,
      OverdueCount
}
