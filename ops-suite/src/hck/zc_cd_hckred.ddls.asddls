// Artifact: zc_cd_hckred.ddls.asddls
// Purpose: Consumption view of the red / amber checks of the last run (overview-page list card,
//          service ZUI_CD_HCK_DASH), red first.
//          Read access: DCL ZC_CD_HCKDASH (ZCD_OPS, ZCD_PE_AREA = HCK, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'HCK health check dashboard - red checks'
@Metadata.allowExtensions: true
define root view entity ZC_CD_HckRed
  provider contract transactional_query
  as projection on ZR_CD_HckRed
{
  key CheckId,
      PaymentEngineArea,
      CheckText,
      Category,
      CategoryText,
      Priority,
      CheckStatus,
      StatusCriticality,
      StatusOrder,
      OpenFindingCount,
      OldestDueDate,
      AsOfAt
}
