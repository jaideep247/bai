// Artifact: zc_cd_paylifecycle.ddls.asddls
// Purpose: Consumption view of the payment lifecycle (overview page, entity PaymentLifecycle): payments of the
//          business date per configured stage and company code - analytical card (bars in stage order).
//          Read access: DCL ZC_CD_OPSOVERVIEW (area CD_OPS and the company code of the base rows; request rows
//          carry no company code - BUKRS blank as on the transactions dashboard). Read-only.
// Modification log: 2026-11-10 | Initial version (control center: payment lifecycle).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Production support - payment lifecycle'
@Metadata.allowExtensions: true
define root view entity ZC_CD_PayLifecycle
  provider contract transactional_query
  as projection on ZR_CD_PayLifecycle
{
  key BusinessDate,
  key CompanyCode,
      @ObjectModel.text.element: [ 'StageLabel' ]
  key Stage,
      StageSequence,
      @Semantics.text: true
      StageLabel,
      StageSource,
      PaymentEngineArea,
      IsCurrentDay,
      @Aggregation.default: #SUM
      PaymentCount
}
