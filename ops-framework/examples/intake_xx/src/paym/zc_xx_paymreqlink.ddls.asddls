// Artifact: zc_xx_paymreqlink.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the example customer XX (intake) - payment to request link (entity PaymentRequestLink of ZUI_XX_PAYM):
//          the requests table of the payment object page and the payments table of the request object page.
//          Read access: DCL ZC_XX_PAYM.
// Modification log: 2026-11-16 | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payment model - payment to request'
@Metadata.allowExtensions: true
define root view entity ZC_XX_PaymReqLink
  provider contract transactional_query
  as projection on ZR_XX_PaymReqLink
{
  key PaymentDocument,
  key RequestReference,
      _Payments : redirected to ZC_XX_Payment,
      _Request  : redirected to ZC_XX_PaymRequest,
      CompanyCode,
      OpsArea
}
