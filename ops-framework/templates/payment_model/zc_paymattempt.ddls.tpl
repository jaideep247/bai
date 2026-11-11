// Artifact: zc_{{p}}_paymattempt.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the {{CONSUMER}} - attempts of a request (entity PaymentRequestAttempt of {{SERVICE}}).
//          Read access: DCL ZC_{{P}}_PAYM.
// Modification log: {{SINCE}} | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payment model - request attempt'
@Metadata.allowExtensions: true
define root view entity ZC_{{P}}_PaymAttempt
  provider contract transactional_query
  as projection on ZR_{{P}}_PaymAttempt
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
