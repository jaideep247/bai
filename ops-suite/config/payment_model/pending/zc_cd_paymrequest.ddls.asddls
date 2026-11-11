// Artifact: zc_cd_paymrequest.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - payment request object page (entity PaymentRequest of ZUI_CD_PAYM):
//          source, transaction, received time, request status, amount where configured, attempts, timeline and
//          the payments it ended in. Read access: DCL ZC_CD_PAYM.
// Modification log: 2026-11-11 | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payment model - payment request'
@Metadata.allowExtensions: true
define root view entity ZC_CD_PaymRequest
  provider contract transactional_query
  as projection on ZR_CD_PaymRequest
{
  key RequestReference,
      _Payments : redirected to ZC_CD_PaymReqLink,
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
