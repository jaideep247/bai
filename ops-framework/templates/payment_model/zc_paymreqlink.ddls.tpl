// Artifact: zc_{{p}}_paymreqlink.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the {{CONSUMER}} - payment to request link (entity PaymentRequestLink of {{SERVICE}}):
//          the requests table of the payment object page and the payments table of the request object page.
//          Read access: DCL ZC_{{P}}_PAYM.
// Modification log: {{SINCE}} | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payment model - payment to request'
@Metadata.allowExtensions: true
define root view entity ZC_{{P}}_PaymReqLink
  provider contract transactional_query
  as projection on ZR_{{P}}_PaymReqLink
{
  key PaymentDocument,
  key RequestReference,
      _Payments : redirected to ZC_{{P}}_Payment,
#if REQUEST
      _Request  : redirected to ZC_{{P}}_PaymRequest,
#endif
      CompanyCode,
      OpsArea
}
