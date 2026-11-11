// Artifact: zc_{{p}}_paymrequest.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the {{CONSUMER}} - payment request object page (entity PaymentRequest of {{SERVICE}}):
//          source, transaction, received time, request status, amount where configured, attempts, timeline and
//          the payments it ended in. Read access: DCL ZC_{{P}}_PAYM.
// Modification log: {{SINCE}} | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payment model - payment request'
@Metadata.allowExtensions: true
define root view entity ZC_{{P}}_PaymRequest
  provider contract transactional_query
  as projection on ZR_{{P}}_PaymRequest
{
  key RequestReference,
      _Payments : redirected to ZC_{{P}}_PaymReqLink,
#if ATTEMPT
      _Attempts : redirected to ZC_{{P}}_PaymAttempt,
#endif
#if EVENT
      _Events   : redirected to ZC_{{P}}_PaymEvent,
#endif
      BusinessDate,
      ReceivedAt,
      CompanyCode,
      OpsArea,
      @ObjectModel.text.element: [ 'FeederName' ]
      Source,
      @Semantics.text: true
      FeederName,
      @ObjectModel.text.element: [ 'TransactionText' ]
      TransactionType,
      @Semantics.text: true
      TransactionText,
      RequestStatus,
      ProcessingStatus,
      FeederReference,
      FeederUrl,
      Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Amount
}
