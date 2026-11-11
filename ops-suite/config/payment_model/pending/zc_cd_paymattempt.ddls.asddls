// Artifact: zc_cd_paymattempt.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - attempts of a request (entity PaymentRequestAttempt of ZUI_CD_PAYM).
//          Read access: DCL ZC_CD_PAYM.
// Modification log: 2026-11-11 | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payment model - request attempt'
@Metadata.allowExtensions: true
define root view entity ZC_CD_PaymAttempt
  provider contract transactional_query
  as projection on ZR_CD_PaymAttempt
{
      @EndUserText.label: 'Request reference'
  key RequestReference,
      @EndUserText.label: 'Attempt'
      @UI.lineItem: [ { position: 10 } ]
  key AttemptNumber,
      @EndUserText.label: 'Company code'
      CompanyCode,
      @UI.hidden: true
      OpsArea,
      @EndUserText.label: 'Processing status'
      @UI.lineItem: [ { position: 20 } ]
      ProcessingStatus,
      @EndUserText.label: 'Received at'
      @UI.lineItem: [ { position: 30 } ]
      ReceivedAt,
      @EndUserText.label: 'Accepted attempt'
      @UI.lineItem: [ { position: 40 } ]
      IsAccepted
}
