// Artifact: zc_cd_paymreqlink.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - payment to request link (entity PaymentRequestLink of ZUI_CD_PAYM):
//          the requests table of the payment object page and the payments table of the request object page.
//          Read access: DCL ZC_CD_PAYM.
// Modification log: 2026-11-11 | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payment model - payment to request'
@Metadata.allowExtensions: true
define root view entity ZC_CD_PaymReqLink
  provider contract transactional_query
  as projection on ZR_CD_PaymReqLink
{
  key PaymentDocument,
  key RequestReference,
      _Payments : redirected to ZC_CD_Payment,
      CompanyCode,
      OpsArea
}
