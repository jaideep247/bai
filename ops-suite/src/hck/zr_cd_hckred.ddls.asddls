// Artifact: zr_cd_hckred.ddls.asddls
// Purpose: "Reds" list of the health check dashboard (launchpad list tile and the production-support
//          overview page list card): active checks that are RED or AMBER in the last completed
//          morning report run, red first, with category, priority and open exceptions. Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK health check dashboard - red checks'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #S, dataClass: #MIXED }
define root view entity ZR_CD_HckRed
  as select from ZR_CD_HckCheck
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
where CheckStatus = 'RED'
   or CheckStatus = 'AMBER'
